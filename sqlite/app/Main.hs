module Main (main) where

import Prelude

import Database.HDBC.Sqlite3 (connectSqlite3)
import Moo.Main

main :: IO ()
main = hdbcMain connectSqlite3
