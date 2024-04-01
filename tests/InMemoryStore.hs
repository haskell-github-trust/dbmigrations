module InMemoryStore (inMemoryStore) where

import Prelude

import Control.Concurrent.MVar
import Data.String.Conversions (cs)
import Data.Text (Text)
import Database.Schema.Migrations.Migration
import Database.Schema.Migrations.Store

type InMemoryData = [(Text, Migration)]

-- | Builds simple in-memory store that uses 'MVar' to preserve a list of
--  migrations.
inMemoryStore :: IO MigrationStore
inMemoryStore = do
  store <- newMVar []
  pure
    MigrationStore
      { loadMigration = loadMigrationInMem store
      , saveMigration = saveMigrationInMem store
      , getMigrations = getMigrationsInMem store
      , fullMigrationName = pure . cs
      }

loadMigrationInMem :: MVar InMemoryData -> Text -> IO (Either String Migration)
loadMigrationInMem store migId = withMVar store $ \migrations -> do
  let mig = lookup migId migrations
  pure $ case mig of
    Just m -> Right m
    _ -> Left "Migration not found"

saveMigrationInMem :: MVar InMemoryData -> Migration -> IO ()
saveMigrationInMem store m = modifyMVar_ store $ pure . ((mId m, m) :)

getMigrationsInMem :: MVar InMemoryData -> IO [Text]
getMigrationsInMem store = withMVar store $ pure . fmap fst
