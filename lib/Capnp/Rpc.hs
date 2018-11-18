{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
module Capnp.Rpc
    (
    -- * Connections to other vats
      ConnConfig(..)
    , handleConn

    -- * Clients for capabilities
    , Client
    , incRef
    , decRef
    , call
    , nullClient

    , IsClient(..)

    -- * Exporting local objects
    , export
    , clientMethodHandler

    -- * Errors
    , RpcError(..)
    , RpcGen.Exception(..)
    , RpcGen.Exception'Type(..)
    ) where

-- Note [Organization]
-- ===================
--
-- As much as possible, the logic in this module is centralized according to
-- type types of objects it concerns.
--
-- As an example, consider how we handle embargos: The 'Conn' type's 'embargos'
-- table has values that are arbitrary 'STM' transactions. This allows the code
-- which triggers sending embargoes to have full control over what happens when
-- they return, while the code that routes incoming messages (in 'coordinator')
-- doesn't need to concern itself with the details of embargos -- it just needs
-- to route them to the right place.
--
-- This approach generally results in better separation of concerns.

-- Note [Implementation checklist]
-- ===============================
--
-- While RPC support is still incomplete, we keep a checklist of some things
-- that still need is implemented. In many cases, it's more natural to put
-- error "TODO: ..." in the relevant spots in the source code, but there are
-- a few cross-cutting concerns that we keep track of here.
--
-- * [ ] Handle decode errors
-- * [ ] Resource limits (see Note [Limiting resource usage])

import Data.Word
import UnliftIO.STM

import Control.Concurrent.STM (throwSTM)
import Control.Monad          (forever, when)
import Data.Default           (Default(def))
import Data.Hashable          (Hashable, hash, hashWithSalt)
import Data.String            (fromString)
import GHC.Generics           (Generic)
import Supervisors            (Supervisor, superviseSTM, withSupervisor)
import System.Mem.StableName
    (StableName, eqStableName, hashStableName, makeStableName)
import System.Mem.Weak        (addFinalizer)
import UnliftIO.Async         (concurrently_)
import UnliftIO.Exception     (Exception, bracket)

import qualified Data.Vector       as V
import qualified Focus
import qualified StmContainers.Map as M

import Capnp.Convert       (msgToValue, valueToMsg)
import Capnp.Message       (ConstMsg)
import Capnp.Promise       (breakPromise)
import Capnp.Rpc.Transport (Transport(recvMsg, sendMsg))
import Internal.BuildPure  (createPure)

import qualified Capnp.Gen.Capnp.Rpc.Pure as RpcGen
import qualified Capnp.Rpc.Server         as Server
import qualified Capnp.Untyped.Pure       as Untyped


-- | Errors which can be thrown by the rpc system.
newtype RpcError
    = ReceivedAbort RpcGen.Exception
    -- ^ The remote vat sent us an abort message.
    deriving(Show, Generic)

instance Exception RpcError

-- These aliases are the same ones defined in rpc.capnp; unfortunately the
-- schema compiler doesn't supply information about type aliases, so we
-- have to re-define them ourselves. See the comments in rpc.capnp for
-- more information.
type QuestionId = Word32
type AnswerId   = QuestionId
type ExportId   = Word32
type ImportId   = ExportId
type EmbargoId  = Word32

-- | A connection to a remote vat
data Conn = Conn
    { stableName     :: StableName ()
    -- So we can use the connection as a map key.

    , sendQ          :: TBQueue ConstMsg
    , recvQ          :: TBQueue ConstMsg
    -- queues of messages to send and receive; each of these has a dedicated
    -- thread doing the IO (see 'sendLoop' and 'recvLoop'):

    , supervisor     :: Supervisor
    -- Supervisor managing the lifetimes of threads bound to this connection.

    , questionIdPool :: IdPool
    , exportIdPool   :: IdPool
    -- Pools of identifiers for new questions and exports

    , questions      :: M.Map QuestionId Question
    , answers        :: M.Map AnswerId Answer
    , exports        :: M.Map ExportId Export
    -- TODO: imports

    , embargos       :: M.Map EmbargoId (STM ())
    -- Outstanding embargos. When we receive a 'Disembargo' message with its
    -- context field set to receiverLoopback, we look up the embargo id in
    -- this table, and execute the STM we have registered.

    , bootstrap      :: Client
    -- The capability which should be served as this connection's bootstrap
    -- interface.
    }

instance Eq Conn where
    x == y = stableName x `eqStableName` stableName y

instance Hashable Conn where
    hash Conn{stableName} = hashStableName stableName
    hashWithSalt _ = hash

-- | Configuration information for a connection.
data ConnConfig = ConnConfig
    { maxQuestions :: !Word32
    -- ^ The maximum number of simultanious outstanding requests to the peer
    -- vat. Once this limit is reached, further questsions will block until
    -- some of the existing questions have been answered.
    --
    -- Defaults to 32.

    , maxExports   :: !Word32
    -- ^ The maximum number of objects which may be exported on this connection.
    --
    -- Defaults to 32.

    , debugMode    :: !Bool
    -- ^ In debug mode, errors reported by the RPC system to its peers will
    -- contain extra information. This should not be used in production, as
    -- it is possible for these messages to contain sensitive information,
    -- but it can be useful for debugging.
    --
    -- Defaults to 'False'.

    , getBootstrap :: Supervisor -> STM Client
    -- ^ Get the bootstrap interface we should serve for this connection.
    -- the argument is a supervisor whose lifetime is bound to the
    -- connection. If 'getBootstrap' returns 'nullClient', we will respond
    -- to bootstrap messages with an exception.
    --
    -- The default always returns 'nullClient'.
    }

instance Default ConnConfig where
    def = ConnConfig
        { maxQuestions = 32
        , maxExports   = 32
        , debugMode    = False
        , getBootstrap = \_ -> pure nullClient
        }

-- | Get a new question id. retries if we are out of available question ids.
newQuestion :: Conn -> STM QuestionId
newQuestion = newId . questionIdPool

-- | Return a question id to the pool of available ids.
freeQuestion :: Conn -> QuestionId -> STM ()
freeQuestion = freeId . questionIdPool

-- | Get a new export id. retries if we are out of available export ids.
newExport :: Conn -> STM ExportId
newExport = newId . exportIdPool

-- | Return a export id to the pool of available ids.
freeExport :: Conn -> ExportId -> STM ()
freeExport = freeId . exportIdPool

-- | Handle a connection to another vat. Returns when the connection is closed.
handleConn :: Transport -> ConnConfig -> IO ()
handleConn transport cfg@ConnConfig{maxQuestions, maxExports} =
    withSupervisor $ \sup ->
        bracket
            (newConn sup)
            stopConn
            runConn
  where
    newConn sup = do
        stableName <- makeStableName ()
        atomically $ do
            bootstrap <- getBootstrap cfg sup
            questionIdPool <- newIdPool maxQuestions
            exportIdPool <- newIdPool maxExports

            sendQ <- newTBQueue $ fromIntegral maxQuestions
            recvQ <- newTBQueue $ fromIntegral maxQuestions

            questions <- M.new
            answers <- M.new
            exports <- M.new

            embargos <- M.new

            pure Conn
                { stableName
                , supervisor = sup
                , questionIdPool
                , exportIdPool
                , recvQ
                , sendQ
                , questions
                , answers
                , exports
                , embargos
                , bootstrap
                }
    runConn conn =
        coordinator conn
            `concurrently_` sendLoop transport conn
            `concurrently_` recvLoop transport conn
    stopConn conn =
        atomically $ decRef (bootstrap conn)


-- | A pool of ids; used when choosing identifiers for questions and exports.
newtype IdPool = IdPool (TVar [Word32])

-- | @'newIdPool' size@ creates a new pool of ids, with @size@ available ids.
newIdPool :: Word32 -> STM IdPool
newIdPool size = IdPool <$> newTVar [0..size-1]

-- | Get a new id from the pool. Retries if the pool is empty.
newId :: IdPool -> STM Word32
newId (IdPool pool) = readTVar pool >>= \case
    [] -> retrySTM
    (id:ids) -> do
        writeTVar pool $! ids
        pure id

-- | Return an id to the pool.
freeId :: IdPool -> Word32 -> STM ()
freeId (IdPool pool) id = modifyTVar' pool (id:)

data Question = Question
    { onReturn :: RpcGen.Return -> STM ()
    -- ^ Called when the remote vat sends a return message for this question.
    }

-- | An entry in our answers table.
data Answer = Answer
    { onFinish :: RpcGen.Finish -> STM ()
    -- ^ Called when a the remote vat sends a finish message for this question.
    }

data Export = Export
    { client   :: Client
    , refCount :: !Word32
    }


-- Note [Client representation]
-- ============================
--
-- A client is a reference to a capability, which can be used to
-- call methods on an object. The implementation is composed of two
-- types, Client and Client'. Only the former is exposed by the API.
-- Client contains a @TVar Client'@ (or Nothing if it is a null
-- client).
--
-- The reason for the indirection is so that we can swap out the
-- implementation. Some examples of when this is useful include:
--
-- * When a promise resolves, we want to redirect it to the thing it
--   resolved to.
-- * When a connection is dropped, we replace the relevant clients
--   with ones that always throw disconnected exceptions.
--
-- The reason for not using the TVar to represent null clients is so
-- that we can define the top-level definition 'nullClient', which
-- can be used statically. If the value 'nullClient' included a 'TVar',
-- we would have to create it at runtime.


