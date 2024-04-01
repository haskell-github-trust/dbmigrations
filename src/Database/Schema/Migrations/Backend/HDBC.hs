module Database.Schema.Migrations.Backend.HDBC
  ( hdbcBackend
  , HDBCConnection (..)
  )
where

import Prelude

import Control.Exception (catch)
import Control.Monad (void)
import Data.String.Conversions (cs)
import Data.Text (Text)
import Data.Time.Clock (getCurrentTime)
import Database.HDBC
  ( IConnection (getTables, run, runRaw)
  , SqlError
  , commit
  , disconnect
  , fromSql
  , quickQuery'
  , rollback
  , toSql
  , withTransaction
  )
import Database.Schema.Migrations.Backend (Backend (..), rootMigrationName)
import Database.Schema.Migrations.Migration (Migration (..), newMigration)
import Database.Schema.Migrations.Test.BackendTest qualified as BackendTest

installedMigrations :: Text
installedMigrations = "installed_migrations"

-- | General Backend constructor for all HDBC connection implementations.
hdbcBackend :: IConnection conn => conn -> Backend
hdbcBackend conn =
  Backend
    { isBootstrapped = elem (cs installedMigrations) <$> getTables conn
    , getBootstrapMigration =
        do
          ts <- getCurrentTime
          pure $
            (newMigration rootMigrationName)
              { mApply = "CREATE TABLE " <> installedMigrations <> " (migration_id TEXT)"
              , mRevert = Just $ "DROP TABLE " <> installedMigrations
              , mDesc = Just "Migration table installation"
              , mTimestamp = Just ts
              }
    , applyMigration = \m -> do
        runRaw conn (cs $ mApply m)
        void $
          run
            conn
            ( cs $
                "INSERT INTO "
                  <> installedMigrations
                  <> " (migration_id) VALUES (?)"
            )
            [toSql $ mId m]
    , revertMigration = \m -> do
        case mRevert m of
          Nothing -> pure ()
          Just query -> runRaw conn (cs query)
        -- Remove migration from installed_migrations in either case.
        void $
          run
            conn
            ( cs $
                "DELETE FROM "
                  <> installedMigrations
                  <> " WHERE migration_id = ?"
            )
            [toSql $ mId m]
    , getMigrations = do
        results <-
          quickQuery' conn (cs $ "SELECT migration_id FROM " <> installedMigrations) []
        pure $ map (fromSql . head) results
    , commitBackend = commit conn
    , rollbackBackend = rollback conn
    , disconnectBackend = disconnect conn
    }

-- | For newtype deriving any HDBC-compatible connection
newtype HDBCConnection a = HDBCConnection a

instance IConnection a => BackendTest.BackendConnection (HDBCConnection a) where
  supportsTransactionalDDL = const True
  makeBackend (HDBCConnection c) = hdbcBackend c
  commit (HDBCConnection c) = commit c
  withTransaction (HDBCConnection c) transaction =
    withTransaction c (transaction . HDBCConnection)
  getTables (HDBCConnection c) = map cs <$> getTables c
  catchAll (HDBCConnection _) act handler = act `catch` \(_ :: SqlError) -> handler
