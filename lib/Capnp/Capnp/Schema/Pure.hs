{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
module Capnp.Capnp.Schema.Pure where

-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/schema.capnp

import Data.Int
import Data.Word

import Data.Capnp.Untyped.Pure (List)
import Data.Capnp.Basics.Pure (Data, Text)
import Control.Monad.Catch (MonadThrow)
import Data.Capnp.TraversalLimit (MonadLimit)

import qualified Data.Capnp.Message as M'
import qualified Data.Capnp.Untyped.Pure as PU'
import qualified Codec.Capnp.Generic as C'

import qualified Capnp.ById.Xa93fc509624c72d9
import qualified Capnp.ById.Xbdf87d7bb8304e81.Pure
import qualified Capnp.ById.Xbdf87d7bb8304e81

data Type'anyPointer'unconstrained
    = Type'anyPointer'unconstrained'anyKind
    | Type'anyPointer'unconstrained'struct
    | Type'anyPointer'unconstrained'list
    | Type'anyPointer'unconstrained'capability
    | Type'anyPointer'unconstrained'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained M'.Message) Type'anyPointer'unconstrained where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained'anyKind -> pure Type'anyPointer'unconstrained'anyKind
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained'struct -> pure Type'anyPointer'unconstrained'struct
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained'list -> pure Type'anyPointer'unconstrained'list
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained'capability -> pure Type'anyPointer'unconstrained'capability
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained'unknown' val -> Type'anyPointer'unconstrained'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Type'anyPointer'unconstrained where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained M'.Message)

