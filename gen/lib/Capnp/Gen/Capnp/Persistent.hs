{-# OPTIONS_GHC -Wno-unused-imports #-}
{-# OPTIONS_GHC -Wno-unused-matches #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}
{- |
Module: Capnp.Gen.Capnp.Persistent
Description: Low-level generated module for capnp/persistent.capnp
This module is the generated code for capnp/persistent.capnp, for the
low-level api.
-}
module Capnp.Gen.Capnp.Persistent where
-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/persistent.capnp
import Data.Int
import Data.Word
import GHC.Generics (Generic)
import Capnp.Bits (Word1)
import qualified Data.Bits
import qualified Data.Maybe
import qualified Data.ByteString
import qualified Capnp.Classes as C'
import qualified Capnp.Basics as B'
import qualified Capnp.GenHelpers as H'
import qualified Capnp.TraversalLimit as TL'
import qualified Capnp.Untyped as U'
import qualified Capnp.Message as M'
import qualified Capnp.Gen.ById.Xbdf87d7bb8304e81
newtype Persistent msg = Persistent (Maybe (U'.Cap msg))
instance C'.FromPtr msg (Persistent msg) where
    fromPtr msg cap = Persistent <$> C'.fromPtr msg cap
instance C'.ToPtr s (Persistent (M'.MutMsg s)) where
    toPtr msg (Persistent Nothing) = pure Nothing
    toPtr msg (Persistent (Just cap)) = pure $ Just $ U'.PtrCap cap
newtype RealmGateway msg = RealmGateway (Maybe (U'.Cap msg))
instance C'.FromPtr msg (RealmGateway msg) where
    fromPtr msg cap = RealmGateway <$> C'.fromPtr msg cap
instance C'.ToPtr s (RealmGateway (M'.MutMsg s)) where
    toPtr msg (RealmGateway Nothing) = pure Nothing
    toPtr msg (RealmGateway (Just cap)) = pure $ Just $ U'.PtrCap cap
newtype Persistent'SaveParams msg = Persistent'SaveParams_newtype_ (U'.Struct msg)
instance U'.TraverseMsg Persistent'SaveParams where
    tMsg f (Persistent'SaveParams_newtype_ s) = Persistent'SaveParams_newtype_ <$> U'.tMsg f s
instance C'.FromStruct msg (Persistent'SaveParams msg) where
    fromStruct = pure . Persistent'SaveParams_newtype_
instance C'.ToStruct msg (Persistent'SaveParams msg) where
    toStruct (Persistent'SaveParams_newtype_ struct) = struct
instance U'.HasMessage (Persistent'SaveParams msg) where
    type InMessage (Persistent'SaveParams msg) = msg
    message (Persistent'SaveParams_newtype_ struct) = U'.message struct
instance U'.MessageDefault (Persistent'SaveParams msg) where
    messageDefault = Persistent'SaveParams_newtype_ . U'.messageDefault
instance B'.ListElem msg (Persistent'SaveParams msg) where
    newtype List msg (Persistent'SaveParams msg) = List_Persistent'SaveParams (U'.ListOf msg (U'.Struct msg))
    listFromPtr msg ptr = List_Persistent'SaveParams <$> C'.fromPtr msg ptr
    toUntypedList (List_Persistent'SaveParams l) = U'.ListStruct l
    length (List_Persistent'SaveParams l) = U'.length l
    index i (List_Persistent'SaveParams l) = U'.index i l >>= C'.fromStruct
instance C'.FromPtr msg (Persistent'SaveParams msg) where
    fromPtr msg ptr = Persistent'SaveParams_newtype_ <$> C'.fromPtr msg ptr
instance C'.ToPtr s (Persistent'SaveParams (M'.MutMsg s)) where
    toPtr msg (Persistent'SaveParams_newtype_ struct) = C'.toPtr msg struct
instance B'.MutListElem s (Persistent'SaveParams (M'.MutMsg s)) where
    setIndex (Persistent'SaveParams_newtype_ elt) i (List_Persistent'SaveParams l) = U'.setIndex elt i l
    newList msg len = List_Persistent'SaveParams <$> U'.allocCompositeList msg 0 1 len
instance C'.Allocate s (Persistent'SaveParams (M'.MutMsg s)) where
    new msg = Persistent'SaveParams_newtype_ <$> U'.allocStruct msg 0 1
get_Persistent'SaveParams'sealFor :: U'.ReadCtx m msg => Persistent'SaveParams msg -> m (Maybe (U'.Ptr msg))
get_Persistent'SaveParams'sealFor (Persistent'SaveParams_newtype_ struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)
has_Persistent'SaveParams'sealFor :: U'.ReadCtx m msg => Persistent'SaveParams msg -> m Bool
has_Persistent'SaveParams'sealFor(Persistent'SaveParams_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
set_Persistent'SaveParams'sealFor :: U'.RWCtx m s => Persistent'SaveParams (M'.MutMsg s) -> (Maybe (U'.Ptr (M'.MutMsg s))) -> m ()
set_Persistent'SaveParams'sealFor (Persistent'SaveParams_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 0 struct
newtype Persistent'SaveResults msg = Persistent'SaveResults_newtype_ (U'.Struct msg)
instance U'.TraverseMsg Persistent'SaveResults where
    tMsg f (Persistent'SaveResults_newtype_ s) = Persistent'SaveResults_newtype_ <$> U'.tMsg f s
instance C'.FromStruct msg (Persistent'SaveResults msg) where
    fromStruct = pure . Persistent'SaveResults_newtype_
instance C'.ToStruct msg (Persistent'SaveResults msg) where
    toStruct (Persistent'SaveResults_newtype_ struct) = struct
instance U'.HasMessage (Persistent'SaveResults msg) where
    type InMessage (Persistent'SaveResults msg) = msg
    message (Persistent'SaveResults_newtype_ struct) = U'.message struct
instance U'.MessageDefault (Persistent'SaveResults msg) where
    messageDefault = Persistent'SaveResults_newtype_ . U'.messageDefault
instance B'.ListElem msg (Persistent'SaveResults msg) where
    newtype List msg (Persistent'SaveResults msg) = List_Persistent'SaveResults (U'.ListOf msg (U'.Struct msg))
    listFromPtr msg ptr = List_Persistent'SaveResults <$> C'.fromPtr msg ptr
    toUntypedList (List_Persistent'SaveResults l) = U'.ListStruct l
    length (List_Persistent'SaveResults l) = U'.length l
    index i (List_Persistent'SaveResults l) = U'.index i l >>= C'.fromStruct
instance C'.FromPtr msg (Persistent'SaveResults msg) where
    fromPtr msg ptr = Persistent'SaveResults_newtype_ <$> C'.fromPtr msg ptr
instance C'.ToPtr s (Persistent'SaveResults (M'.MutMsg s)) where
    toPtr msg (Persistent'SaveResults_newtype_ struct) = C'.toPtr msg struct
instance B'.MutListElem s (Persistent'SaveResults (M'.MutMsg s)) where
    setIndex (Persistent'SaveResults_newtype_ elt) i (List_Persistent'SaveResults l) = U'.setIndex elt i l
    newList msg len = List_Persistent'SaveResults <$> U'.allocCompositeList msg 0 1 len
instance C'.Allocate s (Persistent'SaveResults (M'.MutMsg s)) where
    new msg = Persistent'SaveResults_newtype_ <$> U'.allocStruct msg 0 1
get_Persistent'SaveResults'sturdyRef :: U'.ReadCtx m msg => Persistent'SaveResults msg -> m (Maybe (U'.Ptr msg))
get_Persistent'SaveResults'sturdyRef (Persistent'SaveResults_newtype_ struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)
has_Persistent'SaveResults'sturdyRef :: U'.ReadCtx m msg => Persistent'SaveResults msg -> m Bool
has_Persistent'SaveResults'sturdyRef(Persistent'SaveResults_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
set_Persistent'SaveResults'sturdyRef :: U'.RWCtx m s => Persistent'SaveResults (M'.MutMsg s) -> (Maybe (U'.Ptr (M'.MutMsg s))) -> m ()
set_Persistent'SaveResults'sturdyRef (Persistent'SaveResults_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 0 struct
newtype RealmGateway'export'params msg = RealmGateway'export'params_newtype_ (U'.Struct msg)
instance U'.TraverseMsg RealmGateway'export'params where
    tMsg f (RealmGateway'export'params_newtype_ s) = RealmGateway'export'params_newtype_ <$> U'.tMsg f s
instance C'.FromStruct msg (RealmGateway'export'params msg) where
    fromStruct = pure . RealmGateway'export'params_newtype_
instance C'.ToStruct msg (RealmGateway'export'params msg) where
    toStruct (RealmGateway'export'params_newtype_ struct) = struct
instance U'.HasMessage (RealmGateway'export'params msg) where
    type InMessage (RealmGateway'export'params msg) = msg
    message (RealmGateway'export'params_newtype_ struct) = U'.message struct
instance U'.MessageDefault (RealmGateway'export'params msg) where
    messageDefault = RealmGateway'export'params_newtype_ . U'.messageDefault
instance B'.ListElem msg (RealmGateway'export'params msg) where
    newtype List msg (RealmGateway'export'params msg) = List_RealmGateway'export'params (U'.ListOf msg (U'.Struct msg))
    listFromPtr msg ptr = List_RealmGateway'export'params <$> C'.fromPtr msg ptr
    toUntypedList (List_RealmGateway'export'params l) = U'.ListStruct l
    length (List_RealmGateway'export'params l) = U'.length l
    index i (List_RealmGateway'export'params l) = U'.index i l >>= C'.fromStruct
instance C'.FromPtr msg (RealmGateway'export'params msg) where
    fromPtr msg ptr = RealmGateway'export'params_newtype_ <$> C'.fromPtr msg ptr
instance C'.ToPtr s (RealmGateway'export'params (M'.MutMsg s)) where
    toPtr msg (RealmGateway'export'params_newtype_ struct) = C'.toPtr msg struct
instance B'.MutListElem s (RealmGateway'export'params (M'.MutMsg s)) where
    setIndex (RealmGateway'export'params_newtype_ elt) i (List_RealmGateway'export'params l) = U'.setIndex elt i l
    newList msg len = List_RealmGateway'export'params <$> U'.allocCompositeList msg 0 2 len
instance C'.Allocate s (RealmGateway'export'params (M'.MutMsg s)) where
    new msg = RealmGateway'export'params_newtype_ <$> U'.allocStruct msg 0 2
get_RealmGateway'export'params'cap :: U'.ReadCtx m msg => RealmGateway'export'params msg -> m (Persistent msg)
get_RealmGateway'export'params'cap (RealmGateway'export'params_newtype_ struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)
has_RealmGateway'export'params'cap :: U'.ReadCtx m msg => RealmGateway'export'params msg -> m Bool
has_RealmGateway'export'params'cap(RealmGateway'export'params_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
set_RealmGateway'export'params'cap :: U'.RWCtx m s => RealmGateway'export'params (M'.MutMsg s) -> (Persistent (M'.MutMsg s)) -> m ()
set_RealmGateway'export'params'cap (RealmGateway'export'params_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 0 struct
get_RealmGateway'export'params'params :: U'.ReadCtx m msg => RealmGateway'export'params msg -> m (Persistent'SaveParams msg)
get_RealmGateway'export'params'params (RealmGateway'export'params_newtype_ struct) =
    U'.getPtr 1 struct
    >>= C'.fromPtr (U'.message struct)
has_RealmGateway'export'params'params :: U'.ReadCtx m msg => RealmGateway'export'params msg -> m Bool
has_RealmGateway'export'params'params(RealmGateway'export'params_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 1 struct
set_RealmGateway'export'params'params :: U'.RWCtx m s => RealmGateway'export'params (M'.MutMsg s) -> (Persistent'SaveParams (M'.MutMsg s)) -> m ()
set_RealmGateway'export'params'params (RealmGateway'export'params_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 1 struct
new_RealmGateway'export'params'params :: U'.RWCtx m s => RealmGateway'export'params (M'.MutMsg s) -> m ((Persistent'SaveParams (M'.MutMsg s)))
new_RealmGateway'export'params'params struct = do
    result <- C'.new (U'.message struct)
    set_RealmGateway'export'params'params struct result
    pure result
newtype RealmGateway'import'params msg = RealmGateway'import'params_newtype_ (U'.Struct msg)
instance U'.TraverseMsg RealmGateway'import'params where
    tMsg f (RealmGateway'import'params_newtype_ s) = RealmGateway'import'params_newtype_ <$> U'.tMsg f s
instance C'.FromStruct msg (RealmGateway'import'params msg) where
    fromStruct = pure . RealmGateway'import'params_newtype_
instance C'.ToStruct msg (RealmGateway'import'params msg) where
    toStruct (RealmGateway'import'params_newtype_ struct) = struct
instance U'.HasMessage (RealmGateway'import'params msg) where
    type InMessage (RealmGateway'import'params msg) = msg
    message (RealmGateway'import'params_newtype_ struct) = U'.message struct
instance U'.MessageDefault (RealmGateway'import'params msg) where
    messageDefault = RealmGateway'import'params_newtype_ . U'.messageDefault
instance B'.ListElem msg (RealmGateway'import'params msg) where
    newtype List msg (RealmGateway'import'params msg) = List_RealmGateway'import'params (U'.ListOf msg (U'.Struct msg))
    listFromPtr msg ptr = List_RealmGateway'import'params <$> C'.fromPtr msg ptr
    toUntypedList (List_RealmGateway'import'params l) = U'.ListStruct l
    length (List_RealmGateway'import'params l) = U'.length l
    index i (List_RealmGateway'import'params l) = U'.index i l >>= C'.fromStruct
instance C'.FromPtr msg (RealmGateway'import'params msg) where
    fromPtr msg ptr = RealmGateway'import'params_newtype_ <$> C'.fromPtr msg ptr
instance C'.ToPtr s (RealmGateway'import'params (M'.MutMsg s)) where
    toPtr msg (RealmGateway'import'params_newtype_ struct) = C'.toPtr msg struct
instance B'.MutListElem s (RealmGateway'import'params (M'.MutMsg s)) where
    setIndex (RealmGateway'import'params_newtype_ elt) i (List_RealmGateway'import'params l) = U'.setIndex elt i l
    newList msg len = List_RealmGateway'import'params <$> U'.allocCompositeList msg 0 2 len
instance C'.Allocate s (RealmGateway'import'params (M'.MutMsg s)) where
    new msg = RealmGateway'import'params_newtype_ <$> U'.allocStruct msg 0 2
get_RealmGateway'import'params'cap :: U'.ReadCtx m msg => RealmGateway'import'params msg -> m (Persistent msg)
get_RealmGateway'import'params'cap (RealmGateway'import'params_newtype_ struct) =
    U'.getPtr 0 struct
    >>= C'.fromPtr (U'.message struct)
has_RealmGateway'import'params'cap :: U'.ReadCtx m msg => RealmGateway'import'params msg -> m Bool
has_RealmGateway'import'params'cap(RealmGateway'import'params_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 0 struct
set_RealmGateway'import'params'cap :: U'.RWCtx m s => RealmGateway'import'params (M'.MutMsg s) -> (Persistent (M'.MutMsg s)) -> m ()
set_RealmGateway'import'params'cap (RealmGateway'import'params_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 0 struct
get_RealmGateway'import'params'params :: U'.ReadCtx m msg => RealmGateway'import'params msg -> m (Persistent'SaveParams msg)
get_RealmGateway'import'params'params (RealmGateway'import'params_newtype_ struct) =
    U'.getPtr 1 struct
    >>= C'.fromPtr (U'.message struct)
has_RealmGateway'import'params'params :: U'.ReadCtx m msg => RealmGateway'import'params msg -> m Bool
has_RealmGateway'import'params'params(RealmGateway'import'params_newtype_ struct) = Data.Maybe.isJust <$> U'.getPtr 1 struct
set_RealmGateway'import'params'params :: U'.RWCtx m s => RealmGateway'import'params (M'.MutMsg s) -> (Persistent'SaveParams (M'.MutMsg s)) -> m ()
set_RealmGateway'import'params'params (RealmGateway'import'params_newtype_ struct) value = do
    ptr <- C'.toPtr (U'.message struct) value
    U'.setPtr ptr 1 struct
new_RealmGateway'import'params'params :: U'.RWCtx m s => RealmGateway'import'params (M'.MutMsg s) -> m ((Persistent'SaveParams (M'.MutMsg s)))
new_RealmGateway'import'params'params struct = do
    result <- C'.new (U'.message struct)
    set_RealmGateway'import'params'params struct result
    pure result