module Database.Schema.Migrations.Migration
  ( Migration (..)
  , newMigration
  , emptyMigration
  )
where

import Prelude

import Data.Text (Text)
import Data.Time ()
import Data.Time.Clock qualified as Clock
import Database.Schema.Migrations.Dependencies

data Migration = Migration
  { mTimestamp :: Maybe Clock.UTCTime
  , mId :: Text
  , mDesc :: Maybe Text
  , mApply :: Text
  , mRevert :: Maybe Text
  , mDeps :: [Text]
  }
  deriving stock (Eq, Show, Ord)

instance Dependable Migration where
  depsOf = mDeps
  depId = mId

emptyMigration :: Text -> Migration
emptyMigration name =
  Migration
    { mTimestamp = Nothing
    , mId = name
    , mApply = ""
    , mRevert = Nothing
    , mDesc = Nothing
    , mDeps = []
    }

newMigration :: Text -> Migration
newMigration theId =
  (emptyMigration theId)
    { mApply = "(Apply SQL here.)"
    , mDesc = Just "(Describe migration here.)"
    }
