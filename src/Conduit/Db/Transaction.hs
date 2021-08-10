{-# LANGUAGE RankNTypes #-}
module Conduit.Db.Transaction where

import RIO
import Hasql.Connection
import Hasql.Pool ( Pool, UsageError(..) )
import qualified Hasql.Pool as Pool
import Hasql.Transaction ( Transaction, condemn, statement )
import qualified Hasql.Session as Session
import qualified Hasql.Transaction.Sessions as Hasql
import Hasql.Statement (Statement)

import Conduit.App

runTransactionWithConnection :: MonadIO m => Connection -> Transaction b -> m b
runTransactionWithConnection conn transaction = do
    e <- liftIO $ Session.run (Hasql.transaction Hasql.Serializable Hasql.Write transaction) conn
    either throwIO pure e

runTransactionWithPool :: MonadIO m => Pool -> Transaction b -> m b
runTransactionWithPool pool transaction = do
    result <- liftIO $ Pool.use pool (Hasql.transaction Hasql.Serializable Hasql.Write transaction)
    case result of
        Right e -> pure e
        Left (ConnectionError e) -> error $ "Failed to connect to database, error: " ++ show e
        Left (SessionError e) -> throwIO e

runStmt :: Statement () a -> Transaction a
runStmt = statement ()

runTransaction :: forall a . Transaction a -> AppM a
runTransaction transaction = do
    pool <- getDbPool
    runTransactionWithPool pool transaction

executeStmt :: Statement () a -> AppM a
executeStmt = runTransaction . runStmt