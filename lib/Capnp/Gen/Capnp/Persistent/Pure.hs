{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
{- |
Module: Capnp.Gen.Capnp.Persistent.Pure
Description: High-level generated module for capnp/persistent.capnp
This module is the generated code for capnp/persistent.capnp,
for the high-level api.
-}
module Capnp.Gen.Capnp.Persistent.Pure (Persistent(..), Persistent'server_(..),export_Persistent, RealmGateway(..), RealmGateway'server_(..),export_RealmGateway, Persistent'SaveParams(..), Persistent'SaveResults(..), RealmGateway'export'params(..), RealmGateway'import'params(..)
) where
-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/persistent.capnp
import Data.Int
import Data.Word
import Data.Default (Default(def))
import GHC.Generics (Generic)
import Capnp.Basics.Pure (Data, Text)
import Control.Monad.Catch (MonadThrow(throwM))
import Control.Concurrent.STM (atomically)
import Control.Monad.IO.Class (liftIO)
import Capnp.TraversalLimit (MonadLimit, evalLimitT)
import Control.Monad (forM_)
import qualified Capnp.Convert as Convert
import qualified Capnp.Message as M'
import qualified Capnp.Untyped as U'
import qualified Capnp.Untyped.Pure as PU'
import qualified Capnp.GenHelpers.Pure as PH'
import qualified Capnp.Classes as C'
import qualified Capnp.Rpc as Rpc
import qualified Capnp.Gen.Capnp.Rpc.Pure as Rpc
import qualified Capnp.GenHelpers.Rpc as RH'
import qualified Data.Vector as V
import qualified Data.ByteString as BS
import qualified Capnp.Gen.ById.Xb8630836983feed7
import qualified Capnp.Gen.ById.Xbdf87d7bb8304e81.Pure
import qualified Capnp.Gen.ById.Xbdf87d7bb8304e81
newtype Persistent = Persistent M'.Client
    deriving(Show, Eq, Read, Generic)
instance Rpc.IsClient Persistent where
    fromClient = Persistent
    toClient (Persistent client) = client
instance C'.FromPtr msg Persistent where
    fromPtr = RH'.isClientFromPtr
instance C'.ToPtr s Persistent where
    toPtr = RH'.isClientToPtr
instance C'.Decerialize Persistent where
    type Cerial msg Persistent = Capnp.Gen.ById.Xb8630836983feed7.Persistent msg
    decerialize (Capnp.Gen.ById.Xb8630836983feed7.Persistent Nothing) = pure $ Persistent M'.nullClient
    decerialize (Capnp.Gen.ById.Xb8630836983feed7.Persistent (Just cap)) = Persistent <$> U'.getClient cap
instance C'.Cerialize s Persistent where
    cerialize msg (Persistent client) = Capnp.Gen.ById.Xb8630836983feed7.Persistent . Just <$> U'.appendCap msg client
class Persistent'server_ cap where
    {-# MINIMAL persistent'save #-}
    persistent'save :: Persistent'SaveParams -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    persistent'save _ _ = Rpc.throwMethodUnimplemented
export_Persistent :: Persistent'server_ a => a -> Rpc.RpcT IO Persistent
export_Persistent server_ = Persistent <$> Rpc.export Rpc.Server
    { handleStop = pure () -- TODO
    , handleCall = \interfaceId methodId payload fulfiller -> case interfaceId of
        14468694717054801553 -> case methodId of
            0 -> do
                RH'.handleMethod server_ persistent'save payload fulfiller
            _ -> liftIO $ atomically $ Rpc.breakPromise fulfiller Rpc.methodUnimplemented
        _ -> liftIO $ atomically $ Rpc.breakPromise fulfiller Rpc.methodUnimplemented
    }
instance Persistent'server_ Persistent where
    persistent'save args (Persistent client) = do
        args' <- PH'.createPure maxBound $ Convert.valueToMsg args >>= PH'.getRoot
        resultPromise <- Rpc.call 14468694717054801553 0 (Just (U'.PtrStruct args')) client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
newtype RealmGateway = RealmGateway M'.Client
    deriving(Show, Eq, Read, Generic)
instance Rpc.IsClient RealmGateway where
    fromClient = RealmGateway
    toClient (RealmGateway client) = client
instance C'.FromPtr msg RealmGateway where
    fromPtr = RH'.isClientFromPtr
instance C'.ToPtr s RealmGateway where
    toPtr = RH'.isClientToPtr
instance C'.Decerialize RealmGateway where
    type Cerial msg RealmGateway = Capnp.Gen.ById.Xb8630836983feed7.RealmGateway msg
    decerialize (Capnp.Gen.ById.Xb8630836983feed7.RealmGateway Nothing) = pure $ RealmGateway M'.nullClient
    decerialize (Capnp.Gen.ById.Xb8630836983feed7.RealmGateway (Just cap)) = RealmGateway <$> U'.getClient cap
instance C'.Cerialize s RealmGateway where
    cerialize msg (RealmGateway client) = Capnp.Gen.ById.Xb8630836983feed7.RealmGateway . Just <$> U'.appendCap msg client
class RealmGateway'server_ cap where
    {-# MINIMAL realmGateway'import, realmGateway'export #-}
    realmGateway'import :: RealmGateway'import'params -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    realmGateway'import _ _ = Rpc.throwMethodUnimplemented
    realmGateway'export :: RealmGateway'export'params -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    realmGateway'export _ _ = Rpc.throwMethodUnimplemented
export_RealmGateway :: RealmGateway'server_ a => a -> Rpc.RpcT IO RealmGateway
export_RealmGateway server_ = RealmGateway <$> Rpc.export Rpc.Server
    { handleStop = pure () -- TODO
    , handleCall = \interfaceId methodId payload fulfiller -> case interfaceId of
        9583422979879616212 -> case methodId of
            0 -> do
                RH'.handleMethod server_ realmGateway'import payload fulfiller
            1 -> do
                RH'.handleMethod server_ realmGateway'export payload fulfiller
            _ -> liftIO $ atomically $ Rpc.breakPromise fulfiller Rpc.methodUnimplemented
        _ -> liftIO $ atomically $ Rpc.breakPromise fulfiller Rpc.methodUnimplemented
    }
instance RealmGateway'server_ RealmGateway where
    realmGateway'import args (RealmGateway client) = do
        args' <- PH'.createPure maxBound $ Convert.valueToMsg args >>= PH'.getRoot
        resultPromise <- Rpc.call 9583422979879616212 0 (Just (U'.PtrStruct args')) client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
    realmGateway'export args (RealmGateway client) = do
        args' <- PH'.createPure maxBound $ Convert.valueToMsg args >>= PH'.getRoot
        resultPromise <- Rpc.call 9583422979879616212 1 (Just (U'.PtrStruct args')) client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
data Persistent'SaveParams
    = Persistent'SaveParams
        {sealFor :: Maybe (PU'.PtrType)}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize Persistent'SaveParams where
    type Cerial msg Persistent'SaveParams = Capnp.Gen.ById.Xb8630836983feed7.Persistent'SaveParams msg
    decerialize raw = do
        Persistent'SaveParams <$>
            (Capnp.Gen.ById.Xb8630836983feed7.get_Persistent'SaveParams'sealFor raw >>= C'.decerialize)
instance C'.Marshal Persistent'SaveParams where
    marshalInto raw value = do
        case value of
            Persistent'SaveParams{..} -> do
                field_ <- C'.cerialize (U'.message raw) sealFor
                Capnp.Gen.ById.Xb8630836983feed7.set_Persistent'SaveParams'sealFor raw field_
instance C'.Cerialize s Persistent'SaveParams
instance C'.FromStruct M'.ConstMsg Persistent'SaveParams where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.Gen.ById.Xb8630836983feed7.Persistent'SaveParams M'.ConstMsg)
instance Default Persistent'SaveParams where
    def = PH'.defaultStruct
data Persistent'SaveResults
    = Persistent'SaveResults
        {sturdyRef :: Maybe (PU'.PtrType)}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize Persistent'SaveResults where
    type Cerial msg Persistent'SaveResults = Capnp.Gen.ById.Xb8630836983feed7.Persistent'SaveResults msg
    decerialize raw = do
        Persistent'SaveResults <$>
            (Capnp.Gen.ById.Xb8630836983feed7.get_Persistent'SaveResults'sturdyRef raw >>= C'.decerialize)
instance C'.Marshal Persistent'SaveResults where
    marshalInto raw value = do
        case value of
            Persistent'SaveResults{..} -> do
                field_ <- C'.cerialize (U'.message raw) sturdyRef
                Capnp.Gen.ById.Xb8630836983feed7.set_Persistent'SaveResults'sturdyRef raw field_
instance C'.Cerialize s Persistent'SaveResults
instance C'.FromStruct M'.ConstMsg Persistent'SaveResults where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.Gen.ById.Xb8630836983feed7.Persistent'SaveResults M'.ConstMsg)
instance Default Persistent'SaveResults where
    def = PH'.defaultStruct
data RealmGateway'export'params
    = RealmGateway'export'params
        {cap :: Persistent,
        params :: Persistent'SaveParams}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize RealmGateway'export'params where
    type Cerial msg RealmGateway'export'params = Capnp.Gen.ById.Xb8630836983feed7.RealmGateway'export'params msg
    decerialize raw = do
        RealmGateway'export'params <$>
            (Capnp.Gen.ById.Xb8630836983feed7.get_RealmGateway'export'params'cap raw >>= C'.decerialize) <*>
            (Capnp.Gen.ById.Xb8630836983feed7.get_RealmGateway'export'params'params raw >>= C'.decerialize)
instance C'.Marshal RealmGateway'export'params where
    marshalInto raw value = do
        case value of
            RealmGateway'export'params{..} -> do
                field_ <- C'.cerialize (U'.message raw) cap
                Capnp.Gen.ById.Xb8630836983feed7.set_RealmGateway'export'params'cap raw field_
                field_ <- Capnp.Gen.ById.Xb8630836983feed7.new_RealmGateway'export'params'params raw
                C'.marshalInto field_ params
instance C'.Cerialize s RealmGateway'export'params
instance C'.FromStruct M'.ConstMsg RealmGateway'export'params where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.Gen.ById.Xb8630836983feed7.RealmGateway'export'params M'.ConstMsg)
instance Default RealmGateway'export'params where
    def = PH'.defaultStruct
data RealmGateway'import'params
    = RealmGateway'import'params
        {cap :: Persistent,
        params :: Persistent'SaveParams}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize RealmGateway'import'params where
    type Cerial msg RealmGateway'import'params = Capnp.Gen.ById.Xb8630836983feed7.RealmGateway'import'params msg
    decerialize raw = do
        RealmGateway'import'params <$>
            (Capnp.Gen.ById.Xb8630836983feed7.get_RealmGateway'import'params'cap raw >>= C'.decerialize) <*>
            (Capnp.Gen.ById.Xb8630836983feed7.get_RealmGateway'import'params'params raw >>= C'.decerialize)
instance C'.Marshal RealmGateway'import'params where
    marshalInto raw value = do
        case value of
            RealmGateway'import'params{..} -> do
                field_ <- C'.cerialize (U'.message raw) cap
                Capnp.Gen.ById.Xb8630836983feed7.set_RealmGateway'import'params'cap raw field_
                field_ <- Capnp.Gen.ById.Xb8630836983feed7.new_RealmGateway'import'params'params raw
                C'.marshalInto field_ params
instance C'.Cerialize s RealmGateway'import'params
instance C'.FromStruct M'.ConstMsg RealmGateway'import'params where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.Gen.ById.Xb8630836983feed7.RealmGateway'import'params M'.ConstMsg)
instance Default RealmGateway'import'params where
    def = PH'.defaultStruct