data Brand
    = Brand
        { scopes :: List (Brand'Scope)
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Brand M'.Message) Brand where
    decerialize raw = Brand
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Brand'scopes raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Brand where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Brand M'.Message)

data Method
    = Method
        { name :: Text
        , codeOrder :: Word16
        , paramStructType :: Word64
        , resultStructType :: Word64
        , annotations :: List (Annotation)
        , paramBrand :: Brand
        , resultBrand :: Brand
        , implicitParameters :: List (Node'Parameter)
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Method M'.Message) Method where
    decerialize raw = Method
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Method'name raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'codeOrder raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'paramStructType raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'resultStructType raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'annotations raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'paramBrand raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'resultBrand raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Method'implicitParameters raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Method where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Method M'.Message)

data Enumerant
    = Enumerant
        { name :: Text
        , codeOrder :: Word16
        , annotations :: List (Annotation)
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Enumerant M'.Message) Enumerant where
    decerialize raw = Enumerant
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Enumerant'name raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Enumerant'codeOrder raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Enumerant'annotations raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Enumerant where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Enumerant M'.Message)

field'noDiscriminant :: Word16
field'noDiscriminant = C'.fromWord 65535
data Field
    = Field'
        { name :: Text
        , codeOrder :: Word16
        , annotations :: List (Annotation)
        , discriminantValue :: Word16
        , ordinal :: Field'ordinal
        , union' :: Field'
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Field M'.Message) Field where
    decerialize raw = Field'
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Field''name raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field''codeOrder raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field''annotations raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field''discriminantValue raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field''ordinal raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field''union' raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Field where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Field M'.Message)

data Field'
    = Field'slot
        { offset :: Word32
        , type_ :: Type
        , defaultValue :: Value
        , hadExplicitDefault :: Bool
        }
    | Field'group
        { typeId :: Word64
        }
    | Field'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Field' M'.Message) Field' where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Field'slot raw -> Field'slot
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Field'slot'offset raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field'slot'type_ raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field'slot'defaultValue raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Field'slot'hadExplicitDefault raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Field'group raw -> Field'group
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Field'group'typeId raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Field'unknown' val -> Field'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Field' where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Field' M'.Message)

data Superclass
    = Superclass
        { id :: Word64
        , brand :: Brand
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Superclass M'.Message) Superclass where
    decerialize raw = Superclass
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Superclass'id raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Superclass'brand raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Superclass where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Superclass M'.Message)

data Brand'Scope
    = Brand'Scope'
        { scopeId :: Word64
        , union' :: Brand'Scope'
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Brand'Scope M'.Message) Brand'Scope where
    decerialize raw = Brand'Scope'
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Brand'Scope''scopeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Brand'Scope''union' raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Brand'Scope where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Brand'Scope M'.Message)

data Brand'Scope'
    = Brand'Scope'bind (List (Brand'Binding))
    | Brand'Scope'inherit
    | Brand'Scope'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Brand'Scope' M'.Message) Brand'Scope' where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Brand'Scope'bind val -> Brand'Scope'bind <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Brand'Scope'inherit -> pure Brand'Scope'inherit
        Capnp.ById.Xa93fc509624c72d9.Brand'Scope'unknown' val -> Brand'Scope'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Brand'Scope' where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Brand'Scope' M'.Message)

data CodeGeneratorRequest'RequestedFile'Import
    = CodeGeneratorRequest'RequestedFile'Import
        { id :: Word64
        , name :: Text
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest'RequestedFile'Import M'.Message) CodeGeneratorRequest'RequestedFile'Import where
    decerialize raw = CodeGeneratorRequest'RequestedFile'Import
            <$> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'RequestedFile'Import'id raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'RequestedFile'Import'name raw >>= C'.decerialize)

instance C'.IsStruct M'.Message CodeGeneratorRequest'RequestedFile'Import where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest'RequestedFile'Import M'.Message)

data Node'Parameter
    = Node'Parameter
        { name :: Text
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Node'Parameter M'.Message) Node'Parameter where
    decerialize raw = Node'Parameter
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'Parameter'name raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Node'Parameter where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Node'Parameter M'.Message)

data Field'ordinal
    = Field'ordinal'implicit
    | Field'ordinal'explicit (Word16)
    | Field'ordinal'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Field'ordinal M'.Message) Field'ordinal where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Field'ordinal'implicit -> pure Field'ordinal'implicit
        Capnp.ById.Xa93fc509624c72d9.Field'ordinal'explicit val -> Field'ordinal'explicit <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Field'ordinal'unknown' val -> Field'ordinal'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Field'ordinal where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Field'ordinal M'.Message)

data CodeGeneratorRequest
    = CodeGeneratorRequest
        { nodes :: List (Node)
        , requestedFiles :: List (CodeGeneratorRequest'RequestedFile)
        , capnpVersion :: CapnpVersion
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest M'.Message) CodeGeneratorRequest where
    decerialize raw = CodeGeneratorRequest
            <$> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'nodes raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'requestedFiles raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'capnpVersion raw >>= C'.decerialize)

instance C'.IsStruct M'.Message CodeGeneratorRequest where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest M'.Message)

data Type'anyPointer
    = Type'anyPointer'unconstrained
        { union' :: Type'anyPointer'unconstrained
        }
    | Type'anyPointer'parameter
        { scopeId :: Word64
        , parameterIndex :: Word16
        }
    | Type'anyPointer'implicitMethodParameter
        { parameterIndex :: Word16
        }
    | Type'anyPointer'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Type'anyPointer M'.Message) Type'anyPointer where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unconstrained raw -> Type'anyPointer'unconstrained
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'anyPointer'unconstrained'union' raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'parameter raw -> Type'anyPointer'parameter
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'anyPointer'parameter'scopeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Type'anyPointer'parameter'parameterIndex raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'implicitMethodParameter raw -> Type'anyPointer'implicitMethodParameter
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'anyPointer'implicitMethodParameter'parameterIndex raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer'unknown' val -> Type'anyPointer'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Type'anyPointer where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Type'anyPointer M'.Message)

data Brand'Binding
    = Brand'Binding'unbound
    | Brand'Binding'type_ (Type)
    | Brand'Binding'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Brand'Binding M'.Message) Brand'Binding where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Brand'Binding'unbound -> pure Brand'Binding'unbound
        Capnp.ById.Xa93fc509624c72d9.Brand'Binding'type_ val -> Brand'Binding'type_ <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Brand'Binding'unknown' val -> Brand'Binding'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Brand'Binding where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Brand'Binding M'.Message)

data Value
    = Value'void
    | Value'bool (Bool)
    | Value'int8 (Int8)
    | Value'int16 (Int16)
    | Value'int32 (Int32)
    | Value'int64 (Int64)
    | Value'uint8 (Word8)
    | Value'uint16 (Word16)
    | Value'uint32 (Word32)
    | Value'uint64 (Word64)
    | Value'float32 (Float)
    | Value'float64 (Double)
    | Value'text (Text)
    | Value'data_ (Data)
    | Value'list (Maybe (PU'.PtrType))
    | Value'enum (Word16)
    | Value'struct (Maybe (PU'.PtrType))
    | Value'interface
    | Value'anyPointer (Maybe (PU'.PtrType))
    | Value'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Value M'.Message) Value where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Value'void -> pure Value'void
        Capnp.ById.Xa93fc509624c72d9.Value'bool val -> Value'bool <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'int8 val -> Value'int8 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'int16 val -> Value'int16 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'int32 val -> Value'int32 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'int64 val -> Value'int64 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'uint8 val -> Value'uint8 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'uint16 val -> Value'uint16 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'uint32 val -> Value'uint32 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'uint64 val -> Value'uint64 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'float32 val -> Value'float32 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'float64 val -> Value'float64 <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'text val -> Value'text <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'data_ val -> Value'data_ <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'list val -> Value'list <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'enum val -> Value'enum <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'struct val -> Value'struct <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'interface -> pure Value'interface
        Capnp.ById.Xa93fc509624c72d9.Value'anyPointer val -> Value'anyPointer <$> C'.decerialize val
        Capnp.ById.Xa93fc509624c72d9.Value'unknown' val -> Value'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Value where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Value M'.Message)

