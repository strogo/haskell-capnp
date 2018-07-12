{-# OPTIONS_GHC -Wno-unused-imports #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
module Capnp.Capnp.Json where

-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/json.capnp

import Data.Int
import Data.Word
import qualified Data.Bits
import qualified Data.Maybe
import qualified Codec.Capnp.Generic as C'
import qualified Data.Capnp.Basics.Generic as GB'
import qualified Data.Capnp.TraversalLimit as TL'
import qualified Data.Capnp.Untyped.Generic as U'
import qualified Data.Capnp.Message.Mutable as MM'

import qualified Capnp.ById.Xbdf87d7bb8304e81

data JsonValue msg
    = JsonValue'null
    | JsonValue'boolean Bool
    | JsonValue'number Double
    | JsonValue'string (GB'.Text msg)
    | JsonValue'array (GB'.List msg (JsonValue msg))
    | JsonValue'object (GB'.List msg (JsonValue'Field msg))
    | JsonValue'call (JsonValue'Call msg)
    | JsonValue'unknown' Word16








instance C'.IsStruct msg (JsonValue msg) where
    fromStruct struct = do
        tag <-  C'.getWordField struct 0 0 0
        case tag of
            6 -> JsonValue'call <$>  (U'.getPtr 0 struct >>= C'.fromPtr (U'.message struct))
            5 -> JsonValue'object <$>  (U'.getPtr 0 struct >>= C'.fromPtr (U'.message struct))
            4 -> JsonValue'array <$>  (U'.getPtr 0 struct >>= C'.fromPtr (U'.message struct))
            3 -> JsonValue'string <$>  (U'.getPtr 0 struct >>= C'.fromPtr (U'.message struct))
            2 -> JsonValue'number <$>  C'.getWordField struct 1 0 0
            1 -> JsonValue'boolean <$>  C'.getWordField struct 0 16 0
            0 -> pure JsonValue'null
            _ -> pure $ JsonValue'unknown' tag
instance GB'.ListElem msg (JsonValue msg) where
    newtype List msg (JsonValue msg) = List_JsonValue (U'.ListOf msg (U'.Struct msg))
    length (List_JsonValue l) = U'.length l
    index i (List_JsonValue l) = U'.index i l >>= (let {go :: U'.ReadCtx m msg => U'.Struct msg -> m (JsonValue msg); go = C'.fromStruct} in go)

instance C'.IsPtr msg (JsonValue msg) where
    fromPtr msg ptr = C'.fromPtr msg ptr >>= (let {go :: U'.ReadCtx m msg => U'.Struct msg -> m (JsonValue msg); go = C'.fromStruct} in go)

instance C'.IsPtr msg (GB'.List msg (JsonValue msg)) where
    fromPtr msg ptr = List_JsonValue <$> C'.fromPtr msg ptr

newtype JsonValue'Call msg = JsonValue'Call (U'.Struct msg)

instance C'.IsStruct msg (JsonValue'Call msg) where
    fromStruct = pure . JsonValue'Call
instance C'.IsPtr msg (JsonValue'Call msg) where
    fromPtr msg ptr = JsonValue'Call <$> C'.fromPtr msg ptr
instance GB'.ListElem msg (JsonValue'Call msg) where
    newtype List msg (JsonValue'Call msg) = List_JsonValue'Call (U'.ListOf msg (U'.Struct msg))
    length (List_JsonValue'Call l) = U'.length l
    index i (List_JsonValue'Call l) = U'.index i l >>= (let {go :: U'.ReadCtx m msg => U'.Struct msg -> m (JsonValue'Call msg); go = C'.fromStruct} in go)
instance GB'.MutListElem s (JsonValue'Call (MM'.Message s)) where
    setIndex (JsonValue'Call elt) i (List_JsonValue'Call l) = U'.setIndex elt i l

instance C'.IsPtr msg (GB'.List msg (JsonValue'Call msg)) where
    fromPtr msg ptr = List_JsonValue'Call <$> C'.fromPtr msg ptr
get_JsonValue'Call'function :: U'.ReadCtx m msg => JsonValue'Call msg -> m (GB'.Text msg)
get_JsonValue'Call'function (JsonValue'Call struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)


has_JsonValue'Call'function :: U'.ReadCtx m msg => JsonValue'Call msg -> m Bool
has_JsonValue'Call'function(JsonValue'Call struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
get_JsonValue'Call'params :: U'.ReadCtx m msg => JsonValue'Call msg -> m (GB'.List msg (JsonValue msg))
get_JsonValue'Call'params (JsonValue'Call struct) =
    U'.getPtr 1 struct
    >>= C'.fromPtr (U'.message struct)


has_JsonValue'Call'params :: U'.ReadCtx m msg => JsonValue'Call msg -> m Bool
has_JsonValue'Call'params(JsonValue'Call struct) = Data.Maybe.isJust <$> U'.getPtr 1 struct
newtype JsonValue'Field msg = JsonValue'Field (U'.Struct msg)

instance C'.IsStruct msg (JsonValue'Field msg) where
    fromStruct = pure . JsonValue'Field
instance C'.IsPtr msg (JsonValue'Field msg) where
    fromPtr msg ptr = JsonValue'Field <$> C'.fromPtr msg ptr
instance GB'.ListElem msg (JsonValue'Field msg) where
    newtype List msg (JsonValue'Field msg) = List_JsonValue'Field (U'.ListOf msg (U'.Struct msg))
    length (List_JsonValue'Field l) = U'.length l
    index i (List_JsonValue'Field l) = U'.index i l >>= (let {go :: U'.ReadCtx m msg => U'.Struct msg -> m (JsonValue'Field msg); go = C'.fromStruct} in go)
instance GB'.MutListElem s (JsonValue'Field (MM'.Message s)) where
    setIndex (JsonValue'Field elt) i (List_JsonValue'Field l) = U'.setIndex elt i l

instance C'.IsPtr msg (GB'.List msg (JsonValue'Field msg)) where
    fromPtr msg ptr = List_JsonValue'Field <$> C'.fromPtr msg ptr
get_JsonValue'Field'name :: U'.ReadCtx m msg => JsonValue'Field msg -> m (GB'.Text msg)
get_JsonValue'Field'name (JsonValue'Field struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)


has_JsonValue'Field'name :: U'.ReadCtx m msg => JsonValue'Field msg -> m Bool
has_JsonValue'Field'name(JsonValue'Field struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
get_JsonValue'Field'value :: U'.ReadCtx m msg => JsonValue'Field msg -> m (JsonValue msg)
get_JsonValue'Field'value (JsonValue'Field struct) =
    U'.getPtr 1 struct
    >>= C'.fromPtr (U'.message struct)


has_JsonValue'Field'value :: U'.ReadCtx m msg => JsonValue'Field msg -> m Bool
has_JsonValue'Field'value(JsonValue'Field struct) = Data.Maybe.isJust <$> U'.getPtr 1 struct