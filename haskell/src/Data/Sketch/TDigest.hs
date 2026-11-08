{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveGeneric #-}

-- |
-- Module      : Data.Sketch.TDigest
-- Description : Dunning t-digest with flat PrimArray Double storage
-- Copyright   : (c) Nadia Yvette Chambers, 2025
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
--
-- A pure functional implementation of the Dunning t-digest data structure,
-- backed by unboxed, cache-local 'PrimArray Double' buffers for both centroid
-- means and weights. Supports progressive scale functions (K0, K1, K2, K3) and
-- amortised \(O(1)\) ingestion via buffer-and-flush.
module Data.Sketch.TDigest
  ( -- * Types
    TDigest,
    Centroid (..),
    ScaleFunction (..),

    -- * Construction
    empty,
    emptyWith,
    emptyWithScale,

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
    getScaleFunction,

    -- * Scale Functions
    kScale,
    kScaleInv,

    -- * Primitive Array Operations
    sortCentroids,
    greedyMergePrim,

    -- * Reconstruction
    fromComponents,
  )
where

import Control.Monad.ST (ST, runST)
import Data.Primitive.PrimArray
  ( MutablePrimArray,
    PrimArray,
    copyMutablePrimArray,
    copyPrimArray,
    emptyPrimArray,
    indexPrimArray,
    newPrimArray,
    readPrimArray,
    sizeofPrimArray,
    unsafeFreezePrimArray,
    writePrimArray,
  )
import GHC.Generics (Generic)

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- | Scale function variants for governing centroid size allocation.
data ScaleFunction
  = K0 -- ^ Uniform / linear scale function
  | K1 -- ^ Arcsine scale function (default, high accuracy at both tails)
  | K2 -- ^ Log-odds / logarithmic scale function
  | K3 -- ^ Square root scale function
  deriving (Eq, Ord, Show, Enum, Bounded, Generic)

-- | A single centroid representing a cluster of values by weighted mean and weight.
data Centroid = Centroid
  { cMean :: {-# UNPACK #-} !Double,
    cWeight :: {-# UNPACK #-} !Double
  }
  deriving (Eq, Show, Generic)

-- | A persistent t-digest sketch backed by cache-local flat 'PrimArray Double' buffers.
data TDigest = TDigest
  { tdMeans :: !(PrimArray Double),
    tdWeights :: !(PrimArray Double),
    tdTotalWeight :: {-# UNPACK #-} !Double,
    tdMin :: {-# UNPACK #-} !Double,
    tdMax :: {-# UNPACK #-} !Double,
    tdDelta :: {-# UNPACK #-} !Double,
    tdScaleFunction :: !ScaleFunction,
    tdBufferMeans :: !(PrimArray Double),
    tdBufferWeights :: !(PrimArray Double)
  }
  deriving (Show, Generic)

instance Eq TDigest where
  td1 == td2 =
    tdDelta td1 == tdDelta td2
      && tdScaleFunction td1 == tdScaleFunction td2
      && tdTotalWeight td1 == tdTotalWeight td2
      && centroidList td1 == centroidList td2

-- ---------------------------------------------------------------------------
-- Scale functions
-- ---------------------------------------------------------------------------

-- | Forward scale function mapping quantile \(q \in [0, 1]\) to scale space.
kScale :: ScaleFunction -> Double -> Double -> Double
kScale K0 delta q = (delta / 2) * clamp 0 1 q
kScale K1 delta q = (delta / (2 * pi)) * asin (2 * clamp 0 1 q - 1)
kScale K2 delta q =
  let q' = clamp 1e-9 (1 - 1e-9) q
   in (delta / (2 * pi)) * log (q' / (1 - q'))
kScale K3 delta q =
  let q' = clamp 0 1 q
   in if q' <= 0.5
        then (delta / 2) * sqrt (2 * q')
        else (delta / 2) * (2 - sqrt (2 * (1 - q')))

-- | Inverse scale function mapping scale space \(k\) to quantile \(q \in [0, 1]\).
kScaleInv :: ScaleFunction -> Double -> Double -> Double
kScaleInv K0 delta k = clamp 0 1 (2 * k / delta)
kScaleInv K1 delta k = clamp 0 1 ((1 + sin (2 * pi * k / delta)) / 2)
kScaleInv K2 delta k =
  let z = exp ((2 * pi * k) / delta)
   in clamp 0 1 (z / (1 + z))
kScaleInv K3 delta k =
  let halfDelta = delta / 2
   in if k <= halfDelta
        then clamp 0 1 (0.5 * (k / halfDelta) ** 2)
        else clamp 0 1 (1 - 0.5 * (2 - k / halfDelta) ** 2)

clamp :: Double -> Double -> Double -> Double
clamp lo hi x = max lo (min hi x)

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Empty digest with default \(\delta = 100\) and \(K_1\) scale function.
empty :: TDigest
empty = emptyWith 100

-- | Empty digest with custom \(\delta\) and \(K_1\) scale function.
emptyWith :: Double -> TDigest
emptyWith = emptyWithScale K1

-- | Empty digest with custom scale function and \(\delta\).
emptyWithScale :: ScaleFunction -> Double -> TDigest
emptyWithScale sf delta =
  TDigest
    { tdMeans = emptyPrimArray,
      tdWeights = emptyPrimArray,
      tdTotalWeight = 0,
      tdMin = 1 / 0,
      tdMax = -(1 / 0),
      tdDelta = max 1 delta,
      tdScaleFunction = sf,
      tdBufferMeans = emptyPrimArray,
      tdBufferWeights = emptyPrimArray
    }

-- ---------------------------------------------------------------------------
-- Insertion
-- ---------------------------------------------------------------------------

-- | Insert an observation with unit weight.
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1.0

-- | Insert an observation with explicit positive weight.
addWeighted :: Double -> Double -> TDigest -> TDigest
addWeighted !x !w !td
  | isNaN x || isInfinite x || w <= 0 = td
  | otherwise =
      let !newMin = min (tdMin td) x
          !newMax = max (tdMax td) x
          !newTotal = tdTotalWeight td + w
          !bLen = sizeofPrimArray (tdBufferMeans td)
          !cap = max 64 (ceiling (5 * tdDelta td) :: Int)
       in if bLen + 1 >= cap
            then
              let (!bm, !bw) = appendBuffer x w (tdBufferMeans td) (tdBufferWeights td)
                  !uncompressed =
                    td
                      { tdTotalWeight = newTotal,
                        tdMin = newMin,
                        tdMax = newMax,
                        tdBufferMeans = bm,
                        tdBufferWeights = bw
                      }
               in compress uncompressed
            else
              let (!bm, !bw) = appendBuffer x w (tdBufferMeans td) (tdBufferWeights td)
               in td
                    { tdTotalWeight = newTotal,
                      tdMin = newMin,
                      tdMax = newMax,
                      tdBufferMeans = bm,
                      tdBufferWeights = bw
                    }

appendBuffer ::
  Double ->
  Double ->
  PrimArray Double ->
  PrimArray Double ->
  (PrimArray Double, PrimArray Double)
appendBuffer !m !w !bm !bw = runST $ do
  let !n = sizeofPrimArray bm
  mbm <- newPrimArray (n + 1)
  mbw <- newPrimArray (n + 1)
  copyPrimArray mbm 0 bm 0 n
  copyPrimArray mbw 0 bw 0 n
  writePrimArray mbm n m
  writePrimArray mbw n w
  fbm <- unsafeFreezePrimArray mbm
  fbw <- unsafeFreezePrimArray mbw
  pure (fbm, fbw)

-- ---------------------------------------------------------------------------
-- Compression & Greedy Merge
-- ---------------------------------------------------------------------------

-- | Flush pending buffer entries and compress centroids via greedy merge.
compress :: TDigest -> TDigest
compress td
  | sizeofPrimArray (tdBufferMeans td) == 0 && sizeofPrimArray (tdMeans td) <= ceiling (3 * tdDelta td) = td
  | otherwise =
      let totalW = tdTotalWeight td
       in if totalW <= 0
            then td {tdBufferMeans = emptyPrimArray, tdBufferWeights = emptyPrimArray}
            else
              let (!newMeans, !newWeights) = runST $ do
                    let !cLen = sizeofPrimArray (tdMeans td)
                        !bLen = sizeofPrimArray (tdBufferMeans td)
                        !totalItems = cLen + bLen
                    allM <- newPrimArray totalItems
                    allW <- newPrimArray totalItems
                    copyPrimArray allM 0 (tdMeans td) 0 cLen
                    copyPrimArray allW 0 (tdWeights td) 0 cLen
                    copyPrimArray allM cLen (tdBufferMeans td) 0 bLen
                    copyPrimArray allW cLen (tdBufferWeights td) 0 bLen

                    -- In-place quicksort by mean
                    sortCentroids allM allW 0 (totalItems - 1)

                    -- Single-pass greedy merge
                    outM <- newPrimArray totalItems
                    outW <- newPrimArray totalItems
                    mergedCount <-
                      greedyMergePrim
                        (tdScaleFunction td)
                        (tdDelta td)
                        totalW
                        allM
                        allW
                        totalItems
                        outM
                        outW

                    finalM <- newPrimArray mergedCount
                    finalW <- newPrimArray mergedCount
                    copyMutablePrimArray finalM 0 outM 0 mergedCount
                    copyMutablePrimArray finalW 0 outW 0 mergedCount
                    fM <- unsafeFreezePrimArray finalM
                    fW <- unsafeFreezePrimArray finalW
                    pure (fM, fW)
               in td
                    { tdMeans = newMeans,
                      tdWeights = newWeights,
                      tdBufferMeans = emptyPrimArray,
                      tdBufferWeights = emptyPrimArray
                    }

-- In-place quicksort + insertion sort for cache-local PrimArrays
sortCentroids :: MutablePrimArray s Double -> MutablePrimArray s Double -> Int -> Int -> ST s ()
sortCentroids mMeans mWeights lo hi
  | hi - lo <= 16 = insertionSortRange mMeans mWeights lo hi
  | otherwise = do
      pivotIdx <- partitionRange mMeans mWeights lo hi
      sortCentroids mMeans mWeights lo (pivotIdx - 1)
      sortCentroids mMeans mWeights (pivotIdx + 1) hi

partitionRange :: MutablePrimArray s Double -> MutablePrimArray s Double -> Int -> Int -> ST s Int
partitionRange mMeans mWeights lo hi = do
  pivotVal <- readPrimArray mMeans hi
  let loop i j
        | j >= hi = do
            swapCentroids mMeans mWeights i hi
            pure i
        | otherwise = do
            vj <- readPrimArray mMeans j
            if vj < pivotVal
              then do
                swapCentroids mMeans mWeights i j
                loop (i + 1) (j + 1)
              else loop i (j + 1)
  loop lo lo

swapCentroids :: MutablePrimArray s Double -> MutablePrimArray s Double -> Int -> Int -> ST s ()
swapCentroids mMeans mWeights i j
  | i == j = pure ()
  | otherwise = do
      mi <- readPrimArray mMeans i
      mj <- readPrimArray mMeans j
      writePrimArray mMeans i mj
      writePrimArray mMeans j mi
      wi <- readPrimArray mWeights i
      wj <- readPrimArray mWeights j
      writePrimArray mWeights i wj
      writePrimArray mWeights j wi

insertionSortRange :: MutablePrimArray s Double -> MutablePrimArray s Double -> Int -> Int -> ST s ()
insertionSortRange mMeans mWeights lo hi = go (lo + 1)
  where
    go i
      | i > hi = pure ()
      | otherwise = do
          mKey <- readPrimArray mMeans i
          wKey <- readPrimArray mWeights i
          j <- shiftDown (i - 1) mKey wKey
          writePrimArray mMeans (j + 1) mKey
          writePrimArray mWeights (j + 1) wKey
          go (i + 1)

    shiftDown j mKey wKey
      | j < lo = pure j
      | otherwise = do
          mj <- readPrimArray mMeans j
          if mj > mKey
            then do
              wj <- readPrimArray mWeights j
              writePrimArray mMeans (j + 1) mj
              writePrimArray mWeights (j + 1) wj
              shiftDown (j - 1) mKey wKey
            else pure j

-- Single-pass greedy merge
greedyMergePrim ::
  ScaleFunction ->
  Double ->
  Double ->
  MutablePrimArray s Double ->
  MutablePrimArray s Double ->
  Int ->
  MutablePrimArray s Double ->
  MutablePrimArray s Double ->
  ST s Int
greedyMergePrim sf delta totalW inMeans inWeights inLen outMeans outWeights
  | inLen == 0 = pure 0
  | otherwise = do
      m0 <- readPrimArray inMeans 0
      w0 <- readPrimArray inWeights 0
      let k q = kScale sf delta q
          go idx weightSoFar curM curW outIdx
            | idx >= inLen = do
                writePrimArray outMeans outIdx curM
                writePrimArray outWeights outIdx curW
                pure (outIdx + 1)
            | otherwise = do
                itemM <- readPrimArray inMeans idx
                itemW <- readPrimArray inWeights idx
                let proposed = curW + itemW
                    q0 = weightSoFar / totalW
                    q1 = (weightSoFar + proposed) / totalW
                    canMerge =
                      (proposed <= 1 && idx < inLen - 1)
                        || (k q1 - k q0 <= 1.0)
                if canMerge
                  then do
                    let newM = (curM * curW + itemM * itemW) / proposed
                    go (idx + 1) weightSoFar newM proposed outIdx
                  else do
                    writePrimArray outMeans outIdx curM
                    writePrimArray outWeights outIdx curW
                    go (idx + 1) (weightSoFar + curW) itemM itemW (outIdx + 1)
      go 1 0.0 m0 w0 0

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Estimate value at quantile \(q \in [0, 1]\).
quantile :: Double -> TDigest -> Maybe Double
quantile q rawTd
  | totalWeight td <= 0 || cc == 0 = Nothing
  | cc == 1 = Just (indexPrimArray (tdMeans td) 0)
  | otherwise = Just (findQuantile (clamp 0 1 q))
  where
    td = compress rawTd
    cc = sizeofPrimArray (tdMeans td)
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    findQuantile q' =
      let target = q' * n
          -- Compute prefix sums
          prefix = buildPrefixArray (tdWeights td) cc
          -- Find centroid containing target
          i = bsearchPrefixArray prefix cc target
          ci = max 0 (min (cc - 1) (i - 1))
          cM = indexPrimArray (tdMeans td) ci
          cW = indexPrimArray (tdWeights td) ci
          cumBefore = indexPrimArray prefix ci
          mid = cumBefore + cW / 2.0
       in if ci == 0 && target < cW / 2.0
            then
              if cW == 1
                then mn
                else mn + (cM - mn) * (target / (cW / 2.0))
            else
              if ci == cc - 1 && target > n - cW / 2.0
                then
                  let remaining = n - cW / 2.0
                   in if cW == 1
                        then mx
                        else cM + (mx - cM) * ((target - remaining) / (cW / 2.0))
                else walkOrInterpolate ci mid cM prefix target

    walkOrInterpolate ci mid cM prefix target
      | ci >= cc - 1 = cM
      | otherwise =
          let nextM = indexPrimArray (tdMeans td) (ci + 1)
              nextW = indexPrimArray (tdWeights td) (ci + 1)
              cumNext = indexPrimArray prefix (ci + 1)
              nextMid = cumNext + nextW / 2.0
           in if target <= nextMid
                then
                  let frac =
                        if nextMid == mid
                          then 0.5
                          else (target - mid) / (nextMid - mid)
                   in cM + frac * (nextM - cM)
                else walkOrInterpolate (ci + 1) nextMid nextM prefix target

-- | Estimate cumulative distribution function at value \(x\).
cdf :: Double -> TDigest -> Maybe Double
cdf x rawTd
  | totalWeight td <= 0 || cc == 0 = Nothing
  | x < mn = Just 0.0
  | x > mx = Just 1.0
  | mn == mx = Just 0.5
  | otherwise = Just (clamp 0 1 (findCdf x))
  where
    td = compress rawTd
    cc = sizeofPrimArray (tdMeans td)
    n = tdTotalWeight td
    mn = tdMin td
    mx = tdMax td

    findCdf x' =
      let prefix = buildPrefixArray (tdWeights td) cc
          m0 = indexPrimArray (tdMeans td) 0
          w0 = indexPrimArray (tdWeights td) 0
       in if x' < m0
            then
              let denom = m0 - mn
                  frac = if denom == 0 then 0.5 else (x' - mn) / denom
               in (frac * (w0 / 2.0)) / n
            else
              let mk = indexPrimArray (tdMeans td) (cc - 1)
                  wk = indexPrimArray (tdWeights td) (cc - 1)
               in if x' >= mk
                    then
                      let denom = mx - mk
                          frac = if denom == 0 then 0.5 else (x' - mk) / denom
                          cumK = indexPrimArray prefix (cc - 1)
                       in (cumK + wk / 2.0 + frac * (wk / 2.0)) / n
                    else scanAndInterp prefix 0

    scanAndInterp prefix i
      | i >= cc - 1 = 1.0
      | otherwise =
          let mi = indexPrimArray (tdMeans td) i
              mi1 = indexPrimArray (tdMeans td) (i + 1)
           in if x >= mi && x <= mi1
                then
                  let wi = indexPrimArray (tdWeights td) i
                      wi1 = indexPrimArray (tdWeights td) (i + 1)
                      ci = indexPrimArray prefix i
                      ci1 = indexPrimArray prefix (i + 1)
                      midi = ci + wi / 2.0
                      midi1 = ci1 + wi1 / 2.0
                      frac = if mi1 == mi then 0.5 else (x - mi) / (mi1 - mi)
                   in (midi + frac * (midi1 - midi)) / n
                else scanAndInterp prefix (i + 1)

buildPrefixArray :: PrimArray Double -> Int -> PrimArray Double
buildPrefixArray weights len = runST $ do
  arr <- newPrimArray (len + 1)
  writePrimArray arr 0 0.0
  let loop !i !acc
        | i >= len = pure ()
        | otherwise = do
            let w = indexPrimArray weights i
                acc' = acc + w
            writePrimArray arr (i + 1) acc'
            loop (i + 1) acc'
  loop 0 0.0
  unsafeFreezePrimArray arr

bsearchPrefixArray :: PrimArray Double -> Int -> Double -> Int
bsearchPrefixArray prefix len target = go 0 len
  where
    go lo hi
      | lo >= hi = lo
      | otherwise =
          let mid = (lo + hi + 1) `div` 2
              v = indexPrimArray prefix mid
           in if v <= target
                then go mid hi
                else go lo (mid - 1)

-- ---------------------------------------------------------------------------
-- Merging
-- ---------------------------------------------------------------------------

-- | Merge two digests.
merge :: TDigest -> TDigest -> TDigest
merge td1 td2 =
  let !c1 = compress td1
      !c2 = compress td2
      !n1 = sizeofPrimArray (tdMeans c1)
      !n2 = sizeofPrimArray (tdMeans c2)
      !totalN = n1 + n2
   in if totalN == 0
        then emptyWithScale (tdScaleFunction td1) (min (tdDelta td1) (tdDelta td2))
        else
          let (!combM, !combW) = runST $ do
                allM <- newPrimArray totalN
                allW <- newPrimArray totalN
                copyPrimArray allM 0 (tdMeans c1) 0 n1
                copyPrimArray allW 0 (tdWeights c1) 0 n1
                copyPrimArray allM n1 (tdMeans c2) 0 n2
                copyPrimArray allW n1 (tdWeights c2) 0 n2
                fM <- unsafeFreezePrimArray allM
                fW <- unsafeFreezePrimArray allW
                pure (fM, fW)
              !merged =
                TDigest
                  { tdMeans = combM,
                    tdWeights = combW,
                    tdTotalWeight = tdTotalWeight c1 + tdTotalWeight c2,
                    tdMin = min (tdMin c1) (tdMin c2),
                    tdMax = max (tdMax c1) (tdMax c2),
                    tdDelta = min (tdDelta c1) (tdDelta c2),
                    tdScaleFunction = tdScaleFunction c1,
                    tdBufferMeans = emptyPrimArray,
                    tdBufferWeights = emptyPrimArray
                  }
           in compress merged

-- ---------------------------------------------------------------------------
-- Accessors & Reconstruction
-- ---------------------------------------------------------------------------

-- | Total weight of all data points ingested.
totalWeight :: TDigest -> Double
totalWeight = tdTotalWeight

-- | Number of centroids in the compressed digest.
centroidCount :: TDigest -> Int
centroidCount td = sizeofPrimArray (tdMeans (compress td))

-- | List of centroids in the compressed digest.
centroidList :: TDigest -> [Centroid]
centroidList rawTd =
  let td = compress rawTd
      n = sizeofPrimArray (tdMeans td)
   in [ Centroid (indexPrimArray (tdMeans td) i) (indexPrimArray (tdWeights td) i)
        | i <- [0 .. n - 1]
      ]

-- | Compression parameter \(\delta\).
getDelta :: TDigest -> Double
getDelta = tdDelta

-- | Minimum value observed.
getMin :: TDigest -> Maybe Double
getMin td
  | tdTotalWeight td <= 0 = Nothing
  | otherwise = Just (tdMin td)

-- | Maximum value observed.
getMax :: TDigest -> Maybe Double
getMax td
  | tdTotalWeight td <= 0 = Nothing
  | otherwise = Just (tdMax td)

-- | Active scale function.
getScaleFunction :: TDigest -> ScaleFunction
getScaleFunction = tdScaleFunction

-- | Reconstruct a t-digest directly from component vectors and metadata.
fromComponents ::
  [Double] ->
  [Double] ->
  Double ->
  Double ->
  Double ->
  Double ->
  ScaleFunction ->
  TDigest
fromComponents means weights totalW minV maxV delta sf =
  let len = min (length means) (length weights)
      (!pMeans, !pWeights) = runST $ do
        mM <- newPrimArray len
        mW <- newPrimArray len
        let loop [] _ = pure ()
            loop _ [] = pure ()
            loop (m : ms) (w : ws) = do
              writePrimArray mM (len - 1 - length ms) m
              writePrimArray mW (len - 1 - length ws) w
              loop ms ws
        loop means weights
        fM <- unsafeFreezePrimArray mM
        fW <- unsafeFreezePrimArray mW
        pure (fM, fW)
   in TDigest
        { tdMeans = pMeans,
          tdWeights = pWeights,
          tdTotalWeight = totalW,
          tdMin = minV,
          tdMax = maxV,
          tdDelta = delta,
          tdScaleFunction = sf,
          tdBufferMeans = emptyPrimArray,
          tdBufferWeights = emptyPrimArray
        }
