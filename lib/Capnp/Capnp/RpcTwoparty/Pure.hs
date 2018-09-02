{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
{- |
Module: Capnp.Capnp.RpcTwoparty.Pure
Description: High-level generated module for capnp/rpc-twoparty.capnp
This module is the generated code for capnp/rpc-twoparty.capnp,
for the high-level api.
-}
module Capnp.Capnp.RpcTwoparty.Pure (JoinKeyPart(..), JoinResult(..), ProvisionId(..), Capnp.ById.Xa184c7885cdaf2a1.Side(..), VatId(..)
) where
-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/rpc-twoparty.capnp
import Data.Int
import Data.Word
import Data.Default (Default(def))
import GHC.Generics (Generic)
import Data.Capnp.Basics.Pure (Data, Text)
import Control.Monad.Catch (MonadThrow)
import Data.Capnp.TraversalLimit (MonadLimit)
import Control.Monad (forM_)
import qualified Data.Capnp.Message as M'
import qualified Data.Capnp.Untyped as U'
import qualified Data.Capnp.Untyped.Pure as PU'
import qualified Data.Capnp.GenHelpers.Pure as PH'
import qualified Data.Capnp.Classes as C'
import qualified Data.Vector as V
import qualified Data.ByteString as BS
import qualified Capnp.ById.Xa184c7885cdaf2a1
import qualified Capnp.ById.Xbdf87d7bb8304e81.Pure
import qualified Capnp.ById.Xbdf87d7bb8304e81
data JoinKeyPart
    = JoinKeyPart
        {joinId :: Word32,
        partCount :: Word16,
        partNum :: Word16}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize JoinKeyPart where
    type Cerial msg JoinKeyPart = Capnp.ById.Xa184c7885cdaf2a1.JoinKeyPart msg
    decerialize raw = do
        JoinKeyPart <$>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinKeyPart'joinId raw) <*>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinKeyPart'partCount raw) <*>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinKeyPart'partNum raw)
instance C'.Marshal JoinKeyPart where
    marshalInto raw value = do
        case value of
            JoinKeyPart{..} -> do
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinKeyPart'joinId raw joinId
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinKeyPart'partCount raw partCount
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinKeyPart'partNum raw partNum
instance C'.Cerialize s JoinKeyPart
instance C'.FromStruct M'.ConstMsg JoinKeyPart where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa184c7885cdaf2a1.JoinKeyPart M'.ConstMsg)
instance Default JoinKeyPart where
    def = PH'.defaultStruct
data JoinResult
    = JoinResult
        {joinId :: Word32,
        succeeded :: Bool,
        cap :: Maybe (PU'.PtrType)}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize JoinResult where
    type Cerial msg JoinResult = Capnp.ById.Xa184c7885cdaf2a1.JoinResult msg
    decerialize raw = do
        JoinResult <$>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinResult'joinId raw) <*>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinResult'succeeded raw) <*>
            (Capnp.ById.Xa184c7885cdaf2a1.get_JoinResult'cap raw >>= C'.decerialize)
instance C'.Marshal JoinResult where
    marshalInto raw value = do
        case value of
            JoinResult{..} -> do
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinResult'joinId raw joinId
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinResult'succeeded raw succeeded
                field_ <- C'.cerialize (U'.message raw) cap
                Capnp.ById.Xa184c7885cdaf2a1.set_JoinResult'cap raw field_
instance C'.Cerialize s JoinResult
instance C'.FromStruct M'.ConstMsg JoinResult where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa184c7885cdaf2a1.JoinResult M'.ConstMsg)
instance Default JoinResult where
    def = PH'.defaultStruct
data ProvisionId
    = ProvisionId
        {joinId :: Word32}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize ProvisionId where
    type Cerial msg ProvisionId = Capnp.ById.Xa184c7885cdaf2a1.ProvisionId msg
    decerialize raw = do
        ProvisionId <$>
            (Capnp.ById.Xa184c7885cdaf2a1.get_ProvisionId'joinId raw)
instance C'.Marshal ProvisionId where
    marshalInto raw value = do
        case value of
            ProvisionId{..} -> do
                Capnp.ById.Xa184c7885cdaf2a1.set_ProvisionId'joinId raw joinId
instance C'.Cerialize s ProvisionId
instance C'.FromStruct M'.ConstMsg ProvisionId where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa184c7885cdaf2a1.ProvisionId M'.ConstMsg)
instance Default ProvisionId where
    def = PH'.defaultStruct
data VatId
    = VatId
        {side :: Capnp.ById.Xa184c7885cdaf2a1.Side}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize VatId where
    type Cerial msg VatId = Capnp.ById.Xa184c7885cdaf2a1.VatId msg
    decerialize raw = do
        VatId <$>
            (Capnp.ById.Xa184c7885cdaf2a1.get_VatId'side raw)
instance C'.Marshal VatId where
    marshalInto raw value = do
        case value of
            VatId{..} -> do
                Capnp.ById.Xa184c7885cdaf2a1.set_VatId'side raw side
instance C'.Cerialize s VatId
instance C'.FromStruct M'.ConstMsg VatId where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xa184c7885cdaf2a1.VatId M'.ConstMsg)
instance Default VatId where
    def = PH'.defaultStruct