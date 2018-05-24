-- Generate low-level accessors from type types in IR.
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module FmtRaw
    ( fmtModule
    ) where

import IR

import Data.Capnp.Core.Schema (Id)
import Data.List              (sortOn)
import Data.Monoid            ((<>))
import Text.Printf            (printf)
import Util                   (mintercalate)

import qualified Data.Text.Lazy.Builder as TB

fmtModule :: Module -> TB.Builder
fmtModule Module{..} = mintercalate "\n"
    [ "{-# OPTIONS_GHC -Wno-unused-imports #-}"
    , "{-# LANGUAGE FlexibleInstances #-}"
    , "{-# LANGUAGE MultiParamTypeClasses #-}"
    , "module " <> fmtModRef (ByCapnpId modId) <> " where"
    , ""
    , "-- Code generated by capnpc-haskell. DO NOT EDIT."
    , "-- Generated from schema file: " <> TB.fromText modFile
    , ""
    , "import Data.Int"
    , "import Data.Word"
    , "import qualified Data.Bits"
    , ""
    , "import qualified Codec.Capnp"
    , "import qualified Data.Capnp.BuiltinTypes"
    , "import qualified Data.Capnp.TraversalLimit"
    , "import qualified Data.Capnp.Untyped"
    , ""
    , mintercalate "\n" $ map fmtImport modImports
    , ""
    , mintercalate "\n" $ map (fmtDataDef modId) modDefs
    ]

fmtModRef :: ModuleRef -> TB.Builder
fmtModRef (ByCapnpId id) = TB.fromString $ printf "Data.Capnp.ById.X%x" id
fmtModRef (FullyQualified (Namespace ns)) = mintercalate "." (map TB.fromText ns)

fmtImport :: Import -> TB.Builder
fmtImport (Import ref) = "import qualified " <> fmtModRef ref

fmtNewtypeStruct :: Id -> Name -> TB.Builder
fmtNewtypeStruct thisMod name =
    let nameText = fmtName thisMod name
    in mconcat
        [ "newtype "
        , nameText
        , " b = "
        , nameText
        , " (Data.Capnp.Untyped.Struct b)\n\n"
        ]


fmtFieldAccessor :: Id -> Name -> Name -> Field -> TB.Builder
fmtFieldAccessor thisMod typeName variantName Field{..} =
    let accessorName = "get_" <> fmtName thisMod (subName variantName fieldName)
    in mconcat
        [ accessorName, " :: Data.Capnp.Untyped.ReadCtx m b => "
        , fmtName thisMod typeName, " b -> m ", fmtType thisMod fieldType, "\n"
        , accessorName
        , " (", fmtName thisMod typeName, " struct) =", case fieldLoc of
            DataField DataLoc{..} -> mconcat
                [ " fmap\n"
                , "    ( Codec.Capnp.fromWord\n"
                , "    . Data.Bits.xor ", TB.fromString (show dataDef), "\n"
                , "    . (`Data.Bits.shiftR` ", TB.fromString (show dataOff), ")\n"
                , "    )\n"
                , "    (Data.Capnp.Untyped.getData ", TB.fromString (show dataIdx), " struct)\n"
                ]
            PtrField idx -> mconcat
                [ "\n    Data.Capnp.Untyped.getPtr ", TB.fromString (show idx), " struct"
                , "\n    >>= Codec.Capnp.fromPtr (Data.Capnp.Untyped.message struct)"
                , "\n"
                ]
            HereField -> " undefined -- TODO: handle groups/anonymous union fields"
            VoidField -> " Data.Capnp.TraversalLimit.invoice 1 >> pure ()"
        ]

fmtDataDef :: Id -> DataDef -> TB.Builder
fmtDataDef thisMod DataDef{dataVariants=[Variant{..}], dataCerialType=CTyStruct, ..} =
    fmtNewtypeStruct thisMod dataName <>
    case variantParams of
        Record fields ->
            mintercalate "\n" $ map (fmtFieldAccessor thisMod dataName variantName) fields
        _ -> ""
    <> let nameText = fmtName thisMod dataName
       in mconcat
            [ "\ninstance Codec.Capnp.IsPtr (", nameText, " b) b where"
            , "\n    fromPtr msg ptr = fmap ", nameText, " (Codec.Capnp.fromPtr msg ptr)"
            , "\n"
            ]
fmtDataDef thisMod DataDef{dataCerialType=CTyStruct,..} =
    let nameText = fmtName thisMod dataName
    in mconcat
        [ "data ", nameText, " b"
        , "\n    = "
        , mintercalate "\n    | " (map fmtDataVariant dataVariants)
        -- Generate auxiliary newtype definitions for group fields:
        , "\n"
        , mintercalate "\n" (map fmtVariantAuxNewtype dataVariants)
        , "\ninstance Codec.Capnp.IsPtr (", nameText, " b) b where"
        , "\n    fromPtr = undefined -- TODO: define fromPtr for sums."
        ]
  where
    fmtDataVariant Variant{..} = fmtName thisMod variantName <>
        case variantParams of
            Record _   -> " (" <> fmtName thisMod (subName variantName "group'") <> " b)"
            NoParams   -> ""
            Unnamed ty -> " " <> fmtType thisMod ty
    fmtVariantAuxNewtype Variant{variantName, variantParams=Record fields} =
        let typeName = subName variantName "group'"
        in fmtNewtypeStruct thisMod typeName <>
            mintercalate "\n" (map (fmtFieldAccessor thisMod typeName variantName) fields)
    fmtVariantAuxNewtype _ = ""
