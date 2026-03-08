module Blog.Paths
  ( normalizeTitleToSlug
  , slugToOutputPath
  , postRoutePath
  ) where

import Blog.Domain (Slug(..))
import Data.Char (isAlphaNum, toLower)
import System.FilePath (takeBaseName, (<.>), (</>))

normalizeTitleToSlug :: String -> Slug
normalizeTitleToSlug =
  Slug
    . trimDashes
    . collapseDashes
    . map normalizeChar
  where
    normalizeChar :: Char -> Char
    normalizeChar c
      | isAlphaNum c = toLower c
      | otherwise    = '-'

    collapseDashes :: String -> String
    collapseDashes = go False
      where
        go _ [] = []
        go prevDash (x:xs)
          | x == '-' && prevDash = go True xs
          | x == '-'             = x : go True xs
          | otherwise            = x : go False xs

    trimDashes :: String -> String
    trimDashes = reverse . dropWhile (== '-') . reverse . dropWhile (== '-')

slugToOutputPath :: Slug -> FilePath
slugToOutputPath (Slug slug) = "posts" </> slug <.> "html"

postRoutePath :: FilePath -> FilePath
postRoutePath = slugToOutputPath . normalizeTitleToSlug . takeBaseName
