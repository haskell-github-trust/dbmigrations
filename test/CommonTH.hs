module CommonTH
  ( getRepoRoot
  )
where

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
    return =<< runIO $
      canonicalizePath $
        head $
          drop 2 $
            iterate takeDirectory thisFileName