-- | An untyped capability on which methods may be called.
newtype Client =
    -- See Note [Client representation]
    Client (Maybe (TVar Client'))
    deriving(Eq)

-- | Types which may be converted to and from 'Client's. Typically these
-- will be simple type wrappers for capabilities.
class IsClient a where
    -- | Convert a value to a client.
    toClient :: a -> Client
    -- | Convert a client to a value.
    fromClient :: Client -> a

instance Show Client where
    show (Client Nothing) = "nullClient"
    show (Client (Just _)) = "({- capability; not statically representable -})"

-- See Note [Client representation]
data Client'
    -- | A client which always throws an exception in response
    -- to calls.
    = ExnClient RpcGen.Exception
    -- | A client which lives in the same vat/process as us.
    | LocalClient
        { refCount  :: TVar Word32
        -- ^ The number of live references to this object. When this
        -- reaches zero, we will tell the server to stop.
        , opQueue   :: TQueue Server.ServerMsg
        -- ^ A queue for submitting commands to the server thread managing
        -- the object.
        , exportIds :: M.Map Conn ExportId
        -- ^ A the ids under which this is exported on each connection.
        }
    -- | A client for an object that lives in a remote vat.
    | RemoteClient
        { remoteConn :: Conn
        -- ^ The connection to the vat where the object lives.
        , msgTarget  :: MsgTarget
        -- ^ The address of the object in the remote vat.
        }

-- | The destination of a remote method call. This is closely related to
-- the 'MessageTarget' type defined in rpc.capnp, but has a couple
-- differences:
--
-- * It does not have an unknown' variant, which is more convienent to work
--   with. See also issue #60.
-- * In the case of an imported capability, it records whether the capability
--   is an unresolved promise (answers are always unresolved by definition).
data MsgTarget
    = AnswerTgt !AnswerId
    -- ^ Targets an entry in the remote vat's answers table/local vat's
    -- questions table.
    | ImportTgt
        { importId   :: !ImportId
        -- ^ Targets an entry in the remote vat's export table/local vat's
        -- imports table.
        , isResolved :: !Bool
        -- ^ Records whether the capability has resolved to its final value.
        -- This is True iff the target is not a promise. If it is an unresolved
        -- promise, this will be false. When the promise resolves, clients using
        -- this message target will have their target replaced with the target
        -- to which the promise resolved, so a client should never actually point
        -- at a promise which has already resolved.
        }

-- | A null client. This is the only client value that can be represented
-- statically. Throws exceptions in response to all method calls.
nullClient :: Client
nullClient = Client Nothing

-- | A client that is disconnected; always throws disconnected exceptions.
disconnectedClient' :: Client'
disconnectedClient' = ExnClient def
    { RpcGen.type_ = RpcGen.Exception'Type'disconnected
    , RpcGen.reason = "disconnected"
    }

-- | Increment the reference count on a client.
incRef :: Client -> STM ()
incRef (Client Nothing) = pure ()
incRef (Client (Just clientVar)) = readTVar clientVar >>= \case
    ExnClient _ ->
        pure ()

    LocalClient{refCount} ->
        modifyTVar' refCount succ

    -- TODO: RemoteClient


-- | Decrement the reference count on a client. If the count reaches zero,
-- the object is destroyed.
decRef :: Client -> STM ()
decRef (Client Nothing) = pure ()
decRef (Client (Just clientVar)) = readTVar clientVar >>= \case
    ExnClient _ ->
        pure ()

    LocalClient{refCount, opQueue} -> do
        modifyTVar' refCount pred
        cnt <- readTVar refCount
        when (cnt == 0) $ do
            -- Refcount is zero. Tell the server to stop:
            writeTQueue opQueue Server.Stop
            -- ...and then replace ourselves with a disconnected client:
            writeTVar clientVar disconnectedClient'

    -- TODO: RemoteClient


-- | Call a method on the object pointed to by this client.
call :: Server.CallInfo -> Client -> STM ()
call info (Client Nothing) =
    breakPromise (Server.response info) def
        { RpcGen.type_ = RpcGen.Exception'Type'failed
        , RpcGen.reason = "Client is null"
        }
call info (Client (Just clientVar)) =
    readTVar clientVar >>= \case
        ExnClient e ->
            breakPromise (Server.response info) e

        LocalClient{opQueue} ->
            writeTQueue opQueue (Server.Call info)

    -- TODO: RemoteClient

-- | Spawn a local server with its lifetime bound to the supervisor,
-- and return a client for it. When the client is garbage collected,
-- the server will be stopped (if it is still running).
export :: Supervisor -> Server.ServerOps IO -> STM Client
export sup ops = do
    q <- newTQueue
    refCount <- newTVar 1
    exportIds <- M.new
    let client' = LocalClient
            { refCount = refCount
            , opQueue = q
            , exportIds
            }
    superviseSTM sup $ do
        addFinalizer client' $
            atomically $ writeTQueue q Server.Stop
        Server.runServer q ops
    Client . Just <$> newTVar client'

clientMethodHandler :: Word64 -> Word16 -> Client -> Server.MethodHandler IO p r
clientMethodHandler interfaceId methodId client =
    Server.fromUntypedHandler $ Server.untypedHandler $
        \arguments response -> atomically $ call Server.CallInfo{..} client

-- | 'sendLoop' shunts messages from the send queue into the transport.
sendLoop :: Transport -> Conn -> IO ()
sendLoop transport Conn{sendQ} =
    forever $ atomically (readTBQueue sendQ) >>= sendMsg transport

-- | 'recvLoop' shunts messages from the transport into the receive queue.
recvLoop :: Transport -> Conn -> IO ()
recvLoop transport Conn{recvQ} =
    forever $ recvMsg transport >>= atomically . writeTBQueue recvQ

-- | The coordinator processes incoming messages.
coordinator :: Conn -> IO ()
-- The logic here mostly routes messages to other parts of the code that know
-- more about the objects in question; See Note [Organization] for more info.
coordinator conn@Conn{recvQ} = atomically $ do
    msg <- readTBQueue recvQ
    pureMsg <- msgToValue msg -- FIXME: handle decode errors
    case pureMsg of
        RpcGen.Message'abort exn ->
            handleAbortMsg conn exn
        RpcGen.Message'unimplemented msg ->
            handleUnimplementedMsg conn msg
        RpcGen.Message'bootstrap bs ->
            handleBootstrapMsg conn bs
        RpcGen.Message'return ret ->
            handleReturnMsg conn ret
        RpcGen.Message'finish finish ->
            handleFinishMsg conn finish
        _ ->
            error "TODO"
    error "TODO"

-- Each function handle*Msg handles a message of a particular type;
-- 'coordinator' dispatches to these.

handleAbortMsg :: Conn -> RpcGen.Exception -> STM ()
handleAbortMsg _ exn =
    throwSTM (ReceivedAbort exn)

handleUnimplementedMsg :: Conn -> RpcGen.Message -> STM ()
handleUnimplementedMsg conn = \case
    RpcGen.Message'unimplemented _ ->
        -- If the client itself doesn't handle unimplemented messages, that's
        -- weird, but ultimately their problem.
        pure ()
    _ ->
        error "TODO"

handleBootstrapMsg :: Conn -> RpcGen.Bootstrap -> STM ()
handleBootstrapMsg conn RpcGen.Bootstrap{questionId} = do
    capDesc <- sendableCapDesc conn (bootstrap conn)
    let ret = RpcGen.Return
            { RpcGen.answerId = questionId
            , RpcGen.releaseParamCaps = True -- Not really meaningful for bootstrap, but...
            , RpcGen.union' = case capDesc of
                RpcGen.CapDescriptor'none ->
                    RpcGen.Return'exception def
                        { RpcGen.type_ = RpcGen.Exception'Type'failed
                        , RpcGen.reason = "No bootstrap interface for this connection."
                        }
                _ ->
                    RpcGen.Return'results RpcGen.Payload
                            -- XXX: this is a bit fragile; we're relying on
                            -- the encode step to pick the right index for
                            -- our capability.
                        { content = Just $ Untyped.PtrCap (bootstrap conn)
                        , capTable = V.singleton capDesc
                        }
            }
    M.focus
        (Focus.alterM $ insertBootstrap ret)
        questionId
        (answers conn)
    sendPureMsg conn $ RpcGen.Message'return ret
  where
    insertBootstrap ret Nothing =
        pure $ Just Answer
            { onFinish = \_ -> M.delete questionId (answers conn)
            }
    insertBootstrap _ (Just _) =
        abortConn conn def
            { RpcGen.type_ = RpcGen.Exception'Type'failed
            , RpcGen.reason = "Duplicate question ID"
            }

handleReturnMsg :: Conn -> RpcGen.Return -> STM ()
handleReturnMsg conn@Conn{questions} ret@RpcGen.Return{answerId} =
    lookupAbort "question" conn questions answerId $
        \Question{onReturn} -> onReturn ret

handleFinishMsg :: Conn -> RpcGen.Finish -> STM ()
handleFinishMsg conn@Conn{answers} finish@RpcGen.Finish{questionId} =
    lookupAbort "answer" conn answers questionId $
        \Answer{onFinish} -> onFinish finish

lookupAbort keyTypeName conn m key f = do
    result <- M.lookup key m
    case result of
        Just val ->
            f val
        Nothing ->
            abortConn conn def
                { RpcGen.type_ = RpcGen.Exception'Type'failed
                , RpcGen.reason = mconcat
                    [ "No such "
                    , keyTypeName
                    ,  ": "
                    , fromString (show key)
                    ]
                }

sendPureMsg :: Conn -> RpcGen.Message -> STM ()
sendPureMsg Conn{sendQ} msg =
    createPure maxBound (valueToMsg msg) >>= writeTBQueue sendQ

abortConn :: Conn -> RpcGen.Exception -> STM a
abortConn = error "TODO"

-- | Get a CapDescriptor for this client, suitable for sending to the remote
-- vat. If the client points to our own vat, this will increment the refcount
-- in the exports table, and will allocate a new export ID if needed. Returns
-- CapDescriptor'none if the client is 'nullClient'.
sendableCapDesc :: Conn -> Client -> STM RpcGen.CapDescriptor
sendableCapDesc _ (Client Nothing)  = pure RpcGen.CapDescriptor'none
sendableCapDesc conn@Conn{exports} client@(Client (Just clientVar)) =
    readTVar clientVar >>= \case
        LocalClient{exportIds} ->
            M.lookup conn exportIds >>= \case
                Just exportId -> do
                    -- This client is already exported on the connection; bump the
                    -- refcount and use the existing export id.
                    M.focus
                        (Focus.adjust $ \e@Export{refCount} ->
                            e { refCount = refCount + 1 } :: Export
                        )
                        exportId
                        exports
                    pure $ RpcGen.CapDescriptor'senderHosted exportId
                Nothing -> do
                    -- This client is not yet exported on this connection; allocate
                    -- a new export ID and insert it into the exports table.
                    exportId <- newExport conn
                    M.insert exportId conn exportIds
                    M.insert Export { client, refCount = 1 } exportId exports
                    pure $ RpcGen.CapDescriptor'senderHosted exportId

        -- TODO: other client types

-- Note [Limiting resource usage]
-- =============================
--
-- We employ various strategies to prevent remote vats from causing excessive
-- resource usage. In particular:
--
-- * We set a maximum size for incoming messages; this is in keeping with how
--   we mitigate these concerns when dealing with plain capnp data (i.e. not
--   rpc).
-- * We set a limit on the total *size* of all messages from the remote vat that
--   are currently being serviced. For example, if a Call message comes in,
--   we note its size, and deduct it from the quota. Once we have sent a return
--   and received a finish for this call, and thus can safely forget about it,
--   we remove it from our answers table, and add its size back to the available
--   quota.
--
-- Still TBD:
--
-- * We should come up with some way of guarding against too many intra-vat calls;
--   depending on the object graph, it may be possible for an attacker to get us
--   to "eat our own tail" so to speak.
--
--   Ideas:
--     * Per-object bounded queues for messages
--     * Global limit on intra-vat calls.
--
--   Right now I(zenhack) am more fond of the former.
--
-- * What should we actually do when limits are exceeded?
--
--   Possible strategies:
--     * Block
--     * Throw an 'overloaded' exception
--     * Some combination of the two; block with a timeout, then throw.
--
--   If we just block, we need to make sure this doesn't hang the vat;
--   we probably need a timeout at some level.
