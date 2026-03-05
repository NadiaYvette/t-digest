-- |
-- Module      : TDigest
-- Description : Dunning t-digest for online quantile estimation
-- Stability   : experimental
-- Maintainer  : Nadia Yvette Chambers
--
-- A pure functional implementation of the Dunning t-digest data structure,
-- using the merging digest variant with the K1 (arcsine) scale function.
-- The t-digest provides streaming, mergeable, memory-bounded approximation
-- of quantile (percentile) queries with high accuracy in the tails.
--
-- This implementation uses only @base@ libraries; no external dependencies
-- are required.
--
-- == Quick start
--
-- @
-- import TDigest
-- import Data.List ('Data.List.foldl\'')
--
-- main :: IO ()
-- main = do
--   let td = 'Data.List.foldl\'' (flip 'add') 'empty' [1.0 .. 10000.0]
--   print ('quantile' 0.99 td)   -- Just ~9900.5
--   print ('cdf' 5000.0 td)      -- Just ~0.5
-- @
module TDigest
  ( -- * Types
    TDigest,
    Centroid (..),

    -- * Construction
    empty,
    emptyWith,

    -- * Insertion
    add,
    addWeighted,

    -- * Compression
    compress,

    -- * Queries
    quantile,
    cdf,

    -- * Merging
    merge,

    -- * Accessors
    totalWeight,
    centroidCount,
  )
where

