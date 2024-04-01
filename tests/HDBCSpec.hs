{-# LANGUAGE DerivingVia #-}
{-# OPTIONS_GHC -Wno-orphans #-}

-- | Use SQlite3 as an example to test the supplied 'hdbcBackend'
module HDBCSpec
  ( spec
  )
where

import Prelude

import Database.HDBC (IConnection (disconnect))
import Database.HDBC.Sqlite3 (Connection, connectSqlite3)
import Database.Schema.Migrations.Backend.HDBC
import Database.Schema.Migrations.Test.BackendTest hiding (spec)
import Database.Schema.Migrations.Test.BackendTest qualified as BackendTest
import Test.Hspec

deriving via (HDBCConnection Connection) instance BackendConnection Connection

spec :: Spec
spec = before (connectSqlite3 ":memory:") $ after disconnect BackendTest.spec
