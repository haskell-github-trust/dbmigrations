module Main (main) where

import Prelude

import Database.HDBC.PostgreSQL (connectPostgreSQL)
import Moo.Main

main :: IO ()
main = hdbcMain connectPostgreSQL
