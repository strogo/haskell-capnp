{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DuplicateRecordFields      #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE NamedFieldPuns             #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE ViewPatterns               #-}
module Capnp.Rpc.Untyped
    (
    -- * Connections to other vats
      ConnConfig(..)
    , handleConn

    -- * Clients for capabilities
    , Client
    , call
    , nullClient

    , IsClient(..)

    -- * Exporting local objects
    , export
    , clientMethodHandler

    -- * Errors
    , RpcError(..)
    , R.Exception(..)
    , R.Exception'Type(..)

    -- * Shutting down the connection
    , stopVat

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

import Control.Concurrent     (threadDelay)
import Control.Concurrent.STM (catchSTM, flushTQueue, throwSTM)
import Control.Monad          (forever)
import Data.Default           (Default(def))
import Data.Foldable          (toList, traverse_)
import Data.Hashable          (Hashable, hash, hashWithSalt)
import Data.String            (fromString)
import Data.Text              (Text)
import GHC.Generics           (Generic)
import Supervisors            (Supervisor, superviseSTM, withSupervisor)
import System.Mem.StableName
    (StableName, eqStableName, hashStableName, makeStableName)
import UnliftIO.Async         (concurrently_)
import UnliftIO.Exception     (Exception, bracket, handle, throwIO, try)

import qualified Data.Vector       as V
import qualified Focus
import qualified StmContainers.Map as M

import Capnp.Classes        (cerialize, decerialize)
import Capnp.Convert        (msgToValue, valueToMsg)
import Capnp.Message        (ConstMsg)
import Capnp.Promise        (Fulfiller, breakPromise, fulfill, newCallback)
import Capnp.Rpc.Errors
    ( eDisconnected
    , eFailed
    , eMethodUnimplemented
    , eUnimplemented
    , wrapException
    )
import Capnp.Rpc.Transport  (Transport(recvMsg, sendMsg))
import Capnp.TraversalLimit (defaultLimit, evalLimitT)
import Internal.BuildPure   (createPure)
import Internal.Rc          (Rc)
import Internal.SnocList    (SnocList)

import qualified Capnp.Gen.Capnp.Rpc.Pure as R
import qualified Capnp.Message            as Message
import qualified Capnp.Rpc.Server         as Server
import qualified Capnp.Untyped            as UntypedRaw
import qualified Capnp.Untyped.Pure       as Untyped
import qualified Internal.FinalizerKey    as FinalizerKey
import qualified Internal.Rc              as Rc
import qualified Internal.SnocList        as SnocList
import qualified Internal.TCloseQ         as TCloseQ

-- We use this type often enough that the types get noisy without a shorthand:
type MPtr = Maybe Untyped.Ptr
-- Less often, but still helpful:
type RawMPtr = Maybe (UntypedRaw.Ptr ConstMsg)


-- | Errors which can be thrown by the rpc system.
data RpcError
    = ReceivedAbort R.Exception
    -- ^ The remote vat sent us an abort message.
    | SentAbort R.Exception
    -- ^ We sent an abort to the remote vat.
    deriving(Show, Eq, Generic)

instance Exception RpcError

-- | 'StopVat' is an exception used to terminate a capnproto connection; it is
-- raised by `stopVat`.
--
-- XXX TODO: this is not a good mechanism. For one thing, it only actually works
-- if thrown from the same thread as 'handleConn'. Come up with something better.
data StopVat = StopVat deriving(Show)
instance Exception StopVat

-- | Shut down the rpc connection, and all resources managed by the vat. This
-- does not return (it raises an exception used to actually signal termination
-- of the connection).
stopVat :: IO ()
stopVat = throwIO StopVat

newtype EmbargoId = EmbargoId { embargoWord :: Word32 }
newtype QAId = QAId { qaWord :: Word32 } deriving(Eq, Hashable)
newtype IEId = IEId { ieWord :: Word32 } deriving(Eq, Hashable)

-- We define these to just show the number; the derived instances would include
-- data constructors, which is a bit weird since these show up in output that
-- is sometimes show to users.
instance Show QAId where
    show = show . qaWord
instance Show IEId where
    show = show . ieWord

-- | A connection to a remote vat
data Conn = Conn
    { stableName       :: StableName ()
    -- So we can use the connection as a map key.

    , sendQ            :: TBQueue ConstMsg
    , recvQ            :: TBQueue ConstMsg
    -- queues of messages to send and receive; each of these has a dedicated
    -- thread doing the IO (see 'sendLoop' and 'recvLoop'):

    , supervisor       :: Supervisor
    -- Supervisor managing the lifetimes of threads bound to this connection.

    , questionIdPool   :: IdPool
    , exportIdPool     :: IdPool
    -- Pools of identifiers for new questions and exports

    , maxAnswerCalls   :: !Int
    -- Maximum number of calls that can be outstanding on an unresolved answer.

    , questions        :: M.Map QAId EntryQA
    , answers          :: M.Map QAId EntryQA
    , exports          :: M.Map IEId EntryE
    , imports          :: M.Map IEId EntryI

    , embargos         :: M.Map EmbargoId (STM ())
    -- Outstanding embargos. When we receive a 'Disembargo' message with its
    -- context field set to receiverLoopback, we look up the embargo id in
    -- this table, and execute the STM we have registered.

    , pendingCallbacks :: TQueue (IO ())
    -- See Note [callbacks]

    , bootstrap        :: Maybe Client
    -- The capability which should be served as this connection's bootstrap
    -- interface (if any).

    , debugMode        :: !Bool
    -- whether to include extra (possibly sensitive) info in error messages.
    }

instance Eq Conn where
    x == y = stableName x `eqStableName` stableName y

instance Hashable Conn where
    hash Conn{stableName} = hashStableName stableName
    hashWithSalt _ = hash

-- | Configuration information for a connection.
data ConnConfig = ConnConfig
    { maxQuestions   :: !Word32
    -- ^ The maximum number of simultanious outstanding requests to the peer
    -- vat. Once this limit is reached, further questsions will block until
    -- some of the existing questions have been answered.
    --
    -- Defaults to 32.

    , maxExports     :: !Word32
    -- ^ The maximum number of objects which may be exported on this connection.
    --
    -- Defaults to 32.

    , maxAnswerCalls :: !Int
    -- Maximum number of calls that can be outstanding on an unresolved answer.
    --
    -- Defaults to 16.

    , debugMode      :: !Bool
    -- ^ In debug mode, errors reported by the RPC system to its peers will
    -- contain extra information. This should not be used in production, as
    -- it is possible for these messages to contain sensitive information,
    -- but it can be useful for debugging.
    --
    -- Defaults to 'False'.

    , getBootstrap   :: Supervisor -> STM (Maybe Client)
    -- ^ Get the bootstrap interface we should serve for this connection.
    -- the argument is a supervisor whose lifetime is bound to the
    -- connection. If 'getBootstrap' returns 'Nothing', we will respond
    -- to bootstrap messages with an exception.
    --
    -- The default always returns 'nullClient'.

    , withBootstrap  :: Maybe (Supervisor -> Client -> IO ())
    -- ^ An action to perform with access to the remote vat's bootstrap
    -- interface. The supervisor argument is bound to the lifetime of the
    -- connection. If this is 'Nothing' (the default), the bootstrap
    -- interface will not be requested.
    }

instance Default ConnConfig where
    def = ConnConfig
        { maxQuestions   = 32
        , maxExports     = 32
        , maxAnswerCalls = 16
        , debugMode      = False
        , getBootstrap   = \_ -> pure Nothing
        , withBootstrap  = Nothing
        }

-- | Queue an IO action to be run some time after this transaction commits.
-- See Note [callbacks].
queueIO :: Conn -> IO () -> STM ()
queueIO Conn{pendingCallbacks} = writeTQueue pendingCallbacks

-- | Queue another transaction to be run some time after this transaction
-- commits, in a thread bound to the lifetime of the connection. If this is
-- called multiple times within the same transaction, each of the
-- transactions will be run separately, in the order they were queued.
--
-- See Note [callbacks]
queueSTM :: Conn -> STM () -> STM ()
queueSTM conn = queueIO conn . atomically

-- | @'mapQueueSTM' conn fs val@ queues the list of transactions obtained
-- by applying each element of @fs@ to @val@.
mapQueueSTM :: Conn -> SnocList (a -> STM ()) -> a -> STM ()
mapQueueSTM conn fs x = traverse_ (\f -> queueSTM conn (f x)) fs

-- Note [callbacks]
-- ================
--
-- There are many places where we want to register some code to run after
-- some later event has happened -- for exmaple:
--
-- * We send a Call to the remote vat, and when a corresponding Return message
--   is received, we want to fulfill (or break) the local promise for the
--   result.
-- * We send a Disembargo (with senderLoopback set), and want to actually lift
--   the embargo when the corresponding (receiverLoopback) message arrives.
--
-- Keeping the two parts of these patterns together tends to result in better
-- separation of concerns, and is easier to maintain.
--
-- To achieve this, the four tables and other connection state have fields in
-- which callbacks can be registered -- for example, an outstanding question has
-- fields containing transactions to run when the return and/or finish messages
-- arrive.
--
-- When it is time to actually run these, we want to make sure that each of them
-- runs as their own transaction. If, for example, when registering a callback to
-- run when a return message is received, we find that the return message is
-- already available, it might be tempting to just run the transaction immediately.
-- But this means that the synchronization semantics are totally different from the
-- case where the callback really does get run later!
--
-- In addition, we sometimes want to register a finalizer, inside a transaction,
-- but this can only be done in IO.
--
-- To solve these issues, the connection maintains a queue of all callback actions
-- that are ready to run, and when the event a callback is waiting for occurs, we
-- simply move the callback to the queue, using 'queueIO' or 'queueSTM'. When the
-- connection starts up, it creates a thread running 'callbackLoop', which just
-- continually flushes the queue, running the actions in the queue.

-- | Get a new question id. retries if we are out of available question ids.
newQuestion :: Conn -> STM QAId
newQuestion = fmap QAId . newId . questionIdPool

-- | Return a question id to the pool of available ids.
freeQuestion :: Conn -> QAId -> STM ()
freeQuestion conn = freeId (questionIdPool conn) . qaWord

-- | Get a new export id. retries if we are out of available export ids.
newExport :: Conn -> STM IEId
newExport = fmap IEId . newId . exportIdPool

-- | Return a export id to the pool of available ids.
freeExport :: Conn -> IEId -> STM ()
freeExport conn = freeId (exportIdPool conn) . ieWord

-- | Handle a connection to another vat. Returns when the connection is closed.
handleConn :: Transport -> ConnConfig -> IO ()
handleConn
    transport
    cfg@ConnConfig
        { maxQuestions
        , maxExports
        , withBootstrap
        , debugMode
        , maxAnswerCalls
        }
    = withSupervisor $ \sup ->
        handle
            (\StopVat -> pure ())
            $ bracket
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
            imports <- M.new

            embargos <- M.new
            pendingCallbacks <- newTQueue

            pure Conn
                { stableName
                , supervisor = sup
                , questionIdPool
                , exportIdPool
                , recvQ
                , sendQ
                , maxAnswerCalls
                , questions
                , answers
                , exports
                , imports
                , embargos
                , pendingCallbacks
                , bootstrap
                , debugMode
                }
    runConn conn =
        coordinator conn
            `concurrently_` sendLoop transport conn
            `concurrently_` recvLoop transport conn
            `concurrently_` callbacksLoop conn
            `concurrently_` useBootstrap conn
    stopConn Conn{bootstrap=Nothing} = pure ()
    stopConn Conn{bootstrap=Just (Client Nothing)} = pure ()
    stopConn conn@Conn{bootstrap=Just (Client (Just client'))} =
        atomically $ dropConnExport conn client'
        -- TODO: clear out the rest of the connection state.
    useBootstrap conn = case withBootstrap of
        Nothing -> pure ()
        Just f  -> atomically (requestBootstrap conn) >>= f (supervisor conn)


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

-- | An entry in our questions or answers table.
data EntryQA
    -- | An entry for which we have neither sent/received a finish, nor
    -- a return. Contains two sets of callbacks, to invoke on each type
    -- of message.
    = NewQA
        { onFinish :: SnocList (R.Finish -> STM ())
        , onReturn :: SnocList (R.Return -> STM ())
        }
    -- | An entry for which we've sent/received a return, but not a finish.
    -- Contains the return message, and a set of callbacks to invoke on the
    -- finish.
    | HaveReturn
        { returnMsg :: R.Return
        , onFinish  :: SnocList (R.Finish -> STM ())
        }
    -- | An entry for which we've sent/received a finish, but not a return.
    -- Contains the finish message, and a set of callbacks to invoke on the
    -- return.
    | HaveFinish
        { finishMsg :: R.Finish
        , onReturn  :: SnocList (R.Return -> STM ())
        }


-- | An entry in our imports table.
data EntryI = EntryI
    { localRc  :: Rc ()
    -- ^ A refcount cell with a finalizer attached to it; when the finalizer
    -- runs it will remove this entry from the table and send a release
    -- message to the remote vat.
    , remoteRc :: !Word32
    -- ^ The reference count for this object as understood by the remote
    -- vat. This tells us what to send in the release message's count field.
    , proxies  :: ExportMap
    -- ^ See Note [proxies]
    }

-- | An entry in our exports table.
data EntryE = EntryE
    { client   :: Client'
    -- ^ The client. We cache it in the table so there's only one object
    -- floating around, which lets us attach a finalizer without worrying
    -- about it being run more than once.
    , refCount :: !Word32
    -- ^ The refcount for this entry. This lets us know when we can drop
    -- the entry from the table.
    }

-- | Types which may be converted to and from 'Client's. Typically these
-- will be simple type wrappers for capabilities.
class IsClient a where
    -- | Convert a value to a client.
    toClient :: a -> Client
    -- | Convert a client to a value.
    fromClient :: Client -> a

instance Show Client where
    show (Client Nothing) = "nullClient"
    show _                = "({- capability; not statically representable -})"

-- | A reference to a capability, which may be live either in the current vat
-- or elsewhere. Holding a client affords making method calls on a capability
-- or modifying the local vat's reference count to it.
newtype Client =
    -- We wrap the real client in a Maybe, with Nothing representing a 'null'
    -- capability.
    Client (Maybe Client')
    deriving(Eq)

-- | A non-null client.
data Client'
    -- | A client pointing at a capability local to our own vat.
    = LocalClient
        { exportMap    :: ExportMap
        -- ^ Record of what export IDs this client has on different remote
        -- connections.
        , qCall        :: Rc (Server.CallInfo -> STM ())
        -- ^ Queue a call for the local capability to handle. This is wrapped
        -- in a reference counted cell, whose finalizer stops the server.
        , finalizerKey :: FinalizerKey.Key
        -- ^ Finalizer key; when this is collected, qCall will be released.
        }
    -- | A client which will resolve to some other capability at
    -- some point.
    | PromiseClient
        { pState    :: TVar PromiseState
        -- ^ The current state of the promise; the indirection allows
        -- the promise to be updated.
        , exportMap :: ExportMap
        }
    -- | A client which points to a (resolved) capability in a remote vat.
    | ImportClient ImportRef

-- | The current state of a 'PromiseClient'.
data PromiseState
    -- | The promise is fully resolved.
    = Ready
        { target :: Client
        -- ^ Capability to which the promise resolved.
        }
    -- | The promise has resolved, but is waiting on a Disembargo message
    -- before it is safe to send it messages.
    | Embargo
        { callBuffer :: TQueue Server.CallInfo
        -- ^ A queue in which to buffer calls while waiting for the
        -- disembargo.
        }
    -- | The promise has not yet resolved.
    | Pending
        { tmpDest :: TmpDest
        -- ^ A temporary destination to send calls, while we wait for the
        -- promise to resolve.
        }
    -- | The promise resolved to an exception.
    | Error R.Exception

-- | A temporary destination for calls on an unresolved promise.
data TmpDest
    -- | Queue the calls locally, rather than sending them elsewhere.
    = LocalBuffer { callBuffer :: TQueue Server.CallInfo }
    -- | Send call messages to a remote vat, targeting the results
    -- of an outstanding question.
    | AnswerDest
        { conn   :: Conn
        -- ^ The connection to the remote vat.
        , answer :: PromisedAnswer
        -- ^ The answer to target.
        }
    -- | Send call messages to a remote vat, targeting an entry in our
    -- imports table.
    | ImportDest ImportRef

-- | A reference to a capability in our import table/a remote vat's export
-- table.
data ImportRef = ImportRef
    { conn         :: Conn
    -- ^ The connection to the remote vat.
    , importId     :: !IEId
    -- ^ The import id for this capability.
    , proxies      :: ExportMap
    -- ^ Export ids to use when this client is passed to a vat other than
    -- the one identified by 'conn'. See Note [proxies]
    , finalizerKey :: FinalizerKey.Key
    }

-- Ideally we could just derive these, but stm-containers doesn't have Eq
-- instances, so neither does ExportMap. not all of the fields are actually
-- necessary to check equality though. See also
-- https://github.com/nikita-volkov/stm-hamt/pull/1
instance Eq ImportRef where
    ImportRef { conn=cx, importId=ix } == ImportRef { conn=cy, importId=iy } =
        cx == cy && ix == iy
instance Eq Client' where
    LocalClient { qCall = x } == LocalClient { qCall = y } =
        x == y
    PromiseClient { pState = x } == PromiseClient { pState = y } =
        x == y
    ImportClient x == ImportClient y =
        x == y
    _ == _ =
        False


-- | an 'ExportMap' tracks a mapping from connections to export IDs; it is
-- used to ensure that we re-use export IDs for capabilities when passing
-- them to remote vats. This used for locally hosted capabilities, but also
-- by proxied imports (see Note [proxies]).
newtype ExportMap = ExportMap (M.Map Conn IEId)

-- MsgTarget and PromisedAnswer correspond to the similarly named types in
-- rpc.capnp, except:
--
-- * They use our newtype wrappers for ids
-- * They don't have unknown variants
-- * PromisedAnswer's transform field is just a list of pointer offsets,
--   rather than a union with no other actually-useful variants.
-- * PromisedAnswer's transform field is a SnocList, efficient appending.
data MsgTarget
    = ImportTgt !IEId
    | AnswerTgt PromisedAnswer
data PromisedAnswer = PromisedAnswer
    { answerId  :: !QAId
    , transform :: SnocList Word16
    }

-- Note [proxies]
-- ==============
--
-- It is possible to have multiple connections open at once, and pass around
-- clients freely between them. Without level 3 support, this means that when
-- we pass a capability pointing into Vat A to another Vat B, we must proxy it.
--
-- To achieve this, capabilities pointing into a remote vat hold an 'ExportMap',
-- which tracks which export IDs we should be using to proxy the client on each
-- connection.

-- | Queue a call on a client.
call :: Server.CallInfo -> Client -> STM ()
call Server.CallInfo { response } (Client Nothing) =
    breakPromise response eMethodUnimplemented
call info@Server.CallInfo { response } (Client (Just client')) = case client' of
    LocalClient { qCall } -> Rc.get qCall >>= \case
        Just q ->
            q info
        Nothing ->
            breakPromise response eDisconnected

    PromiseClient { pState } -> readTVar pState >>= \case
        Ready { target }  ->
            call info target

        Embargo { callBuffer } ->
            writeTQueue callBuffer info

        Pending { tmpDest } -> case tmpDest of
            LocalBuffer { callBuffer } ->
                writeTQueue callBuffer info

            AnswerDest { conn, answer } ->
                callRemote conn info $ AnswerTgt answer

            ImportDest ImportRef { conn, importId } ->
                callRemote conn info (ImportTgt importId)

        Error exn ->
            breakPromise response exn

    ImportClient ImportRef { conn, importId } ->
        callRemote conn info (ImportTgt importId)

-- | Send a call to a remote capability.
callRemote :: Conn -> Server.CallInfo -> MsgTarget -> STM ()
callRemote
        conn@Conn{ questions }
        Server.CallInfo{ interfaceId, methodId, arguments, response }
        target = do
    qid <- newQuestion conn
    payload <- makeOutgoingPayload conn arguments
    sendPureMsg conn $ R.Message'call def
        { R.questionId = qaWord qid
        , R.target = marshalMsgTarget target
        , R.params = payload
        , R.interfaceId = interfaceId
        , R.methodId = methodId
        }
    M.insert
        NewQA
            { onReturn = SnocList.singleton $ cbCallReturn conn response
            , onFinish = SnocList.empty
            }
        qid
        questions

-- | Callback to run when a return comes in that corresponds to a call
-- we sent. Registered in callRemote.
cbCallReturn :: Conn -> Fulfiller RawMPtr -> R.Return -> STM ()
cbCallReturn conn@Conn{answers} response R.Return{ answerId, union' } = do
    case union' of
        R.Return'exception exn ->
            breakPromise response exn
        R.Return'results R.Payload{ content } -> do
            rawPtr <- createPure defaultLimit $ do
                msg <- Message.newMessage Nothing
                cerialize msg content
            fulfill response rawPtr
        R.Return'canceled ->
            breakPromise response $ eFailed "Canceled"

        R.Return'resultsSentElsewhere ->
            -- This should never happen, since we always set
            -- sendResultsTo = caller
            abortConn conn $ eFailed $ mconcat
                [ "Received Return.resultsSentElswhere for a call "
                , "with sendResultsTo = caller."
                ]

        R.Return'takeFromOtherQuestion (QAId -> qid) ->
            -- TODO(cleanup): we should be a little stricter; the protocol
            -- requires that (1) each answer is only used this way once, and
            -- (2) The question was sent with sendResultsTo set to 'yourself',
            -- but we don't enforce either of these requirements.
            subscribeReturn "answer" conn answers qid $
                cbCallReturn conn response

        R.Return'acceptFromThirdParty _ ->
            -- LEVEL 3
            abortConn conn $ eUnimplemented
                "This vat does not support level 3."
        R.Return'unknown' ordinal ->
            abortConn conn $ eUnimplemented $
                "Unknown return variant #" <> fromString (show ordinal)
    finishQuestion conn def
        { R.questionId = answerId
        , R.releaseResultCaps = False
        }


marshalMsgTarget :: MsgTarget -> R.MessageTarget
marshalMsgTarget = \case
    ImportTgt importId ->
        R.MessageTarget'importedCap (ieWord importId)
    AnswerTgt tgt ->
        R.MessageTarget'promisedAnswer $ marshalPromisedAnswer tgt

marshalPromisedAnswer :: PromisedAnswer -> R.PromisedAnswer
marshalPromisedAnswer PromisedAnswer{ answerId, transform } =
    R.PromisedAnswer
        { R.questionId = qaWord answerId
        , R.transform = V.fromList $
            map R.PromisedAnswer'Op'getPointerField $
            toList transform
        }

unmarshalMsgTarget :: R.MessageTarget -> Either R.Exception MsgTarget
unmarshalMsgTarget (R.MessageTarget'importedCap importId) =
    Right $ ImportTgt (IEId importId)
unmarshalMsgTarget (R.MessageTarget'promisedAnswer pa) =
    AnswerTgt <$> unmarshalPromisedAnswer pa
unmarshalMsgTarget (R.MessageTarget'unknown' tag) =
    Left $ eFailed $ "Unknown MessageTarget: " <> fromString (show tag)

unmarshalPromisedAnswer :: R.PromisedAnswer -> Either R.Exception PromisedAnswer
unmarshalPromisedAnswer R.PromisedAnswer { questionId, transform } = do
    idxes <- unmarshalOps (toList transform)
    pure PromisedAnswer
        { answerId = QAId questionId
        , transform = SnocList.fromList idxes
        }

unmarshalOps :: [R.PromisedAnswer'Op] -> Either R.Exception [Word16]
unmarshalOps [] = Right []
unmarshalOps (R.PromisedAnswer'Op'noop:ops) =
    unmarshalOps ops
unmarshalOps (R.PromisedAnswer'Op'getPointerField i:ops) =
    (i:) <$> unmarshalOps ops
unmarshalOps (R.PromisedAnswer'Op'unknown' tag:_) =
    Left $ eFailed $ "Unknown PromisedAnswer.Op: " <> fromString (show tag)


-- | A null client. This is the only client value that can be represented
-- statically. Throws exceptions in response to all method calls.
nullClient :: Client
nullClient = Client Nothing

-- | Spawn a local server with its lifetime bound to the supervisor,
-- and return a client for it. When the client is garbage collected,
-- the server will be stopped (if it is still running).
export :: Supervisor -> Server.ServerOps IO -> STM Client
export sup ops = do
    q <- TCloseQ.new
    qCall <- Rc.new (TCloseQ.write q) (TCloseQ.close q)
    exportMap <- ExportMap <$> M.new
    finalizerKey <- FinalizerKey.newSTM
    let client' = LocalClient
            { qCall
            , exportMap
            , finalizerKey
            }
    superviseSTM sup $ do
        FinalizerKey.set finalizerKey $ atomically $ Rc.release qCall
        Server.runServer q ops
    pure $ Client (Just client')

clientMethodHandler :: Word64 -> Word16 -> Client -> Server.MethodHandler IO p r
clientMethodHandler interfaceId methodId client =
    Server.fromUntypedHandler $ Server.untypedHandler $
        \arguments response -> atomically $ call Server.CallInfo{..} client

-- | See Note [callbacks]
callbacksLoop :: Conn -> IO ()
callbacksLoop Conn{pendingCallbacks} = forever $
    atomically (flushTQueue pendingCallbacks)
    >>= sequence_

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
coordinator conn@Conn{recvQ,debugMode} = go
  where
    go = try (atomically handleMsg) >>= \case
        Right () ->
            go
        Left (SentAbort e) -> do
            atomically $ sendPureMsg conn $ R.Message'abort e
            -- Give the message a bit of time to reach the remote vat:
            threadDelay 1000000
            throwIO (SentAbort e)
        Left e ->
            throwIO e
    handleMsg = do
        msg <- (readTBQueue recvQ >>= parseWithCaps conn)
            `catchSTM`
            (abortConn conn . wrapException debugMode)
        case msg of
            R.Message'abort exn ->
                handleAbortMsg conn exn
            R.Message'unimplemented oldMsg ->
                handleUnimplementedMsg conn oldMsg
            R.Message'bootstrap bs ->
                handleBootstrapMsg conn bs
            R.Message'call call ->
                handleCallMsg conn call
            R.Message'return ret ->
                handleReturnMsg conn ret
            R.Message'finish finish ->
                handleFinishMsg conn finish
            R.Message'release release ->
                handleReleaseMsg conn release
            R.Message'disembargo disembargo ->
                handleDisembargoMsg conn disembargo
            _ ->
                sendPureMsg conn $ R.Message'unimplemented msg

-- | 'parseWithCaps' parses a message, making sure to interpret its capability
-- table. The latter bit is the difference between this and just calling
-- 'msgToValue'; 'msgToValue' will leave all of the clients in the message
-- null.
parseWithCaps :: Conn -> ConstMsg -> STM R.Message
parseWithCaps conn msg = do
    pureMsg <- msgToValue msg
    case pureMsg of
        -- capabilities only appear in call and return messages, and in the
        -- latter only in the 'results' variant. In the other cases we can
        -- just leave the result alone.
        R.Message'call R.Call{params=R.Payload{capTable}} ->
            fixCapTable capTable conn msg >>= msgToValue
        R.Message'return R.Return{union'=R.Return'results R.Payload{capTable}} ->
            fixCapTable capTable conn msg >>= msgToValue
        _ ->
            pure pureMsg

-- Each function handle*Msg handles a message of a particular type;
-- 'coordinator' dispatches to these.

handleAbortMsg :: Conn -> R.Exception -> STM ()
handleAbortMsg _ exn =
    throwSTM (ReceivedAbort exn)

handleUnimplementedMsg :: Conn -> R.Message -> STM ()
handleUnimplementedMsg conn = \case
    R.Message'unimplemented _ ->
        -- If the client itself doesn't handle unimplemented messages, that's
        -- weird, but ultimately their problem.
        pure ()
    R.Message'abort _ ->
        abortConn conn $ eFailed $
            "Your vat sent an 'unimplemented' message for an abort message " <>
            "that its remote peer never sent. This is likely a bug in your " <>
            "capnproto library."
    _ ->
        abortConn conn $
            eFailed "Received unimplemented response for required message."

handleBootstrapMsg :: Conn -> R.Bootstrap -> STM ()
handleBootstrapMsg conn R.Bootstrap{ questionId } = do
    ret <- case bootstrap conn of
        Nothing ->
            pure $ R.Return
                { R.answerId = questionId
                , R.releaseParamCaps = True -- Not really meaningful for bootstrap, but...
                , R.union' =
                    R.Return'exception $
                        eFailed "No bootstrap interface for this connection."
                }
        Just client -> do
            capDesc <- emitCap conn client
            pure $ R.Return
                { R.answerId = questionId
                , R.releaseParamCaps = True -- Not really meaningful for bootstrap, but...
                , R.union' =
                    R.Return'results R.Payload
                            -- XXX: this is a bit fragile; we're relying on
                            -- the encode step to pick the right index for
                            -- our capability.
                        { content = Just (Untyped.PtrCap client)
                        , capTable = V.singleton capDesc
                        }
                }
    M.focus
        (Focus.alterM $ insertBootstrap ret)
        (QAId questionId)
        (answers conn)
    sendPureMsg conn $ R.Message'return ret
  where
    insertBootstrap ret Nothing =
        pure $ Just HaveReturn
            { returnMsg = ret
            , onFinish = SnocList.empty
            }
    insertBootstrap _ (Just _) =
        abortConn conn $ eFailed "Duplicate question ID"

handleCallMsg :: Conn -> R.Call -> STM ()
handleCallMsg
        conn@Conn{exports, answers}
        R.Call
            { questionId
            , target
            , interfaceId
            , methodId
            , params=R.Payload{content}
            }
        = do
    -- First, add an entry in our answers table:
    insertNewAbort
        "answer"
        conn
        (QAId questionId)
        NewQA
            { onReturn = SnocList.empty
            , onFinish = SnocList.empty
            }
        answers

    -- Marshal the parameters to the call back into the low-level form:
    callParams <- createPure defaultLimit $ do
        msg <- Message.newMessage Nothing
        cerialize msg content

    -- Set up a callback for when the call is finished, to
    -- send the return message:
    fulfiller <- newCallback $ \case
        Left e ->
            returnAnswer conn def
                { R.answerId = questionId
                , R.releaseParamCaps = False
                , R.union' = R.Return'exception e
                }
        Right v -> do
            content <- evalLimitT defaultLimit (decerialize v)
            capTable <- genSendableCapTable conn content
            returnAnswer conn def
                { R.answerId = questionId
                , R.releaseParamCaps = False
                , R.union'   = R.Return'results def
                    { R.content  = content
                    , R.capTable = capTable
                    }
                }
    -- Package up the info for the call:
    let callInfo = Server.CallInfo
            { interfaceId
            , methodId
            , arguments = callParams
            , response = fulfiller
            }
    -- Finally, figure out where to send it:
    case target of
        R.MessageTarget'importedCap exportId ->
            lookupAbort "export" conn exports (IEId exportId) $
                \EntryE{client} -> call callInfo $ Client $ Just client
        R.MessageTarget'promisedAnswer R.PromisedAnswer { questionId = targetQid, transform } ->
            subscribeReturn "answer" conn answers (QAId targetQid) $ \ret@R.Return{union'} ->
                case union' of
                    R.Return'exception _ ->
                        returnAnswer conn ret { R.answerId = questionId }
                    R.Return'results R.Payload{content} ->
                        transformClient transform content conn >>= call callInfo
                    _ ->
                        error "TODO"
        R.MessageTarget'unknown' ordinal ->
            abortConn conn $ eUnimplemented $
                "Unknown MessageTarget ordinal #" <> fromString (show ordinal)

transformClient :: V.Vector R.PromisedAnswer'Op -> MPtr -> Conn -> STM Client
transformClient transform ptr conn =
    case unmarshalOps (V.toList transform) >>= flip followPtrs ptr of
        Left e ->
            abortConn conn e
        Right Nothing ->
            pure nullClient
        Right (Just (Untyped.PtrCap client)) ->
            pure client
        Right (Just _) ->
            abortConn conn $ eFailed "Tried to call method on non-capability."

-- | Follow a series of pointer indicies, returning the final value, or 'Left'
-- with an error if any of the pointers in the chain (except the last one) is
-- a non-null non struct.
followPtrs :: [Word16] -> MPtr -> Either R.Exception MPtr
followPtrs [] ptr =
    Right ptr
followPtrs (_:_) Nothing =
    Right Nothing
followPtrs (i:is) (Just (Untyped.PtrStruct (Untyped.Struct _ ptrs))) =
    followPtrs is (Untyped.sliceIndex (fromIntegral i) ptrs)
followPtrs (_:_) (Just _) =
    Left (eFailed "Tried to access pointer field of non-struct.")

handleReturnMsg :: Conn -> R.Return -> STM ()
handleReturnMsg conn@Conn{questions} =
    -- TODO: handle releaseParamCaps
    updateQAReturn conn questions "question"

handleFinishMsg :: Conn -> R.Finish -> STM ()
handleFinishMsg conn@Conn{answers} =
    -- TODO: handle releaseResultCaps
    updateQAFinish conn answers "answer"

handleReleaseMsg :: Conn -> R.Release -> STM ()
handleReleaseMsg
        conn@Conn{exports}
        R.Release
            { id=(IEId -> eid)
            , referenceCount=refCountDiff
            } =
    lookupAbort "export" conn exports eid $
        \EntryE{client, refCount=oldRefCount} ->
            case compare oldRefCount refCountDiff of
                LT ->
                    abortConn conn $ eFailed $
                        "Received release for export with referenceCount " <>
                        "greater than our recorded total ref count."
                EQ ->
                    dropConnExport conn client
                GT ->
                    M.insert
                        EntryE
                            { client
                            , refCount = oldRefCount - refCountDiff
                            }
                        eid
                        exports

handleDisembargoMsg :: Conn -> R.Disembargo -> STM ()
handleDisembargoMsg
        conn@Conn{exports, answers}
        R.Disembargo{ target, context=R.Disembargo'context'senderLoopback embargoId }
    =
    case target of
        R.MessageTarget'importedCap exportId ->
            lookupAbort "export" conn exports (IEId exportId) $ \EntryE{ client } ->
                disembargoPromise client
        R.MessageTarget'promisedAnswer R.PromisedAnswer{ questionId, transform } ->
            lookupAbort "answer" conn answers (QAId questionId) $ \case
                HaveReturn { returnMsg=R.Return{union'=R.Return'results R.Payload{content} } } ->
                    transformClient transform content conn >>= \case
                        Client (Just client') -> disembargoClient client'
                        Client Nothing -> abortDisembargo "targets a null capability"
                _ ->
                    abortDisembargo $
                        "does not target an answer which has resolved to a value hosted by"
                        <> " the sender."
        R.MessageTarget'unknown' ordinal ->
            abortConn conn $ eUnimplemented $
                "Unknown MessageTarget ordinal #" <> fromString (show ordinal)
  where
    disembargoPromise PromiseClient{ pState } = readTVar pState >>= \case
        Ready (Client (Just client)) ->
            disembargoClient client
        Ready (Client Nothing) ->
            abortDisembargo "targets a promise which resolved to null."
        _ ->
            abortDisembargo "targets a promise which has not resolved."
    disembargoPromise _ =
        abortDisembargo "targets something that is not a promise."

    disembargoClient (ImportClient ImportRef {conn=targetConn, importId})
        | conn == targetConn =
            sendPureMsg conn $ R.Message'disembargo R.Disembargo
                { context = R.Disembargo'context'receiverLoopback embargoId
                , target = R.MessageTarget'importedCap (ieWord importId)
                }
    disembargoClient _ =
            abortDisembargo $
                "targets a promise which has not resolved to a capability"
                <> " hosted by the sender."

    abortDisembargo info =
        abortConn conn $ eFailed $ mconcat
            [ "Disembargo #"
            , fromString (show embargoId)
            , " with context = senderLoopback "
            , info
            ]
handleDisembargoMsg _ _ =
    error "TODO"



-- | Interpret the list of cap descriptors, and replace the message's capability
-- table with the result.
fixCapTable :: V.Vector R.CapDescriptor -> Conn -> ConstMsg -> STM ConstMsg
fixCapTable capDescs conn msg = do
    clients <- traverse (acceptCap conn) capDescs
    pure $ Message.withCapTable clients msg

lookupAbort
    :: (Eq k, Hashable k, Show k)
    => Text -> Conn -> M.Map k v -> k -> (v -> STM a) -> STM a
lookupAbort keyTypeName conn m key f = do
    result <- M.lookup key m
    case result of
        Just val ->
            f val
        Nothing ->
            abortConn conn $ eFailed $ mconcat
                [ "No such "
                , keyTypeName
                ,  ": "
                , fromString (show key)
                ]

-- | @'insertNewAbort' keyTypeName conn key value stmMap@ inserts a key into a
-- map, aborting the connection if it is already present. @keyTypeName@ will be
-- used in the error message sent to the remote vat.
insertNewAbort :: (Eq k, Hashable k) => Text -> Conn -> k -> v -> M.Map k v -> STM ()
insertNewAbort keyTypeName conn key value =
    M.focus
        (Focus.alterM $ \case
            Just _ ->
                abortConn conn $ eFailed $
                    "duplicate entry in " <> keyTypeName <> " table."
            Nothing ->
                pure (Just value)
        )
        key

-- | Generate a cap table describing the capabilities reachable from the given
-- pointer. The capability table will be correct for any message where all of
-- the capabilities are within the subtree under the pointer.
--
-- XXX: it's kinda gross that we're serializing the pointer just to collect
-- this, then decerializing to put it in the larger adt, then reserializing
-- again... at some point we'll probably want to overhaul much of this module
-- for performance. This kind of thing is the motivation for #52.
genSendableCapTable :: Conn -> MPtr -> STM (V.Vector R.CapDescriptor)
genSendableCapTable conn ptr = do
    rawPtr <- createPure defaultLimit $ do
        msg <- Message.newMessage Nothing
        cerialize msg ptr
    genSendableCapTableRaw conn rawPtr

genSendableCapTableRaw
    :: Conn
    -> Maybe (UntypedRaw.Ptr ConstMsg)
    -> STM (V.Vector R.CapDescriptor)
genSendableCapTableRaw _ Nothing = pure V.empty
genSendableCapTableRaw conn (Just ptr) =
    traverse
        (emitCap conn)
        (Message.getCapTable (UntypedRaw.message ptr))

-- | Convert the pointer into a Payload, including a capability table for
-- the clients in the pointer's cap table.
makeOutgoingPayload :: Conn -> RawMPtr -> STM R.Payload
makeOutgoingPayload conn rawContent = do
    capTable <- genSendableCapTableRaw conn rawContent
    content <- evalLimitT defaultLimit (decerialize rawContent)
    pure R.Payload { content, capTable }

sendPureMsg :: Conn -> R.Message -> STM ()
sendPureMsg Conn{sendQ} msg =
    createPure maxBound (valueToMsg msg) >>= writeTBQueue sendQ

-- | Send a finish message, updating connection state and triggering
-- callbacks as necessary.
finishQuestion :: Conn -> R.Finish -> STM ()
finishQuestion conn@Conn{questions} finish@R.Finish{questionId} = do
    -- arrange for the question ID to be returned to the pool once
    -- the return has also been received:
    subscribeReturn "question" conn questions (QAId questionId) $ \_ ->
        freeQuestion conn (QAId questionId)
    sendPureMsg conn $ R.Message'finish finish
    updateQAFinish conn questions "question" finish

-- | Send a return message, update the corresponding entry in our
-- answers table, and queue any registered callbacks. Calls 'error'
-- if the answerId is not in the table, or if we've already sent a
-- return for this answer.
returnAnswer :: Conn -> R.Return -> STM ()
returnAnswer conn@Conn{answers} ret = do
    sendPureMsg conn $ R.Message'return ret
    updateQAReturn conn answers "answer" ret

-- TODO: updateQAReturn/Finish have a lot in common; can we refactor?

updateQAReturn :: Conn -> M.Map QAId EntryQA -> Text -> R.Return -> STM ()
updateQAReturn conn table tableName ret@R.Return{answerId} =
    lookupAbort tableName conn table (QAId answerId) $ \case
        NewQA{onFinish, onReturn} -> do
            mapQueueSTM conn onReturn ret
            M.insert
                HaveReturn
                    { returnMsg = ret
                    , onFinish
                    }
                (QAId answerId)
                table
        HaveFinish{onReturn} -> do
            mapQueueSTM conn onReturn ret
            M.delete (QAId answerId) table
        HaveReturn{} ->
            abortConn conn $ eFailed $
                "Duplicate return message for " <> tableName <> " #"
                <> fromString (show answerId)

updateQAFinish :: Conn -> M.Map QAId EntryQA -> Text -> R.Finish -> STM ()
updateQAFinish conn table tableName finish@R.Finish{questionId} =
    lookupAbort tableName conn table (QAId questionId) $ \case
        NewQA{onFinish, onReturn} -> do
            mapQueueSTM conn onFinish finish
            M.insert
                HaveFinish
                    { finishMsg = finish
                    , onReturn
                    }
                (QAId questionId)
                table
        HaveReturn{onFinish} -> do
            mapQueueSTM conn onFinish finish
            M.delete (QAId questionId) table
        HaveFinish{} ->
            abortConn conn $ eFailed $
                "Duplicate finish message for " <> tableName <> " #"
                <> fromString (show questionId)

-- | Update an entry in the questions or answers table to queue the given
-- callback when the return message for that answer comes in. If the return
-- has already arrived, the callback is queued immediately.
--
-- If the entry already has other callbacks registered, this callback is
-- run *after* the others (see Note [callbacks]). Note that this is an
-- important property, as it is necessary to preserve E-order if the
-- callbacks are successive method calls on the returned object.
subscribeReturn :: Text -> Conn -> M.Map QAId EntryQA -> QAId -> (R.Return -> STM ()) -> STM ()
subscribeReturn tableName conn table qaId onRet =
    lookupAbort tableName conn table qaId $ \qa -> do
        new <- go qa
        M.insert new qaId table
  where
    go = \case
        NewQA{onFinish, onReturn} ->
            pure NewQA
                { onFinish
                , onReturn = SnocList.snoc onReturn onRet
                }

        HaveFinish{finishMsg, onReturn} ->
            pure HaveFinish
                { finishMsg
                , onReturn = SnocList.snoc onReturn onRet
                }

        val@HaveReturn{returnMsg} -> do
            queueSTM conn (onRet returnMsg)
            pure val

abortConn :: Conn -> R.Exception -> STM a
abortConn _ e = throwSTM (SentAbort e)

-- | Request the remote vat's bootstrap interface.
requestBootstrap :: Conn -> STM Client
requestBootstrap conn@Conn{questions} = do
    qid <- newQuestion conn
    let tmpDest = AnswerDest
            { conn
            , answer = PromisedAnswer
                { answerId = qid
                , transform = SnocList.empty
                }
            }
    pState <- newTVar Pending { tmpDest }
    sendPureMsg conn $
        R.Message'bootstrap def { R.questionId = qaWord qid }
    M.insert
        NewQA
            { onReturn = SnocList.singleton $
                resolveClientReturn tmpDest (writeTVar pState) conn []
            , onFinish = SnocList.empty
            }
        qid
        questions
    exportMap <- ExportMap <$> M.new
    pure $ Client $ Just PromiseClient { pState, exportMap }

-- Note [resolveClient]
-- ====================
--
-- There are several functions resolveClient*, each of which resolves a
-- 'PromiseClient', which will previously have been in the 'Pending' state.
-- Each function accepts three parameters: the 'TmpDest' that the
-- pending promise had been targeting, a function for setting the new state,
-- and a thing to resolve the promise to. The type of the latter is specific
-- to each function.

-- | Resolve a promised client to an exception. See Note [resolveClient]
resolveClientExn :: TmpDest -> (PromiseState -> STM ()) -> R.Exception -> STM ()
resolveClientExn tmpDest resolve exn = do
    case tmpDest of
        LocalBuffer { callBuffer } -> do
            calls <- flushTQueue callBuffer
            traverse_
                (\Server.CallInfo{response} ->
                    breakPromise response exn)
                calls
        AnswerDest {} ->
            pure ()
        ImportDest _ ->
            pure () -- FIXME TODO: decrement the refcount for the import?
    resolve $ Error exn

-- Resolve a promised client to a pointer. If it is a non-null non-capability
-- pointer, it resolves to an exception. See Note [resolveClient]
resolveClientPtr :: TmpDest -> (PromiseState -> STM ()) -> MPtr -> STM ()
resolveClientPtr tmpDest resolve ptr = case ptr of
    Nothing ->
        resolveClientClient tmpDest resolve nullClient
    Just (Untyped.PtrCap c) ->
        resolveClientClient tmpDest resolve c
    Just _ ->
        resolveClientExn tmpDest resolve $
            eFailed "Promise resolved to non-capability pointer"

-- | Resolve a promised client to another client. See Note [resolveClient]
resolveClientClient :: TmpDest -> (PromiseState -> STM ()) -> Client -> STM ()
resolveClientClient tmpDest resolve (Client client) =
    case (client, tmpDest) of
        ( Just LocalClient{}, AnswerDest{} ) ->
            error "TODO: embargo"
        ( Just LocalClient{}, ImportDest _ ) ->
            error "TODO: embargo"
        ( _, LocalBuffer { callBuffer } ) -> do
            flushTQueue callBuffer >>= traverse_ (`call` Client client)
            resolve $ Ready (Client client)
        ( Just PromiseClient{}, _ ) ->
            error "TODO"
        ( _, AnswerDest{ answer=PromisedAnswer{ transform } } )
            | not (null transform) ->
                resolveClientExn tmpDest resolve $ eFailed
                    "Tried to access pointer fields on a client"
            | otherwise -> do
                releaseTmpDest tmpDest
                resolve $ Ready (Client client)
        _ ->
            error "TODO"

-- Do any cleanup of a TmpDest; this should be called after resolving a
-- pending promise.
releaseTmpDest :: TmpDest -> STM ()
releaseTmpDest LocalBuffer{} = pure ()
releaseTmpDest AnswerDest { conn, answer=PromisedAnswer{ answerId } } =
    finishQuestion conn def
        { R.questionId = qaWord answerId
        , R.releaseResultCaps = False
        }
releaseTmpDest (ImportDest _) = pure ()

-- | Resolve a promised client to the result of a return. See Note [resolveClient]
--
-- The [Word16] is a list of pointer indexes to follow from the result.
resolveClientReturn :: TmpDest -> (PromiseState -> STM ()) -> Conn -> [Word16] -> R.Return -> STM ()
resolveClientReturn tmpDest resolve conn@Conn{answers} transform R.Return { union' } = case union' of
    -- TODO(cleanup) there is a lot of redundency betwen this and cbCallReturn; can
    -- we refactor?
    R.Return'exception exn ->
        resolveClientExn tmpDest resolve exn
    R.Return'results R.Payload{ content } ->
        case followPtrs transform content of
            Right v ->
                resolveClientPtr tmpDest resolve v
            Left e ->
                resolveClientExn tmpDest resolve e

    R.Return'canceled ->
        resolveClientExn tmpDest resolve $ eFailed "Canceled"

    R.Return'resultsSentElsewhere ->
        -- Should never happen; we don't set sendResultsTo to anything other than
        -- caller.
        abortConn conn $ eFailed $ mconcat
            [ "Received Return.resultsSentElsewhere for a call "
            , "with sendResultsTo = caller."
            ]

    R.Return'takeFromOtherQuestion (QAId -> qid) ->
        subscribeReturn "answer" conn answers qid $
            resolveClientReturn tmpDest resolve conn transform

    R.Return'acceptFromThirdParty _ ->
        -- LEVEL 3
        abortConn conn $ eUnimplemented
            "This vat does not support level 3."

    R.Return'unknown' ordinal ->
        abortConn conn $ eUnimplemented $
            "Unknown return variant #" <> fromString (show ordinal)

-- | Get the client's export ID for this connection, or allocate a new one if needed.
-- If this is the first time this client has been exported on this connection,
-- bump the refcount.
getConnExport :: Conn -> Client' -> STM IEId
getConnExport conn@Conn{exports} client = do
    let ExportMap m = clientExportMap client
    val <- M.lookup conn m
    case val of
        Just eid -> do
            addBumpExport eid client exports
            pure eid

        Nothing -> do
            eid <- newExport conn
            addBumpExport eid client exports
            M.insert eid conn m
            pure eid

-- | Remove export of the client on the connection. This entails removing it
-- from the export id, removing the connection from the client's ExportMap,
-- freeing the export id, and dropping the client's refcount.
dropConnExport :: Conn -> Client' -> STM ()
dropConnExport conn@Conn{exports} client' = do
    let ExportMap eMap = clientExportMap client'
    val <- M.lookup conn eMap
    case val of
        Just eid -> do
            M.delete conn eMap
            M.delete eid exports
            freeExport conn eid
        Nothing ->
            error "BUG: tried to drop an export that doesn't exist."

clientExportMap :: Client' -> ExportMap
clientExportMap LocalClient{exportMap}            = exportMap
clientExportMap PromiseClient{exportMap}          = exportMap
clientExportMap (ImportClient ImportRef{proxies}) = proxies

-- | Generate a CapDescriptor, which the connection's remote vat may use to
-- refer to the client. In the process, this may allocate export ids, update
-- reference counts, and so forth.
emitCap :: Conn -> Client -> STM R.CapDescriptor
emitCap _conn (Client Nothing) =
    pure R.CapDescriptor'none
emitCap conn (Client (Just client')) = case client' of
    LocalClient{} ->
        R.CapDescriptor'senderHosted . ieWord <$> getConnExport conn client'
    PromiseClient{} ->
        R.CapDescriptor'senderPromise . ieWord <$> getConnExport conn client'
    ImportClient ImportRef { conn=hostConn, importId }
        | hostConn == conn ->
            pure (R.CapDescriptor'receiverHosted (ieWord importId))
        | otherwise ->
            R.CapDescriptor'senderHosted . ieWord <$> getConnExport conn client'

-- | insert the client into the exports table, bumping the refcount if it is
-- already there. If a different client is already in the table at the same
-- id, call 'error'.
addBumpExport :: IEId -> Client' -> M.Map IEId EntryE -> STM ()
addBumpExport exportId client =
    M.focus (Focus.alter go) exportId
  where
    go Nothing = Just EntryE { client, refCount = 1 }
    go (Just EntryE{ client = oldClient, refCount } )
        | client /= oldClient =
            error $
                "BUG: addExportRef called with a client that is different " ++
                "from what is already in our exports table."
        | otherwise =
            Just EntryE { client, refCount = refCount + 1 }

-- | 'acceptCap' is a dual of 'emitCap'; it derives a Client from a CapDescriptor
-- received via the connection. May update connection state as necessary.
acceptCap :: Conn -> R.CapDescriptor -> STM Client
acceptCap _ R.CapDescriptor'none = pure (Client Nothing)
acceptCap conn@Conn{imports} (R.CapDescriptor'senderHosted (IEId -> importId)) = do
    entry <- M.lookup importId imports
    finalizerKey <- FinalizerKey.newSTM
    case entry of
        Just EntryI{ localRc, remoteRc, proxies } -> do
            Rc.incr localRc
            M.insert EntryI { localRc, remoteRc = remoteRc + 1, proxies } importId imports
            queueIO conn $ FinalizerKey.set finalizerKey $ atomically (Rc.decr localRc)
            pure $ Client $ Just $ ImportClient ImportRef
                { conn
                , importId
                , proxies
                , finalizerKey
                }

        Nothing -> do
            localRc <- Rc.new () $
                lookupAbort "imports" conn imports importId $ \EntryI { remoteRc } -> do
                    sendPureMsg conn $ R.Message'release
                        R.Release
                            { id = ieWord importId
                            , referenceCount = remoteRc
                            }
                    M.delete importId imports
            proxies <- ExportMap <$> M.new
            M.insert EntryI { localRc, remoteRc = 1, proxies } importId imports
            pure $ Client $ Just $ ImportClient ImportRef
                { conn
                , importId
                , proxies
                , finalizerKey
                }
acceptCap conn@Conn{exports} (R.CapDescriptor'receiverHosted exportId) =
    lookupAbort "export" conn exports (IEId exportId) $
        \EntryE{client} ->
            pure $ Client $ Just client
acceptCap conn (R.CapDescriptor'receiverAnswer pa) =
    case unmarshalPromisedAnswer pa of
        Left e ->
            abortConn conn e
        Right pa ->
            newLocalAnswerClient conn pa
acceptCap _ d = error $ "TODO: " ++ show d

-- | Create a new client targeting an object in our answers table.
-- Important: in this case the 'PromisedAnswer' refers to a question we
-- have recevied, not sent.
newLocalAnswerClient :: Conn -> PromisedAnswer -> STM Client
newLocalAnswerClient conn@Conn{answers} PromisedAnswer{ answerId, transform } = do
    callBuffer <- newTQueue
    let tmpDest = LocalBuffer { callBuffer }
    pState <- newTVar Pending { tmpDest }
    subscribeReturn "answer" conn answers answerId $
        resolveClientReturn
            tmpDest
            (writeTVar pState)
            conn
            (toList transform)
    exportMap <- ExportMap <$> M.new
    pure $ Client $ Just PromiseClient { pState, exportMap }


-- Note [Limiting resource usage]
-- ==============================
--
-- N.B. much of this Note is future tense; the library is not yet robust against
-- resource useage attacks.
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