data CodeGeneratorRequest'RequestedFile
    = CodeGeneratorRequest'RequestedFile
        { id :: Word64
        , filename :: Text
        , imports :: List (CodeGeneratorRequest'RequestedFile'Import)
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest'RequestedFile M'.Message) CodeGeneratorRequest'RequestedFile where
    decerialize raw = CodeGeneratorRequest'RequestedFile
            <$> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'RequestedFile'id raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'RequestedFile'filename raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CodeGeneratorRequest'RequestedFile'imports raw >>= C'.decerialize)

instance C'.IsStruct M'.Message CodeGeneratorRequest'RequestedFile where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.CodeGeneratorRequest'RequestedFile M'.Message)

data Type
    = Type'void
    | Type'bool
    | Type'int8
    | Type'int16
    | Type'int32
    | Type'int64
    | Type'uint8
    | Type'uint16
    | Type'uint32
    | Type'uint64
    | Type'float32
    | Type'float64
    | Type'text
    | Type'data_
    | Type'list
        { elementType :: Type
        }
    | Type'enum
        { typeId :: Word64
        , brand :: Brand
        }
    | Type'struct
        { typeId :: Word64
        , brand :: Brand
        }
    | Type'interface
        { typeId :: Word64
        , brand :: Brand
        }
    | Type'anyPointer
        { union' :: Type'anyPointer
        }
    | Type'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Type M'.Message) Type where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Type'void -> pure Type'void
        Capnp.ById.Xa93fc509624c72d9.Type'bool -> pure Type'bool
        Capnp.ById.Xa93fc509624c72d9.Type'int8 -> pure Type'int8
        Capnp.ById.Xa93fc509624c72d9.Type'int16 -> pure Type'int16
        Capnp.ById.Xa93fc509624c72d9.Type'int32 -> pure Type'int32
        Capnp.ById.Xa93fc509624c72d9.Type'int64 -> pure Type'int64
        Capnp.ById.Xa93fc509624c72d9.Type'uint8 -> pure Type'uint8
        Capnp.ById.Xa93fc509624c72d9.Type'uint16 -> pure Type'uint16
        Capnp.ById.Xa93fc509624c72d9.Type'uint32 -> pure Type'uint32
        Capnp.ById.Xa93fc509624c72d9.Type'uint64 -> pure Type'uint64
        Capnp.ById.Xa93fc509624c72d9.Type'float32 -> pure Type'float32
        Capnp.ById.Xa93fc509624c72d9.Type'float64 -> pure Type'float64
        Capnp.ById.Xa93fc509624c72d9.Type'text -> pure Type'text
        Capnp.ById.Xa93fc509624c72d9.Type'data_ -> pure Type'data_
        Capnp.ById.Xa93fc509624c72d9.Type'list raw -> Type'list
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'list'elementType raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'enum raw -> Type'enum
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'enum'typeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Type'enum'brand raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'struct raw -> Type'struct
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'struct'typeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Type'struct'brand raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'interface raw -> Type'interface
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'interface'typeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Type'interface'brand raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'anyPointer raw -> Type'anyPointer
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Type'anyPointer'union' raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Type'unknown' val -> Type'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Type where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Type M'.Message)

data ElementSize
    = ElementSize'empty
    | ElementSize'bit
    | ElementSize'byte
    | ElementSize'twoBytes
    | ElementSize'fourBytes
    | ElementSize'eightBytes
    | ElementSize'pointer
    | ElementSize'inlineComposite
    | ElementSize'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize Capnp.ById.Xa93fc509624c72d9.ElementSize ElementSize where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.ElementSize'empty -> pure ElementSize'empty
        Capnp.ById.Xa93fc509624c72d9.ElementSize'bit -> pure ElementSize'bit
        Capnp.ById.Xa93fc509624c72d9.ElementSize'byte -> pure ElementSize'byte
        Capnp.ById.Xa93fc509624c72d9.ElementSize'twoBytes -> pure ElementSize'twoBytes
        Capnp.ById.Xa93fc509624c72d9.ElementSize'fourBytes -> pure ElementSize'fourBytes
        Capnp.ById.Xa93fc509624c72d9.ElementSize'eightBytes -> pure ElementSize'eightBytes
        Capnp.ById.Xa93fc509624c72d9.ElementSize'pointer -> pure ElementSize'pointer
        Capnp.ById.Xa93fc509624c72d9.ElementSize'inlineComposite -> pure ElementSize'inlineComposite
        Capnp.ById.Xa93fc509624c72d9.ElementSize'unknown' val -> ElementSize'unknown' <$> C'.decerialize val

