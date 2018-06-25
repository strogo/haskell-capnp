{-# LANGUAGE TypeFamilies #-}
module Data.Capnp.BuiltinTypes.Lists where
-- This module is auto-generated; DO NOT EDIT.

import Data.Int
import Data.Word
import Data.ReinterpretCast

import qualified Data.Capnp.Message.Generic as GM
import qualified Data.Capnp.Message.Mutable as MM
import qualified Data.Capnp.Untyped.Generic as GU

class ListElem e where
    data List msg e
    length :: List msg e -> Int
    index :: (GM.Message m msg, GU.ReadCtx m) => Int -> List msg e -> m e
    setIndex :: (GU.ReadCtx m, MM.WriteCtx m s) => e -> Int -> List (MM.Message s) e -> m ()

instance ListElem Int8 where
    newtype List msg Int8 = ListInt8 (GU.ListOf msg Word8)
    length (ListInt8 l) = GU.length l
    index i (ListInt8 l) = fromIntegral <$> GU.index i l
    setIndex elt i (ListInt8 l) = GU.setIndex (fromIntegral elt) i l
instance ListElem Int16 where
    newtype List msg Int16 = ListInt16 (GU.ListOf msg Word16)
    length (ListInt16 l) = GU.length l
    index i (ListInt16 l) = fromIntegral <$> GU.index i l
    setIndex elt i (ListInt16 l) = GU.setIndex (fromIntegral elt) i l
instance ListElem Int32 where
    newtype List msg Int32 = ListInt32 (GU.ListOf msg Word32)
    length (ListInt32 l) = GU.length l
    index i (ListInt32 l) = fromIntegral <$> GU.index i l
    setIndex elt i (ListInt32 l) = GU.setIndex (fromIntegral elt) i l
instance ListElem Int64 where
    newtype List msg Int64 = ListInt64 (GU.ListOf msg Word64)
    length (ListInt64 l) = GU.length l
    index i (ListInt64 l) = fromIntegral <$> GU.index i l
    setIndex elt i (ListInt64 l) = GU.setIndex (fromIntegral elt) i l
instance ListElem Word8 where
    newtype List msg Word8 = ListWord8 (GU.ListOf msg Word8)
    length (ListWord8 l) = GU.length l
    index i (ListWord8 l) = id <$> GU.index i l
    setIndex elt i (ListWord8 l) = GU.setIndex (id elt) i l
instance ListElem Word16 where
    newtype List msg Word16 = ListWord16 (GU.ListOf msg Word16)
    length (ListWord16 l) = GU.length l
    index i (ListWord16 l) = id <$> GU.index i l
    setIndex elt i (ListWord16 l) = GU.setIndex (id elt) i l
instance ListElem Word32 where
    newtype List msg Word32 = ListWord32 (GU.ListOf msg Word32)
    length (ListWord32 l) = GU.length l
    index i (ListWord32 l) = id <$> GU.index i l
    setIndex elt i (ListWord32 l) = GU.setIndex (id elt) i l
instance ListElem Word64 where
    newtype List msg Word64 = ListWord64 (GU.ListOf msg Word64)
    length (ListWord64 l) = GU.length l
    index i (ListWord64 l) = id <$> GU.index i l
    setIndex elt i (ListWord64 l) = GU.setIndex (id elt) i l
instance ListElem Float where
    newtype List msg Float = ListFloat (GU.ListOf msg Word32)
    length (ListFloat l) = GU.length l
    index i (ListFloat l) = wordToFloat <$> GU.index i l
    setIndex elt i (ListFloat l) = GU.setIndex (floatToWord elt) i l
instance ListElem Double where
    newtype List msg Double = ListDouble (GU.ListOf msg Word64)
    length (ListDouble l) = GU.length l
    index i (ListDouble l) = wordToDouble <$> GU.index i l
    setIndex elt i (ListDouble l) = GU.setIndex (doubleToWord elt) i l
instance ListElem Bool where
    newtype List msg Bool = ListBool (GU.ListOf msg Bool)
    length (ListBool l) = GU.length l
    index i (ListBool l) = id <$> GU.index i l
    setIndex elt i (ListBool l) = GU.setIndex (id elt) i l

