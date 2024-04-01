{-# LANGUAGE DerivingVia #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Main (main) where

import Prelude

import Database.HDBC (IConnection (disconnect))
import Database.HDBC.Sqlite3 (Connection, connectSqlite3)
import Database.Schema.Migrations.Backend.HDBC
import Database.Schema.Migrations.Test.BackendTest hiding (spec)
import Database.Schema.Migrations.Test.BackendTest qualified as BackendTest
import Test.Hspec

deriving via (HDBCConnection Connection) instance BackendConnection Connection

main :: IO ()
main =
  hspec
    . before (connectSqlite3 ":memory:")
    $ after disconnect BackendTest.spec
