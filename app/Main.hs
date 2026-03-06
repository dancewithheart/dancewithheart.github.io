{-# LANGUAGE OverloadedStrings #-}

import Hakyll

main :: IO ()
main = hakyll $ do
  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match "content/posts/*" $ do
    route $ setExtension "html"
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/post.html" postCtx
        >>= loadAndApplyTemplate "templates/default.html" postCtx
        >>= relativizeUrls

  match (fromList ["content/index.md", "content/about.md"]) $ do
    route $ gsubRoute "content/" (const "") `composeRoutes` setExtension "html"
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  create ["archive.html"] $ do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll "content/posts/*"
      let archiveCtx =
            listField "posts" postCtx (pure posts) <>
            constField "title" "Archive" <>
            defaultContext

      makeItem ("" :: String)
        >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
        >>= loadAndApplyTemplate "templates/default.html" archiveCtx
        >>= relativizeUrls

  match "templates/*" $
    compile templateBodyCompiler

postCtx :: Context String
postCtx =
  dateField "date" "%Y-%m-%d" <>
  defaultContext
