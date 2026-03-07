module Blog.ValidationTest (tests) where

import Blog.Validation
import Data.List.NonEmpty (NonEmpty(..))
import Data.Time (Day, fromGregorian)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty
import Test.Tasty.Hedgehog (testProperty)
import qualified Test.Tasty.HUnit as HU

tests :: TestTree
tests =
  testGroup
    "Blog.Validation"
    [ testProperty "validatePostMeta succeeds on sensible metadata" prop_validate_success
    , testProperty "validatePostMeta rejects future dates" prop_validate_future_date
    , HU.testCase "validatePostMeta accumulates title and slug errors" unit_accumulates_errors
    ]

prop_validate_success :: Property
prop_validate_success = property $ do
  title <- forAll nonBlank
  slug  <- forAll nonBlank
  let today = fromGregorian 2026 3 6
      raw =
        RawPostMeta
          { rawTitle = title
          , rawSlug  = slug
          , rawDate  = fromGregorian 2026 3 1
          , rawTags  = ["haskell", "blog"]
          }
  case validatePostMeta today raw of
    Failure err -> do
      annotateShow err
      failure
    Success _ ->
      success

prop_validate_future_date :: Property
prop_validate_future_date = property $ do
  title <- forAll nonBlank
  slug  <- forAll nonBlank
  let today = fromGregorian 2026 3 6
      future = fromGregorian 2026 3 7
      raw =
        RawPostMeta
          { rawTitle = title
          , rawSlug  = slug
          , rawDate  = future
          , rawTags  = []
          }
  case validatePostMeta today raw of
    Failure errs -> assert (FutureDate future `elemNE` errs)
    Success ok -> do
      annotateShow ok
      failure

unit_accumulates_errors :: HU.Assertion
unit_accumulates_errors = do
  let today = fromGregorian 2026 3 6
      raw =
        RawPostMeta
          { rawTitle = "   "
          , rawSlug  = "   "
          , rawDate  = fromGregorian 2026 3 1
          , rawTags  = []
          }

  case validatePostMeta today raw of
    Failure errs -> do
      HU.assertBool "contains EmptyTitle" (EmptyTitle `elemNE` errs)
      HU.assertBool "contains EmptySlug"  (EmptySlug  `elemNE` errs)
    Success _ ->
      HU.assertFailure "expected validation failure"

nonBlank :: Gen String
nonBlank =
  Gen.string
    (Range.linear 1 30)
    Gen.alphaNum

elemNE :: Eq a => a -> NonEmpty a -> Bool
elemNE x (y :| ys) = x == y || x `elem` ys
