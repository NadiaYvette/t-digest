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
-- This implementation uses a 'Data.FingerTree.FingerTree' from the
-- @fingertree@ package for O(log n) quantile queries by cumulative weight
-- and O(1) total count\/weight via a monoidal measure.
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
    centroidList,
    getDelta,
    getMin,
    getMax,

    -- * Reconstruction
    fromComponents,
  )
where

import Data.FingerTree (FingerTree, Measured (..), ViewL (..), ViewR (..), (<|), (|>))
import qualified Data.FingerTree as FT
import Data.List (foldl', sortBy)
import Data.Ord (comparing)

-- ---------------------------------------------------------------------------
-- Measure (monoidal annotation for the finger tree)
-- ---------------------------------------------------------------------------

-- | Monoidal measure tracking total weight and centroid count in a subtree.
data Measure = Measure
  { mWeight :: {-# UNPACK #-} !Double,
    mCount :: {-# UNPACK #-} !Int
  }
  deriving (Show)

instance Semigroup Measure where
  (Measure w1 c1) <> (Measure w2 c2) = Measure (w1 + w2) (c1 + c2)

instance Monoid Measure where
  mempty = Measure 0 0

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

instance Measured Measure Centroid where
  measure c = Measure (cWeight c) 1

-- | The t-digest data structure for online quantile estimation.
--
-- Internally, it maintains a 'FingerTree' of 'Centroid's (sorted by mean)
-- and an unsorted buffer list. When the buffer reaches capacity, a
-- compression pass merges buffer entries into the centroid tree using the
-- K1 scale function to enforce the size invariant: centroids near the tails
-- are kept small (high accuracy) while centroids near the median may be
-- large (saving space).
data TDigest = TDigest
  { -- | Sorted (by mean) finger tree of centroids.
    tdCentroids :: !(FingerTree Measure Centroid),
    -- | Unsorted buffered additions awaiting compression.
    tdBuffer :: ![Centroid],
    -- | Current buffer length (avoids O(n) length calls).
    tdBufferLen :: {-# UNPACK #-} !Int,
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
    { tdCentroids = FT.empty,
      tdBuffer = [],
      tdBufferLen = 0,
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
-- FingerTree helpers
-- ---------------------------------------------------------------------------

-- | Convert a finger tree to a list (left to right).
ftToList :: FingerTree Measure Centroid -> [Centroid]
ftToList ft = case FT.viewl ft of
  EmptyL -> []
  x :< rest -> x : ftToList rest

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
  let newBufLen = tdBufferLen td + 1
      td' =
        td
          { tdBuffer = Centroid x w : tdBuffer td,
            tdBufferLen = newBufLen,
            tdTotalWeight = tdTotalWeight td + w,
            tdMin = min x (tdMin td),
            tdMax = max x (tdMax td)
          }
   in if newBufLen >= tdBufferCap td'
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
  | tdBufferLen td == 0 && mCount (FT.measure (tdCentroids td)) <= 1 = td
  | otherwise =
      let allItems = ftToList (tdCentroids td) ++ tdBuffer td
          sorted = sortBy (comparing cMean) allItems
          n = tdTotalWeight td
          delta = tdDelta td
          merged = greedyMerge delta n sorted
       in td
            { tdCentroids = FT.fromList merged,
              tdBuffer = [],
              tdBufferLen = 0
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
-- Uses 'Data.FingerTree.split' for O(log n) lookup by cumulative weight.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> quantile 0.5 td
-- Just ...   -- approximately 500
-- >>> quantile 0.0 td
-- Just 1.0
quantile :: Double -> TDigest -> Maybe Double
quantile q td0
  | numCentroids == 0 = Nothing
  | numCentroids == 1 =
      case FT.viewl cs of
        c :< _ -> Just (cMean c)
        EmptyL -> Nothing
  | otherwise = Just (findQuantile (clamp 0 1 q))
  where
    td = if tdBufferLen td0 == 0 then td0 else compress td0
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td
    numCentroids = mCount (FT.measure cs)

    findQuantile :: Double -> Double
    findQuantile q' =
      let target = q' * n
          -- Split the tree at the point where cumulative weight exceeds target.
          -- After the split: left contains centroids whose cumulative weight <= target,
          -- right starts with the centroid that pushes cumulative weight past target.
          (left, right) = FT.split (\m -> mWeight m > target) cs
          leftWeight = mWeight (FT.measure left)
          leftCount = mCount (FT.measure left)
       in case FT.viewl right of
            EmptyL ->
              -- target is beyond all centroids; use the last centroid
              case FT.viewr left of
                _ :> lastC -> interpolateRight lastC (leftWeight - cWeight lastC) target
                EmptyR -> mx
            cur :< rightRest ->
              let cumulative = leftWeight -- weight before cur
                  i = leftCount -- 0-based index of cur
               in interpolateAt i cumulative cur rightRest target

    interpolateAt :: Int -> Double -> Centroid -> FingerTree Measure Centroid -> Double -> Double
    interpolateAt i cumulative c rest target
      -- Left boundary: interpolate between min and first centroid
      | i == 0 && target < cWeight c / 2 =
          if cWeight c == 1
            then mn
            else mn + (cMean c - mn) * (target / (cWeight c / 2))
      -- Right boundary: interpolate between last centroid and max
      | i == numCentroids - 1 =
          if target > n - cWeight c / 2
            then
              if cWeight c == 1
                then mx
                else
                  let remaining = n - cWeight c / 2
                   in cMean c + (mx - cMean c) * ((target - remaining) / (cWeight c / 2))
            else cMean c
      -- Middle: interpolate between adjacent centroid midpoints
      | otherwise =
          let mid = cumulative + cWeight c / 2
           in case FT.viewl rest of
                nextC :< _ ->
                  let nextMid = cumulative + cWeight c + cWeight nextC / 2
                   in if target <= nextMid
                        then
                          let frac =
                                if nextMid == mid
                                  then 0.5
                                  else (target - mid) / (nextMid - mid)
                           in cMean c + frac * (cMean nextC - cMean c)
                        else
                          -- Need to advance to the next centroid
                          interpolateAt (i + 1) (cumulative + cWeight c) nextC (ftTail rest) target
                EmptyL -> cMean c

    interpolateRight :: Centroid -> Double -> Double -> Double
    interpolateRight c cumulative target =
      if target > n - cWeight c / 2
        then
          if cWeight c == 1
            then mx
            else
              let remaining = n - cWeight c / 2
               in cMean c + (mx - cMean c) * ((target - remaining) / (cWeight c / 2))
        else cMean c

    ftTail :: FingerTree Measure Centroid -> FingerTree Measure Centroid
    ftTail ft = case FT.viewl ft of
      EmptyL -> FT.empty
      _ :< r -> r

-- ---------------------------------------------------------------------------
-- CDF estimation
-- ---------------------------------------------------------------------------

-- | Estimate the cumulative distribution function (CDF) at value @x@.
--
-- Returns 'Nothing' if the digest is empty. Otherwise returns 'Just' a
-- value in [0, 1] representing the estimated fraction of values less than
-- or equal to @x@.
--
-- Uses 'Data.FingerTree.split' to locate the centroid neighbourhood by
-- cumulative weight, then interpolates between centroid midpoints.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> cdf 500.0 td
-- Just ...   -- approximately 0.5
-- >>> cdf 0.0 td
-- Just 0.0
cdf :: Double -> TDigest -> Maybe Double
cdf x td0
  | numCentroids == 0 = Nothing
  | x <= mn = Just 0
  | x >= mx = Just 1
  | otherwise = Just (walkCdf x (ftToList cs))
  where
    td = if tdBufferLen td0 == 0 then td0 else compress td0
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td
    numCentroids = mCount (FT.measure cs)

    walkCdf :: Double -> [Centroid] -> Double
    walkCdf x' centroids = go 0 0 centroids
      where
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
              case rest of
                [] -> (cumulative + cWeight c / 2) / n
                (nextC : _) ->
                  let mid = cumulative + cWeight c / 2
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
  let otherTd = if tdBufferLen other == 0 then other else compress other
      otherCs = ftToList (tdCentroids otherTd)
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
--
-- Uses the monoidal measure for O(1) count after compression.
centroidCount :: TDigest -> Int
centroidCount td =
  let td' = if tdBufferLen td == 0 then td else compress td
   in mCount (FT.measure (tdCentroids td'))

-- ---------------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------------

clamp :: Double -> Double -> Double -> Double
clamp lo hi x
  | x < lo = lo
  | x > hi = hi
  | otherwise = x

-- ---------------------------------------------------------------------------
-- Additional accessors (for TDigestM interop)
-- ---------------------------------------------------------------------------

-- | Return the list of centroids (sorted by mean) after compressing.
centroidList :: TDigest -> [Centroid]
centroidList td =
  let td' = if tdBufferLen td == 0 then td else compress td
   in ftToList (tdCentroids td')

-- | Return the compression parameter (delta).
getDelta :: TDigest -> Double
getDelta = tdDelta

-- | Return the minimum value seen.
getMin :: TDigest -> Double
getMin = tdMin

-- | Return the maximum value seen.
getMax :: TDigest -> Double
getMax = tdMax

-- | Reconstruct a TDigest from its components.
fromComponents :: [Centroid] -> Double -> Double -> Double -> Double -> TDigest
fromComponents cs tw mn mx delta =
  TDigest
    { tdCentroids = FT.fromList cs,
      tdBuffer = [],
      tdBufferLen = 0,
      tdTotalWeight = tw,
      tdMin = mn,
      tdMax = mx,
      tdDelta = delta,
      tdBufferCap = ceiling (delta * 5)
    }
