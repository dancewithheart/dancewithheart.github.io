module Main where

import Test.Tasty
import qualified Blog.PathsTest
import qualified Blog.ValidationTest
import qualified Blog.RenderingTest

main :: IO ()
main =
  defaultMain $
    testGroup
      "blog"
      [ Blog.PathsTest.tests
      , Blog.ValidationTest.tests
      , Blog.RenderingTest.tests
      ]
