module CommonTH
  ( getRepoRoot
  )
where

import Prelude

import Language.Haskell.TH
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.FilePath (combine, takeDirectory)

getRepoRoot :: Q FilePath
getRepoRoot =
  do
    here <- location
    cwd <- runIO getCurrentDirectory
    let thisFileName = combine cwd $ loc_filename here
    -- XXX: This depends on the location of this file in the source tree
    runIO $
      canonicalizePath (iterate takeDirectory thisFileName !! 2)