import Data.List (foldl', sortBy)
import Data.Ord (comparing)

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- | A single centroid in the t-digest, representing a cluster of nearby values.
--
-- Each centroid tracks the weighted mean of its constituent values and the
-- total weight (number of values, or sum of weights if non-unit weights are
-- used).
data Centroid = Centroid
  { -- | Weighted mean of all values merged into this centroid.
    cMean :: {-# UNPACK #-} !Double,
    -- | Total weight (count) of values in this centroid.
    cWeight :: {-# UNPACK #-} !Double
  }
  deriving (Show)

-- | The t-digest data structure for online quantile estimation.
--
-- Internally, it maintains a sorted list of 'Centroid's and an unsorted
-- buffer. When the buffer reaches capacity, a compression pass merges
-- buffer entries into the centroid list using the K1 scale function to
-- enforce the size invariant: centroids near the tails are kept small
-- (high accuracy) while centroids near the median may be large (saving
-- space).
data TDigest = TDigest
  { -- | Sorted (by mean) list of centroids.
    tdCentroids :: ![Centroid],
    -- | Unsorted buffered additions awaiting compression.
    tdBuffer :: ![Centroid],
    -- | Sum of all weights ever added.
    tdTotalWeight :: !Double,
    -- | Minimum value seen.
    tdMin :: !Double,
    -- | Maximum value seen.
    tdMax :: !Double,
    -- | Compression parameter (typically 100).
    tdDelta :: !Double,
    -- | Buffer capacity: @ceiling(delta * 5)@.
    tdBufferCap :: !Int
  }
  deriving (Show)

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create an empty t-digest with the default compression parameter (delta = 100).
--
-- >>> centroidCount empty
-- 0
-- >>> totalWeight empty
-- 0.0
empty :: TDigest
empty = emptyWith 100

-- | Create an empty t-digest with a given compression parameter.
--
-- Higher delta values produce more centroids and better accuracy at the
-- cost of more memory. Typical values are 100--200.
--
-- >>> totalWeight (emptyWith 200)
-- 0.0
emptyWith :: Double -> TDigest
emptyWith delta =
  TDigest
    { tdCentroids = [],
      tdBuffer = [],
      tdTotalWeight = 0,
      tdMin = 1 / 0, -- +Infinity
      tdMax = -(1 / 0), -- -Infinity
      tdDelta = delta,
      tdBufferCap = ceiling (delta * 5)
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

-- | Add a single value with weight 1 to the digest.
--
-- Triggers automatic compression when the internal buffer reaches capacity.
--
-- >>> quantile 0.5 (add 42.0 empty)
-- Just 42.0
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1

-- | Add a value with a given weight to the digest.
--
-- This is useful when ingesting pre-aggregated data (e.g., centroids from
-- another digest during a merge operation).
--
-- >>> totalWeight (addWeighted 10.0 5.0 empty)
-- 5.0
addWeighted :: Double -> Double -> TDigest -> TDigest
addWeighted x w td =
  let td' =
        td
          { tdBuffer = Centroid x w : tdBuffer td,
            tdTotalWeight = tdTotalWeight td + w,
            tdMin = min x (tdMin td),
            tdMax = max x (tdMax td)
          }
   in if length (tdBuffer td') >= tdBufferCap td'
        then compress td'
        else td'

-- ---------------------------------------------------------------------------
-- Compression (greedy merge)
-- ---------------------------------------------------------------------------

-- | Compress the digest by merging the buffer into the centroid list.
--
-- Normally this is triggered automatically when the buffer fills up.
-- You can call it explicitly if you want to ensure the digest is in
-- a compressed state (e.g., before serialization).
compress :: TDigest -> TDigest
compress td
  | null (tdBuffer td) && length (tdCentroids td) <= 1 = td
  | otherwise =
      let allItems = tdCentroids td ++ tdBuffer td
          sorted = sortBy (comparing cMean) allItems
          n = tdTotalWeight td
          delta = tdDelta td
          merged = greedyMerge delta n sorted
       in td
            { tdCentroids = merged,
              tdBuffer = []
            }

-- | Greedy merge pass: walk sorted centroids and merge adjacent ones
-- when the scale function constraint allows it.
greedyMerge :: Double -> Double -> [Centroid] -> [Centroid]
greedyMerge _ _ [] = []
greedyMerge delta n (c : cs) = go 0 c cs
  where
    k = kScale delta

    go :: Double -> Centroid -> [Centroid] -> [Centroid]
    go _ current [] = [current]
    go weightSoFar current (item : rest)
      -- Always allow merging when the proposed weight is tiny (single count).
      | proposed <= 1 && not (null rest) =
          go weightSoFar (mergeCentroid current item) rest
      | k q1 - k q0 <= 1.0 =
          go weightSoFar (mergeCentroid current item) rest
      | otherwise =
          current : go (weightSoFar + cWeight current) item rest
      where
        proposed = cWeight current + cWeight item
        q0 = weightSoFar / n
        q1 = (weightSoFar + proposed) / n

-- | Merge a centroid into another using weighted mean.
mergeCentroid :: Centroid -> Centroid -> Centroid
mergeCentroid a b =
  let w = cWeight a + cWeight b
      m = (cMean a * cWeight a + cMean b * cWeight b) / w
   in Centroid m w

-- ---------------------------------------------------------------------------
-- Quantile estimation
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile @q@ (0 <= q <= 1).
--
-- Returns 'Nothing' if the digest is empty, otherwise 'Just' the estimated
-- value. The q parameter is clamped to [0, 1].
--
-- The estimate is most accurate near the tails (q close to 0 or 1) due
-- to the K1 scale function.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> quantile 0.5 td
-- Just ...   -- approximately 500
-- >>> quantile 0.0 td
-- Just 1.0
quantile :: Double -> TDigest -> Maybe Double
quantile q td0
  | null cs = Nothing
  | length cs == 1 = Just (cMean (head cs))
  | otherwise = Just (walkQuantile (clamp 0 1 q) cs)
  where
    td = if null (tdBuffer td0) then td0 else compress td0
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    walkQuantile :: Double -> [Centroid] -> Double
    walkQuantile q' centroids = go 0 0 centroids
      where
        target = q' * n
        numCentroids = length centroids
        lastIdx = numCentroids - 1

        go :: Int -> Double -> [Centroid] -> Double
        go _ _ [] = mx -- fallback
        go i cumulative (c : rest) =
          let mid = cumulative + cWeight c / 2
           in -- Left boundary: interpolate between min and first centroid
              if i == 0 && target < cWeight c / 2
                then
                  if cWeight c == 1
                    then mn
                    else mn + (cMean c - mn) * (target / (cWeight c / 2))
                -- Right boundary: interpolate between last centroid and max
                else
                  if i == lastIdx
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
                      let nextC = head rest
                          nextMid = cumulative + cWeight c + cWeight nextC / 2
                       in if target <= nextMid
                            then
                              let frac =
                                    if nextMid == mid
                                      then 0.5
                                      else (target - mid) / (nextMid - mid)
                               in cMean c + frac * (cMean nextC - cMean c)
                            else go (i + 1) (cumulative + cWeight c) rest

-- ---------------------------------------------------------------------------
-- CDF estimation
-- ---------------------------------------------------------------------------

-- | Estimate the cumulative distribution function (CDF) at value @x@.
--
-- Returns 'Nothing' if the digest is empty. Otherwise returns 'Just' a
-- value in [0, 1] representing the estimated fraction of values less than
-- or equal to @x@.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> cdf 500.0 td
-- Just ...   -- approximately 0.5
-- >>> cdf 0.0 td
-- Just 0.0
cdf :: Double -> TDigest -> Maybe Double
cdf x td0
  | null cs = Nothing
  | x <= mn = Just 0
  | x >= mx = Just 1
  | otherwise = Just (walkCdf x cs)
  where
    td = if null (tdBuffer td0) then td0 else compress td0
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    walkCdf :: Double -> [Centroid] -> Double
    walkCdf x' centroids = go 0 0 centroids
      where
        numCentroids = length centroids
        lastIdx = numCentroids - 1

        go :: Int -> Double -> [Centroid] -> Double
        go _ _ [] = 1.0 -- fallback
        go i cumulative (c : rest)
          -- First centroid: left boundary
          | i == 0 && x' < cMean c =
              let innerW = cWeight c / 2
                  frac =
                    if cMean c == mn
                      then 1.0
                      else (x' - mn) / (cMean c - mn)
               in (innerW * frac) / n
          | i == 0 && x' == cMean c =
              (cWeight c / 2) / n
          -- Last centroid: right boundary
          | i == lastIdx && x' > cMean c =
              let halfW = cWeight c / 2
                  rightW = n - cumulative - halfW
                  frac =
                    if mx == cMean c
                      then 0.0
                      else (x' - cMean c) / (mx - cMean c)
               in (cumulative + halfW + rightW * frac) / n
          | i == lastIdx =
              (cumulative + cWeight c / 2) / n
          -- Middle: interpolate between centroid midpoints
          | otherwise =
              let mid = cumulative + cWeight c / 2
                  nextC = head rest
                  nextCumulative = cumulative + cWeight c
                  nextMid = nextCumulative + cWeight nextC / 2
               in if x' < cMean nextC
                    then
                      let frac =
                            if cMean c == cMean nextC
                              then 0.5
                              else (x' - cMean c) / (cMean nextC - cMean c)
                       in (mid + frac * (nextMid - mid)) / n
                    else go (i + 1) (cumulative + cWeight c) rest

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge two t-digests into one.
--
-- All centroids from the second digest are added as buffered values into
-- the first, then the result is compressed. This is useful for combining
-- digests from distributed workers or parallel computations.
--
-- The resulting digest has the same accuracy guarantees as if all values
-- had been added to a single digest.
--
-- >>> let td1 = foldl (flip add) empty [1..500]
-- >>> let td2 = foldl (flip add) empty [501..1000]
-- >>> totalWeight (merge td1 td2)
-- 1000.0
merge :: TDigest -> TDigest -> TDigest
merge td other =
  let otherTd = if null (tdBuffer other) then other else compress other
      otherCs = tdCentroids otherTd
      combined = foldl' (\d c -> addWeighted (cMean c) (cWeight c) d) td otherCs
   in compress combined

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Return the total weight of all values added to the digest.
--
-- For unit-weight additions, this equals the number of values added.
totalWeight :: TDigest -> Double
totalWeight = tdTotalWeight

-- | Return the number of centroids after compressing any pending buffer.
--
-- For a digest with delta = 100, this is typically 50--100 centroids
-- regardless of how many values have been added.
centroidCount :: TDigest -> Int
centroidCount td =
  let td' = if null (tdBuffer td) then td else compress td
   in length (tdCentroids td')

-- ---------------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------------

clamp :: Double -> Double -> Double -> Double
clamp lo hi x
  | x < lo = lo
  | x > hi = hi
  | otherwise = x
