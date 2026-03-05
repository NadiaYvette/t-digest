module Main (main) where

import Data.List (foldl')
import TDigest

-- ---------------------------------------------------------------------------
-- Formatting helpers
-- ---------------------------------------------------------------------------

showFFloat6 :: Double -> String
showFFloat6 = showFFloatN 6

showFFloat3 :: Double -> String
showFFloat3 = showFFloatN 3

showFFloatN :: Int -> Double -> String
showFFloatN n x
  | isInfinite x = if x > 0 then "Inf" else "-Inf"
  | isNaN x = "NaN"
  | x < 0 = "-" ++ showFFloatN n (negate x)
  | otherwise =
      let factor = 10 ^ n :: Integer
          scaled = round (x * fromIntegral factor) :: Integer
          wholePart = scaled `div` factor
          fracPart = scaled `mod` factor
          fracStr = padLeftZ n (show fracPart)
       in show wholePart ++ "." ++ fracStr

padLeftZ :: Int -> String -> String
padLeftZ n s
  | length s >= n = s
  | otherwise = replicate (n - length s) '0' ++ s

padRight :: Int -> String -> String
padRight n s
  | length s >= n = s
  | otherwise = s ++ replicate (n - length s) ' '

-- ---------------------------------------------------------------------------
-- Demo / self-test
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  let numValues = 10000 :: Int
      values = [fromIntegral i / fromIntegral numValues | i <- [0 .. numValues - 1]]
      td = foldl' (flip add) empty values

  putStrLn $ "T-Digest demo: " ++ show numValues ++ " uniform values in [0, 1)"
  putStrLn $ "Centroids: " ++ show (centroidCount td)
  putStrLn ""

  putStrLn "Quantile estimates (expected ~ q for uniform):"
  let qs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] :: [Double]
  mapM_
    ( \q -> do
        let Just est = quantile q td
            err = abs (est - q)
        putStrLn $
          "  q="
            ++ padRight 6 (showFFloat3 q)
            ++ "  estimated="
            ++ showFFloat6 est
            ++ "  error="
            ++ showFFloat6 err
    )
    qs

  putStrLn ""

  putStrLn "CDF estimates (expected ~ x for uniform):"
  let xs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] :: [Double]
  mapM_
    ( \x -> do
        let Just est = cdf x td
            err = abs (est - x)
        putStrLn $
          "  x="
            ++ padRight 6 (showFFloat3 x)
            ++ "  estimated="
            ++ showFFloat6 est
            ++ "  error="
            ++ showFFloat6 err
    )
    xs

  putStrLn ""

  let vals1 = [fromIntegral i / fromIntegral numValues | i <- [0 .. 4999 :: Int]]
      vals2 = [fromIntegral i / fromIntegral numValues | i <- [5000 .. 9999 :: Int]]
      td1 = foldl' (flip add) empty vals1
      td2 = foldl' (flip add) empty vals2
      tdM = merge td1 td2

  putStrLn "After merge of two 5000-element digests:"
  case quantile 0.5 tdM of
    Just m -> putStrLn $ "  median=" ++ showFFloat6 m ++ " (expected ~0.5)"
    Nothing -> putStrLn "  median=N/A"
  case quantile 0.99 tdM of
    Just p -> putStrLn $ "  p99   =" ++ showFFloat6 p ++ " (expected ~0.99)"
    Nothing -> putStrLn "  p99   =N/A"
  putStrLn $ "  centroids=" ++ show (centroidCount tdM)

  putStrLn ""
  putStrLn $
    "Merge total weight: "
      ++ show (totalWeight tdM)
      ++ " (expected "
      ++ show (totalWeight td1 + totalWeight td2)
      ++ ")"
  putStrLn ""
  putStrLn "Done."
