-- Generate low-level accessors from type types in IR.
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module Backends.Raw
    ( fmtModule
    ) where

import Data.Function                ((&))
import Data.List                    (sortOn)
import Data.Maybe                   (fromJust)
import Data.Ord                     (Down(..))
import Data.String                  (IsString(..))
import GHC.Exts                     (IsList(fromList))
import Text.PrettyPrint.Leijen.Text (hcat, vcat)
import Text.Printf                  (printf)

import qualified Data.ByteString.Lazy         as LBS
import qualified Data.Map.Strict              as M
import qualified Data.Text                    as T
import qualified Text.PrettyPrint.Leijen.Text as PP

import Fmt
import IR
import Util

import Backends.Common (dataFieldSize, fmtPrimWord)

import Capnp
    (cerialize, createPure, defaultLimit, msgToLBS, newMessage, setRoot)

import qualified Capnp.Untyped.Pure as Untyped

-- | Sort varaints by their tag, in decending order (with no tag at all being last).
sortVariants :: [Variant] -> [Variant]
sortVariants = sortOn (Down . variantTag)

fmtModule :: Module -> [(FilePath, PP.Doc)]
fmtModule thisMod@Module{modName=Namespace modNameParts,..} =
    [ ( T.unpack $ mintercalate "/" humanParts <> ".hs"
      , mainContent
      )
    , ( printf "Capnp/Gen/ById/X%x.hs" modId
      , vcat
        [ "{-# OPTIONS_GHC -Wno-unused-imports #-}"
        , "{-# OPTIONS_GHC -Wno-dodgy-exports #-}"
        , "{- |"
        , hcat [ "Module: ", machineMod ]
        , hcat [ "Description: machine-addressable alias for '", humanMod, "'." ]
        , "-}"
        , hcat [ "module ", machineMod, " (module ", humanMod, ") where" ]
        , hcat [ "import ", humanMod ]
        ]
      )
    ] where
  machineMod = fromString (printf "Capnp.Gen.ById.X%x" modId)
  humanMod = fmtModRef $ FullyQualified $ Namespace humanParts
  humanParts = "Capnp":"Gen":modNameParts
  modFileText = PP.textStrict modFile
  mainContent = vcat
    [ "{-# OPTIONS_GHC -Wno-unused-imports #-}"
    , "{-# OPTIONS_GHC -Wno-unused-matches #-}"
    , "{-# LANGUAGE FlexibleContexts #-}"
    , "{-# LANGUAGE FlexibleInstances #-}"
    , "{-# LANGUAGE MultiParamTypeClasses #-}"
    , "{-# LANGUAGE TypeFamilies #-}"
    , "{-# LANGUAGE DeriveGeneric #-}"
    , "{- |"
    , "Module: " <> humanMod
    , "Description: Low-level generated module for " <> modFileText
    , ""
    , "This module is the generated code for " <> modFileText <> ", for the"
    , "low-level api."
    , "-}"
    , "module " <> humanMod <> " where"
    , ""
    , "-- Code generated by capnpc-haskell. DO NOT EDIT."
    , "-- Generated from schema file: " <> modFileText
    , ""
    , "import Data.Int"
    , "import Data.Word"
    , ""
    , "import GHC.Generics (Generic)"
    , ""
    , "import Capnp.Bits (Word1)"
    , ""
    , "import qualified Data.Bits"
    , "import qualified Data.Maybe"
    , "import qualified Data.ByteString"
    -- The trailing ' is to avoid possible name collisions:
    , "import qualified Capnp.Classes as C'"
    , "import qualified Capnp.Basics as B'"
    , "import qualified Capnp.GenHelpers as H'"
    , "import qualified Capnp.TraversalLimit as TL'"
    , "import qualified Capnp.Untyped as U'"
    , "import qualified Capnp.Message as M'"
    , ""
    , vcat $ map fmtImport modImports
    , ""
    , vcat $ map (fmtDecl thisMod) (M.toList modDecls)
    ]

fmtModRef :: ModuleRef -> PP.Doc
fmtModRef (ByCapnpId id) = fromString $ printf "Capnp.Gen.ById.X%x" id
fmtModRef (FullyQualified (Namespace ns)) = mintercalate "." (map PP.textStrict ns)

