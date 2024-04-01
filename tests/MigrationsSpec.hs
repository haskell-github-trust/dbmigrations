{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

module MigrationsSpec
  ( spec
  )
where

import Prelude

import Data.Foldable (for_)
import Data.Map qualified as Map
import Data.Time.Clock (UTCTime)
import Database.Schema.Migrations
import Database.Schema.Migrations.Backend
import Database.Schema.Migrations.Migration
import Database.Schema.Migrations.Store hiding (getMigrations)
import Test.Hspec

spec :: Spec
spec = do
  describe "migrationsToApply" $ do
    for_ missingMigrationsTestcases $ \(mapping, backend, mig, expected) -> do
      let
        Right graph = depGraphFromMapping mapping
        storeData = StoreData mapping graph
        withDeps = case mDeps mig of
          [] -> ""
          ds -> " with deps " <> show ds

      it ("migration " <> show (mId mig) <> withDeps) $ do
        migrationsToApply storeData backend mig `shouldReturn` expected

testBackend :: [Migration] -> Backend
testBackend testMs =
  Backend
    { getBootstrapMigration = undefined
    , isBootstrapped = pure True
    , applyMigration = const undefined
    , revertMigration = const undefined
    , getMigrations = pure $ mId <$> testMs
    , commitBackend = pure ()
    , rollbackBackend = pure ()
    , disconnectBackend = pure ()
    }

-- | Given a backend and a store, what are the list of migrations
--  missing in the backend that are available in the store?
type MissingMigrationTestCase =
  ( MigrationMap
  , Backend
  , Migration
  , [Migration]
  )

ts :: UTCTime
ts = read "2009-04-15 10:02:06 UTC"

blankMigration :: Migration
blankMigration =
  Migration
    { mTimestamp = Just ts
    , mId = undefined
    , mDesc = Nothing
    , mApply = ""
    , mRevert = Nothing
    , mDeps = []
    }

missingMigrationsTestcases :: [MissingMigrationTestCase]
missingMigrationsTestcases =
  [ (m, testBackend [], one, [one])
  , (m, testBackend [one], one, [])
  , (m, testBackend [one], two, [two])
  , (m, testBackend [one, two], one, [])
  , (m, testBackend [one, two], two, [])
  ]
 where
  one = blankMigration {mId = "one"}
  two = blankMigration {mId = "two", mDeps = ["one"]}
  m = Map.fromList [(mId e, e) | e <- [one, two]]
