module FilesystemParseSpec
  ( spec
  )
where

import Prelude

import Common
import Data.String.Conversions (cs)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Database.Schema.Migrations.Filesystem
  ( FilesystemStoreSettings (..)
  , migrationFromFile
  )
import Database.Schema.Migrations.Migration
import System.FilePath ((</>))
import Test.Hspec

spec :: Spec
spec = do
  describe "migrationFromFile" $ do
    let
      testStorePath :: FilePath
      testStorePath = testFile "migration_parsing"

      fp :: FilePath -> FilePath
      fp = (testStorePath </>)

      migrationFromFile' :: Text -> IO (Either String Migration)
      migrationFromFile' =
        migrationFromFile (FSStore {storePath = testStorePath}) . cs

    it "fully valid" $ do
      migrationFromFile' "valid_full" `shouldReturn` Right validFull

    it "comments" $ do
      migrationFromFile' "valid_with_comments"
        `shouldReturn` Right (validFull {mId = "valid_with_comments"})

    it "comments (2)" $ do
      migrationFromFile' "valid_with_comments2"
        `shouldReturn` Right (validFullComments {mId = "valid_with_comments2"})

    it "colon" $ do
      migrationFromFile' "valid_with_colon"
        `shouldReturn` Right (validFullColon {mId = "valid_with_colon"})

    it "multi-line deps" $ do
      migrationFromFile' "valid_with_multiline_deps"
        `shouldReturn` Right
          ( validFull
              { mId = "valid_with_multiline_deps"
              , mDeps = ["one", "two", "three"]
              }
          )

    it "no deps" $ do
      migrationFromFile' "valid_no_depends"
        `shouldReturn` Right (validFull {mId = "valid_no_depends", mDeps = []})

    it "no description" $ do
      migrationFromFile' "valid_no_desc"
        `shouldReturn` Right (validFull {mId = "valid_no_desc", mDesc = Nothing})

    it "no revert" $ do
      migrationFromFile' "valid_no_revert"
        `shouldReturn` Right (validFull {mId = "valid_no_revert", mRevert = Nothing})

    it "no timestamp" $ do
      migrationFromFile' "valid_no_timestamp"
        `shouldReturn` Right (validFull {mId = "valid_no_timestamp", mTimestamp = Nothing})

    context "invalid" $ do
      it "missing required fields" $ do
        pendingWith "Aeson 2.x changes the message format"
        migrationFromFile' "invalid_missing_required_fields"
          `shouldReturn` Left
            ( "Could not parse migration "
                <> fp "invalid_missing_required_fields"
                <> ":Error in "
                <> show (fp "invalid_missing_required_fields")
                <> ": missing required field(s): "
                <> "[\"Depends\"]"
            )

      it "unrecognized field name" $ do
        pendingWith "Aeson 2.x changes the message format"
        migrationFromFile' "invalid_field_name"
          `shouldReturn` Left
            ( "Could not parse migration "
                <> fp "invalid_field_name"
                <> ":Error in "
                <> show (fp "invalid_field_name")
                <> ": unrecognized field found"
            )

      it "invalid syntax" $ do
        migrationFromFile' "invalid_syntax"
          `shouldReturn` Left
            ( "Could not parse migration "
                <> fp "invalid_syntax"
                <> ":InvalidYaml (Just (YamlParseException {yamlProblem = \"could not find expected ':'\", yamlContext = \"while scanning a simple key\", yamlProblemMark = YamlMark {yamlIndex = 130, yamlLine = 6, yamlColumn = 0}}))"
            )

      it "invalid timestamp" $ do
        pendingWith "Aeson 2.x changes the message format"
        migrationFromFile' "invalid_timestamp"
          `shouldReturn` Left
            ( "Could not parse migration "
                <> fp "invalid_timestamp"
                <> ":Error in "
                <> show (fp "invalid_timestamp")
                <> ": unrecognized field found"
            )

validFull :: Migration
validFull =
  Migration
    { mTimestamp = Just ts
    , mId = "valid_full"
    , mDesc = Just "A valid full migration."
    , mDeps = ["another_migration"]
    , mApply = "CREATE TABLE test ( a int );"
    , mRevert = Just "DROP TABLE test;"
    }

validFullComments :: Migration
validFullComments =
  Migration
    { mTimestamp = Just ts
    , mId = "valid_full"
    , mDesc = Just "A valid full migration."
    , mDeps = ["another_migration"]
    , mApply =
        "\n-- Comment on a line\nCREATE TABLE test (\n  a int -- comment inline\n);\n"
    , mRevert = Just "DROP TABLE test;"
    }

validFullColon :: Migration
validFullColon =
  Migration
    { mTimestamp = Just ts
    , mId = "valid_full"
    , mDesc = Just "A valid full migration."
    , mDeps = ["another_migration"]
    , mApply =
        "\n-- Comment on a line with a colon:\nCREATE TABLE test (\n  a int\n);\n"
    , mRevert = Just "DROP TABLE test;"
    }

ts :: UTCTime
ts = read tsStr

tsStr :: String
tsStr = "2009-04-15 10:02:06 UTC"
