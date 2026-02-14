{-# LANGUAGE TemplateHaskell #-}

module Common
  ( TestDependable (..)
  , testFile
  )
where

import Prelude

import CommonTH
import Data.Text (Text)
import Database.Schema.Migrations.Dependencies (Dependable (..))
import Language.Haskell.TH.Syntax (lift)
import System.FilePath ((</>))

repoRoot :: FilePath
repoRoot = $(getRepoRoot >>= lift)

testFile :: FilePath -> FilePath
testFile fp = repoRoot </> "tests" </> fp

instance Dependable TestDependable where
  depId = tdId
  depsOf = tdDeps

data TestDependable = TD
  { tdId :: Text
  , tdDeps :: [Text]
  }
  deriving stock (Show, Eq, Ord)
