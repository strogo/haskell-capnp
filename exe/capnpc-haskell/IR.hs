{-# LANGUAGE NamedFieldPuns  #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies    #-}
{-# LANGUAGE ViewPatterns    #-}
-- This module defines datatypes that represent something between the capnp
-- schema and Haskell code. The representation has the following
-- chracteristics:
--
-- * Type definitions can map directly to idiomatic haskell types. Both the capnp
--   schema format itself and the types defined for it in schema.capnp have some
--   quirks that need to be ironed out to perform the mapping:
--   * Unions and structs are not separate types; a union is just a (possibly
--     anonymous) field within a struct.
--   * Groups are only kindof their own type.
--   * Schema can have nested, mutually recursive namespaces even within a
--     single file. We want to generate a module with a flat namespace.
--   * Even features that conceptually map simply have somewhat odd
--     representations and irregularities schema.capnp
--   Our intermediate representation just has data declarations, with
--   enough information attached to access each variant and argument.
-- * Names are fully-qualified; see the 'Name' type for more information
--   (TODO).
module IR
    ( Name(..)
    , Namespace(..)
    , Module(..)
    , ModuleRef(..)
    , Import(..)
    , Type(..)
    , PrimType(..)
    , Untyped(..)
    , Variant(..)
    , VariantParams(..)
    , Field(..)
    , Decl(..)
    , DataDef(..)
    , CerialType(..)
    , Const(..)
    , FieldLoc(..)
    , DataLoc(..)
    , subName
    , prefixName
    , valueName
    ) where

import Util

import Data.Word

import Data.Char   (toLower)
import Data.String (IsString(fromString))
import Data.Text   (Text)

import Data.Monoid ((<>))
import GHC.Exts    (IsList(..))

import qualified Data.Text as T

newtype Namespace = Namespace [Text]
    deriving(Show, Read, Eq)

instance IsList Namespace where
    type Item Namespace = Text
    fromList = Namespace
    toList (Namespace parts) = parts

data Module = Module
    { modId      :: Id
    , modName    :: Namespace
    , modFile    :: Text
    , modImports :: [Import]
    , modDecls   :: [(Name, Decl)]
    }
    deriving(Show, Read, Eq)

data Decl
    = DeclDef DataDef
    | DeclConst Const
    deriving(Show, Read, Eq)

newtype Import = Import ModuleRef
    deriving(Show, Read, Eq)

data ModuleRef
    = FullyQualified Namespace
    | ByCapnpId Id
    deriving(Show, Read, Eq)

data Name = Name
    { nameModule      :: ModuleRef
    , nameLocalNS     :: Namespace
    , nameUnqualified :: Text
    }
    deriving(Show, Read, Eq)

subName :: Name -> Text -> Name
subName name@Name{..} nextPart = name
    { nameLocalNS = fromList $ toList nameLocalNS ++ [nameUnqualified]
    , nameUnqualified = nextPart
    }

prefixName :: Text -> Name -> Name
prefixName prefix name@Name{nameLocalNS=(toList -> (x:xs))} =
    name { nameLocalNS = fromList $ (prefix <> x):xs }
prefixName prefix name = name { nameLocalNS = fromList [prefix] }

-- | 'valueName' converts a name to one which starts with a lowercase
-- letter, so that it is valid to use as a name for a value (as opposed
-- to a type).
valueName :: Name -> Name
valueName name@Name{nameLocalNS=(toList -> (T.unpack -> (c:cs)):xs)} =
    name { nameLocalNS = fromList $ T.pack (toLower c : cs) : xs }
valueName name = name

instance IsString Name where
    fromString str = Name
        { nameModule = FullyQualified []
        , nameLocalNS = []
        , nameUnqualified = T.pack str
        }

data Type
    = StructType Name [Type]
    | EnumType Name
    | ListOf Type
    | PrimType PrimType
    | Untyped Untyped
    deriving(Show, Read, Eq)

data PrimType
    = PrimInt { isSigned :: !Bool, size :: !Int }
    | PrimFloat32
    | PrimFloat64
    | PrimText
    | PrimData
    | PrimBool
    | PrimVoid
    deriving(Show, Read, Eq)

data Untyped
    = Struct
    | List
    | Cap
    | Ptr
    deriving(Show, Read, Eq)

data Variant = Variant
    { variantName   :: Name
    , variantParams :: VariantParams
    , variantTag    :: Maybe Word16
    }
    deriving(Show, Read, Eq)

data VariantParams
    = Unnamed Type FieldLoc
    | Record [Field]
    | NoParams
    deriving(Show, Read, Eq)

data Field = Field
    { fieldName :: Text
    , fieldType :: Type
    , fieldLoc  :: FieldLoc
    }
    deriving(Show, Read, Eq)

data Const
    = WordConst
        { wordValue :: Word64
        , wordType  :: Type
        }
    -- TODO: support pointer types.
    deriving(Show, Read, Eq)

data DataDef = DataDef
    { dataVariants   :: [Variant]
    -- | The location of the tag for the union, if any.
    , dataTagLoc     :: Maybe DataLoc
    , dataCerialType :: CerialType
    }
    deriving(Show, Read, Eq)

-- | What kind of untyped wire format a type is stored as.
data CerialType
    -- | Stored as a struct
    = CTyStruct
    -- | Stored in the data section (i.e. an integer-like type). The argument
    -- is the size of the data type, in bits.
    | CTyWord !Int
    deriving(Show, Read, Eq)

-- | The location of a field within a struct
data FieldLoc
    -- | The field is in the struct's data section.
    = DataField DataLoc
    -- | The field is in the struct's pointer section (the argument is the
    -- index).
    | PtrField !Word16
    -- | The field is a group or union; it's "location" is the whole struct.
    | HereField
    -- | The field is zero-size (and has no argument)
    | VoidField
    deriving(Show, Read, Eq)

-- | The location of a field within a struct's data section.
data DataLoc = DataLoc
    { dataIdx :: !Int
    -- ^ The index of the 64-bit word containing the field.
    , dataOff :: !Int
    , dataDef :: !Word64
    -- ^ The value is stored xor-ed with this value. This is used
    -- to allow for encoding default values. Note that this is xor-ed
    -- with the bits representing the value, not the whole word.
    }
    deriving(Show, Read, Eq)
