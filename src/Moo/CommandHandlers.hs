{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

module Moo.CommandHandlers
  ( newCommand
  , upgradeCommand
  , upgradeListCommand
  , reinstallCommand
  , listCommand
  , applyCommand
  , revertCommand
  , testCommand
  )
where

import Prelude

import Control.Monad (forM_, unless, when)
import Control.Monad.Reader (asks)
import Control.Monad.Trans (liftIO)
import Data.Maybe (isJust)
import Data.String.Conversions (cs)
import Data.Time.Clock qualified as Clock
import Database.Schema.Migrations
import Database.Schema.Migrations.Backend
import Database.Schema.Migrations.Migration
import Database.Schema.Migrations.Store hiding (getMigrations)
import Moo.CommandUtils
import Moo.Core
import System.Exit (ExitCode (..), exitSuccess, exitWith)

newCommand :: CommandHandler
newCommand storeData = do
  required <- asks _appRequiredArgs
  store <- asks _appStore
  linear <- asks _appLinearMigrations
  timestamp <- asks _appTimestampFilenames
  timeString <- (<> "_") <$> liftIO getCurrentTimestamp

  let [migrationId] =
        if timestamp
          then fmap (timeString <>) required
          else required
  noAsk <- asks (_noAsk . _appOptions)

  liftIO $ do
    fullPath <- fullMigrationName store migrationId
    when (isJust $ storeLookup storeData migrationId) $
      do
        putStrLn $ "Migration " <> show fullPath <> " already exists"
        exitWith (ExitFailure 1)

    -- Default behavior: ask for dependencies if linear mode is disabled
    deps <-
      if linear
        then pure $ leafMigrations storeData
        else
          if noAsk
            then pure []
            else do
              putStrLn . cs $
                "Selecting dependencies for new \
                \migration: "
                  <> migrationId
              interactiveAskDeps storeData

    result <-
      if noAsk
        then pure True
        else confirmCreation migrationId deps

    ( if result
        then
          ( do
              now <- Clock.getCurrentTime
              status <-
                createNewMigration store $
                  (newMigration migrationId)
                    { mDeps = deps
                    , mTimestamp = Just now
                    }
              case status of
                Left e -> putStrLn e >> exitWith (ExitFailure 1)
                Right _ ->
                  putStrLn $
                    "Migration created successfully: "
                      <> show fullPath
          )
        else
          ( do
              putStrLn "Migration creation cancelled."
          )
      )

upgradeCommand :: CommandHandler
upgradeCommand storeData = do
  isTesting <- asks (_test . _appOptions)
  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    migrationNames <- missingMigrations backend storeData
    when (null migrationNames) $ do
      putStrLn "Database is up to date."
      exitSuccess
    forM_ migrationNames $ \migrationName -> do
      m <- lookupMigration storeData migrationName
      apply m storeData backend False
    ( if isTesting
        then
          ( do
              rollbackBackend backend
              putStrLn "Upgrade test successful."
          )
        else
          ( do
              commitBackend backend
              putStrLn "Database successfully upgraded."
          )
      )

upgradeListCommand :: CommandHandler
upgradeListCommand storeData = do
  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    migrationNames <- missingMigrations backend storeData
    when (null migrationNames) $ do
      putStrLn "Database is up to date."
      exitSuccess
    putStrLn "Migrations to install:"
    forM_ migrationNames (putStrLn . cs . ("  " <>))

reinstallCommand :: CommandHandler
reinstallCommand storeData = do
  isTesting <- asks (_test . _appOptions)
  required <- asks _appRequiredArgs
  let [migrationId] = required

  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    m <- lookupMigration storeData migrationId

    _ <- revert m storeData backend
    _ <- apply m storeData backend True

    ( if isTesting
        then
          ( do
              rollbackBackend backend
              putStrLn "Reinstall test successful."
          )
        else
          ( do
              commitBackend backend
              putStrLn "Migration successfully reinstalled."
          )
      )

listCommand :: CommandHandler
listCommand _ = do
  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    ms <- getMigrations backend
    forM_ ms $ \m ->
      unless (m == rootMigrationName) $ putStrLn . cs $ m

applyCommand :: CommandHandler
applyCommand storeData = do
  isTesting <- asks (_test . _appOptions)
  required <- asks _appRequiredArgs
  let [migrationId] = required

  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    m <- lookupMigration storeData migrationId
    _ <- apply m storeData backend True
    ( if isTesting
        then
          ( do
              rollbackBackend backend
              putStrLn "Migration installation test successful."
          )
        else
          ( do
              commitBackend backend
              putStrLn "Successfully applied migrations."
          )
      )

revertCommand :: CommandHandler
revertCommand storeData = do
  isTesting <- asks (_test . _appOptions)
  required <- asks _appRequiredArgs
  let [migrationId] = required

  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    m <- lookupMigration storeData migrationId
    _ <- revert m storeData backend

    ( if isTesting
        then
          ( do
              rollbackBackend backend
              putStrLn "Migration uninstallation test successful."
          )
        else
          ( do
              commitBackend backend
              putStrLn "Successfully reverted migrations."
          )
      )

testCommand :: CommandHandler
testCommand storeData = do
  required <- asks _appRequiredArgs
  let [migrationId] = required

  withBackend $ \backend -> do
    ensureBootstrappedBackend backend >> commitBackend backend
    m <- lookupMigration storeData migrationId
    migrationNames <- missingMigrations backend storeData
    -- If the migration is already installed, remove it as part of
    -- the test
    unless (migrationId `elem` migrationNames) $
      do
        _ <- revert m storeData backend
        pure ()
    applied <- apply m storeData backend True
    forM_ (reverse applied) $ \migration -> do
      revert migration storeData backend
    rollbackBackend backend
    putStrLn "Successfully tested migrations."
