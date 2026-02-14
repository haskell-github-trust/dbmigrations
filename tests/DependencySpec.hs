{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}

module DependencySpec
  ( spec
  )
where

import Prelude

import Common
import Data.Foldable (for_)
import Data.Graph.Inductive.Graph (Graph (..))
import Data.Text (Text, unpack)
import Data.Text qualified as T
import Database.Schema.Migrations.Dependencies
import Test.Hspec

spec :: Spec
spec = do
  describe "mkDepGraph" $ do
    let
      first = TD "first" []
      second = TD "second" ["first"]
      cycleFirst = TD "first" ["second"]
      cycleSecond = TD "second" ["first"]

    it "returns empty for empty" $ do
      mkDepGraph @TestDependable [] `shouldBe` Right (DG [] [] empty)

    it "builds a graph" $ do
      mkDepGraph [first, second]
        `shouldBe` Right
          ( DG
              [(first, 1), (second, 2)]
              [("first", 1), ("second", 2)]
              ( mkGraph
                  [(1, "first"), (2, "second")]
                  [(2, 1, "first -> second")]
              )
          )

    it "fails on cycles" $ do
      mkDepGraph [cycleFirst, cycleSecond]
        `shouldBe` Left "Invalid dependency graph; cycle detected"

  describe "dependencies and reverseDependencies" $ do
    for_ dependencyTestCases $ \(deps, a, dir, expected) -> do
      let (f, arrow) = case dir of
            Forward -> (dependencies, " -> ")
            Reverse -> (reverseDependencies, " <- ")

      it (unpack $ T.intercalate arrow $ map tdId deps) $ do
        let Right g = mkDepGraph deps
        f g a `shouldBe` expected

data Direction = Forward | Reverse
  deriving stock (Show)

type DependencyTestCase = ([TestDependable], Text, Direction, [Text])

dependencyTestCases :: [DependencyTestCase]
dependencyTestCases =
  [ ([TD "first" []], "first", Forward, [])
  , ([TD "first" []], "first", Reverse, [])
  , ([TD "first" ["second"], TD "second" []], "first", Forward, ["second"])
  , ([TD "first" ["second"], TD "second" []], "second", Reverse, ["first"])
  ,
    ( [TD "first" ["second"], TD "second" ["third"], TD "third" []]
    , "first"
    , Forward
    , ["third", "second"]
    )
  ,
    (
      [ TD "first" ["second"]
      , TD "second" ["third"]
      , TD "third" []
      , TD "fourth" ["third"]
      ]
    , "first"
    , Forward
    , ["third", "second"]
    )
  ,
    ( [TD "first" [], TD "second" ["first"]]
    , "first"
    , Reverse
    , ["second"]
    )
  ,
    ( [TD "first" [], TD "second" ["first"], TD "third" ["second"]]
    , "first"
    , Reverse
    , ["third", "second"]
    )
  ,
    (
      [ TD "first" []
      , TD "second" ["first"]
      , TD "third" ["second"]
      , TD "fourth" ["second"]
      ]
    , "first"
    , Reverse
    , ["fourth", "third", "second"]
    )
  ,
    (
      [ TD "first" ["second"]
      , TD "second" ["third"]
      , TD "third" ["fourth"]
      , TD "second" ["fifth"]
      , TD "fifth" ["third"]
      , TD "fourth" []
      ]
    , "fourth"
    , Reverse
    , ["first", "second", "fifth", "third"]
    )
  ,
    (
      [ TD "first" ["second"]
      , TD "second" ["third", "fifth"]
      , TD "third" ["fourth"]
      , TD "fifth" ["third"]
      , TD "fourth" []
      ]
    , "first"
    , Forward
    , ["fourth", "third", "fifth", "second"]
    )
  ]
