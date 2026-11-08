{-# LANGUAGE BangPatterns #-}

module Main (main) where

import Control.Monad (forM_)
import Data.Maybe (isNothing)
import qualified Data.Sketch.TDigest as TD
import qualified Data.Sketch.TDigest.Mutable as TDM
import qualified Data.Sketch.TDigest.Tree234 as Tree234
import System.Exit (exitFailure, exitSuccess)
import Text.Printf (printf)

main :: IO ()
main = do
  putStrLn "=== [dunning-t-digest Flat PrimArray Test Suite] ==="
  let tests =
        [ ("testEmptyDigest", testEmptyDigest),
          ("testSingletonDigest", testSingletonDigest),
          ("testUniformTailAccuracy", testUniformTailAccuracy),
          ("testCdfAccuracy", testCdfAccuracy),
          ("testCentroidCountBound", testCentroidCountBound),
          ("testMergePreservation", testMergePreservation),
          ("testScaleFunctions", testScaleFunctions),
          ("testMutableParity", testMutableParity),
          ("testTree234ArrayHosted", testTree234ArrayHosted)
        ]
  results <- mapM runTest tests
  if and results
    then do
      putStrLn "\nAll tests PASSED!"
      exitSuccess
    else do
      putStrLn "\nSome tests FAILED!"
      exitFailure

runTest :: (String, IO Bool) -> IO Bool
runTest (name, act) = do
  printf "Running %-30s ... " name
  ok <- act
  if ok
    then putStrLn "PASS"
    else putStrLn "FAIL"
  pure ok

testEmptyDigest :: IO Bool
testEmptyDigest = do
  let td = TD.empty
  pure $
    TD.totalWeight td == 0
      && TD.centroidCount td == 0
      && isNothing (TD.quantile 0.5 td)
      && isNothing (TD.cdf 0.5 td)
      && isNothing (TD.getMin td)
      && isNothing (TD.getMax td)

testSingletonDigest :: IO Bool
testSingletonDigest = do
  let td = TD.add 42.0 TD.empty
  pure $
    TD.totalWeight td == 1.0
      && TD.centroidCount td == 1
      && TD.quantile 0.5 td == Just 42.0
      && TD.quantile 0.0 td == Just 42.0
      && TD.quantile 1.0 td == Just 42.0
      && TD.cdf 42.0 td == Just 0.5
      && TD.getMin td == Just 42.0
      && TD.getMax td == Just 42.0

testUniformTailAccuracy :: IO Bool
testUniformTailAccuracy = do
  let n = 10000 :: Int
      td = foldl (\acc i -> TD.add (fromIntegral i / fromIntegral n) acc) TD.empty [0 .. n - 1]
      qs = [0.001, 0.01, 0.1, 0.5, 0.9, 0.99, 0.999]
      checkQ q =
        case TD.quantile q td of
          Nothing -> False
          Just est -> abs (est - q) < 0.01
  pure (all checkQ qs)

testCdfAccuracy :: IO Bool
testCdfAccuracy = do
  let n = 10000 :: Int
      td = foldl (\acc i -> TD.add (fromIntegral i / fromIntegral n) acc) TD.empty [0 .. n - 1]
      xs = [0.001, 0.01, 0.1, 0.5, 0.9, 0.99, 0.999]
      checkX x =
        case TD.cdf x td of
          Nothing -> False
          Just est -> abs (est - x) < 0.01
  pure (all checkX xs)

testCentroidCountBound :: IO Bool
testCentroidCountBound = do
  let delta = 100 :: Double
      n = 10000 :: Int
      td = foldl (\acc i -> TD.add i acc) (TD.emptyWith delta) [1 .. fromIntegral n :: Double]
      cc = TD.centroidCount td
  pure (cc <= ceiling (5 * delta))

testMergePreservation :: IO Bool
testMergePreservation = do
  let n = 5000 :: Int
      td1 = foldl (\acc i -> TD.add i acc) TD.empty [1 .. fromIntegral n :: Double]
      td2 = foldl (\acc i -> TD.add i acc) TD.empty [fromIntegral n + 1 .. 2 * fromIntegral n :: Double]
      merged = TD.merge td1 td2
      wMerged = TD.totalWeight merged
  pure (wMerged == fromIntegral (2 * n))

testScaleFunctions :: IO Bool
testScaleFunctions = do
  let sfs = [TD.K0, TD.K1, TD.K2, TD.K3]
      testSf sf =
        let td = foldl (\acc i -> TD.add i acc) (TD.emptyWithScale sf 100) [1 .. 1000 :: Double]
         in TD.centroidCount td > 0 && TD.totalWeight td == 1000
  pure (all testSf sfs)

testMutableParity :: IO Bool
testMutableParity = do
  let n = 1000 :: Int
      pureTd = foldl (\acc i -> TD.add i acc) TD.empty [1 .. fromIntegral n :: Double]
      qPure = TD.quantile 0.95 pureTd
      qMut = TDM.runTDigest $ do
        md <- TDM.new
        forM_ [1 .. fromIntegral n :: Double] $ \i -> TDM.add i md
        TDM.quantile 0.95 md
  case (qPure, qMut) of
    (Just p, Just m) -> pure (abs (p - m) < 1.0)
    _ -> pure False

testTree234ArrayHosted :: IO Bool
testTree234ArrayHosted = do
  let centroids = [(fromIntegral i, 1.0) | i <- [1 .. 100 :: Int]]
      t = Tree234.buildFromSorted centroids
      res = Tree234.collectCentroids t
      m = Tree234.rootMeasure t
      wRes = Tree234.findByWeight 50.0 t
  pure $
    Tree234.treeSize t == 100
      && length res == 100
      && Tree234.tmWeight m == 100.0
      && Tree234.wrFound wRes
      && abs (Tree234.wrMean wRes - 50.0) <= 2.0
