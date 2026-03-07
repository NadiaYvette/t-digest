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
-- @fingertree@ package with a four-component monoidal measure
-- @(weight, count, maxMean, weightedMeanSum)@ enabling:
--
-- * O(log n) insertion via split-by-mean (no buffering needed)
-- * O(log n) quantile queries via split-by-cumulative-weight
-- * O(log n) CDF queries via split-by-mean
-- * O(δ log n) compression via split-based greedy merge
-- * O(1) total weight, centroid count, and chunk mean computation
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
import Data.List (foldl')

-- ---------------------------------------------------------------------------
-- Measure (monoidal annotation for the finger tree)
-- ---------------------------------------------------------------------------

-- | Monoidal measure with four components:
--
-- * @mWeight@: sum of centroid weights (for quantile split-by-weight)
-- * @mCount@: number of centroids (O(1) count)
-- * @mMaxMean@: maximum centroid mean (for split-by-mean, monotone over sorted sequence)
-- * @mMeanWeightSum@: sum of @mean * weight@ (for O(1) weighted mean of any subtree)
--
-- The @mMeanWeightSum@ component is what enables O(δ log n) compression:
-- when splitting the tree into chunks at K1 scale function boundaries,
-- each chunk's merged centroid has mean = @mMeanWeightSum / mWeight@,
-- computed in O(1) from the measure without touching individual centroids.
data Measure = Measure
  { mWeight :: {-# UNPACK #-} !Double,
    mCount :: {-# UNPACK #-} !Int,
    mMaxMean :: {-# UNPACK #-} !Double,
    mMeanWeightSum :: {-# UNPACK #-} !Double
  }
  deriving (Show)

instance Semigroup Measure where
  (Measure w1 c1 mm1 mws1) <> (Measure w2 c2 mm2 mws2) =
    Measure (w1 + w2) (c1 + c2) (max mm1 mm2) (mws1 + mws2)

instance Monoid Measure where
  mempty = Measure 0 0 (-(1 / 0)) 0

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- | A single centroid in the t-digest, representing a cluster of nearby values.
data Centroid = Centroid
  { -- | Weighted mean of all values merged into this centroid.
    cMean :: {-# UNPACK #-} !Double,
    -- | Total weight (count) of values in this centroid.
    cWeight :: {-# UNPACK #-} !Double
  }
  deriving (Show)

instance Measured Measure Centroid where
  measure c = Measure (cWeight c) 1 (cMean c) (cMean c * cWeight c)

-- | The t-digest data structure for online quantile estimation.
--
-- Centroids are stored in a 'FingerTree' sorted by mean. New values are
-- inserted directly via O(log n) split-by-mean. Compression uses O(δ)
-- split-by-weight operations, each O(log n), merging each chunk into a
-- single centroid via the @mMeanWeightSum@ measure component.
data TDigest = TDigest
  { tdCentroids :: !(FingerTree Measure Centroid),
    tdTotalWeight :: !Double,
    tdMin :: !Double,
    tdMax :: !Double,
    tdDelta :: !Double,
    tdMaxCentroids :: {-# UNPACK #-} !Int
  }
  deriving (Show)

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create an empty t-digest with the default compression parameter (delta = 100).
empty :: TDigest
empty = emptyWith 100

-- | Create an empty t-digest with a given compression parameter.
emptyWith :: Double -> TDigest
emptyWith delta =
  TDigest
    { tdCentroids = FT.empty,
      tdTotalWeight = 0,
      tdMin = 1 / 0,
      tdMax = -(1 / 0),
      tdDelta = delta,
      tdMaxCentroids = ceiling (delta * 3)
    }

-- ---------------------------------------------------------------------------
-- Scale function K_1
-- ---------------------------------------------------------------------------

-- | K_1 scale function: k(q, δ) = (δ / (2π)) * asin(2q - 1)
kScale :: Double -> Double -> Double
kScale delta q = (delta / (2 * pi)) * asin (2 * q - 1)

-- | K_1 inverse: q(k, δ) = (1 + sin(2πk / δ)) / 2
kScaleInv :: Double -> Double -> Double
kScaleInv delta k = (1 + sin (2 * pi * k / delta)) / 2

-- ---------------------------------------------------------------------------
-- FingerTree helpers
-- ---------------------------------------------------------------------------

ftToList :: FingerTree Measure Centroid -> [Centroid]
ftToList ft = case FT.viewl ft of
  EmptyL -> []
  x :< rest -> x : ftToList rest

splitByMean :: Double -> FingerTree Measure Centroid -> (FingerTree Measure Centroid, FingerTree Measure Centroid)
splitByMean x = FT.split (\m -> mMaxMean m >= x)

-- ---------------------------------------------------------------------------
-- Adding values
-- ---------------------------------------------------------------------------

-- | Add a single value with weight 1 to the digest. O(log n).
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1

-- | Add a value with a given weight to the digest. O(log n).
--
-- Splits the finger tree at the insertion point by mean, checks whether
-- the new value can be merged with the nearest existing centroid without
-- violating the K1 scale function constraint, and either merges or inserts.
-- Auto-compresses when centroid count exceeds @3 * delta@.
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
            let (left, right) = splitByMean x cs
                leftWeight = mWeight (FT.measure left)
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

-- | Try to merge with nearest neighbor; insert if neither allows merging.
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
      k = kScale delta

      leftNeighbor = case FT.viewr left of
        EmptyR -> Nothing
        leftRest :> lc ->
          let cumBefore = mWeight (FT.measure leftRest)
              proposed = cWeight lc + cWeight newC
              q0 = cumBefore / n
              q1 = (cumBefore + proposed) / n
              canMerge = k q1 - k q0 <= 1.0
              dist = abs (cMean lc - x)
           in if canMerge then Just (leftRest, lc, dist) else Nothing

      rightNeighbor = case FT.viewl right of
        EmptyL -> Nothing
        rc :< rightRest ->
          let proposed = cWeight rc + cWeight newC
              q0 = leftWeight / n
              q1 = (leftWeight + proposed) / n
              canMerge = k q1 - k q0 <= 1.0
              dist = abs (cMean rc - x)
           in if canMerge then Just (rightRest, rc, dist) else Nothing
   in case (leftNeighbor, rightNeighbor) of
        (Just (leftRest, lc, ldist), Just (rightRest, rc, rdist))
          | ldist <= rdist ->
              (leftRest |> mergeCentroid lc newC) FT.>< right
          | otherwise ->
              left FT.>< (mergeCentroid rc newC <| rightRest)
        (Just (leftRest, lc, _), Nothing) ->
          (leftRest |> mergeCentroid lc newC) FT.>< right
        (Nothing, Just (rightRest, rc, _)) ->
          left FT.>< (mergeCentroid rc newC <| rightRest)
        (Nothing, Nothing) ->
          left FT.>< (newC <| right)

-- | Merge two centroids using weighted mean.
mergeCentroid :: Centroid -> Centroid -> Centroid
mergeCentroid a b =
  let w = cWeight a + cWeight b
      m = (cMean a * cWeight a + cMean b * cWeight b) / w
   in Centroid m w

-- ---------------------------------------------------------------------------
-- Compression (split-based greedy merge)
-- ---------------------------------------------------------------------------

-- | Compress the digest by merging centroids within each K1 scale function
-- unit interval.
--
-- Computes the K1 unit boundaries @q_j = k⁻¹(j)@ for integer @j@,
-- splits the tree at each boundary by cumulative weight (O(log n) per
-- split), and merges each chunk into a single centroid using the
-- @mMeanWeightSum@ measure (O(1) per chunk).
--
-- Total complexity: O(δ log n) where n is the centroid count.
compress :: TDigest -> TDigest
compress td
  | cnt <= 1 = td
  | otherwise =
      let n = tdTotalWeight td
          delta = tdDelta td
          cs = tdCentroids td
          -- K1 range: k(0) = -delta/2, k(1) = delta/2
          -- Integer unit boundaries from ceil(k(0)) to floor(k(1))
          kMin = kScale delta 0 -- = -delta/2
          kMax = kScale delta 1 -- = +delta/2
          jMin = ceiling kMin :: Int
          jMax = floor kMax :: Int
          -- Build boundaries: q values at each integer k-value
          boundaries = [kScaleInv delta (fromIntegral j) * n | j <- [jMin + 1 .. jMax]]
          -- Split-and-merge at each boundary
          merged = splitMerge boundaries cs
       in td {tdCentroids = merged}
  where
    cnt = mCount (FT.measure (tdCentroids td))

-- | Split a finger tree at cumulative weight boundaries and merge each
-- chunk into a single centroid.
splitMerge :: [Double] -> FingerTree Measure Centroid -> FingerTree Measure Centroid
splitMerge boundaries tree = go boundaries tree FT.empty
  where
    go [] remaining acc =
      -- Last chunk: everything remaining
      case mergeChunk remaining of
        Nothing -> acc
        Just c -> acc |> c
    go (b : bs) remaining acc =
      let (chunk, rest) = FT.split (\m -> mWeight m > b) remaining
       in case mergeChunk chunk of
            Nothing -> go bs rest acc
            Just c -> go bs rest (acc |> c)

-- | Merge all centroids in a finger tree chunk into a single centroid
-- using the measure. O(1) — no need to traverse individual centroids.
mergeChunk :: FingerTree Measure Centroid -> Maybe Centroid
mergeChunk ft
  | w == 0 = Nothing
  | otherwise = Just (Centroid (mws / w) w)
  where
    m = FT.measure ft
    w = mWeight m
    mws = mMeanWeightSum m

-- ---------------------------------------------------------------------------
-- Quantile estimation
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile @q@ (0 <= q <= 1).
--
-- O(log n) via 'FT.split' on cumulative weight.
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
          (left, right) = FT.split (\m -> mWeight m > target) cs
          leftWeight = mWeight (FT.measure left)
          leftCount = mCount (FT.measure left)
       in case FT.viewl right of
            EmptyL ->
              case FT.viewr left of
                _ :> lastC -> interpolateRight lastC (leftWeight - cWeight lastC) target
                EmptyR -> mx
            cur :< rightRest ->
              interpolateAt leftCount leftWeight cur left rightRest target

    interpolateAt :: Int -> Double -> Centroid -> FingerTree Measure Centroid -> FingerTree Measure Centroid -> Double -> Double
    interpolateAt i cumulative c left rest target
      | i == 0 && target < cWeight c / 2 =
          if cWeight c == 1
            then mn
            else mn + (cMean c - mn) * (target / (cWeight c / 2))
      | i == numCentroids - 1 =
          if target > n - cWeight c / 2
            then
              if cWeight c == 1
                then mx
                else
                  let remaining = n - cWeight c / 2
                   in cMean c + (mx - cMean c) * ((target - remaining) / (cWeight c / 2))
            else cMean c
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
-- O(log n) via 'FT.split' on mean value using the max-mean measure.
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
      let (left, right) = splitByMean x' cs
       in case (FT.viewr left, FT.viewl right) of
            (EmptyR, rc :< _) ->
              cdfAtFirst rc x'
            (_, EmptyL) ->
              case FT.viewr left of
                lRest :> lc ->
                  cdfAtLast lc (mWeight (FT.measure lRest)) x'
                EmptyR -> 1.0
            (lRest :> lc, rc :< _) ->
              let lcCum = mWeight (FT.measure lRest)
                  lcIdx = mCount (FT.measure lRest)
                  rcIdx = mCount (FT.measure left)
               in if x' <= cMean lc
                    then
                      if lcIdx == 0
                        then cdfAtFirst lc x'
                        else case FT.viewr lRest of
                          llRest :> llc ->
                            cdfBetween llc (mWeight (FT.measure llRest)) lc lcCum x'
                          EmptyR -> cdfAtFirst lc x'
                    else
                      if rcIdx == numCentroids - 1 && x' > cMean rc
                        then cdfAtLast rc (mWeight (FT.measure left)) x'
                        else cdfBetween lc lcCum rc (mWeight (FT.measure left)) x'

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

    cdfBetween :: Centroid -> Double -> Centroid -> Double -> Double -> Double
    cdfBetween lc lcCum rc rcCum x'
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
merge :: TDigest -> TDigest -> TDigest
merge td other =
  let otherCs = ftToList (tdCentroids other)
      combined = foldl' (\d c -> addWeighted (cMean c) (cWeight c) d) td otherCs
   in compress combined

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Return the total weight of all values added to the digest.
totalWeight :: TDigest -> Double
totalWeight = tdTotalWeight

-- | Return the number of centroids. O(1).
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

centroidList :: TDigest -> [Centroid]
centroidList = ftToList . tdCentroids

getDelta :: TDigest -> Double
getDelta = tdDelta

getMin :: TDigest -> Double
getMin = tdMin

getMax :: TDigest -> Double
getMax = tdMax

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
