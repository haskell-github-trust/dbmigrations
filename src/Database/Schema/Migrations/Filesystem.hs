-- | This module provides a type for interacting with a
--  filesystem-backed 'MigrationStore'.
module Database.Schema.Migrations.Filesystem
  ( FilesystemStoreSettings (..)
  , migrationFromFile
  , migrationFromPath
  , filesystemStore
  )
where

import Prelude

import Control.Exception (Exception (..), catch, throw)
import Control.Monad (filterM, msum)
import Data.Aeson
import Data.Aeson.Types (typeMismatch)
import Data.ByteString.Char8 qualified as BSC
import Data.String.Conversions (cs)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (defaultTimeLocale, formatTime, parseTimeM)
import Data.Time.Clock (UTCTime)
import Data.Yaml qualified as Yaml
import Database.Schema.Migrations.Filesystem.Serialize
import Database.Schema.Migrations.Migration (Migration (..))
import Database.Schema.Migrations.Store
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getDirectoryContents)
import System.FilePath (dropExtension, takeBaseName, takeExtension, (</>))

newtype FilesystemStoreSettings = FSStore
  { storePath :: FilePath
  }

newtype FilesystemStoreError = FilesystemStoreError String
  deriving stock (Show)
  deriving anyclass (Exception)

throwFS :: String -> a
throwFS = throw . FilesystemStoreError

filenameExtension :: String
filenameExtension = ".yml"

filenameExtensionTxt :: String
filenameExtensionTxt = ".txt"

filesystemStore :: FilesystemStoreSettings -> MigrationStore
filesystemStore s =
  MigrationStore
    { fullMigrationName = fmap addNewMigrationExtension . fsFullMigrationName s
    , loadMigration = migrationFromFile s
    , getMigrations = do
        contents <- getDirectoryContents $ storePath s
        let
          migrationFilenames = [f | f <- contents, isMigrationFilename f]
          fullPaths = [(f, storePath s </> f) | f <- migrationFilenames]
        existing <- filterM (\(_, full) -> doesFileExist full) fullPaths
        pure [cs $ dropExtension short | (short, _) <- existing]
    , saveMigration = \m -> do
        filename <- fsFullMigrationName s $ mId m
        BSC.writeFile (cs $ addNewMigrationExtension filename) $ serializeMigration m
    }

addNewMigrationExtension :: FilePath -> FilePath
addNewMigrationExtension path = path <> filenameExtension

addMigrationExtension :: FilePath -> String -> FilePath
addMigrationExtension path ext = path <> ext

-- | Build path to migrations without extension.
fsFullMigrationName :: FilesystemStoreSettings -> Text -> IO FilePath
fsFullMigrationName s name = pure $ storePath s </> cs name

isMigrationFilename :: String -> Bool
isMigrationFilename path = cs (takeExtension path) `elem` [filenameExtension, filenameExtensionTxt]

-- | Given a store and migration name, read and parse the associated
--  migration and return the migration if successful.  Otherwise return
--  a parsing error message.
migrationFromFile
  :: FilesystemStoreSettings -> Text -> IO (Either String Migration)
migrationFromFile store name =
  fsFullMigrationName store (cs name) >>= migrationFromPath

-- | Given a filesystem path, read and parse the file as a migration
--  pure the 'Migration' if successful.  Otherwise pure a parsing
--  error message.
migrationFromPath :: FilePath -> IO (Either String Migration)
migrationFromPath path = do
  let name = cs $ takeBaseName path
  (Right <$> process name)
    `catch` ( \(FilesystemStoreError s) -> pure $ Left $ "Could not parse migration " <> path <> ":" <> s
            )
 where
  readMigrationFile = do
    ymlExists <- doesFileExist (addNewMigrationExtension path)
    if ymlExists
      then
        Yaml.decodeFileThrow (addNewMigrationExtension path)
          `catch` (\(e :: Yaml.ParseException) -> throwFS $ show e)
      else
        Yaml.decodeFileThrow (addMigrationExtension path filenameExtensionTxt)
          `catch` (\(e :: Yaml.ParseException) -> throwFS $ show e)

  process name = migrationYamlToMigration name <$> readMigrationFile

-- | TODO: re-use this for the generation side too
data MigrationYaml = MigrationYaml
  { myCreated :: Maybe UTCTimeYaml
  , myDescription :: Maybe Text
  , myApply :: Text
  , myRevert :: Maybe Text
  , myDepends :: DependsYaml
  }
  deriving stock (Generic)

instance FromJSON MigrationYaml where
  parseJSON = genericParseJSON jsonOptions

instance ToJSON MigrationYaml where
  toJSON = genericToJSON jsonOptions
  toEncoding = genericToEncoding jsonOptions

jsonOptions :: Options
jsonOptions =
  defaultOptions
    { fieldLabelModifier = drop 2 -- remove "my" prefix
    , omitNothingFields = True
    , rejectUnknownFields = True
    }

migrationYamlToMigration :: Text -> MigrationYaml -> Migration
migrationYamlToMigration theId my =
  Migration
    { mTimestamp = unUTCTimeYaml <$> myCreated my
    , mId = theId
    , mDesc = myDescription my
    , mApply = myApply my
    , mRevert = myRevert my
    , mDeps = unDependsYaml $ myDepends my
    }

newtype UTCTimeYaml = UTCTimeYaml
  { unUTCTimeYaml :: UTCTime
  }

instance FromJSON UTCTimeYaml where
  parseJSON =
    withText "UTCTime" $ \t ->
      let s = cs t
      in  case msum [parseTimeM True defaultTimeLocale fmt s | fmt <- utcTimeParseFormats] of
            Nothing -> fail "Unable to parse UTCTime"
            Just utc -> pure $ UTCTimeYaml utc

instance ToJSON UTCTimeYaml where
  toJSON = toJSON . formatTime defaultTimeLocale utcTimeWriteFormat . unUTCTimeYaml
  toEncoding = toEncoding . formatTime defaultTimeLocale utcTimeWriteFormat . unUTCTimeYaml

-- | Canonical output format: the old Show/Read-based format,
-- e.g "2009-04-15 10:02:06.123456 UTC"
utcTimeWriteFormat :: String
utcTimeWriteFormat = "%F %T%Q UTC"

-- | Accepted input formats, tried in order. Lenient parsing accepts
-- timestamps with or without fractional seconds.
utcTimeParseFormats :: [String]
utcTimeParseFormats =
  [ "%F %T%Q UTC" -- "2009-04-15 10:02:06.123456 UTC" (with fractional seconds)
  , "%F %T UTC" -- "2009-04-15 10:02:06 UTC" (without fractional seconds)
  ]

newtype DependsYaml = DependsYaml
  { unDependsYaml :: [Text]
  }

instance FromJSON DependsYaml where
  parseJSON = \case
    Null -> pure $ DependsYaml []
    String t -> pure $ DependsYaml $ T.words t
    x -> typeMismatch "Null or whitespace-separated String" x

instance ToJSON DependsYaml where
  toJSON (DependsYaml ts) = case ts of
    [] -> toJSON Null
    _ -> toJSON $ T.unwords ts
  toEncoding (DependsYaml ts) = case ts of
    [] -> toEncoding Null
    _ -> toEncoding $ T.unwords ts