fmtImport :: Import -> PP.Doc
fmtImport (Import ref) = "import qualified " <> fmtModRef ref

-- | Generate declarations common to all types which are represented
-- by 'Untyped.Struct'.
--
-- parameters:
--
-- * thisMod - the module that we are generating.
-- * name    - the name of the type.
-- * info    - the StructInfo; this is a group, some instances will be skipped.
fmtNewtypeStruct :: Module -> Name -> IR.StructInfo -> PP.Doc
fmtNewtypeStruct thisMod name info =
    let typeCon = fmtName thisMod name
        dataCon = typeCon <> "_newtype_"
    in vcat
        [ hcat [ "newtype ", typeCon, " msg = ", dataCon, " (U'.Struct msg)" ]
        , instance_ [] ("U'.TraverseMsg " <> typeCon)
            [ hcat [ "tMsg f (", dataCon, " s) = ", dataCon, " <$> U'.tMsg f s" ]
            ]
        , instance_ [] ("C'.FromStruct msg (" <> typeCon <> " msg)")
            [ hcat [ "fromStruct = pure . ", dataCon ]
            ]
        , instance_ [] ("C'.ToStruct msg (" <> typeCon <> " msg)")
            [ hcat [ "toStruct (", dataCon, " struct) = struct" ]
            ]
        , instance_ [] ("U'.HasMessage (" <> typeCon <> " msg)")
            [ hcat [ "type InMessage (", typeCon, " msg) = msg" ]
            , hcat [ "message (", dataCon, " struct) = U'.message struct" ]
            ]
        , instance_ [] ("U'.MessageDefault (" <> typeCon <> " msg)")
            [ hcat [ "messageDefault = ", dataCon, " . U'.messageDefault" ]
            ]
        , case info of
            IR.IsGroup ->
                ""
            IR.IsStandalone{dataSz, ptrSz} -> vcat
                [ fmtStructListElem typeCon
                , instance_ [] ("C'.FromPtr msg (" <> typeCon <> " msg)")
                    [ hcat [ "fromPtr msg ptr = ", dataCon, " <$> C'.fromPtr msg ptr" ]
                    ]
                , instance_ [] ("C'.ToPtr s (" <> typeCon <> " (M'.MutMsg s))")
                    [ hcat [ "toPtr msg (", dataCon, " struct) = C'.toPtr msg struct" ]
                    ]
                , instance_ [] ("B'.MutListElem s (" <> typeCon <> " (M'.MutMsg s))")
                    [ hcat [ "setIndex (", dataCon, " elt) i (List_", typeCon, " l) = U'.setIndex elt i l" ]
                    , hcat
                        [ "newList msg len = List_", typeCon, " <$> U'.allocCompositeList msg "
                        , fromString (show dataSz), " "
                        , fromString (show ptrSz), " len"
                        ]
                    ]
                , instance_ [] ("C'.Allocate s (" <> typeCon <> " (M'.MutMsg s))")
                    [ hcat
                        [ "new msg = ", dataCon , " <$> U'.allocStruct msg "
                        , fromString (show dataSz), " "
                        , fromString (show ptrSz)
                        ]
                    ]
                ]
        ]

-- | Generate an instance of ListElem for a struct type. The parameter is the name of
-- the type constructor.
fmtStructListElem :: PP.Doc -> PP.Doc
fmtStructListElem nameText =
    instance_ [] ("B'.ListElem msg (" <> nameText <> " msg)")
        [ hcat [ "newtype List msg (", nameText, " msg) = List_", nameText, " (U'.ListOf msg (U'.Struct msg))" ]
        , hcat [ "listFromPtr msg ptr = List_", nameText, " <$> C'.fromPtr msg ptr" ]
        , hcat [ "toUntypedList (List_", nameText, " l) = U'.ListStruct l" ]
        , hcat [ "length (List_", nameText, " l) = U'.length l" ]
        , hcat [ "index i (List_", nameText, " l) = U'.index i l >>= ", fmtRestrictedFromStruct nameText ]
        ]

-- | Output an expression equivalent to fromStruct, but restricted to the type
-- with the given type constructor (which must have kind * -> *).
fmtRestrictedFromStruct :: PP.Doc -> PP.Doc
fmtRestrictedFromStruct nameText = hcat
    [ "(let {"
    , "go :: U'.ReadCtx m msg => U'.Struct msg -> m (", nameText, " msg); "
    , "go = C'.fromStruct"
    , "} in go)"
    ]

