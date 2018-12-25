{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE OverloadedStrings     #-}
module Trans.RawToHaskell (fileToModule) where

import Data.Word

import Data.Char       (toUpper)
import System.FilePath (splitDirectories)
import Text.Printf     (printf)

import qualified Data.Text as T

import IR.Haskell

import qualified IR.Common as C
import qualified IR.Name   as Name
import qualified IR.Raw    as Raw

-- Misc shortcuts for common constructs:

std_ :: Name.UnQ -> Name.GlobalQ
std_ name = gName ["Std_"] (Name.mkLocal Name.emptyNS name)

eStd_ :: Name.UnQ -> Exp
eStd_ = EGName . std_

tStd_ :: Name.UnQ -> Type
tStd_ = TGName . std_

gName :: [T.Text] -> Name.LocalQ -> Name.GlobalQ
gName parts local = Name.GlobalQ
    { globalNS = Name.NS parts
    , local
    }

egName :: [T.Text] -> Name.LocalQ -> Exp
egName parts local = EGName $ gName parts local

tgName :: [T.Text] -> Name.LocalQ -> Type
tgName parts local = TGName $ gName parts local

iValue :: Name.UnQ -> [Pattern] -> Exp -> InstanceDef
iValue name params value = IdValue DfValue {name, params, value}

readCtx :: T.Text -> T.Text -> Type
readCtx m msg = TApp
    (tgName ["Untyped"] "ReadCtx")
    [ TVar m
    , TVar msg
    ]

instance_ :: [Type] -> [T.Text] -> Name.LocalQ -> [Type] -> [InstanceDef] -> Decl
instance_ ctx classNS className tys defs = DcInstance
    { ctx
    , typ = TApp
        (tgName classNS className)
        tys
    , defs
    }

fileToModule :: Raw.File -> Module
fileToModule Raw.File{fileName, fileId, decls} =
    Module
        { modName = makeModName fileName
        , modLangPragmas =
            [ "FlexibleInstances"
            , "MultiParamTypeClasses"
            , "TypeFamilies"
            , "DeriveGeneric"
            ]
        , modImports =
            [ imp ["Capnp", "Message"] "Message"
            , imp ["Capnp", "Untyped"] "Untyped"
            , imp ["Capnp", "Basics"] "Basics"
            , imp ["Capnp", "GenHelpers"] "GenHelpers"
            , imp ["Capnp", "Classes"] "Classes"
            , imp ["GHC", "Generics"] "Generics"
            ]
        , modDecls = concatMap (declToDecls fileId) decls
        }
  where
    imp parts importAs = Import {parts, importAs}

declToDecls :: Word64 -> Raw.Decl -> [Decl]
declToDecls thisMod Raw.UnionVariant{typeCtor, unionDataCtors} =
    [ DcData Data
        { dataName = Name.localToUnQ typeCtor
        , dataNewtype = False
        , typeArgs = [TVar "msg"]
        , dataVariants =
            [ DataVariant
                { dvCtorName = Name.localToUnQ dataCtor
                , dvArgs = APos $
                    case locType of
                        C.VoidField ->
                            []
                        _ ->
                            [ typeToType thisMod (C.fieldType locType) "msg" ]
                }
            | (dataCtor, locType) <- unionDataCtors
            ]
        , derives = []
        }
    , instance_ [] ["Classes"] "FromStruct" [TVar "msg", TApp (TLName typeCtor) [TVar "msg"]]
        [ iValue "fromStruct" [PVar "struct"] $ EDo
            [ DoBind "tag" (eStd_ "undefined")
            ]
            (ECase (ELName "tag") $
                [ (PInt i, eStd_ "undefined")
                | (i, (_, _)) <- zip [0..] unionDataCtors
                ] ++
                [(PVar "_", eStd_ "undefined")]
            )
        ]
    ]
declToDecls _thisMod Raw.Enum{typeCtor, dataCtors} =
    let listCtor = Name.mkSub typeCtor "List_"
        unknownCtor = Name.mkSub typeCtor "unknown'"
    in
    [ DcData Data
        { dataName = Name.localToUnQ typeCtor
        , dataNewtype = False
        , typeArgs = []
        , dataVariants =
            map enumerantToVariant dataCtors
            ++
            [ DataVariant
                { dvCtorName = Name.localToUnQ unknownCtor
                , dvArgs = APos
                    [ TPrim $ C.PrimInt $ C.IntType C.Unsigned C.Sz16 ]
                }
            ]
        , derives =
            [ "Std_.Show"
            , "Std_.Read"
            , "Std_.Eq"
            , "Generics.Generic"
            ]
        }
    , mkIsWordInstance typeCtor dataCtors unknownCtor
    -- An Enum instance that just wraps the IsWord instance:
    , instance_ [] ["Std_"] "Enum" [TLName typeCtor]
        [ iValue "fromEnum" [PVar "x"] $
            EApp
                (eStd_ "fromIntegral")
                [ EApp
                    (egName ["Classes"] "toWord")
                    [ELName "x"]
                ]
        , iValue "toEnum" [PVar "x"] $
            EApp
                (egName ["Classes"] "fromWord")
                [ EApp
                    (eStd_ "fromIntegral")
                    [ELName "x"]
                ]
        ]
    -- lists:
    , instance_ [] ["Basics"] "ListElem" [TVar "msg", TLName typeCtor]
        [ IdData Data
            { dataName = "List"
            , typeArgs =
                [ TVar "msg"
                , TLName typeCtor
                ]
            , dataVariants =
                [ DataVariant
                    { dvCtorName = Name.localToUnQ listCtor
                    , dvArgs = APos
                        [ TApp
                            (tgName ["Untyped"] "ListOf")
                            [ TVar "msg"
                            , tStd_ "Word16"
                            ]
                        ]
                    }
                ]
            , derives = []
            , dataNewtype = True
            }
        , iValue "index" [PVar "i", PLCtor listCtor [PVar "l"]] $ EFApp
            (egName ["Classes"] "fromWord")
            [ EFApp
                (eStd_ "fromIntegral")
                [ EApp
                    (egName ["Untyped"] "index")
                    [ ELName "i"
                    , ELName "l"
                    ]
                ]
            ]
        , iValue "listFromPtr" [PVar "msg", PVar "ptr"] $ EFApp
            (ELName listCtor)
            [ EApp
                (egName ["Classes"] "fromPtr")
                [ ELName "msg"
                , ELName "ptr"
                ]
            ]
        , iValue "toUntypedList" [PLCtor listCtor [PVar "l"]] $ EApp
            (egName ["Untyped"] "List16")
            [ELName "l"]
        , iValue "length" [PLCtor listCtor [PVar "l"]] $ EApp
            (egName ["Untyped"] "length")
            [ELName "l"]
        ]
    , instance_ [] ["Classes"] "MutListElem" [TVar "s", TLName typeCtor]
        [ iValue
            "setIndex"
            [PVar "elt", PVar "i", PLCtor listCtor [PVar "l"]] $
            EApp
                (egName ["Untyped"] "setIndex")
                [ EApp
                    (eStd_ "fromIntegral")
                    [ EApp (egName ["Classes"] "toWord") [ELName "elt"]
                    ]
                , ELName "i"
                , ELName "l"
                ]
        , iValue "newList" [PVar "msg", PVar "size"] $ EFApp
            (ELName listCtor)
            [ EApp
                (egName ["Untyped"] "allocList16")
                [ ELName "msg"
                , ELName "size"
                ]
            ]
        ]
    ]
  where
    enumerantToVariant variantName =
        DataVariant
            { dvCtorName =
                Name.localToUnQ variantName
            , dvArgs = APos []
            }
declToDecls _thisMod Raw.InterfaceWrapper{typeCtor} =
    let dataCtor = Name.mkSub typeCtor "newtype_" in
    [ newtypeWrapper typeCtor ["msg"] $ TApp
        (tStd_ "Maybe")
        [ TApp
            (tgName ["Untyped"] "Cap")
            [TVar "msg"]
        ]
    , wrapperFromPtr typeCtor dataCtor
    , instance_ [] ["Classes"] "ToPtr"
        [ TVar "s"
        , TApp (TLName typeCtor) [TApp (tgName ["Message"] "MutMsg") [TVar "s"]]
        ]
        [ iValue "toPtr" [PVar "msg", PLCtor dataCtor [PGCtor (std_ "Nothing") []]]
            (EApp (eStd_ "pure") [eStd_ "Nothing"])
        , iValue "toPtr" [PVar "msg", PLCtor dataCtor [PGCtor (std_ "Just") [PVar "cap"]]]
            (EApp
                (eStd_ "pure")
                [ EApp
                    (eStd_ "Just")
                    [ EApp
                        (egName ["Untyped"] "PtrCap")
                        [ELName "cap"]
                    ]
                ]
            )
        ]
    ]
declToDecls _thisMod Raw.StructWrapper{typeCtor} =
    let dataCtor = Name.mkSub typeCtor "newtype_" in
    [ newtypeWrapper typeCtor ["msg"] $ TApp
        (tgName ["Untyped"] "Struct")
        [TVar "msg"]

    -- There are several type classes that are defined for all structs:
    , instance_ [] ["Untyped"] "TraverseMsg" [TLName typeCtor]
        [ iValue "tMsg" [PVar "f", PLCtor dataCtor [PVar "s"]] $ EFApp
            (ELName dataCtor)
            [EApp (egName ["Untyped"] "tMsg") [ELName "f", ELName "s"]]
        ]
    , instance_ [] ["Classes"] "FromStruct"
        [ TVar "msg", TApp (TLName typeCtor) [TVar "msg"]
        ]
        [ iValue "fromStruct" [PVar "struct"] $ EApp
            (eStd_ "pure")
            [EApp (ELName dataCtor) [ELName "struct"]]
        ]
    , instance_ [] ["Classes"] "ToStruct"
        [TVar "msg", TApp (TLName typeCtor) [TVar "msg"]]
        [ iValue "toStruct" [PLCtor dataCtor [PVar "struct"]]
            (ELName "struct")
        ]
    , instance_ [] ["Untyped"] "HasMessage" [TApp (TLName typeCtor) [TVar "msg"]]
        [ IdType $ TypeAlias
            "InMessage"
            [ TApp (TLName typeCtor) [TVar "msg"] ]
            (TVar "msg")
        , iValue "message" [PLCtor dataCtor [PVar "struct"]]
            (EApp (egName ["Untyped"] "message") [ELName "struct"])
        ]
    , instance_ [] ["Untyped"] "MessageDefault" [TApp (TLName typeCtor) [TVar "msg"]]
        [ iValue "messageDefault" [PVar "msg"] $ EApp
            (ELName dataCtor)
            [ EApp
                (egName ["Untyped"] "messageDefault")
                [ELName "msg"]
            ]
        ]
    ]
declToDecls _thisMod Raw.StructInstances{typeCtor, dataWordCount, pointerCount} =
    let listCtor = Name.mkSub typeCtor "List_"
        dataCtor = Name.mkSub typeCtor "newtype_"
    in
    [ wrapperFromPtr typeCtor dataCtor
    , instance_ [] ["Classes"] "ToPtr"
        [ TVar "s"
        , TApp
            (TLName typeCtor)
            [ TApp (tgName ["Message"] "MutMsg") [TVar "s"] ]
        ]
        [ iValue
            "toPtr"
            [PVar "msg", PLCtor dataCtor [PVar "struct"]]
            (EApp
                (egName ["Classes"] "toPtr")
                [ ELName "msg"
                , ELName "struct"
                ]
            )
        ]
    , instance_ [] ["Basics"] "ListElem"
        [ TVar "msg"
        , TApp
            (TLName typeCtor)
            [TVar "msg"]
        ]
        [ IdData Data
            { dataName = "List"
            , typeArgs =
                [ TVar "msg"
                , TApp
                    (TLName typeCtor)
                    [TVar "msg"]
                ]
            , dataVariants =
                [ DataVariant
                    { dvCtorName = Name.localToUnQ listCtor
                    , dvArgs = APos
                        [ TApp
                            (tgName ["Untyped"] "ListOf")
                            [ TVar "msg"
                            , TApp
                                (tgName ["Untyped"] "Struct")
                                [TVar "msg"]
                            ]
                        ]
                    }
                ]
            , derives = []
            , dataNewtype = True
            }
        , iValue "listFromPtr" [PVar "msg", PVar "ptr"] $ EFApp
            (ELName listCtor)
            [ EApp
                (egName ["Classes"] "fromPtr")
                [ELName "msg", ELName "ptr"]
            ]
        , iValue "toUntypedList" [PLCtor listCtor [PVar "l"]] $ EApp
            (egName ["Untyped"] "ListStruct")
            [ELName "l"]
        , iValue "length" [PLCtor listCtor [PVar "l"]] $ EApp
            (egName ["Untyped"] "length")
            [ELName "l"]
        , iValue "index" [PVar "i", PLCtor listCtor [PVar "l"]] $ EDo
            [ DoBind "elt" $ EApp
                (egName ["Untyped"] "index")
                [ ELName "i"
                , ELName "l"
                ]
            ]
            ( EApp
                (egName ["Classes"] "fromStruct")
                [ELName "elt"]
            )
        ]
    , instance_ [] ["Basics"] "MutListElem"
        [ TVar "s"
        , TApp
            (TLName typeCtor)
            [ TApp (tgName ["Message"] "MutMsg") [TVar "s"] ]
        ]
        [ iValue "setIndex"
            [ PLCtor dataCtor [PVar "elt"]
            , PVar "i"
            , PLCtor listCtor [PVar "l"]
            ]
            (EApp
                (egName ["Untyped"] "setIndex")
                [ ELName "elt"
                , ELName "i"
                , ELName "l"
                ]
            )
        , iValue "newList" [PVar "msg", PVar "len"] $ EFApp
            (ELName listCtor)
            [ EApp
                (egName ["Untyped"] "allocCompositeList")
                [ ELName "msg"
                , EInt $ fromIntegral dataWordCount
                , EInt $ fromIntegral pointerCount
                , ELName "len"
                ]
            ]
        ]
    ]
declToDecls thisMod Raw.Getter{fieldName, fieldLocType, containerType} =
    let containerDataCtor = Name.mkSub containerType "newtype_" in
    [ DcValue
        { typ = TCtx
            [readCtx "m" "msg"]
            (TFn
                [ TApp
                    (TLName containerType)
                    [ TVar "msg" ]
                , TApp
                    (TVar "m")
                    [ typeToType thisMod (C.fieldType fieldLocType) "msg"
                    ]
                ]
            )
        , def = DfValue
            { name = Name.UnQ $
                "get_" <> Name.renderLocalQ fieldName
            , params = [PLCtor containerDataCtor [PVar "struct"]]
            , value = case fieldLocType of
                C.DataField C.DataLoc{dataIdx, dataOff, dataDef} _ ->
                    EApp
                        (egName ["GenHelpers"] "getWordField")
                        [ ELName "struct"
                        , EInt $ fromIntegral dataIdx
                        , EInt $ fromIntegral dataOff
                        , EInt $ fromIntegral dataDef
                        ]
                C.PtrField idx _ -> EDo
                    [ DoBind "ptr" $ EApp
                        (egName ["Untyped"] "getPtr")
                        [ EInt (fromIntegral idx)
                        , ELName "struct"
                        ]
                    ]
                    (EApp
                        (egName ["Classes"] "fromPtr")
                        [ EApp
                            (egName ["Untyped"] "message")
                            [ELName "struct"]
                        , ELName "ptr"
                        ]
                    )
                C.HereField _ ->
                    EApp
                        (egName ["Classes"] "fromStruct")
                        [ELName "struct"]
                C.VoidField ->
                    EApp
                        (eStd_ "pure")
                        [ETup []]
            }
        }
    ]

-- | Make an instance of the IsWord type class for an enum.
mkIsWordInstance :: Name.LocalQ -> [Name.LocalQ] -> Name.LocalQ -> Decl
mkIsWordInstance typeCtor dataCtors unknownCtor =
    instance_ [] ["Classes"] "IsWord" [TLName typeCtor] $
        [ IdValue $ DfValue
            { name = "fromWord"
            , params = [PInt i]
            , value = ELName ctor
            }
        | (i, ctor) <- zip [0..] dataCtors
        ] ++
        [ IdValue $ DfValue
            { name = "fromWord"
            , params = [PVar "tag"]
            , value = EApp
                (ELName unknownCtor)
                [ EApp
                    (eStd_ "fromIntegral")
                    [ELName "tag"]
                ]
            }
        ] ++
        [ IdValue $ DfValue
            { name = "toWord"
            , params = [PLCtor ctor []]
            , value = EInt i
            }
        | (i, ctor) <- zip [0..] dataCtors
        ] ++
        [ IdValue $ DfValue
            { name = "toWord"
            , params =
                [ PLCtor unknownCtor [PVar "tag"] ]
            , value =
                EApp
                    (eStd_ "fromIntegral")
                    [ELName "tag"]
            }
        ]

newtypeWrapper :: Name.LocalQ -> [T.Text] -> Type -> Decl
newtypeWrapper typeCtor typeArgs wrappedType =
    DcData Data
        { dataName = Name.localToUnQ typeCtor
        , dataNewtype = True
        , typeArgs = map TVar typeArgs
        , dataVariants =
            [ DataVariant
                { dvCtorName = Name.localToUnQ $ Name.mkSub typeCtor "newtype_"
                , dvArgs = APos [ wrappedType ]
                }
            ]
        , derives = []
        }

wrapperFromPtr :: Name.LocalQ -> Name.LocalQ -> Decl
wrapperFromPtr typeCtor dataCtor =
    instance_ [] ["Classes"] "FromPtr"
        [ TVar "msg", TApp (TLName typeCtor) [TVar "msg"] ]
        [ iValue "fromPtr" [PVar "msg", PVar "ptr"] $ EFApp
            (ELName dataCtor)
            [ EApp
                (egName ["Classes"] "fromPtr")
                [ ELName "msg"
                , ELName "ptr"
                ]
            ]
        ]

nameToType :: Word64 -> Name.CapnpQ -> Type
nameToType thisMod Name.CapnpQ{local, fileId} =
    if fileId == thisMod
        then TLName local
        else tgName
            ["Capnp", "Gen", T.pack $ printf "X%x" fileId]
            local
typeToType :: Word64 -> C.Type Name.CapnpQ -> T.Text -> Type
typeToType thisMod ty var = case ty of
    C.VoidType -> TUnit
    C.WordType (C.PrimWord ty) -> TPrim ty
    C.WordType (C.EnumType typeId) ->
        nameToType thisMod typeId
    C.PtrType (C.ListOf elt) ->
        TApp (tgName ["Basics"] "List")
            [ TVar var
            , typeToType thisMod elt var
            ]
    C.PtrType (C.PrimPtr C.PrimText) ->
        appV $ tgName ["Basics"] "Text"
    C.PtrType (C.PrimPtr C.PrimData) ->
        appV $ tgName ["Basics"] "Data"
    C.PtrType (C.PtrComposite (C.StructType typeId)) ->
        appV $ nameToType thisMod typeId
    C.PtrType (C.PtrInterface typeId) ->
        nameToType thisMod typeId
    C.PtrType (C.PrimPtr (C.PrimAnyPtr _)) ->
        TApp (tStd_ "Maybe") [appV $ tgName ["Untyped"] "Ptr"]
    C.CompositeType (C.StructType typeId) ->
        appV $ nameToType thisMod typeId
  where
    appV t = TApp t [TVar var]

-- | Transform the file path into a valid haskell module name.
-- TODO: this is a best-effort transformation; it gives good
-- results on the schema I've found in the wild, but may fail
-- to generate valid/non-overlapping module names in all cases.
makeModName :: FilePath -> [Name.UnQ]
makeModName fileName =
    "Capnp":"Gen":[ Name.UnQ (T.pack (mangleSegment seg)) | seg <- splitDirectories fileName ]
  where
    mangleSegment "c++.capnp" = "Cxx"
    mangleSegment ""          = error "Unexpected empty file name"
    mangleSegment (c:cs)      = go (toUpper c : cs) where
        go ('-':c:cs) = toUpper c : go cs
        go ".capnp"   = ""
        go []         = ""
        go (c:cs)     = c : go cs
