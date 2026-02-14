{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

module LinearMigrationsSpec
  ( spec
  )
where

import Prelude

import Control.Monad.Reader (runReaderT)
import DBM.CommandHandlers
import DBM.Core
import Data.Either (isRight)
import Data.Text (Text)
import Database.Schema.Migrations.Migration
import Database.Schema.Migrations.Store
import InMemoryStore
import Test.Hspec

spec :: Spec
spec = do
  describe "linear migrations" $ do
    it "addsMigration" $ do
      state <- prepareState "first"
      mig <- addTestMigration state

      mig `shouldSatisfy` isRight

    it "selectsLatestMigrationAsDep" $ do
      state1 <- prepareState "first"
      _ <- addTestMigration state1
      state2 <- prepareStateWith state1 "second"
      Right mig <- addTestMigration state2

      mDeps mig `shouldBe` ["first"]

    it "selectsOnlyLeavesAsDeps" $ do
      state1 <- prepareNormalState "first"
      addTestMigrationWithDeps state1 []
      state2 <- prepareStateWith state1 "second"
      addTestMigrationWithDeps state2 ["first"]
      state3 <- prepareStateWith state2 "third"
      addTestMigrationWithDeps state3 ["first"]
      state4' <- prepareStateWith state3 "fourth"
      let state4 = state4' {_appLinearMigrations = True}
      Right mig <- addTestMigration state4

      mDeps mig `shouldBe` ["second", "third"]

    it "doesNotAddDependencyWhenLinearMigrationsAreDisabled" $ do
      state1 <- prepareNormalState "first"
      _ <- addTestMigration state1
      state2 <- prepareStateWith state1 "second"
      Right mig <- addTestMigration state2

      mDeps mig `shouldSatisfy` null

addTestMigration :: AppState -> IO (Either String Migration)
addTestMigration state = do
  let
    store = _appStore state
    [migrationId] = _appRequiredArgs state
  runReaderT (newCommand $ _appStoreData state) state
  loadMigration store migrationId

addTestMigrationWithDeps :: AppState -> [Text] -> IO ()
addTestMigrationWithDeps state deps = do
  let store = _appStore state
  let [migrationId] = _appRequiredArgs state
  saveMigration store (newMigration migrationId) {mDeps = deps}

prepareState :: Text -> IO AppState
prepareState m = do
  store <- inMemoryStore
  Right storeData <- loadMigrations store
  pure
    AppState
      { _appOptions = CommandOptions Nothing False True
      , _appBackend = undefined -- Not used here
      , _appCommand = undefined -- Not used by newCommand
      , _appRequiredArgs = [m]
      , _appOptionalArgs = []
      , _appStore = store
      , _appStoreData = storeData
      , _appLinearMigrations = True
      , _appTimestampFilenames = False
      }

prepareStateWith :: AppState -> Text -> IO AppState
prepareStateWith state m = do
  Right storeData <- loadMigrations $ _appStore state
  pure state {_appRequiredArgs = [m], _appStoreData = storeData}

prepareNormalState :: Text -> IO AppState
prepareNormalState m = do
  state <- prepareState m
  pure $ state {_appLinearMigrations = False}
