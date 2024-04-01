{-# LANGUAGE DerivingVia #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import Prelude

import Data.Maybe (fromMaybe)
import Database.HDBC (IConnection (disconnect))
import Database.HDBC.PostgreSQL (Connection, connectPostgreSQL)
import Database.Schema.Migrations.Backend.HDBC
import Database.Schema.Migrations.Test.BackendTest hiding (spec)
import Database.Schema.Migrations.Test.BackendTest qualified as BackendTest
import System.Environment (lookupEnv)
import Test.Hspec

deriving via (HDBCConnection Connection) instance BackendConnection Connection

main :: IO ()
main = hspec $ before setupPostgreSQL $ after disconnect BackendTest.spec

setupPostgreSQL :: IO Connection
setupPostgreSQL = do
  url <- fromMaybe defaultDatabaseURL <$> lookupEnv "DATABASE_URL"
  conn <- connectPostgreSQL url
  conn <$ dropTables conn

defaultDatabaseURL :: String
defaultDatabaseURL = "postgres://postgres:password@localhost:5432"
