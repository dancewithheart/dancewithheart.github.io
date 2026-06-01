{-# LANGUAGE OverloadedStrings #-}

module Main where

import Blog.Paths (postRoutePath)
import Hakyll (
    Compiler
  , Context
  , Item
  , Rules
  , copyFileCompiler
  , defaultContext
  , dateField
  , defaultHakyllReaderOptions
  , defaultHakyllWriterOptions
  , pandocCompilerWith
  , relativizeUrls
  , loadAndApplyTemplate
  , constField
  , recentFirst
  , loadAll
  , listField
  , makeItem
  , route
  , create
  , idRoute
  , compile
  , setExtension
  , gsubRoute
  , customRoute
  , match
  , fromList
  , compressCssCompiler
  , templateBodyCompiler
  , hakyll
  , composeRoutes
  , toFilePath
  )
import Text.Pandoc.Highlighting (pygments)
import Text.Pandoc.Options
  ( HighlightMethod (Skylighting)
  , WriterOptions (..)
  )
import System.FilePath ()

main :: IO ()
main = hakyll $ do
  rulesCss
  rulesImages
  rulesPosts
  rulesPages
  rulesArchive
  match "templates/*" $ compile templateBodyCompiler

blogPandocCompiler :: Compiler (Item String)
blogPandocCompiler =
  pandocCompilerWith
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions
      { writerHighlightMethod = Skylighting pygments
      }

rulesImages :: Rules ()
rulesImages =
  match "content/img/**" $ do
    route $ gsubRoute "content/" (const "")
    compile copyFileCompiler

rulesCss :: Rules ()
rulesCss =
  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

rulesPosts :: Rules ()
rulesPosts =
  match "content/posts/*" $ do
    route $ customRoute (postRoutePath . toFilePath)
    compile $
      blogPandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" postCtx
        >>= loadAndApplyTemplate "templates/default.html" postCtx
        >>= relativizeUrls

rulesPages :: Rules ()
rulesPages =
  match (fromList ["content/index.md", "content/about.md"]) $ do
    route $ gsubRoute "content/" (const "") `composeRoutes` setExtension "html"
    compile $
      blogPandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

rulesArchive :: Rules ()
rulesArchive =
  create ["archive.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "content/posts/*"
      let archiveCtx =
            listField "posts" postCtx (pure posts)
              <> constField "title" "Archive"
              <> defaultContext

      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
        >>= loadAndApplyTemplate "templates/default.html" archiveCtx
        >>= relativizeUrls

postCtx :: Context String
postCtx =
  dateField "date" "%Y-%m-%d"
    <> constField "github" "https://github.com/dancewithheart"
    <> defaultContext
