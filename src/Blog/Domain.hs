{-# LANGUAGE DerivingStrategies #-}

module Blog.Domain
  ( Slug(..)
  , Title(..)
  , Section(..)
  , PostMeta(..)
  ) where

import Data.Time (Day)

newtype Slug = Slug { unSlug :: String }
  deriving stock (Eq, Ord, Show)

newtype Title = Title { unTitle :: String }
  deriving stock (Eq, Ord, Show)

data Section
  = Home
  | About
  | Archive
  | Posts
  | Projects
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data PostMeta = PostMeta
  { postTitle :: Title
  , postSlug  :: Slug
  , postDate  :: Day
  , postTags  :: [String]
  }
  deriving stock (Eq, Show)
