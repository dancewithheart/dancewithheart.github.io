{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE DerivingStrategies #-}

module Blog.Validation
  ( Validation(..)
  , MetaError(..)
  , RawPostMeta(..)
  , validatePostMeta
  , validateTitle
  , validateSlug
  ) where

import Blog.Domain (PostMeta(..), Slug(..), Title(..))
import Blog.Paths (normalizeTitleToSlug)
import Data.Bifunctor (Bifunctor(..))
import Data.Char (isSpace)
import Data.List.NonEmpty (NonEmpty(..))
import Data.Time (Day)

data Validation e a
  = Failure e
  | Success a
  deriving stock (Eq, Show, Functor, Foldable, Traversable)

instance Bifunctor Validation where
  bimap f _ (Failure e) = Failure (f e)
  bimap _ g (Success a) = Success (g a)

instance Semigroup e => Applicative (Validation e) where
  pure = Success

  Success f <*> Success a = Success (f a)
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)
  Failure e <*> _ = Failure e
  _ <*> Failure e = Failure e

data MetaError
  = EmptyTitle
  | EmptySlug
  | FutureDate Day
  deriving stock (Eq, Show)

data RawPostMeta = RawPostMeta
  { rawTitle :: String
  , rawSlug  :: String
  , rawDate  :: Day
  , rawTags  :: [String]
  }
  deriving stock (Eq, Show)

validateTitle :: String -> Validation (NonEmpty MetaError) Title
validateTitle s
  | all isSpace s = Failure (EmptyTitle :| [])
  | otherwise     = Success (Title s)

validateSlug :: String -> Validation (NonEmpty MetaError) Slug
validateSlug s
  | all isSpace s = Failure (EmptySlug :| [])
  | otherwise     = Success (normalizeTitleToSlug s)

validatePostMeta :: Day -> RawPostMeta -> Validation (NonEmpty MetaError) PostMeta
validatePostMeta today raw =
  PostMeta
    <$> validateTitle (rawTitle raw)
    <*> validateSlug (rawSlug raw)
    <*> validateDate
    <*> pure (rawTags raw)
  where
    validateDate
      | rawDate raw > today = Failure (FutureDate (rawDate raw) :| [])
      | otherwise           = Success (rawDate raw)
