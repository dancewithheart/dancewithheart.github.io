module Blog.PathsTest (tests) where

import Blog.Domain (Slug(..))
import Blog.Paths
import Data.Char (isSpace)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty
import Test.Tasty.Hedgehog (testProperty)

tests :: TestTree
tests =
  testGroup
    "Blog.Paths - Routing"
    [ testProperty "Slug normalization is stable after the first pass" prop_slug_idempotent
    , testProperty "Slugs never contain whitespace" prop_slug_no_spaces
    , testProperty "Every generated blog post path is an HTML page" prop_output_html
    , testProperty "Blog posts are published under the posts/ URL namespace" prop_route_prefix
    ]

prop_slug_idempotent :: Property
prop_slug_idempotent = property $ do
  s <- forAll genTitleLike
  normalizeTitleToSlug (unSlug (normalizeTitleToSlug s))
    === normalizeTitleToSlug s

prop_slug_no_spaces :: Property
prop_slug_no_spaces = property $ do
  s <- forAll genTitleLike
  let Slug slug = normalizeTitleToSlug s
  assert (all (not . isSpace) slug)

prop_output_html :: Property
prop_output_html = property $ do
  s <- forAll genTitleLike
  let path = slugToOutputPath (normalizeTitleToSlug s)
  assert (endsWith ".html" path)

prop_route_prefix :: Property
prop_route_prefix = property $ do
  s <- forAll genTitleLike
  let path = postRoutePath (s <> ".md")
  assert (startsWith "posts/" path)

genTitleLike :: Gen String
genTitleLike =
  Gen.string
    (Range.linear 1 60)
    (Gen.choice
      [ Gen.alphaNum
      , Gen.element " -_:/()[]"
      ])

startsWith :: String -> String -> Bool
startsWith prefix xs = take (length prefix) xs == prefix

endsWith :: String -> String -> Bool
endsWith suffix xs =
  drop (length xs - length suffix) xs == suffix
