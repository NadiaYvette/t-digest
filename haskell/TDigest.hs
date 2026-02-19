-- | Dunning t-digest for online quantile estimation.
-- Merging digest variant with K_1 (arcsine) scale function.
-- Pure functional implementation using only base libraries.

module Main
  ( TDigest
  , Centroid(..)
  , empty
  , emptyWith
  , add
  , addWeighted
  , compress
  , quantile
  , cdf
  , merge
  , totalWeight
  , centroidCount
  , main
  ) where

import Data.List (sortBy, foldl')
import Data.Ord  (comparing)

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

data Centroid = Centroid
  { cMean   :: {-# UNPACK #-} !Double
  , cWeight :: {-# UNPACK #-} !Double
  } deriving (Show)

data TDigest = TDigest
  { tdCentroids  :: ![Centroid]    -- sorted by mean
  , tdBuffer     :: ![Centroid]    -- unsorted buffered additions
  , tdTotalWeight :: !Double
  , tdMin        :: !Double
  , tdMax        :: !Double
  , tdDelta      :: !Double        -- compression parameter
  , tdBufferCap  :: !Int           -- delta * 5
  } deriving (Show)

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create an empty t-digest with default delta = 100.
empty :: TDigest
empty = emptyWith 100

-- | Create an empty t-digest with a given compression parameter.
emptyWith :: Double -> TDigest
emptyWith delta = TDigest
  { tdCentroids   = []
  , tdBuffer       = []
  , tdTotalWeight  = 0
  , tdMin          = 1/0    -- +Infinity
  , tdMax          = -(1/0) -- -Infinity
  , tdDelta        = delta
  , tdBufferCap    = ceiling (delta * 5)
  }

-- ---------------------------------------------------------------------------
-- Scale function K_1
-- ---------------------------------------------------------------------------

-- | K_1 scale function: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
kScale :: Double -> Double -> Double
kScale delta q = (delta / (2 * pi)) * asin (2 * q - 1)

-- ---------------------------------------------------------------------------
-- Adding values
-- ---------------------------------------------------------------------------

-- | Add a single value with weight 1.
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1

-- | Add a value with a given weight.
addWeighted :: Double -> Double -> TDigest -> TDigest
addWeighted x w td =
  let td' = td
        { tdBuffer      = Centroid x w : tdBuffer td
        , tdTotalWeight  = tdTotalWeight td + w
        , tdMin          = min x (tdMin td)
        , tdMax          = max x (tdMax td)
        }
  in if length (tdBuffer td') >= tdBufferCap td'
     then compress td'
     else td'

-- ---------------------------------------------------------------------------
-- Compression (greedy merge)
-- ---------------------------------------------------------------------------

-- | Compress the digest by merging the buffer into the centroid list.
compress :: TDigest -> TDigest
compress td
  | null (tdBuffer td) && length (tdCentroids td) <= 1 = td
  | otherwise =
    let allItems = tdCentroids td ++ tdBuffer td
        sorted   = sortBy (comparing cMean) allItems
        n        = tdTotalWeight td
        delta    = tdDelta td
        merged   = greedyMerge delta n sorted
    in td { tdCentroids = merged
          , tdBuffer    = []
          }

-- | Greedy merge pass: walk sorted centroids and merge adjacent ones
-- when the scale function constraint allows it.
greedyMerge :: Double -> Double -> [Centroid] -> [Centroid]
greedyMerge _     _ []     = []
greedyMerge delta n (c:cs) = go 0 c cs
  where
    k = kScale delta

    go :: Double -> Centroid -> [Centroid] -> [Centroid]
    go _          current []     = [current]
    go weightSoFar current (item:rest)
      -- Always allow merging when the proposed weight is tiny (single count).
      | proposed <= 1 && not (null rest) =
          go weightSoFar (mergeCentroid current item) rest
      | k q1 - k q0 <= 1.0 =
          go weightSoFar (mergeCentroid current item) rest
      | otherwise =
          current : go (weightSoFar + cWeight current) item rest
      where
        proposed = cWeight current + cWeight item
        q0       = weightSoFar / n
        q1       = (weightSoFar + proposed) / n

-- | Merge a centroid into another using weighted mean.
mergeCentroid :: Centroid -> Centroid -> Centroid
mergeCentroid a b =
  let w = cWeight a + cWeight b
      m = (cMean a * cWeight a + cMean b * cWeight b) / w
  in Centroid m w

-- ---------------------------------------------------------------------------
-- Quantile estimation
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile q (0 <= q <= 1).
quantile :: Double -> TDigest -> Maybe Double
quantile q td0
  | null cs   = Nothing
  | length cs == 1 = Just (cMean (head cs))
  | otherwise = Just (walkQuantile (clamp 0 1 q) cs)
  where
    td = if null (tdBuffer td0) then td0 else compress td0
    cs = tdCentroids td
    n  = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    walkQuantile :: Double -> [Centroid] -> Double
    walkQuantile q' centroids = go 0 0 centroids
      where
        target       = q' * n
        numCentroids = length centroids
        lastIdx      = numCentroids - 1

        go :: Int -> Double -> [Centroid] -> Double
        go _ _ [] = mx  -- fallback
        go i cumulative (c:rest) =
          let mid = cumulative + cWeight c / 2
          in
          -- Left boundary: interpolate between min and first centroid
          if i == 0 && target < cWeight c / 2
          then
            if cWeight c == 1
            then mn
            else mn + (cMean c - mn) * (target / (cWeight c / 2))
          -- Right boundary: interpolate between last centroid and max
          else if i == lastIdx
          then
            if target > n - cWeight c / 2
            then
              if cWeight c == 1
              then mx
              else
                let remaining = n - cWeight c / 2
                in cMean c + (mx - cMean c) * ((target - remaining) / (cWeight c / 2))
            else cMean c
          -- Middle: interpolate between adjacent centroid midpoints
          else
            let nextC   = head rest
                nextMid = cumulative + cWeight c + cWeight nextC / 2
            in if target <= nextMid
               then
                 let frac = if nextMid == mid
                            then 0.5
                            else (target - mid) / (nextMid - mid)
                 in cMean c + frac * (cMean nextC - cMean c)
               else go (i + 1) (cumulative + cWeight c) rest

-- ---------------------------------------------------------------------------
-- CDF estimation
-- ---------------------------------------------------------------------------

-- | Estimate the cumulative distribution function at value x.
cdf :: Double -> TDigest -> Maybe Double
cdf x td0
  | null cs   = Nothing
  | x <= mn   = Just 0
  | x >= mx   = Just 1
  | otherwise = Just (walkCdf x cs)
  where
    td = if null (tdBuffer td0) then td0 else compress td0
    cs = tdCentroids td
    n  = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    walkCdf :: Double -> [Centroid] -> Double
    walkCdf x' centroids = go 0 0 centroids
      where
        numCentroids = length centroids
        lastIdx      = numCentroids - 1

        go :: Int -> Double -> [Centroid] -> Double
        go _ _ [] = 1.0  -- fallback
        go i cumulative (c:rest)
          -- First centroid: left boundary
          | i == 0 && x' < cMean c =
              let innerW = cWeight c / 2
                  frac   = if cMean c == mn then 1.0
                           else (x' - mn) / (cMean c - mn)
              in (innerW * frac) / n
          | i == 0 && x' == cMean c =
              (cWeight c / 2) / n
          -- Last centroid: right boundary
          | i == lastIdx && x' > cMean c =
              let halfW  = cWeight c / 2
                  rightW = n - cumulative - halfW
                  frac   = if mx == cMean c then 0.0
                           else (x' - cMean c) / (mx - cMean c)
              in (cumulative + halfW + rightW * frac) / n
          | i == lastIdx =
              (cumulative + cWeight c / 2) / n
          -- Middle: interpolate between centroid midpoints
          | otherwise =
              let mid            = cumulative + cWeight c / 2
                  nextC          = head rest
                  nextCumulative = cumulative + cWeight c
                  nextMid        = nextCumulative + cWeight nextC / 2
              in if x' < cMean nextC
                 then
                   let frac = if cMean c == cMean nextC
                              then 0.5
                              else (x' - cMean c) / (cMean nextC - cMean c)
                   in (mid + frac * (nextMid - mid)) / n
                 else go (i + 1) (cumulative + cWeight c) rest

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge two t-digests. All centroids from the second are added as
-- buffered values into the first, then compressed.
merge :: TDigest -> TDigest -> TDigest
merge td other =
  let otherTd   = if null (tdBuffer other) then other else compress other
      otherCs   = tdCentroids otherTd
      combined  = foldl' (\d c -> addWeighted (cMean c) (cWeight c) d) td otherCs
  in compress combined

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

totalWeight :: TDigest -> Double
totalWeight = tdTotalWeight

-- | Number of centroids (after compressing any pending buffer).
centroidCount :: TDigest -> Int
centroidCount td =
  let td' = if null (tdBuffer td) then td else compress td
  in length (tdCentroids td')

-- ---------------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------------

clamp :: Double -> Double -> Double -> Double
clamp lo hi x
  | x < lo   = lo
  | x > hi   = hi
  | otherwise = x

-- ---------------------------------------------------------------------------
-- Main: demo and self-test
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  let numValues = 10000 :: Int

  -- Insert uniformly spaced values in [0, 1): 0/n, 1/n, ..., (n-1)/n
  let values = [ fromIntegral i / fromIntegral numValues | i <- [0 .. numValues - 1] ]

  -- Build t-digest
  let td = foldl' (flip add) empty values

  putStrLn $ "T-Digest demo: " ++ show numValues ++ " uniform values in [0, 1)"
  putStrLn $ "Centroids: " ++ show (centroidCount td)
  putStrLn ""

  -- Quantile estimates
  putStrLn "Quantile estimates (expected ~ q for uniform):"
  let qs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] :: [Double]
  mapM_ (\q -> do
    let Just est = quantile q td
        err = abs (est - q)
    putStrLn $ "  q=" ++ padRight 6 (showFFloat3 q)
            ++ "  estimated=" ++ showFFloat6 est
            ++ "  error=" ++ showFFloat6 err
    ) qs

  putStrLn ""

  -- CDF estimates
  putStrLn "CDF estimates (expected ~ x for uniform):"
  let xs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] :: [Double]
  mapM_ (\x -> do
    let Just est = cdf x td
        err = abs (est - x)
    putStrLn $ "  x=" ++ padRight 6 (showFFloat3 x)
            ++ "  estimated=" ++ showFFloat6 est
            ++ "  error=" ++ showFFloat6 err
    ) xs

  putStrLn ""

  -- Test merge: split values into two halves, merge, check
  let vals1 = [ fromIntegral i / fromIntegral numValues | i <- [0 .. 4999 :: Int] ]
      vals2 = [ fromIntegral i / fromIntegral numValues | i <- [5000 .. 9999 :: Int] ]
      td1 = foldl' (flip add) empty vals1
      td2 = foldl' (flip add) empty vals2
      tdM = merge td1 td2

  putStrLn "After merge of two 5000-element digests:"
  case quantile 0.5 tdM of
    Just m  -> putStrLn $ "  median=" ++ showFFloat6 m ++ " (expected ~0.5)"
    Nothing -> putStrLn "  median=N/A"
  case quantile 0.99 tdM of
    Just p  -> putStrLn $ "  p99   =" ++ showFFloat6 p ++ " (expected ~0.99)"
    Nothing -> putStrLn "  p99   =N/A"
  putStrLn $ "  centroids=" ++ show (centroidCount tdM)

  putStrLn ""

  -- Verify merge preserves total weight
  putStrLn $ "Merge total weight: " ++ show (totalWeight tdM)
              ++ " (expected " ++ show (totalWeight td1 + totalWeight td2) ++ ")"

  putStrLn ""
  putStrLn "Done."

-- ---------------------------------------------------------------------------
-- Formatting helpers (no dependency on Text.Printf)
-- ---------------------------------------------------------------------------

-- | Show a Double with approximately 6 decimal places.
showFFloat6 :: Double -> String
showFFloat6 x = showFFloatN 6 x

-- | Show a Double with approximately 3 decimal places.
showFFloat3 :: Double -> String
showFFloat3 x = showFFloatN 3 x

-- | Show a Double with n decimal places.
showFFloatN :: Int -> Double -> String
showFFloatN n x
  | isInfinite x = if x > 0 then "Inf" else "-Inf"
  | isNaN x      = "NaN"
  | x < 0        = "-" ++ showFFloatN n (negate x)
  | otherwise     =
      let factor   = 10 ^ n :: Integer
          scaled   = round (x * fromIntegral factor) :: Integer
          wholePart = scaled `div` factor
          fracPart  = scaled `mod` factor
          fracStr   = padLeftZ n (show fracPart)
      in show wholePart ++ "." ++ fracStr

-- | Pad a string with leading zeros to length n.
padLeftZ :: Int -> String -> String
padLeftZ n s
  | length s >= n = s
  | otherwise     = replicate (n - length s) '0' ++ s

-- | Pad a string on the right with spaces to length n.
padRight :: Int -> String -> String
padRight n s
  | length s >= n = s
  | otherwise     = s ++ replicate (n - length s) ' '
