module Main (main) where

import Prelude

import DBM.Main
import Database.HDBC.Sqlite3 (connectSqlite3)

main :: IO ()
main = hdbcMain connectSqlite3