-- | Generate a call to 'H'.getWordField' based on a 'DataLoc'.
-- The first argument is an expression for the struct.
fmtGetWordField :: PP.Doc -> DataLoc -> PP.Doc
fmtGetWordField struct DataLoc{..} = mintercalate " "
    [ " H'.getWordField"
    , struct
    , fromString (show dataIdx)
    , fromString (show dataOff)
    , fromString (show dataDef)
    ]

-- | @'fmtSetWordField' struct value loc@ is like 'fmtGetWordField', except that
-- it generates a call to 'H'.setWordField'. The extra value parameter corresponds
-- to the extra parameter in 'H'.setWordField'.
fmtSetWordField :: PP.Doc -> PP.Doc -> DataLoc -> PP.Doc
fmtSetWordField struct value DataLoc{..} = mintercalate " "
    [ "H'.setWordField"
    , struct
    , value
    , fromString (show dataIdx)
    , fromString (show dataOff)
    , fromString (show dataDef)
    ]

-- | Format the various accessors @(set_*, get_*, has_*, new_*)@ for a field.
-- .
-- Parameters (in order):
-- .
-- * @thisMod@: the module we're generating.
-- * @typeName@: the name of the type to which the field belongs.
-- * @variantName@: the name of the variant of @typeName@.
-- * @field@: the field to format.
fmtFieldAccessor :: Module -> Name -> Name -> Field -> PP.Doc
fmtFieldAccessor thisMod typeName variantName Field{..} = vcat
    [ fmtGetter
    , fmtHas
    , fmtSetter
    , fmtNew thisMod accessorName typeCon fieldLocType
    ]
  where
    accessorName prefix = fmtName thisMod $ prefixName prefix (subName variantName fieldName)

    getName = accessorName "get_"
    hasName = accessorName "has_"
    setName = accessorName "set_"

    typeCon = fmtName thisMod typeName
    dataCon = typeCon <> "_newtype_"

    fmtGetter =
        let getType fieldType = typeCon <> " msg -> m " <> fmtType thisMod "msg" fieldType
            typeAnnotation fieldType =
                hcat [ getName, " :: U'.ReadCtx m msg => ", getType fieldType ]
            getDef def = hcat [ getName, " (", dataCon, " struct) =", def ]
        in case fieldLocType of
            DataField loc ty -> vcat
                [ typeAnnotation (WordType ty)
                , getDef $ fmtGetWordField "struct" loc
                ]
            PtrField idx ty -> vcat
                [ typeAnnotation (PtrType ty)
                , getDef $ PP.line <> indent (vcat
                    [ hcat [ "U'.getPtr ", fromString (show idx), " struct" ]
                    , hcat [ ">>= C'.fromPtr (U'.message struct)" ]
                    ])
                ]
            HereField ty -> vcat
                [ typeAnnotation (CompositeType ty)
                , getDef " C'.fromStruct struct"
                ]
            VoidField -> vcat
                [ typeAnnotation VoidType
                , getDef " Capnp.TraversalLimit.invoice 1 >> pure ()"
                ]
    fmtHas =
        case fieldLocType of
            PtrField idx _ -> vcat
                [ hcat [ hasName, " :: U'.ReadCtx m msg => ", typeCon, " msg -> m Bool" ]
                , hcat
                    [ hasName, "(", dataCon, " struct) = "
                    , "Data.Maybe.isJust <$> U'.getPtr "
                    , fromString (show idx)
                    , " struct"
                    ]
                ]
            _ ->
                ""
    fmtSetter =
        let setType fieldType = typeCon <> " (M'.MutMsg s) -> " <> fmtType thisMod "(M'.MutMsg s)" fieldType <> " -> m ()"
            typeAnnotation fieldType = setName <> " :: U'.RWCtx m s => " <> setType fieldType
        in
        case fieldLocType of
            DataField loc@DataLoc{..} ty -> vcat
                [ typeAnnotation (WordType ty)
                , hcat
                    [ setName, " (", dataCon, " struct) value = "
                    , fmtSetWordField
                        "struct"
                        ("(fromIntegral (C'.toWord value) :: Word" <> fromString (show $ dataFieldSize ty) <> ")")
                        loc
                    ]
                ]
            VoidField -> vcat
                [ typeAnnotation VoidType
                , setName <> " _ = pure ()"
                ]
            PtrField idx ty -> vcat
                [ typeAnnotation (PtrType ty)
                , hcat [ setName, " (", dataCon, " struct) value = do" ]
                , indent $ vcat
                    [ "ptr <- C'.toPtr (U'.message struct) value"
                    , hcat [ "U'.setPtr ptr ", fromString (show idx), " struct" ]
                    ]
                ]
            HereField _ ->
                -- We don't generate setters for these fields; instead, the
                -- user should call the getter and then modify the child in-place.
                ""

