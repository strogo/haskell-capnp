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
Module: Capnp.Capnp.Persistent.Pure
Description: High-level generated module for capnp/persistent.capnp
This module is the generated code for capnp/persistent.capnp,
for the high-level api.
-}
module Capnp.Capnp.Persistent.Pure (Persistent(..), Persistent'server_(..), RealmGateway(..), RealmGateway'server_(..), Persistent'SaveParams(..), Persistent'SaveResults(..), RealmGateway'export'params(..), RealmGateway'import'params(..)
) where
-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/persistent.capnp
import Data.Int
import Data.Word
import Data.Default (Default(def))
import GHC.Generics (Generic)
import Data.Capnp.Basics.Pure (Data, Text)
import Control.Monad.Catch (MonadThrow(throwM))
import Data.Capnp.TraversalLimit (MonadLimit, evalLimitT)
import Control.Monad (forM_)
import qualified Data.Capnp.Convert as Convert
import qualified Data.Capnp.Message as M'
import qualified Data.Capnp.Untyped as U'
import qualified Data.Capnp.Untyped.Pure as PU'
import qualified Data.Capnp.GenHelpers.Pure as PH'
import qualified Data.Capnp.Classes as C'
import qualified Network.RPC.Capnp as Rpc
import qualified Capnp.Capnp.Rpc.Pure as Rpc
import qualified Data.Vector as V
import qualified Data.ByteString as BS
import qualified Capnp.ById.Xb8630836983feed7
import qualified Capnp.ById.Xbdf87d7bb8304e81.Pure
import qualified Capnp.ById.Xbdf87d7bb8304e81
newtype Persistent = Persistent M'.Client
    deriving(Show, Eq, Read, Generic)
instance C'.Decerialize Persistent where
    type Cerial msg Persistent = Capnp.ById.Xb8630836983feed7.Persistent msg
    decerialize (Capnp.ById.Xb8630836983feed7.Persistent Nothing) = pure $ Persistent M'.nullClient
    decerialize (Capnp.ById.Xb8630836983feed7.Persistent (Just cap)) = Persistent <$> U'.getClient cap
instance C'.Cerialize s Persistent where
    cerialize msg (Persistent client) = Capnp.ById.Xb8630836983feed7.Persistent . Just <$> U'.appendCap msg client
