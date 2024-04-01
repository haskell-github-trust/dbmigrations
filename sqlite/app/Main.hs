module Main (main) where

import Prelude hiding (lookup)

import Database.HDBC.Sqlite3 (connectSqlite3)
import Database.Schema.Migrations.Backend.HDBC (hdbcBackend)
import Moo.Core
import Moo.Main
import System.Environment (getArgs)
import System.Exit

main :: IO ()
main = do
  args <- getArgs
  (_, opts, _) <- procArgs args
  loadedConf <- loadConfiguration $ _configFilePath opts
  case loadedConf of
    Left e -> putStrLn e >> exitFailure
    Right conf -> do
      let connectionString = _connectionString conf
      connection <- connectSqlite3 connectionString
      let
        backend = hdbcBackend connection
        parameters = makeParameters conf backend
      mainWithParameters args parameters
