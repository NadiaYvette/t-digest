module Main (main) where

import qualified Data.Sketch.TDigest as TD
import Text.Printf (printf)

main :: IO ()
main = do
  let n = 10000 :: Int
      td = foldl (flip TD.add) TD.empty [fromIntegral i / fromIntegral n | i <- [0 .. n - 1]]

  putStrLn $ "T-Digest demo: " ++ show n ++ " uniform values in [0, 1)"
  putStrLn $ "Centroids: " ++ show (TD.centroidCount td)
  putStrLn ""
  putStrLn "Quantile estimates (expected ~ q for uniform):"
  let quantiles = [0.001, 0.010, 0.100, 0.250, 0.500, 0.750, 0.900, 0.990, 0.999]
  mapM_
    ( \q -> do
        let est = case TD.quantile q td of
              Just v -> v
              Nothing -> 0.0
            err = abs (est - q)
        printf "  q=%-7.3f estimated=%-10.6f error=%.6f\n" q est err
    )
    quantiles

  putStrLn ""
  putStrLn "CDF estimates (expected ~ x for uniform):"
  let cdfPoints = [0.001, 0.010, 0.100, 0.250, 0.500, 0.750, 0.900, 0.990, 0.999]
  mapM_
    ( \x -> do
        let est = case TD.cdf x td of
              Just v -> v
              Nothing -> 0.0
            err = abs (est - x)
        printf "  x=%-7.3f estimated=%-10.6f error=%.6f\n" x est err
    )
    cdfPoints

  putStrLn ""
  putStrLn "After merge of two 5000-element digests:"
  let td1 = foldl (flip TD.add) TD.empty [fromIntegral i / fromIntegral n | i <- [0 .. 4999 :: Int]]
      td2 = foldl (flip TD.add) TD.empty [fromIntegral i / fromIntegral n | i <- [5000 .. 9999 :: Int]]
      tdMerged = TD.merge td1 td2
      med = case TD.quantile 0.5 tdMerged of
        Just v -> v
        Nothing -> 0.0
      p99 = case TD.quantile 0.99 tdMerged of
        Just v -> v
        Nothing -> 0.0
  printf "  median=%.6f (expected ~0.5)\n" med
  printf "  p99   =%.6f (expected ~0.99)\n" p99
  printf "  centroids=%d\n" (TD.centroidCount tdMerged)
  printf "\nMerge total weight: %.1f (expected %.1f)\n" (TD.totalWeight tdMerged) (10000.0 :: Double)
  putStrLn "\nDone."