data CapnpVersion
    = CapnpVersion
        { major :: Word16
        , minor :: Word8
        , micro :: Word8
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.CapnpVersion M'.Message) CapnpVersion where
    decerialize raw = CapnpVersion
            <$> (Capnp.ById.Xa93fc509624c72d9.get_CapnpVersion'major raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CapnpVersion'minor raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_CapnpVersion'micro raw >>= C'.decerialize)

instance C'.IsStruct M'.Message CapnpVersion where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.CapnpVersion M'.Message)

data Node'NestedNode
    = Node'NestedNode
        { name :: Text
        , id :: Word64
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Node'NestedNode M'.Message) Node'NestedNode where
    decerialize raw = Node'NestedNode
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'NestedNode'name raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'NestedNode'id raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Node'NestedNode where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Node'NestedNode M'.Message)

data Node
    = Node'
        { id :: Word64
        , displayName :: Text
        , displayNamePrefixLength :: Word32
        , scopeId :: Word64
        , nestedNodes :: List (Node'NestedNode)
        , annotations :: List (Annotation)
        , parameters :: List (Node'Parameter)
        , isGeneric :: Bool
        , union' :: Node'
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Node M'.Message) Node where
    decerialize raw = Node'
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node''id raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''displayName raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''displayNamePrefixLength raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''scopeId raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''nestedNodes raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''annotations raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''parameters raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''isGeneric raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node''union' raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Node where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Node M'.Message)

data Node'
    = Node'file
    | Node'struct
        { dataWordCount :: Word16
        , pointerCount :: Word16
        , preferredListEncoding :: ElementSize
        , isGroup :: Bool
        , discriminantCount :: Word16
        , discriminantOffset :: Word32
        , fields :: List (Field)
        }
    | Node'enum
        { enumerants :: List (Enumerant)
        }
    | Node'interface
        { methods :: List (Method)
        , superclasses :: List (Superclass)
        }
    | Node'const
        { type_ :: Type
        , value :: Value
        }
    | Node'annotation
        { type_ :: Type
        , targetsFile :: Bool
        , targetsConst :: Bool
        , targetsEnum :: Bool
        , targetsEnumerant :: Bool
        , targetsStruct :: Bool
        , targetsField :: Bool
        , targetsUnion :: Bool
        , targetsGroup :: Bool
        , targetsInterface :: Bool
        , targetsMethod :: Bool
        , targetsParam :: Bool
        , targetsAnnotation :: Bool
        }
    | Node'unknown' (Word16)
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Node' M'.Message) Node' where
    decerialize raw = case raw of

        Capnp.ById.Xa93fc509624c72d9.Node'file -> pure Node'file
        Capnp.ById.Xa93fc509624c72d9.Node'struct raw -> Node'struct
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'dataWordCount raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'pointerCount raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'preferredListEncoding raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'isGroup raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'discriminantCount raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'discriminantOffset raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'struct'fields raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Node'enum raw -> Node'enum
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'enum'enumerants raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Node'interface raw -> Node'interface
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'interface'methods raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'interface'superclasses raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Node'const raw -> Node'const
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'const'type_ raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'const'value raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Node'annotation raw -> Node'annotation
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'type_ raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsFile raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsConst raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsEnum raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsEnumerant raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsStruct raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsField raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsUnion raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsGroup raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsInterface raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsMethod raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsParam raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Node'annotation'targetsAnnotation raw >>= C'.decerialize)
        Capnp.ById.Xa93fc509624c72d9.Node'unknown' val -> Node'unknown' <$> C'.decerialize val

instance C'.IsStruct M'.Message Node' where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Node' M'.Message)

data Annotation
    = Annotation
        { id :: Word64
        , value :: Value
        , brand :: Brand
        }
    deriving(Show, Read, Eq)

instance C'.Decerialize (Capnp.ById.Xa93fc509624c72d9.Annotation M'.Message) Annotation where
    decerialize raw = Annotation
            <$> (Capnp.ById.Xa93fc509624c72d9.get_Annotation'id raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Annotation'value raw >>= C'.decerialize)
            <*> (Capnp.ById.Xa93fc509624c72d9.get_Annotation'brand raw >>= C'.decerialize)

instance C'.IsStruct M'.Message Annotation where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa93fc509624c72d9.Annotation M'.Message)

