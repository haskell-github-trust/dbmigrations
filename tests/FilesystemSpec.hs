module FilesystemSpec
  ( spec
  )
where

import Prelude

import Common
import Database.Schema.Migrations.Filesystem
import Database.Schema.Migrations.Store (MigrationStore (..))
import Test.Hspec

spec :: Spec
spec = do
  describe "getMigrations" $ do
    it "gets all migrations in the store" $ do
      let store =
            filesystemStore $
              FSStore {storePath = testFile "migration_parsing"}

      migrations <- getMigrations store
      migrations
        `shouldMatchList` [ "invalid_field_name"
                          , "invalid_missing_required_fields"
                          , "invalid_syntax"
                          , "invalid_timestamp"
                          , "valid_full"
                          , "valid_no_depends"
                          , "valid_no_desc"
                          , "valid_no_revert"
                          , "valid_no_timestamp"
                          , "valid_with_comments"
                          , "valid_with_comments2"
                          , "valid_with_colon"
                          , "valid_with_multiline_deps"
                          ]
