module FilesystemSerializeSpec
  ( spec
  )
where

import Prelude

import Data.String.Conversions (cs)
import Data.Time.Clock (UTCTime)
import Database.Schema.Migrations.Filesystem.Serialize
import Database.Schema.Migrations.Migration
import Test.Hspec

spec :: Spec
spec = do
  describe "serializeMigration" $ do
    it "handles fully valid" $ do
      serializeMigration validFull
        `shouldBe` cs
          ( "Description: A valid full migration.\nCreated: "
              <> tsStr
              <> "\n\
                 \Depends: another_migration\n\
                 \Apply: |\n\
                 \  CREATE TABLE test (\n\
                 \    a int\n\
                 \  );\n\n\
                 \Revert: |\n\
                 \  DROP TABLE test;\n"
          )

    it "handles no description" $ do
      serializeMigration (validFull {mDesc = Nothing})
        `shouldBe` cs
          ( "Created: "
              <> tsStr
              <> "\n\
                 \Depends: another_migration\n\
                 \Apply: |\n\
                 \  CREATE TABLE test (\n\
                 \    a int\n\
                 \  );\n\n\
                 \Revert: |\n\
                 \  DROP TABLE test;\n"
          )

    it "handles no deps" $ do
      serializeMigration (validFull {mDeps = ["one", "two"]})
        `shouldBe` cs
          ( "Description: A valid full migration.\nCreated: "
              <> tsStr
              <> "\n\
                 \Depends: one two\n\
                 \Apply: |\n\
                 \  CREATE TABLE test (\n\
                 \    a int\n\
                 \  );\n\n\
                 \Revert: |\n\
                 \  DROP TABLE test;\n"
          )

    it "handles no revert" $ do
      serializeMigration (validFull {mRevert = Nothing})
        `shouldBe` cs
          ( "Description: A valid full migration.\nCreated: "
              <> tsStr
              <> "\n\
                 \Depends: another_migration\n\
                 \Apply: |\n\
                 \  CREATE TABLE test (\n\
                 \    a int\n\
                 \  );\n"
          )

validFull :: Migration
validFull =
  Migration
    { mTimestamp = Just ts
    , mId = "valid_full"
    , mDesc = Just "A valid full migration."
    , mDeps = ["another_migration"]
    , mApply = "  CREATE TABLE test (\n    a int\n  );\n"
    , mRevert = Just "DROP TABLE test;"
    }

ts :: UTCTime
ts = read tsStr

tsStr :: String
tsStr = "2009-04-15 10:02:06 UTC"
