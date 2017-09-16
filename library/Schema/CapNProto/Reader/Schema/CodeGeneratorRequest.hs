{-# LANGUAGE ConstraintKinds, TemplateHaskell #-}
module Schema.CapNProto.Reader.Schema.CodeGeneratorRequest where

import qualified Schema.CapNProto.Reader.Schema as S
import qualified Data.CapNProto.Untyped as U

import Language.CapNProto.TH

$(mkStructWrappers ["RequestedFile"])

$(mkListReaders
    'S.CodeGeneratorRequest
    [ ("nodes",          0, 'U.ListStruct, 'S.Node)
    , ("requestedFiles", 1, 'U.ListStruct, 'RequestedFile)
    ])
