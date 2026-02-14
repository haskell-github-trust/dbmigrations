{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

module ConfigurationSpec
  ( spec
  )
where

import Prelude

import Common
import DBM.Core
import Data.Either (isLeft, isRight)
import System.Directory
import System.Environment (setEnv, unsetEnv)
import Test.Hspec

spec :: Spec
spec = before_ prepareTestEnv $ do
  describe "loadConfiguration" $ do
    it "loads a file" $ do
      cfg <- loadConfiguration $ Just "cfg1.cfg"
      cfg `shouldSatisfy` isRight

    it "loads properties from a file" $ do
      Right cfg <- loadConfiguration $ Just "cfg1.cfg"

      _connectionString cfg `shouldBe` "connection"
      _migrationStorePath cfg `shouldBe` "store"
      _linearMigrations cfg `shouldBe` True

    it "loads default config file" $ do
      Right cfg <- loadConfiguration Nothing

      _connectionString cfg `shouldBe` "mooconn"
      _migrationStorePath cfg `shouldBe` "moostore"
      _linearMigrations cfg `shouldBe` True

    it "can be overriden via ENV" $ do
      setEnv "DBM_DATABASE" "envconn"
      setEnv "DBM_MIGRATION_STORE" "envstore"
      setEnv "DBM_LINEAR_MIGRATIONS" "off"
      Right cfg <- loadConfiguration $ Just "cfg1.cfg"

      _connectionString cfg `shouldBe` "envconn"
      _migrationStorePath cfg `shouldBe` "envstore"
      _linearMigrations cfg `shouldBe` False

    it "uses ENV if no config file is available" $ do
      setCurrentDirectory $ testFile ""
      setEnv "DBM_DATABASE" "envconn"
      setEnv "DBM_MIGRATION_STORE" "envstore"
      setEnv "DBM_LINEAR_MIGRATIONS" "off"
      Right cfg <- loadConfiguration Nothing

      _connectionString cfg `shouldBe` "envconn"
      _migrationStorePath cfg `shouldBe` "envstore"
      _linearMigrations cfg `shouldBe` False

    it "returns error when not all properties are set" $ do
      cfg <- loadConfiguration $ Just "missing.cfg"
      cfg `shouldSatisfy` isLeft

    it "throws when config is invalid" $ do
      loadConfiguration (Just "invalid.cfg") `shouldThrow` anyException

    it "can read timestamps config" $ do
      Right cfg <- loadConfiguration $ Just "cfg_ts.cfg"

      _timestampFilenames cfg `shouldBe` True

prepareTestEnv :: IO ()
prepareTestEnv = do
  setCurrentDirectory $ testFile "config_loading"
  unsetEnv "DBM_DATABASE"
  unsetEnv "DBM_MIGRATION_STORE"
  unsetEnv "DBM_LINEAR_MIGRATIONS"
  unsetEnv "DBM_TIMESTAMP_FILENAMES"
