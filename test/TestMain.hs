module Main where

import Test.Tasty
import qualified Blog.PathsTest
import qualified Blog.ValidationTest

main :: IO ()
main =
  defaultMain $
    testGroup
      "blog"
      [ Blog.PathsTest.tests
      , Blog.ValidationTest.tests
      ]
