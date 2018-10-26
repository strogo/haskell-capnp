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
Module: Capnp.Gen.Capnp.Cxx.Pure
Description: High-level generated module for capnp/c++.capnp
This module is the generated code for capnp/c++.capnp,
for the high-level api.
-}
module Capnp.Gen.Capnp.Cxx.Pure (
) where
-- Code generated by capnpc-haskell. DO NOT EDIT.
-- Generated from schema file: capnp/c++.capnp
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
import qualified Data.Vector as V
import qualified Data.ByteString as BS
import qualified Capnp.Gen.ById.Xbdf87d7bb8304e81