-- Assume this is an enum, for now:
fmtDataDef thisMod DataDef{dataCerialType=CTyWord 16,..} =
    let typeName = fmtName thisMod dataName
    in mconcat
        [ "data ", typeName, " b"
        , "\n    = "
        , mintercalate "\n    | " (map fmtEnumVariant dataVariants)
        , "\n"
        -- Generate an Enum instance. This is a trivial wrapper around the
        -- IsWord instance, below.
        , "instance Enum (", typeName, " b) where\n"
        , "    toEnum = Codec.Capnp.fromWord . fromIntegral\n"
        , "    fromEnum = fromIntegral . Codec.Capnp.toWord\n"
        , "\n\n"
        -- Generate an IsWord instance.
        , "instance Codec.Capnp.IsWord (", typeName, " b) where"
        , "\n    fromWord "
        , mintercalate "\n    fromWord " $
            map fmtEnumFromWordCase $ reverse $ sortOn variantTag dataVariants
        , "\n    toWord "
        , mintercalate "\n    toWord " $
            map fmtEnumToWordCase   $ reverse $ sortOn variantTag dataVariants
        , "\n"
        -- Generate an IsPtr instance for a list of this type.
        -- TODO: we ought to arrange for arbitrarily nested lists to have instances of
        -- IsPtr.
        , "instance Codec.Capnp.IsPtr (Data.Capnp.Untyped.ListOf b (", typeName, " b)) b where"
        , "\n    fromPtr msg ptr = fmap"
        , "\n       (fmap (toEnum . (fromIntegral :: Word16 -> Int)))"
        , "\n       (Codec.Capnp.fromPtr msg ptr)"
        , "\n"
        ]
  where
    -- | Format a data constructor in the definition of a data type for an enum.
    fmtEnumVariant Variant{variantName,variantParams=NoParams,variantTag=Just _} =
        fmtName thisMod variantName
    fmtEnumVariant Variant{variantName,variantParams=Unnamed ty, variantTag=Nothing} =
        fmtName thisMod variantName <> " " <> fmtType thisMod ty
    fmtEnumVariant variant =
        error $ "Unexpected variant for enum: " ++ show variant
    -- | Format an equation in an enum's IsWord.fromWord implementation.
    fmtEnumFromWordCase Variant{variantTag=Just tag,variantName} =
        -- For the tags we know about:
        TB.fromString (show tag) <> " = " <> fmtName thisMod variantName
    fmtEnumFromWordCase Variant{variantTag=Nothing,variantName} =
        -- For other tags:
        "tag = " <> fmtName thisMod variantName <> " (fromIntegral tag)"
    -- | Format an equation in an enum's IsWord.toWord implementation.
    fmtEnumToWordCase Variant{variantTag=Just tag,variantName} =
        fmtName thisMod variantName <> " = " <> TB.fromString (show tag)
    fmtEnumToWordCase Variant{variantTag=Nothing,variantName} =
        "(" <> fmtName thisMod variantName <> " tag) = fromIntegral tag"
fmtDataDef _ dataDef =
    error $ "Unexpected data definition: " ++ show dataDef

fmtType :: Id -> Type -> TB.Builder
fmtType thisMod = \case
    ListOf eltType ->
        "(Data.Capnp.Untyped.ListOf b " <> fmtType thisMod eltType <> ")"
    Type name [] ->
        "(" <> fmtName thisMod name <> " b)"
    Type name params -> mconcat
        [ "("
        , fmtName thisMod name
        , " b "
        , mintercalate " " $ map (fmtType thisMod) params
        , ")"
        ]
    PrimType prim -> fmtPrimType prim
    Untyped ty -> "(Maybe " <> fmtUntyped ty <> ")"

fmtPrimType :: PrimType -> TB.Builder
-- TODO: most of this (except Text & Data) should probably be shared with FmtPure.
fmtPrimType PrimInt{isSigned=True,size}  = "Int" <> TB.fromString (show size)
fmtPrimType PrimInt{isSigned=False,size} = "Word" <> TB.fromString (show size)
fmtPrimType PrimFloat32                  = "Float"
fmtPrimType PrimFloat64                  = "Double"
fmtPrimType PrimBool                     = "Bool"
fmtPrimType PrimVoid                     = "()"
fmtPrimType PrimText                     = "(Data.Capnp.BuiltinTypes.Text b)"
fmtPrimType PrimData                     = "(Data.Capnp.BuiltinTypes.Data b)"

fmtUntyped :: Untyped -> TB.Builder
fmtUntyped Struct = "(Data.Capnp.Untyped.Struct b)"
fmtUntyped List   = "(Data.Capnp.Untyped.List b)"
fmtUntyped Cap    = "Word32"
fmtUntyped Ptr    = "(Data.Capnp.Untyped.Ptr b)"

fmtName :: Id -> Name -> TB.Builder
fmtName thisMod Name{nameModule, nameLocalNS=Namespace parts, nameUnqualified=localName} =
    modPrefix <> mintercalate "'" (map TB.fromText $ parts <> [localName])
  where
    modPrefix = case nameModule of
        ByCapnpId id                  | id == thisMod -> ""
        FullyQualified (Namespace []) -> ""
        _                             -> fmtModRef nameModule <> "."