class Persistent'server_ cap where
    {-# MINIMAL persistent'save #-}
    persistent'save :: Persistent'SaveParams -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    persistent'save _ _ = Rpc.throwMethodUnimplemented
export_Persistent :: Persistent'server_ a => a -> Rpc.RpcT IO Persistent
export_Persistent server_ = Persistent <$> Rpc.export Rpc.Server
    { handleStop = pure () -- TODO
    , handleCall = \interfaceId methodId params -> case interfaceId of
        14468694717054801553 -> case methodId of
            0 -> do
                typedParams <- evalLimitT maxBound $ PH'.convertValue params
                results <- persistent'save typedParams server_
                resultStruct <- evalLimitT maxBound $ PH'.convertValue results
                (promise, fulfiller) <- Rpc.newPromiseIO
                Rpc.fulfillIO fulfiller resultStruct
                pure promise
            _ -> Rpc.throwMethodUnimplemented
        _ -> Rpc.throwMethodUnimplemented
    }
instance Persistent'server_ Persistent where
    persistent'save args (Persistent client) = do
        args' <- evalLimitT maxBound $ PH'.convertValue args
        resultPromise <- Rpc.call 14468694717054801553 0 Rpc.Payload { content = Just (PU'.PtrStruct args') , capTable = V.empty } client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
newtype RealmGateway = RealmGateway M'.Client
    deriving(Show, Eq, Read, Generic)
instance C'.Decerialize RealmGateway where
    type Cerial msg RealmGateway = Capnp.ById.Xb8630836983feed7.RealmGateway msg
    decerialize (Capnp.ById.Xb8630836983feed7.RealmGateway Nothing) = pure $ RealmGateway M'.nullClient
    decerialize (Capnp.ById.Xb8630836983feed7.RealmGateway (Just cap)) = RealmGateway <$> U'.getClient cap
instance C'.Cerialize s RealmGateway where
    cerialize msg (RealmGateway client) = Capnp.ById.Xb8630836983feed7.RealmGateway . Just <$> U'.appendCap msg client
class RealmGateway'server_ cap where
    {-# MINIMAL realmGateway'import, realmGateway'export #-}
    realmGateway'import :: RealmGateway'import'params -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    realmGateway'import _ _ = Rpc.throwMethodUnimplemented
    realmGateway'export :: RealmGateway'export'params -> cap -> Rpc.RpcT IO (Persistent'SaveResults)
    realmGateway'export _ _ = Rpc.throwMethodUnimplemented
export_RealmGateway :: RealmGateway'server_ a => a -> Rpc.RpcT IO RealmGateway
export_RealmGateway server_ = RealmGateway <$> Rpc.export Rpc.Server
    { handleStop = pure () -- TODO
    , handleCall = \interfaceId methodId params -> case interfaceId of
        9583422979879616212 -> case methodId of
            0 -> do
                typedParams <- evalLimitT maxBound $ PH'.convertValue params
                results <- realmGateway'import typedParams server_
                resultStruct <- evalLimitT maxBound $ PH'.convertValue results
                (promise, fulfiller) <- Rpc.newPromiseIO
                Rpc.fulfillIO fulfiller resultStruct
                pure promise
            1 -> do
                typedParams <- evalLimitT maxBound $ PH'.convertValue params
                results <- realmGateway'export typedParams server_
                resultStruct <- evalLimitT maxBound $ PH'.convertValue results
                (promise, fulfiller) <- Rpc.newPromiseIO
                Rpc.fulfillIO fulfiller resultStruct
                pure promise
            _ -> Rpc.throwMethodUnimplemented
        _ -> Rpc.throwMethodUnimplemented
    }
instance RealmGateway'server_ RealmGateway where
    realmGateway'import args (RealmGateway client) = do
        args' <- evalLimitT maxBound $ PH'.convertValue args
        resultPromise <- Rpc.call 9583422979879616212 0 Rpc.Payload { content = Just (PU'.PtrStruct args') , capTable = V.empty } client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
    realmGateway'export args (RealmGateway client) = do
        args' <- evalLimitT maxBound $ PH'.convertValue args
        resultPromise <- Rpc.call 9583422979879616212 1 Rpc.Payload { content = Just (PU'.PtrStruct args') , capTable = V.empty } client
        result <- Rpc.waitIO resultPromise
        evalLimitT maxBound $ PH'.convertValue result
data Persistent'SaveParams
    = Persistent'SaveParams
        {sealFor :: Maybe (PU'.PtrType)}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize Persistent'SaveParams where
    type Cerial msg Persistent'SaveParams = Capnp.ById.Xb8630836983feed7.Persistent'SaveParams msg
    decerialize raw = do
        Persistent'SaveParams <$>
            (Capnp.ById.Xb8630836983feed7.get_Persistent'SaveParams'sealFor raw >>= C'.decerialize)
instance C'.Marshal Persistent'SaveParams where
    marshalInto raw value = do
        case value of
            Persistent'SaveParams{..} -> do
                field_ <- C'.cerialize (U'.message raw) sealFor
                Capnp.ById.Xb8630836983feed7.set_Persistent'SaveParams'sealFor raw field_
instance C'.Cerialize s Persistent'SaveParams
instance C'.FromStruct M'.ConstMsg Persistent'SaveParams where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xb8630836983feed7.Persistent'SaveParams M'.ConstMsg)
instance Default Persistent'SaveParams where
    def = PH'.defaultStruct
data Persistent'SaveResults
    = Persistent'SaveResults
        {sturdyRef :: Maybe (PU'.PtrType)}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize Persistent'SaveResults where
    type Cerial msg Persistent'SaveResults = Capnp.ById.Xb8630836983feed7.Persistent'SaveResults msg
    decerialize raw = do
        Persistent'SaveResults <$>
            (Capnp.ById.Xb8630836983feed7.get_Persistent'SaveResults'sturdyRef raw >>= C'.decerialize)
instance C'.Marshal Persistent'SaveResults where
    marshalInto raw value = do
        case value of
            Persistent'SaveResults{..} -> do
                field_ <- C'.cerialize (U'.message raw) sturdyRef
                Capnp.ById.Xb8630836983feed7.set_Persistent'SaveResults'sturdyRef raw field_
instance C'.Cerialize s Persistent'SaveResults
instance C'.FromStruct M'.ConstMsg Persistent'SaveResults where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xb8630836983feed7.Persistent'SaveResults M'.ConstMsg)
instance Default Persistent'SaveResults where
    def = PH'.defaultStruct
data RealmGateway'export'params
    = RealmGateway'export'params
        {cap :: Persistent,
        params :: Persistent'SaveParams}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize RealmGateway'export'params where
    type Cerial msg RealmGateway'export'params = Capnp.ById.Xb8630836983feed7.RealmGateway'export'params msg
    decerialize raw = do
        RealmGateway'export'params <$>
            (Capnp.ById.Xb8630836983feed7.get_RealmGateway'export'params'cap raw >>= C'.decerialize) <*>
            (Capnp.ById.Xb8630836983feed7.get_RealmGateway'export'params'params raw >>= C'.decerialize)
instance C'.Marshal RealmGateway'export'params where
    marshalInto raw value = do
        case value of
            RealmGateway'export'params{..} -> do
                field_ <- Capnp.ById.Xb8630836983feed7.new_RealmGateway'export'params'params raw
                C'.marshalInto field_ params
instance C'.Cerialize s RealmGateway'export'params
instance C'.FromStruct M'.ConstMsg RealmGateway'export'params where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xb8630836983feed7.RealmGateway'export'params M'.ConstMsg)
instance Default RealmGateway'export'params where
    def = PH'.defaultStruct
data RealmGateway'import'params
    = RealmGateway'import'params
        {cap :: Persistent,
        params :: Persistent'SaveParams}
    deriving(Show,Read,Eq,Generic)
instance C'.Decerialize RealmGateway'import'params where
    type Cerial msg RealmGateway'import'params = Capnp.ById.Xb8630836983feed7.RealmGateway'import'params msg
    decerialize raw = do
        RealmGateway'import'params <$>
            (Capnp.ById.Xb8630836983feed7.get_RealmGateway'import'params'cap raw >>= C'.decerialize) <*>
            (Capnp.ById.Xb8630836983feed7.get_RealmGateway'import'params'params raw >>= C'.decerialize)
instance C'.Marshal RealmGateway'import'params where
    marshalInto raw value = do
        case value of
            RealmGateway'import'params{..} -> do
                field_ <- Capnp.ById.Xb8630836983feed7.new_RealmGateway'import'params'params raw
                C'.marshalInto field_ params
instance C'.Cerialize s RealmGateway'import'params
instance C'.FromStruct M'.ConstMsg RealmGateway'import'params where
    fromStruct struct = do
        raw <- C'.fromStruct struct
        C'.decerialize (raw :: Capnp.ById.Xb8630836983feed7.RealmGateway'import'params M'.ConstMsg)
instance Default RealmGateway'import'params where
    def = PH'.defaultStruct