{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
-- Generate idiomatic haskell data types from the types in IR.
module Backends.Pure
    ( fmtModule
    ) where

import IR
import Util

import Data.Monoid ((<>))
import Data.String (IsString(..))
import GHC.Exts    (IsList(..))
import Text.Printf (printf)

import qualified Data.Map.Strict as M
import qualified Data.Text       as T

import           Text.PrettyPrint.Leijen.Text (hcat, vcat)
import qualified Text.PrettyPrint.Leijen.Text as PP

indent = PP.indent 4

-- | If a module reference refers to a generated module, does it
-- refer to the raw, low-level module or the *.Pure variant (which
-- this module generates)?
data ModRefType = Pure | Raw
    deriving(Show, Read, Eq)

fmtName :: ModRefType -> Id -> Name -> PP.Doc
fmtName refTy thisMod Name{..} = modPrefix <> localName
  where
    localName = mintercalate "'" $
        map PP.textStrict $ fromList $ toList nameLocalNS ++ [nameUnqualified]
    modPrefix
        | null nsParts = ""
        | refTy == Pure && modRefToNS refTy (ByCapnpId thisMod) == ns = ""
        | otherwise = fmtModRef refTy nameModule <> "."
    ns@(Namespace nsParts) = modRefToNS refTy nameModule

modRefToNS :: ModRefType -> ModuleRef -> Namespace
modRefToNS _ (FullyQualified ns) = ns
modRefToNS ty (ByCapnpId id) = Namespace $ case ty of
    Pure -> ["Capnp", "ById", T.pack (printf "X%x" id), "Pure"]
    Raw  -> ["Capnp", "ById", T.pack (printf "X%x" id)]


fmtModule :: Module -> [(FilePath, PP.Doc)]
fmtModule mod@Module{modName=Namespace modNameParts,..} =
    [ ( T.unpack $ mintercalate "/" humanParts <> ".hs"
      , mainContent
      )
    , ( printf "Capnp/ById/X%x/Pure.hs" modId
      , vcat
            [ "{-# OPTIONS_GHC -Wno-unused-imports #-}"
            , "{- |"
            , hcat [ "Module: ", machineMod ]
            , hcat [ "Description: Machine-addressable alias for '", humanMod, "'." ]
            , "-}"
            , hcat [ "module ", machineMod, "(module ", humanMod, ") where" ]
            , ""
            , hcat [ "import ", humanMod ]
            ]
      )
    ]
 where
  machineMod = fmtModRef Pure (ByCapnpId modId)
  humanMod = fmtModRef Pure $ FullyQualified $ Namespace humanParts
  humanParts = "Capnp":modNameParts ++ ["Pure"]
  modFileText = PP.textStrict modFile
  mainContent = vcat
    [ "{-# LANGUAGE DuplicateRecordFields #-}"
    , "{-# LANGUAGE RecordWildCards #-}"
    , "{-# LANGUAGE FlexibleInstances #-}"
    , "{-# LANGUAGE FlexibleContexts #-}"
    , "{-# LANGUAGE MultiParamTypeClasses #-}"
    , "{-# LANGUAGE ScopedTypeVariables #-}"
    , "{-# OPTIONS_GHC -Wno-unused-imports #-}"
    , "{- |"
    , "Module: " <> humanMod
    , "Description: " <> "High-level generated module for " <> modFileText
    , ""
    , "This module is the generated code for " <> modFileText <> ","
    , "for the high-level api."
    , "-}"
    , "module " <> humanMod <> " (" <> fmtExportList mod, ") where"
    , ""
    , "-- Code generated by capnpc-haskell. DO NOT EDIT."
    , "-- Generated from schema file: " <> modFileText
    , ""
    , "import Data.Int"
    , "import Data.Word"
    , ""
    , "import Data.Capnp.Untyped.Pure (List)"
    , "import Data.Capnp.Basics.Pure (Data, Text)"
    , "import Control.Monad.Catch (MonadThrow)"
    , "import Data.Capnp.TraversalLimit (MonadLimit)"
    , ""
    , "import Control.Monad (forM_)"
    , ""
    , "import qualified Data.Capnp.Message as M'"
    , "import qualified Data.Capnp.Untyped.Pure as PU'"
    , "import qualified Codec.Capnp as C'"
    , ""
    , "import qualified Data.Vector as V"
    , ""
    , fmtImport Raw $ Import (ByCapnpId modId)
    , vcat $ map (fmtImport Pure) modImports
    , vcat $ map (fmtImport Raw) modImports
    , ""
    , vcat $ map (fmtDecl modId) (M.toList modDecls)
    ]

fmtExportList :: Module -> PP.Doc
fmtExportList Module{modId,modDecls} =
    mintercalate ", " (map (fmtExport modId) (M.toList modDecls))

fmtExport :: Id -> (Name, Decl) -> PP.Doc
fmtExport thisMod (name, DeclDef DataDef{dataCerialType}) = case dataCerialType of
    CTyStruct _ _ ->
        fmtName Pure thisMod name <> "(..)"
    CTyEnum ->
        -- This one is 'Raw' because we're just re-exporting these.
        fmtName Raw thisMod name <> "(..)"
fmtExport thisMod (name, DeclConst _) = fmtName Pure thisMod (valueName name)

fmtImport :: ModRefType -> Import -> PP.Doc
fmtImport ty (Import ref) = "import qualified " <> fmtModRef ty ref

fmtModRef :: ModRefType -> ModuleRef -> PP.Doc
fmtModRef ty ref = mintercalate "." (map PP.textStrict $ toList $ modRefToNS ty ref)

fmtType :: Id -> Type -> PP.Doc
fmtType thisMod (CompositeType (StructType name params)) =
    fmtName Pure thisMod name
    <> hcat [" (" <> fmtType thisMod ty <> ")" | ty <- params]
fmtType thisMod (WordType (EnumType name)) = fmtName Raw thisMod name
fmtType thisMod (PtrType (ListOf eltType)) = "List (" <> fmtType thisMod eltType <> ")"
fmtType thisMod (PtrType (PtrComposite ty)) = fmtType thisMod (CompositeType ty)
fmtType _ VoidType = "()"
fmtType _ (WordType (PrimWord prim)) = fmtPrimWord prim
fmtType _ (PtrType (PrimPtr PrimText)) = "Text"
fmtType _ (PtrType (PrimPtr PrimData)) = "Data"
fmtType _ (PtrType (PrimPtr (PrimAnyPtr ty))) = "Maybe (" <> fmtAnyPtr ty <> ")"

fmtPrimWord :: PrimWord -> PP.Doc
fmtPrimWord PrimInt{isSigned=True,size}  = "Int" <> fromString (show size)
fmtPrimWord PrimInt{isSigned=False,size} = "Word" <> fromString (show size)
fmtPrimWord PrimFloat32                  = "Float"
fmtPrimWord PrimFloat64                  = "Double"
fmtPrimWord PrimBool                     = "Bool"

fmtAnyPtr :: AnyPtr -> PP.Doc
fmtAnyPtr Struct = "PU'.Struct"
fmtAnyPtr List   = "PU'.List'"
fmtAnyPtr Cap    = "PU'.Cap"
fmtAnyPtr Ptr    = "PU'.PtrType"

fmtVariant :: Id -> Variant -> PP.Doc
fmtVariant thisMod Variant{variantName,variantParams} =
    fmtName Pure thisMod variantName
    <> case variantParams of
        Unnamed VoidType _ -> ""
        Unnamed ty _ -> " (" <> fmtType thisMod ty <> ")"
        Record [] -> ""
        Record fields -> PP.line <> indent
            (PP.braces $ vcat $
                PP.punctuate "," $ map (fmtField thisMod) fields)

fmtField :: Id -> Field -> PP.Doc
fmtField thisMod Field{fieldName,fieldLocType} =
    PP.textStrict fieldName <> " :: " <> fmtType thisMod fieldType
  where
    fieldType = case fieldLocType of
        VoidField      -> VoidType
        DataField _ ty -> WordType ty
        PtrField _ ty  -> PtrType ty
        HereField ty   -> CompositeType ty

fmtDecl :: Id -> (Name, Decl) -> PP.Doc
fmtDecl thisMod (name, DeclDef d)   = fmtDataDef thisMod name d
fmtDecl thisMod (name, DeclConst c) = fmtConst thisMod name c

-- | Format a constant declaration.
fmtConst :: Id -> Name -> Const -> PP.Doc
fmtConst thisMod name value =
    let pureName = fmtName Pure thisMod (valueName name)
        rawName = fmtName Raw thisMod (valueName name)
    in vcat
        -- We just define this as an alias for the one in the raw module.
        -- TODO: we should just re-export the existing constant instead
        -- (but note that when we support struct and list constants we'll
        -- have to handle those separately).
        [ hcat
            [ pureName, " :: ", case value of
                VoidConst -> "()"
                WordConst{wordType=PrimWord ty} -> fmtPrimWord ty
                WordConst{wordType=EnumType typeName} -> fmtName Raw thisMod typeName
            ]
        , hcat [ pureName, " = ", rawName ]
        ]

fmtDataDef :: Id -> Name -> DataDef -> PP.Doc
fmtDataDef thisMod dataName DataDef{dataCerialType=CTyEnum} =
    let rawName = fmtName Raw thisMod dataName in
    vcat
        [ hcat [ "instance C'.Decerialize ", rawName, " ", rawName, " where" ]
        , indent "decerialize = pure"
        ]
fmtDataDef thisMod dataName DataDef{dataVariants} =
    let rawName = fmtName Raw thisMod dataName
        pureName = fmtName Pure thisMod dataName
    in vcat
        [ hcat [ "data ", fmtName Pure thisMod dataName ]
        , indent $ " = " <> vcat (PP.punctuate " |" $ map (fmtVariant thisMod) dataVariants)
        , indent "deriving(Show, Read, Eq)"
        , hcat [ "instance C'.Decerialize (", rawName, " M'.ConstMsg) ", pureName, " where" ]
        , indent $ "decerialize raw = " <> case dataVariants of
            [Variant{variantName,variantParams=Record fields}] ->
                fmtDecerializeArgs variantName fields
            _ -> vcat
                [ "do"
                , indent $ vcat
                    [ hcat [ "raw <- ", fmtName Raw thisMod $ prefixName "get_" (subName dataName ""), " raw" ]
                    , "case raw of"
                    , indent $ vcat (map fmtDecerializeVariant dataVariants)
                    ]
                ]
        , hcat [ "instance C'.IsStruct M'.ConstMsg ", pureName, " where" ]
        , indent $ vcat
            [ "fromStruct struct = do"
            , indent $ vcat
                [ "raw <- C'.fromStruct struct"
                , hcat [ "C'.decerialize (raw :: ", rawName, " M'.ConstMsg)" ]
                ]
            ]
        , hcat [ "instance C'.Cerialize s ", pureName, " (", rawName, " (M'.MutMsg s)) where" ]
        , indent $ vcat
            [ "marshalInto raw value = do"
            , indent $ vcat
                [ "case value of\n"
                , indent $ vcat $ map
                    (fmtCerializeVariant (length dataVariants /= 1))
                    dataVariants
                ]
            ]
        ]
  where
    fmtDecerializeArgs variantName fields = vcat
        [ hcat [ fmtName Pure thisMod variantName, " <$>" ]
        , indent $ vcat $ PP.punctuate " <*>" $
            flip map fields $ \Field{fieldName} -> hcat
                [ "(", fmtName Raw thisMod $ prefixName "get_" (subName variantName fieldName)
                , " raw >>= C'.decerialize)"
                ]
        ]
    fmtDecerializeVariant Variant{variantName,variantParams} =
        fmtName Raw thisMod variantName <>
        case variantParams of
            Unnamed VoidType _ -> " -> pure " <> fmtName Pure thisMod variantName
            Record fields ->
              " raw -> " <> fmtDecerializeArgs variantName fields
            _ -> hcat
                [ " val -> "
                , fmtName Pure thisMod variantName
                , " <$> C'.decerialize val"
                ]
    fmtCerializeVariant isUnion Variant{variantName, variantParams} =
        fmtName Pure thisMod variantName <>
        let setterName = fmtName Raw thisMod (prefixName "set_" variantName)
            setTag = if isUnion
                then "raw <- " <> setterName <> " raw"
                else ""
        in case variantParams of
            Unnamed VoidType _ -> hcat [ " -> ", setterName, " raw" ]
            Record fields -> vcat
                [ "{..} -> do"
                , indent $ vcat
                    [ setTag
                    , vcat (map (fmtCerializeField variantName) fields)
                    ]
                ]
            _ ->
                " _ -> pure ()" -- TODO
    fmtCerializeField variantName Field{fieldName,fieldLocType} =
        let accessorName prefix = fmtName Raw thisMod $ prefixName prefix (subName variantName fieldName)
            setterName = accessorName "set_"
            getterName = accessorName "get_"
            newName = accessorName "new_"
            fieldNameText = PP.textStrict fieldName
        in case fieldLocType of
            DataField _ _ -> hcat [ setterName, " raw ", fieldNameText ]
            VoidField -> hcat [ setterName, " raw" ]
            HereField _ -> vcat
                [ hcat [ "field_ <- ", getterName, " raw" ]
                , hcat [ "C'.marshalInto field_ ", fieldNameText ]
                ]
            PtrField _ ty -> case ty of
                PrimPtr PrimData -> vcat
                    [ hcat [ "field_ <- newData (BS.length ", fieldNameText, ")"]
                    , hcat [ "C'.marshalInto field_ ", fieldNameText ]
                    ]
                ListOf eltType -> vcat
                    [ hcat [ "let len_ = V.length ", fieldNameText ]
                    , hcat [ "field_ <- ", newName, " len_ raw" ]
                    , case eltType of
                        (CompositeType (StructType _ _)) -> vcat
                            [ "forM_ [0..len_ - 1] $ \\i -> do"
                            , indent $ vcat
                                [ "elt <- C'.index i field_"
                                , hcat [ "C'.marshalInto elt (", fieldNameText, " V.! i)" ]
                                ]
                            ]
                        _ ->  "pure ()" -- TODO
                    ]
                _ -> "pure ()"
