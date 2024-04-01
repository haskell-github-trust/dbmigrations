module Database.Schema.Migrations.Backend.HDBC
  ( hdbcBackend
  , HDBCConnection (..)
  )
where

import Prelude

import Control.Exception (catch)
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

migrationTableName :: Text
migrationTableName = "installed_migrations"

createSql :: Text
createSql = "CREATE TABLE " <> migrationTableName <> " (migration_id TEXT)"

revertSql :: Text
revertSql = "DROP TABLE " <> migrationTableName

-- | General Backend constructor for all HDBC connection implementations.
hdbcBackend :: IConnection conn => conn -> Backend
hdbcBackend conn =
  Backend
    { isBootstrapped = elem (cs migrationTableName) <$> getTables conn
    , getBootstrapMigration =
        do
          ts <- getCurrentTime
          pure $
            (newMigration rootMigrationName)
              { mApply = createSql
              , mRevert = Just revertSql
              , mDesc = Just "Migration table installation"
              , mTimestamp = Just ts
              }
    , applyMigration = \m -> do
        runRaw conn (cs $ mApply m)
        _ <-
          run
            conn
            ( cs $
                "INSERT INTO "
                  <> migrationTableName
                  <> " (migration_id) VALUES (?)"
            )
            [toSql $ mId m]
        pure ()
    , revertMigration = \m -> do
        case mRevert m of
          Nothing -> pure ()
          Just query -> runRaw conn (cs query)
        -- Remove migration from installed_migrations in either case.
        _ <-
          run
            conn
            ( cs $
                "DELETE FROM "
                  <> migrationTableName
                  <> " WHERE migration_id = ?"
            )
            [toSql $ mId m]
        pure ()
    , getMigrations = do
        results <-
          quickQuery' conn (cs $ "SELECT migration_id FROM " <> migrationTableName) []
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
