{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Internal.Gen.Instances where
-- This module is auto-generated by gen-builtintypes-lists.hs; DO NOT EDIT.

import Data.Int
import Data.ReinterpretCast
import Data.Word

import Codec.Capnp
    ( ListElem(..)
    , MutListElem(..)
    , Decerialize(..)
    , IsPtr(..)
    )

import qualified Data.Capnp.Untyped as U

instance ListElem msg Int8 where
    newtype List msg Int8 = ListInt8 (U.ListOf msg Word8)
    length (ListInt8 l) = U.length l
    index i (ListInt8 l) = fromIntegral <$> U.index i l
instance MutListElem s Int8 where
    setIndex elt i (ListInt8 l) = U.setIndex (fromIntegral elt) i l
    newList msg size = ListInt8 <$> U.allocList8 msg size
instance Decerialize Int8 where
    type Cerial msg Int8 = Int8
    decerialize = pure
instance IsPtr msg (List msg Int8) where
    fromPtr msg ptr = ListInt8 <$> fromPtr msg ptr
    toPtr (ListInt8 list) = Just (U.PtrList (U.List8 list))
instance ListElem msg Int16 where
    newtype List msg Int16 = ListInt16 (U.ListOf msg Word16)
    length (ListInt16 l) = U.length l
    index i (ListInt16 l) = fromIntegral <$> U.index i l
instance MutListElem s Int16 where
    setIndex elt i (ListInt16 l) = U.setIndex (fromIntegral elt) i l
    newList msg size = ListInt16 <$> U.allocList16 msg size
instance Decerialize Int16 where
    type Cerial msg Int16 = Int16
    decerialize = pure
instance IsPtr msg (List msg Int16) where
    fromPtr msg ptr = ListInt16 <$> fromPtr msg ptr
    toPtr (ListInt16 list) = Just (U.PtrList (U.List16 list))
instance ListElem msg Int32 where
    newtype List msg Int32 = ListInt32 (U.ListOf msg Word32)
    length (ListInt32 l) = U.length l
    index i (ListInt32 l) = fromIntegral <$> U.index i l
instance MutListElem s Int32 where
    setIndex elt i (ListInt32 l) = U.setIndex (fromIntegral elt) i l
    newList msg size = ListInt32 <$> U.allocList32 msg size
instance Decerialize Int32 where
    type Cerial msg Int32 = Int32
    decerialize = pure
instance IsPtr msg (List msg Int32) where
    fromPtr msg ptr = ListInt32 <$> fromPtr msg ptr
    toPtr (ListInt32 list) = Just (U.PtrList (U.List32 list))
instance ListElem msg Int64 where
    newtype List msg Int64 = ListInt64 (U.ListOf msg Word64)
    length (ListInt64 l) = U.length l
    index i (ListInt64 l) = fromIntegral <$> U.index i l
instance MutListElem s Int64 where
    setIndex elt i (ListInt64 l) = U.setIndex (fromIntegral elt) i l
    newList msg size = ListInt64 <$> U.allocList64 msg size
instance Decerialize Int64 where
    type Cerial msg Int64 = Int64
    decerialize = pure
instance IsPtr msg (List msg Int64) where
    fromPtr msg ptr = ListInt64 <$> fromPtr msg ptr
    toPtr (ListInt64 list) = Just (U.PtrList (U.List64 list))
instance ListElem msg Word8 where
    newtype List msg Word8 = ListWord8 (U.ListOf msg Word8)
    length (ListWord8 l) = U.length l
    index i (ListWord8 l) = id <$> U.index i l
instance MutListElem s Word8 where
    setIndex elt i (ListWord8 l) = U.setIndex (id elt) i l
    newList msg size = ListWord8 <$> U.allocList8 msg size
instance Decerialize Word8 where
    type Cerial msg Word8 = Word8
    decerialize = pure
instance IsPtr msg (List msg Word8) where
    fromPtr msg ptr = ListWord8 <$> fromPtr msg ptr
    toPtr (ListWord8 list) = Just (U.PtrList (U.List8 list))
instance ListElem msg Word16 where
    newtype List msg Word16 = ListWord16 (U.ListOf msg Word16)
    length (ListWord16 l) = U.length l
    index i (ListWord16 l) = id <$> U.index i l
instance MutListElem s Word16 where
    setIndex elt i (ListWord16 l) = U.setIndex (id elt) i l
    newList msg size = ListWord16 <$> U.allocList16 msg size
instance Decerialize Word16 where
    type Cerial msg Word16 = Word16
    decerialize = pure
instance IsPtr msg (List msg Word16) where
    fromPtr msg ptr = ListWord16 <$> fromPtr msg ptr
    toPtr (ListWord16 list) = Just (U.PtrList (U.List16 list))
instance ListElem msg Word32 where
    newtype List msg Word32 = ListWord32 (U.ListOf msg Word32)
    length (ListWord32 l) = U.length l
    index i (ListWord32 l) = id <$> U.index i l
instance MutListElem s Word32 where
    setIndex elt i (ListWord32 l) = U.setIndex (id elt) i l
    newList msg size = ListWord32 <$> U.allocList32 msg size
instance Decerialize Word32 where
    type Cerial msg Word32 = Word32
    decerialize = pure
instance IsPtr msg (List msg Word32) where
    fromPtr msg ptr = ListWord32 <$> fromPtr msg ptr
    toPtr (ListWord32 list) = Just (U.PtrList (U.List32 list))
instance ListElem msg Word64 where
    newtype List msg Word64 = ListWord64 (U.ListOf msg Word64)
    length (ListWord64 l) = U.length l
    index i (ListWord64 l) = id <$> U.index i l
instance MutListElem s Word64 where
    setIndex elt i (ListWord64 l) = U.setIndex (id elt) i l
    newList msg size = ListWord64 <$> U.allocList64 msg size
instance Decerialize Word64 where
    type Cerial msg Word64 = Word64
    decerialize = pure
instance IsPtr msg (List msg Word64) where
    fromPtr msg ptr = ListWord64 <$> fromPtr msg ptr
    toPtr (ListWord64 list) = Just (U.PtrList (U.List64 list))
instance ListElem msg Float where
    newtype List msg Float = ListFloat (U.ListOf msg Word32)
    length (ListFloat l) = U.length l
    index i (ListFloat l) = wordToFloat <$> U.index i l
instance MutListElem s Float where
    setIndex elt i (ListFloat l) = U.setIndex (floatToWord elt) i l
    newList msg size = ListFloat <$> U.allocList32 msg size
instance Decerialize Float where
    type Cerial msg Float = Float
    decerialize = pure
instance IsPtr msg (List msg Float) where
    fromPtr msg ptr = ListFloat <$> fromPtr msg ptr
    toPtr (ListFloat list) = Just (U.PtrList (U.List32 list))
instance ListElem msg Double where
    newtype List msg Double = ListDouble (U.ListOf msg Word64)
    length (ListDouble l) = U.length l
    index i (ListDouble l) = wordToDouble <$> U.index i l
instance MutListElem s Double where
    setIndex elt i (ListDouble l) = U.setIndex (doubleToWord elt) i l
    newList msg size = ListDouble <$> U.allocList64 msg size
instance Decerialize Double where
    type Cerial msg Double = Double
    decerialize = pure
instance IsPtr msg (List msg Double) where
    fromPtr msg ptr = ListDouble <$> fromPtr msg ptr
    toPtr (ListDouble list) = Just (U.PtrList (U.List64 list))
instance ListElem msg Bool where
    newtype List msg Bool = ListBool (U.ListOf msg Bool)
    length (ListBool l) = U.length l
    index i (ListBool l) = id <$> U.index i l
instance MutListElem s Bool where
    setIndex elt i (ListBool l) = U.setIndex (id elt) i l
    newList msg size = ListBool <$> U.allocList1 msg size
instance Decerialize Bool where
    type Cerial msg Bool = Bool
    decerialize = pure
instance IsPtr msg (List msg Bool) where
    fromPtr msg ptr = ListBool <$> fromPtr msg ptr
    toPtr (ListBool list) = Just (U.PtrList (U.List1 list))
