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
-- @fingertree@ package with a three-component monoidal measure
-- @(weight, count, maxMean)@ enabling:
--
-- * O(log n) insertion via split-by-mean (no buffering needed)
-- * O(log n) quantile queries via split-by-cumulative-weight
-- * O(log n) CDF queries via split-by-mean
-- * O(1) total weight and centroid count
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

-- | Monoidal measure tracking total weight, centroid count, and maximum mean
-- in a subtree. The max-mean component enables O(log n) splitting by mean
-- value (for sorted-order insertion and CDF queries), while the weight
-- component enables O(log n) splitting by cumulative weight (for quantile
-- queries).
data Measure = Measure
  { mWeight :: {-# UNPACK #-} !Double,
    mCount :: {-# UNPACK #-} !Int,
    -- | Maximum centroid mean in this subtree. Since centroids are kept
    -- sorted by mean, this equals the rightmost centroid's mean. The
    -- monotonicity of max-mean over a sorted sequence is what makes
    -- @FT.split (\m -> mMaxMean m >= x)@ find the correct insertion point.
    mMaxMean :: {-# UNPACK #-} !Double
  }
  deriving (Show)

instance Semigroup Measure where
  (Measure w1 c1 mm1) <> (Measure w2 c2 mm2) =
    Measure (w1 + w2) (c1 + c2) (max mm1 mm2)

instance Monoid Measure where
  mempty = Measure 0 0 (-(1 / 0)) -- -Infinity for max identity

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
  measure c = Measure (cWeight c) 1 (cMean c)

-- | The t-digest data structure for online quantile estimation.
--
-- Internally, it maintains a 'FingerTree' of 'Centroid's sorted by mean.
-- New values are inserted directly into the tree at the correct sorted
-- position in O(log n) using split-by-mean, merging with the nearest
-- existing centroid when the K1 scale function constraint allows.
--
-- An explicit 'compress' (greedy merge) pass is available for use after
-- 'merge' operations or to compact the digest when centroid count grows
-- beyond the ideal bound.
data TDigest = TDigest
  { -- | Sorted (by mean) finger tree of centroids.
    tdCentroids :: !(FingerTree Measure Centroid),
    -- | Sum of all weights ever added.
    tdTotalWeight :: !Double,
    -- | Minimum value seen.
    tdMin :: !Double,
    -- | Maximum value seen.
    tdMax :: !Double,
    -- | Compression parameter (typically 100).
    tdDelta :: !Double,
    -- | Maximum centroid count before auto-compress.
    tdMaxCentroids :: {-# UNPACK #-} !Int
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
      tdTotalWeight = 0,
      tdMin = 1 / 0, -- +Infinity
      tdMax = -(1 / 0), -- -Infinity
      tdDelta = delta,
      tdMaxCentroids = ceiling (delta * 3)
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

-- | Split the tree to find where mean >= x. The left subtree has all
-- centroids with mean < x, the right subtree starts at mean >= x.
-- O(log n).
splitByMean :: Double -> FingerTree Measure Centroid -> (FingerTree Measure Centroid, FingerTree Measure Centroid)
splitByMean x = FT.split (\m -> mMaxMean m >= x)

-- ---------------------------------------------------------------------------
-- Adding values
-- ---------------------------------------------------------------------------

-- | Add a single value with weight 1 to the digest.
--
-- O(log n) via direct finger tree insertion.
--
-- >>> quantile 0.5 (add 42.0 empty)
-- Just 42.0
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1

-- | Add a value with a given weight to the digest.
--
-- O(log n). Splits the finger tree at the insertion point by mean,
-- checks whether the new value can be merged with the nearest existing
-- centroid (left or right neighbor) without violating the K1 scale
-- function constraint, and either merges or inserts a new centroid.
--
-- >>> totalWeight (addWeighted 10.0 5.0 empty)
-- 5.0
addWeighted :: Double -> Double -> TDigest -> TDigest
addWeighted x w td =
  let n = tdTotalWeight td + w
      newMin = min x (tdMin td)
      newMax = max x (tdMax td)
      delta = tdDelta td
      cs = tdCentroids td
      newC = Centroid x w
      td' =
        if FT.null cs
          then
            td
              { tdCentroids = FT.singleton newC,
                tdTotalWeight = n,
                tdMin = newMin,
                tdMax = newMax
              }
          else
            let -- Split at insertion point: left has mean < x, right has mean >= x
                (left, right) = splitByMean x cs
                leftMeasure = FT.measure left
                leftWeight = mWeight leftMeasure
                -- Try merging with the nearest centroid
                result = tryMergeNeighbor delta n leftWeight left right newC
             in td
                  { tdCentroids = result,
                    tdTotalWeight = n,
                    tdMin = newMin,
                    tdMax = newMax
                  }
   in if mCount (FT.measure (tdCentroids td')) > tdMaxCentroids td'
        then compress td'
        else td'

-- | Try to merge a new centroid with the nearest existing centroid.
-- If the K1 constraint allows merging with either the left neighbor
-- (rightmost of left subtree) or the right neighbor (leftmost of right
-- subtree), merge with the closer one. Otherwise insert as a new centroid.
tryMergeNeighbor ::
  Double ->
  Double ->
  Double ->
  FingerTree Measure Centroid ->
  FingerTree Measure Centroid ->
  Centroid ->
  FingerTree Measure Centroid
tryMergeNeighbor delta n leftWeight left right newC =
  let x = cMean newC
      -- Check left neighbor (rightmost of left subtree)
      leftNeighbor = case FT.viewr left of
        EmptyR -> Nothing
        leftRest :> lc ->
          let cumBefore = mWeight (FT.measure leftRest)
              proposed = cWeight lc + cWeight newC
              q0 = cumBefore / n
              q1 = (cumBefore + proposed) / n
              k = kScale delta
              canMerge = k q1 - k q0 <= 1.0
              dist = abs (cMean lc - x)
           in if canMerge
                then Just (leftRest, lc, dist, cumBefore)
                else Nothing

      -- Check right neighbor (leftmost of right subtree)
      rightNeighbor = case FT.viewl right of
        EmptyL -> Nothing
        rc :< rightRest ->
          let cumBefore = leftWeight
              proposed = cWeight rc + cWeight newC
              q0 = cumBefore / n
              q1 = (cumBefore + proposed) / n
              k = kScale delta
              canMerge = k q1 - k q0 <= 1.0
              dist = abs (cMean rc - x)
           in if canMerge
                then Just (rightRest, rc, dist, cumBefore)
                else Nothing
   in case (leftNeighbor, rightNeighbor) of
        -- Merge with left neighbor (closer or only option)
        (Just (leftRest, lc, ldist, _), Just (_, rc, rdist, _))
          | ldist <= rdist ->
              let merged = mergeCentroid lc newC
               in (leftRest |> merged) FT.>< right
          | otherwise ->
              let merged = mergeCentroid rc newC
                  (_ :< rightRest) = FT.viewl right
               in left FT.>< (merged <| rightRest)
        (Just (leftRest, lc, _, _), Nothing) ->
          let merged = mergeCentroid lc newC
           in (leftRest |> merged) FT.>< right
        (Nothing, Just (_, rc, _, _)) ->
          let merged = mergeCentroid rc newC
              (_ :< rightRest) = FT.viewl right
           in left FT.>< (merged <| rightRest)
        -- Cannot merge with either neighbor: insert new centroid
        (Nothing, Nothing) ->
          left FT.>< (newC <| right)

-- | Merge a centroid into another using weighted mean.
mergeCentroid :: Centroid -> Centroid -> Centroid
mergeCentroid a b =
  let w = cWeight a + cWeight b
      m = (cMean a * cWeight a + cMean b * cWeight b) / w
   in Centroid m w

-- ---------------------------------------------------------------------------
-- Compression (greedy merge)
-- ---------------------------------------------------------------------------

-- | Compress the digest by performing a greedy merge pass over all centroids.
--
-- This is the standard Dunning greedy merge: walk centroids left to right
-- (sorted by mean) and merge adjacent ones when the K1 scale function
-- constraint allows. The result is a minimal set of centroids that still
-- satisfies the accuracy guarantees.
--
-- With O(log n) incremental insertion, explicit compression is typically
-- only needed after 'merge' operations. It is O(n) in the number of
-- centroids (which is itself O(delta)).
compress :: TDigest -> TDigest
compress td
  | cnt <= 1 = td
  | otherwise =
      let sorted = ftToList (tdCentroids td)
          n = tdTotalWeight td
          delta = tdDelta td
          merged = greedyMerge delta n sorted
       in td {tdCentroids = FT.fromList merged}
  where
    cnt = mCount (FT.measure (tdCentroids td))

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

-- ---------------------------------------------------------------------------
-- Quantile estimation
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile @q@ (0 <= q <= 1).
--
-- Returns 'Nothing' if the digest is empty, otherwise 'Just' the estimated
-- value. The q parameter is clamped to [0, 1].
--
-- O(log n) via 'FT.split' on cumulative weight.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> quantile 0.5 td
-- Just ...   -- approximately 500
-- >>> quantile 0.0 td
-- Just 1.0
quantile :: Double -> TDigest -> Maybe Double
quantile q td
  | numCentroids == 0 = Nothing
  | numCentroids == 1 =
      case FT.viewl cs of
        c :< _ -> Just (cMean c)
        EmptyL -> Nothing
  | otherwise = Just (findQuantile (clamp 0 1 q))
  where
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td
    numCentroids = mCount (FT.measure cs)

    findQuantile :: Double -> Double
    findQuantile q' =
      let target = q' * n
          -- Split the tree where cumulative weight exceeds target
          (left, right) = FT.split (\m -> mWeight m > target) cs
          leftWeight = mWeight (FT.measure left)
          leftCount = mCount (FT.measure left)
       in case FT.viewl right of
            EmptyL ->
              -- target beyond all centroids: use last
              case FT.viewr left of
                _ :> lastC -> interpolateRight lastC (leftWeight - cWeight lastC) target
                EmptyR -> mx
            cur :< rightRest ->
              interpolateAt leftCount leftWeight cur left rightRest target

    interpolateAt :: Int -> Double -> Centroid -> FingerTree Measure Centroid -> FingerTree Measure Centroid -> Double -> Double
    interpolateAt i cumulative c left rest target
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
                          -- Advance: split again from the rest
                          let newLeft = left FT.>< FT.singleton c
                           in interpolateAt (i + 1) (cumulative + cWeight c) nextC newLeft (ftTail rest) target
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
-- O(log n) via 'FT.split' on mean value using the max-mean measure.
--
-- >>> let td = foldl (flip add) empty [1..1000]
-- >>> cdf 500.0 td
-- Just ...   -- approximately 0.5
-- >>> cdf 0.0 td
-- Just 0.0
cdf :: Double -> TDigest -> Maybe Double
cdf x td
  | numCentroids == 0 = Nothing
  | x <= mn = Just 0
  | x >= mx = Just 1
  | otherwise = Just (findCdf x)
  where
    cs = tdCentroids td
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td
    numCentroids = mCount (FT.measure cs)

    findCdf :: Double -> Double
    findCdf x' =
      -- Split at the first centroid with mean >= x'
      let (left, right) = splitByMean x' cs
          leftWeight = mWeight (FT.measure left)
          leftCount = mCount (FT.measure left)
       in case (FT.viewr left, FT.viewl right) of
            -- x' is before all centroids
            (EmptyR, rc :< _) ->
              cdfAtFirst rc x'
            -- x' is after all centroids
            (_, EmptyL) ->
              case FT.viewr left of
                lRest :> lc ->
                  cdfAtLast lc (mWeight (FT.measure lRest)) x'
                EmptyR -> 1.0
            -- x' falls between left and right
            (lRest :> lc, rc :< _) ->
              let lcCum = mWeight (FT.measure lRest) -- weight before lc
                  lcIdx = mCount (FT.measure lRest)
                  rcIdx = leftCount
               in if x' <= cMean lc
                    then
                      -- x' is at or before lc
                      if lcIdx == 0
                        then cdfAtFirst lc x'
                        else
                          -- Find the predecessor of lc
                          case FT.viewr lRest of
                            llRest :> llc ->
                              let prevCum = mWeight (FT.measure llRest)
                               in cdfBetween llc (mCount (FT.measure llRest)) prevCum lc lcIdx lcCum x'
                            EmptyR -> cdfAtFirst lc x'
                    else
                      -- x' is between lc and rc
                      if rcIdx == numCentroids - 1 && x' > cMean rc
                        then cdfAtLast rc leftWeight x'
                        else cdfBetween lc lcIdx lcCum rc rcIdx leftWeight x'

    cdfAtFirst :: Centroid -> Double -> Double
    cdfAtFirst c x'
      | x' < cMean c =
          let innerW = cWeight c / 2
              frac =
                if cMean c == mn
                  then 1.0
                  else (x' - mn) / (cMean c - mn)
           in (innerW * frac) / n
      | otherwise = (cWeight c / 2) / n

    cdfAtLast :: Centroid -> Double -> Double -> Double
    cdfAtLast c cumBefore x'
      | x' > cMean c =
          let halfW = cWeight c / 2
              rightW = n - cumBefore - halfW
              frac =
                if mx == cMean c
                  then 0.0
                  else (x' - cMean c) / (mx - cMean c)
           in (cumBefore + halfW + rightW * frac) / n
      | otherwise = (cumBefore + cWeight c / 2) / n

    -- Interpolate CDF between two adjacent centroids
    cdfBetween :: Centroid -> Int -> Double -> Centroid -> Int -> Double -> Double -> Double
    cdfBetween lc _lcIdx lcCum rc _rcIdx rcCum x'
      | x' <= cMean lc = (lcCum + cWeight lc / 2) / n
      | x' >= cMean rc = (rcCum + cWeight rc / 2) / n
      | otherwise =
          let lMid = lcCum + cWeight lc / 2
              rMid = rcCum + cWeight rc / 2
              frac =
                if cMean lc == cMean rc
                  then 0.5
                  else (x' - cMean lc) / (cMean rc - cMean lc)
           in (lMid + frac * (rMid - lMid)) / n

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge two t-digests into one.
--
-- Inserts all centroids from the second digest into the first using
-- O(log n) insertion, then compresses the result with a greedy merge pass.
--
-- >>> let td1 = foldl (flip add) empty [1..500]
-- >>> let td2 = foldl (flip add) empty [501..1000]
-- >>> totalWeight (merge td1 td2)
-- 1000.0
merge :: TDigest -> TDigest -> TDigest
merge td other =
  let otherCs = ftToList (tdCentroids other)
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

-- | Return the number of centroids.
--
-- O(1) via the monoidal measure.
centroidCount :: TDigest -> Int
centroidCount = mCount . FT.measure . tdCentroids

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

-- | Return the list of centroids (sorted by mean).
centroidList :: TDigest -> [Centroid]
centroidList = ftToList . tdCentroids

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
      tdTotalWeight = tw,
      tdMin = mn,
      tdMax = mx,
      tdDelta = delta,
      tdMaxCentroids = ceiling (delta * 3)
    }
