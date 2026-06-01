module Blog.Site
  ( pageSources
  , archiveTitle
  , githubUrl
  , pageRoutePath
  ) where

pageSources :: [FilePath]
pageSources =
  [ "content/index.md"
  , "content/about.md"
  ]

archiveTitle :: String
archiveTitle = "Archive"

githubUrl :: String
githubUrl = "https://github.com/dancewithheart"

pageRoutePath :: FilePath -> FilePath
pageRoutePath path = ...