-- | format a @new_*@ function for a field.
-- .
-- Parameters (in order):
-- .
-- * @thisMod@: The module we're generating.
-- * @accessorName@: function getting the accessor for a specific prefix;
--   takes an argument that is @"set_"@, @"get_"@, etc.
-- * @typeCon@: The name of the type constructor for the type owning the
--   field.
-- * @fieldLocType@: the field location and type.
fmtNew thisMod accessorName typeCon fieldLocType =
    case fieldLocType of
        PtrField _ fieldType ->
            let newType = hcat
                    [ typeCon
                    , " (M'.MutMsg s) -> m ("
                    , fmtType thisMod "(M'.MutMsg s)" (PtrType fieldType)
                    , ")"
                    ]
            in case fieldType of
                ListOf _ ->
                    fmtNewListLike newType "C'.newList"
                PrimPtr PrimText ->
                    fmtNewListLike newType "B'.newText"
                PrimPtr PrimData ->
                    fmtNewListLike newType "B'.newData"
                PrimPtr (PrimAnyPtr _) ->
                    ""
                PtrComposite _ -> vcat
                    [ hcat [ newName, " :: U'.RWCtx m s => ", newType ]
                    , hcat [ newName, " struct = do" ]
                    , indent $ vcat
                        [ hcat [ "result <- C'.new (U'.message struct)" ]
                        , hcat [ setName, " struct result" ]
                        , "pure result"
                        ]
                    ]
                PtrInterface _ ->
                    ""
        _ ->
            ""
  where
    newName = accessorName "new_"
    setName = accessorName "set_"

    fmtNewListLike newType allocFn = vcat
        [ hcat [ newName, " :: U'.RWCtx m s => Int -> ", newType ]
        , hcat [ newName, " len struct = do" ]
        , indent $ vcat
            [ hcat [ "result <- ", allocFn, " (U'.message struct) len" ]
            , hcat [ setName, " struct result" ]
            , "pure result"
            ]
        ]


