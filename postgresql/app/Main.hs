module Main (main) where

import Prelude

import DBM.Main
import Database.HDBC.PostgreSQL (connectPostgreSQL)

main :: IO ()
main = hdbcMain connectPostgreSQL
