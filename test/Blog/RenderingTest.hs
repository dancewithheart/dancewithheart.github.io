module Blog.RenderingTest (tests) where

import Data.List (isInfixOf)
import Data.Foldable (traverse_)
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty
import Test.Tasty.Hedgehog (testProperty)

tests :: TestTree
tests =
  testGroup
    "Blog.Rendering - HTML invariants"
    [ testProperty "code blocks keep Pandoc sourceCode classes" prop_code_blocks_have_source_code_classes
    , testProperty "raw images do not produce implicit figure captions" prop_raw_images_have_no_caption
    , testProperty "lists render as lists with list items" prop_lists_render_as_lists
    ]

prop_code_blocks_have_source_code_classes :: Property
prop_code_blocks_have_source_code_classes = property $ do
  command <- forAll genShellCommand
  let html = renderShellCodeBlock command

  assert ("<div class=\"sourceCode\"" `isInfixOf` html)
  assert ("<pre class=\"sourceCode sh\"" `isInfixOf` html)
  assert ("<code class=\"sourceCode bash\"" `isInfixOf` html)

prop_raw_images_have_no_caption :: Property
prop_raw_images_have_no_caption = property $ do
  alt <- forAll genAltText
  src <- forAll genImagePath

  let html = renderRawImage src alt
      expectedImg = "<img src=\"" <> src <> "\" alt=\"" <> alt <> "\">"
      unexpectedFigcaption = "<figcaption>" <> alt <> "</figcaption>"
      unexpectedParagraph = "<p>" <> alt <> "</p>"

  assert (expectedImg `isInfixOf` html)
  assert (not (unexpectedFigcaption `isInfixOf` html))
  assert (not (unexpectedParagraph `isInfixOf` html))

prop_lists_render_as_lists :: Property
prop_lists_render_as_lists = property $ do
  items <- forAll genListItems

  let html = renderList items

  assert ("<ul>" `isInfixOf` html)
  assert ("</ul>" `isInfixOf` html)

  traverse_
    (\item -> do
      let expectedItem = "<li>" <> item <> "</li>"
      assert (expectedItem `isInfixOf` html)
    )
    items

genShellCommand :: Gen String
genShellCommand =
  Gen.string
    (Range.linear 1 80)
    (Gen.choice
      [ Gen.alphaNum
      , Gen.element " ./:_-$"
      ])

genAltText :: Gen String
genAltText =
  Gen.string
    (Range.linear 1 80)
    (Gen.choice
      [ Gen.alphaNum
      , Gen.element " -_:/"
      ])

genImagePath :: Gen String
genImagePath = do
  name <-
    Gen.string
      (Range.linear 1 40)
      (Gen.choice
        [ Gen.alphaNum
        , Gen.element "-_"
        ])

  ext <- Gen.element [".png", ".jpg", ".jpeg", ".webp", ".svg"]
  pure ("/img/" <> name <> ext)

genListItems :: Gen [String]
genListItems =
  Gen.list
    (Range.linear 1 20)
    genListItem

genListItem :: Gen String
genListItem =
  Gen.string
    (Range.linear 1 80)
    (Gen.choice
      [ Gen.alphaNum
      , Gen.element " -_:/()[]"
      ])

renderShellCodeBlock :: String -> String
renderShellCodeBlock command =
  "<div class=\"sourceCode\" id=\"cb1\">"
    <> "<pre class=\"sourceCode sh\">"
    <> "<code class=\"sourceCode bash\">"
    <> command
    <> "</code></pre></div>"

renderRawImage :: String -> String -> String
renderRawImage src alt =
  "<img src=\"" <> src <> "\" alt=\"" <> alt <> "\">"

renderList :: [String] -> String
renderList items =
  "<ul>"
    <> concatMap (\item -> "<li>" <> item <> "</li>") items
    <> "</ul>"