-- Generate setters for union variants, plus new_* functions where the argument
-- is a pointer type.
fmtUnionSetter :: Module -> Name -> DataLoc -> Maybe Variant -> PP.Doc
fmtUnionSetter thisMod parentType tagLoc variant =
    let (variantName, variantParams) = case variant of
            Just Variant{..} ->
                (variantName, Just variantParams)
            Nothing ->
                ( subName parentType "unknown'"
                , Nothing
                )
        accessorName prefix = prefix <> fmtName thisMod variantName
        setName = "set_" <> fmtName thisMod variantName
        parentTypeCon = fmtName thisMod parentType
        parentDataCon = parentTypeCon <> "_newtype_"
        fmtSetTag = fmtSetWordField
            "struct"
            (case variant of
                Just Variant{variantTag} ->
                    hcat [ "(", fromString (show variantTag), " :: Word16)" ]
                Nothing ->
                    "(tagValue :: Word16)")
            tagLoc
    in case variantParams of
        Nothing -> vcat
            [ hcat [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> Word16 -> m ()" ]
            , hcat
                [ setName, "(", parentDataCon, " struct) tagValue = "
                , fmtSetTag
                ]
            ]
        Just (Record _) ->
            -- Variant is a group; we return a reference to the group so the user can
            -- modify it.
            let childTypeCon = fmtName thisMod (subName variantName "group'")
                childDataCon = childTypeCon <> "_newtype_"
            in vcat
            [ hcat
                [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> "
                , "m (", childTypeCon, " (M'.MutMsg s))"
                ]
            , hcat [ setName, " (", parentDataCon, " struct) = do" ]
            , indent $ vcat
                [ fmtSetTag
                , hcat [ "pure $ ", childDataCon, " struct" ]
                ]
            ]
        Just (Unnamed _ (DataField loc typ)) -> vcat
            [ hcat
                [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> "
                , fmtType thisMod "(M'.MutMsg s)" (WordType typ), " -> m ()"
                ]
            , hcat [ setName, " (", parentDataCon, " struct) value = do" ]
            , indent $ vcat
                [ fmtSetTag
                , let size = dataFieldSize typ
                  in fmtSetWordField "struct"
                        ("(fromIntegral (C'.toWord value) :: Word" <> fromString (show size) <> ")")
                        loc
                ]
            ]
        Just (Unnamed _ fieldLocType@(PtrField index typ)) -> vcat
            [ hcat
                [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> "
                , fmtType thisMod "(M'.MutMsg s)" (PtrType typ), " -> m ()"
                ]
            , hcat [ setName, "(", parentDataCon, " struct) value = do" ]
            , indent $ vcat
                [ fmtSetTag
                , "ptr <- C'.toPtr (U'.message struct) value"
                , hcat [ "U'.setPtr ptr ", fromString (show index), " struct" ]
                ]

            -- Also generate a new_* function.
            , fmtNew thisMod accessorName parentTypeCon fieldLocType
            ]
        Just (Unnamed _ VoidField) -> vcat
            [ hcat [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> m ()" ]
            , hcat [ setName, " (", parentDataCon, " struct) = ", fmtSetTag ]
            ]
        Just (Unnamed _ (HereField typ)) -> vcat
            [ hcat
                [ setName, " :: U'.RWCtx m s => ", parentTypeCon, " (M'.MutMsg s) -> "
                , "m (", fmtType thisMod " (M'.MutMsg s)" (CompositeType typ), ")"
                ]
            , hcat [ setName, "(", parentDataCon, " struct) value = do" ]
            , indent $ vcat
                [ fmtSetTag
                , "fromStruct struct"
                ]
            ]

fmtDecl :: Module -> (Name, Decl) -> PP.Doc
fmtDecl thisMod (name, DeclDef d)   = fmtDataDef thisMod name d
fmtDecl thisMod (name, DeclConst c) = fmtConst thisMod name c

-- | Format a constant declaration.
fmtConst :: Module -> Name -> Const -> PP.Doc
fmtConst thisMod name value =
    let nameText = fmtName thisMod (valueName name)
    in case value of
        WordConst{wordType,wordValue} -> vcat
            [ hcat
                [ nameText, " :: "
                , case wordType of
                    PrimWord ty     -> fmtPrimWord ty
                    EnumType tyName -> fmtName thisMod tyName
                ]
            , hcat [ nameText, " = C'.fromWord ", fromString (show wordValue) ]
            ]
        VoidConst -> vcat
            [ hcat [ nameText, " :: ()" ]
            , hcat [ nameText, " = ()" ]
            ]
        PtrConst{ptrType,ptrValue} ->
            vcat
                [ hcat [ nameText, " :: ", fmtType thisMod "M'.ConstMsg" (PtrType ptrType) ]
                , hcat
                    [ nameText, " = H'.getPtrConst $ Data.ByteString.pack "
                    , makePtrByteList ptrValue
                    ]
                ]
  where
    makePtrByteList ptr =
        let msg = fromJust $ createPure defaultLimit $ do
                msg <- newMessage Nothing
                rootPtr <- cerialize msg $ Untyped.Struct
                    (fromList [])
                    (fromList [ptr])
                setRoot rootPtr
                pure msg
        in
        msgToLBS msg &
        LBS.unpack &
        show &
        T.pack &
        PP.textStrict

fmtDataDef :: Module -> Name -> DataDef -> PP.Doc
fmtDataDef thisMod dataName (DefInterface _) =
    let name = fmtName thisMod dataName in
    vcat
    [ hcat [ "newtype ", name, " msg = ", name, " (Maybe (U'.Cap msg))" ]
    , instance_ [] ("C'.FromPtr msg (" <> name <> " msg)")
        [ hcat [ "fromPtr msg cap = ", name, " <$> C'.fromPtr msg cap" ]
        ]
    , instance_ [] ("C'.ToPtr s (" <> name <> " (M'.MutMsg s))")
        [ hcat [ "toPtr msg (", name , " Nothing) = pure Nothing" ]
        , hcat [ "toPtr msg (", name , " (Just cap)) = pure $ Just $ U'.PtrCap cap" ]
        ]
    ]
fmtDataDef thisMod dataName (DefStruct StructDef{fields, info}) = vcat
    [ fmtNewtypeStruct thisMod dataName info
    , vcat $ map (fmtFieldAccessor thisMod dataName dataName) fields
    ]
fmtDataDef thisMod dataName DefUnion{dataVariants,dataTagLoc,parentStruct=StructDef{info}} =
    let unionName = subName dataName ""
        unionNameText = fmtName thisMod unionName
        unknownName = subName dataName "unknown'"
    in vcat
        [ fmtNewtypeStruct thisMod dataName info
        , data_
            (unionNameText <> " msg")
            (map fmtDataVariant dataVariants ++
                [fmtName thisMod unknownName <> " Word16"]
            )
            []
        , fmtFieldAccessor thisMod dataName dataName Field
            { fieldName = ""
            , fieldLocType = HereField $ StructType unionName []
            }
        , vcat $ map (fmtUnionSetter thisMod dataName dataTagLoc . Just) dataVariants
        , fmtUnionSetter thisMod dataName dataTagLoc Nothing
        -- Generate auxiliary newtype definitions for group fields:
        , vcat $ map fmtVariantAuxNewtype dataVariants
        , instance_ [] ("C'.FromStruct msg (" <> unionNameText <> " msg)")
            [ vcat
                [ "fromStruct struct = do"
                , indent $ vcat
                    [ hcat [ "tag <- ", fmtGetWordField "struct" dataTagLoc ]
                    , "case tag of"
                    , indent $ vcat
                        [ vcat $ map fmtVariantCase $ sortVariants dataVariants
                        , hcat [ "_ -> pure $ ", fmtName thisMod unknownName, " tag" ]
                        ]
                    ]
                ]
            ]
        ]
  where
    fmtDataVariant Variant{..} = fmtName thisMod variantName <>
        case variantParams of
            Record _   -> " (" <> fmtName thisMod (subName variantName "group' msg)")
            Unnamed VoidType _ -> ""
            Unnamed ty _ -> " " <> fmtType thisMod "msg" ty
    fmtVariantCase Variant{..} =
        let nameText = fmtName thisMod variantName
        in hcat
            [ fromString (show variantTag), " -> "
            , case variantParams of
                Record _  -> nameText <> " <$> C'.fromStruct struct"
                Unnamed _ (HereField _) -> nameText <> " <$> C'.fromStruct struct"
                Unnamed _ VoidField ->
                    "pure " <> nameText
                Unnamed _ (DataField loc _) ->
                    nameText <> " <$> " <> fmtGetWordField "struct" loc
                Unnamed _ (PtrField idx _) -> hcat
                    [ nameText," <$> "
                    , " (U'.getPtr ", fromString (show idx), " struct"
                    , " >>= C'.fromPtr (U'.message struct))"
                    ]
            ]
    fmtVariantAuxNewtype Variant{variantName, variantParams=Record fields} =
        let typeName = subName variantName "group'"
        in vcat
            [ fmtNewtypeStruct thisMod typeName IR.IsGroup
            , vcat $ map (fmtFieldAccessor thisMod typeName variantName) fields
            ]
    fmtVariantAuxNewtype _ = ""
fmtDataDef thisMod dataName (DefEnum enumerants) =
    let typeName = fmtName thisMod dataName
        unknownName = subName dataName "unknown'"
    in vcat
    [ data_ typeName
        (map (fmtName thisMod) enumerants ++
        [fmtName thisMod unknownName <> " Word16"]
        )
        ["Show", "Read", "Eq", "Generic"]
    -- Generate an Enum instance. This is a trivial wrapper around the
    -- IsWord instance, below.
    , instance_ [] ("Enum " <> typeName)
        [ "toEnum = C'.fromWord . fromIntegral"
        , "fromEnum = fromIntegral . C'.toWord"
        ]
    -- Generate an IsWord instance.
    , instance_ [] ("C'.IsWord " <> typeName)
        [ "fromWord n = go (fromIntegral n :: Word16) where"
        , indent $ vcat $
            zipWith fmtFromWordCase enumerants [0..]
            ++
            [ hcat
                [ "go tag = "
                , fmtName thisMod unknownName
                , " (fromIntegral tag)"
                ]
            ]
        , vcat $
            zipWith fmtToWordCase enumerants [0..]
            ++
            [ hcat [ "toWord (", fmtName thisMod unknownName, " tag) = fromIntegral tag" ] ]
        ]
    , instance_ [] ("B'.ListElem msg " <> typeName)
        [ hcat [ "newtype List msg ", typeName, " = List_", typeName, " (U'.ListOf msg Word16)" ]
        , hcat [ "listFromPtr msg ptr = List_", typeName, " <$> C'.fromPtr msg ptr" ]
        , hcat [ "toUntypedList (List_", typeName, " l) = U'.List16 l" ]
        , hcat [ "length (List_", typeName, " l) = U'.length l" ]
        , hcat [ "index i (List_", typeName, " l) = (C'.fromWord . fromIntegral) <$> U'.index i l" ]
        ]
    , instance_ [] ("B'.MutListElem s " <> typeName)
        [ hcat [ "setIndex elt i (List_", typeName, " l) = U'.setIndex (fromIntegral $ C'.toWord elt) i l" ]
        , hcat [ "newList msg size = List_", typeName, " <$> U'.allocList16 msg size" ]
        ]
    ]
  where
    -- | Format an equation in an enum's IsWord.fromWord implementation.
    fmtFromWordCase name ordinal =
        hcat [ "go ", fromString (show ordinal), " = ", fmtName thisMod name ]
    -- | Format an equation in an enum's IsWord.toWord implementation.
    fmtToWordCase name ordinal =
        hcat [ "toWord ", fmtName thisMod name, " = ", fromString (show ordinal) ]

-- | @'fmtType ident msg ty@ formats the type @ty@ from module @ident@,
-- using @msg@ as the message parameter, if any.
fmtType :: Module -> PP.Doc -> Type -> PP.Doc
fmtType thisMod msg = \case
    WordType (EnumType name) ->
        fmtName thisMod name
    WordType (PrimWord ty) ->
        fmtPrimWord ty
    VoidType ->
        "()"
    PtrType (ListOf eltType) ->
        "(B'.List " <> msg <> " " <> fmtType thisMod msg eltType <> ")"
    PtrType (PrimPtr PrimText) ->
        "(B'.Text " <> msg <> ")"
    PtrType (PrimPtr PrimData) ->
        "(B'.Data " <> msg <> ")"
    PtrType (PrimPtr (PrimAnyPtr anyPtr)) ->
        "(Maybe " <> fmtAnyPtr msg anyPtr <> ")"
    PtrType (PtrComposite ty) ->
        fmtType thisMod msg (CompositeType ty)
    PtrType (PtrInterface name) ->
        hcat [ "(", fmtName thisMod name, " ", msg, ")" ]
    CompositeType (StructType name params) -> hcat
        [ "("
        , fmtName thisMod name
        , " "
        , mintercalate " " $ msg : map (fmtType thisMod msg) params
        , ")"
        ]

fmtAnyPtr :: PP.Doc -> AnyPtr -> PP.Doc
fmtAnyPtr msg Struct = "(U'.Struct " <> msg <> ")"
fmtAnyPtr msg List   = "(U'.List " <> msg <> ")"
fmtAnyPtr _ Cap      = "Word32"
fmtAnyPtr msg Ptr    = "(U'.Ptr " <> msg <> ")"

fmtName :: Module -> Name -> PP.Doc
fmtName Module{modId=thisMod} Name{nameModule, nameLocalNS=Namespace parts, nameUnqualified=localName} =
    modPrefix <> mintercalate "'" (map PP.textStrict $ parts <> [localName])
  where
    modPrefix = case nameModule of
        ByCapnpId id                  | id == thisMod -> ""
        FullyQualified (Namespace []) -> ""
        _                             -> fmtModRef nameModule <> "."
