{-# LANGUAGE BangPatterns #-}

-- |
-- Module      : Data.Sketch.TDigest.Mutable
-- Description : Mutable t-digest backed by MutablePrimArray in the ST monad
-- Copyright   : (c) Nadia Yvette Chambers, 2025
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
--
-- A mutable t-digest implementation backed by 'MutablePrimArray s Double'
-- operating within the 'Control.Monad.ST.ST' monad.
module Data.Sketch.TDigest.Mutable
  ( -- * Type
    MDigest,

    -- * Construction
    new,
    newWith,
    newWithScale,

    -- * Insertion
    add,
    addWeighted,

    -- * Compression
    compress,

    -- * Queries
    quantile,
    cdf,

    -- * Accessors
    totalWeight,
    centroidCount,
    centroidList,
    getDelta,
    getMin,
    getMax,
    getScaleFunction,

    -- * Conversion
    freeze,
    thaw,

    -- * Runner
    runTDigest,
  )
where

import Control.Monad.ST (ST, runST)
import Data.Primitive.PrimArray
  ( MutablePrimArray,
    copyMutablePrimArray,
    indexPrimArray,
    newPrimArray,
    readPrimArray,
    unsafeFreezePrimArray,
    writePrimArray,
  )
import Data.STRef
  ( STRef,
    newSTRef,
    readSTRef,
    writeSTRef,
  )
import qualified Data.Sketch.TDigest as TD

-- ---------------------------------------------------------------------------
-- Type
-- ---------------------------------------------------------------------------

-- | Mutable t-digest backed by flat 'MutablePrimArray s Double' in the 'ST' monad.
data MDigest s = MDigest
  { mdMeans :: !(STRef s (MutablePrimArray s Double)),
    mdWeights :: !(STRef s (MutablePrimArray s Double)),
    mdCentroidCount :: !(STRef s Int),
    mdBufMeans :: !(STRef s (MutablePrimArray s Double)),
    mdBufWeights :: !(STRef s (MutablePrimArray s Double)),
    mdBufLen :: !(STRef s Int),
    mdBufCap :: !(STRef s Int),
    mdTotalWeight :: !(STRef s Double),
    mdMin :: !(STRef s Double),
    mdMax :: !(STRef s Double),
    mdDelta :: !(STRef s Double),
    mdScaleFunction :: !(STRef s TD.ScaleFunction)
  }

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create a new mutable t-digest with \(\delta = 100\) and \(K_1\) scale function.
new :: ST s (MDigest s)
new = newWith 100

-- | Create a new mutable t-digest with given \(\delta\) and \(K_1\) scale function.
newWith :: Double -> ST s (MDigest s)
newWith = newWithScale TD.K1

-- | Create a new mutable t-digest with given scale function and \(\delta\).
newWithScale :: TD.ScaleFunction -> Double -> ST s (MDigest s)
newWithScale sf delta = do
  let !d = max 1 delta
      !initCap = max 64 (ceiling (10 * d) :: Int)
      !bufCap = max 64 (ceiling (5 * d) :: Int)
  mM <- newPrimArray initCap
  mW <- newPrimArray initCap
  bM <- newPrimArray bufCap
  bW <- newPrimArray bufCap

  refM <- newSTRef mM
  refW <- newSTRef mW
  refCC <- newSTRef 0
  refBM <- newSTRef bM
  refBW <- newSTRef bW
  refBL <- newSTRef 0
  refBCap <- newSTRef bufCap
  refTW <- newSTRef 0.0
  refMin <- newSTRef (1 / 0)
  refMax <- newSTRef (-(1 / 0))
  refDelta <- newSTRef d
  refSF <- newSTRef sf

  pure
    MDigest
      { mdMeans = refM,
        mdWeights = refW,
        mdCentroidCount = refCC,
        mdBufMeans = refBM,
        mdBufWeights = refBW,
        mdBufLen = refBL,
        mdBufCap = refBCap,
        mdTotalWeight = refTW,
        mdMin = refMin,
        mdMax = refMax,
        mdDelta = refDelta,
        mdScaleFunction = refSF
      }

-- ---------------------------------------------------------------------------
-- Insertion
-- ---------------------------------------------------------------------------

-- | Insert a single observation with unit weight.
add :: Double -> MDigest s -> ST s ()
add x md = addWeighted x 1.0 md

-- | Insert an observation with positive weight.
addWeighted :: Double -> Double -> MDigest s -> ST s ()
addWeighted !x !w md
  | isNaN x || isInfinite x || w <= 0 = pure ()
  | otherwise = do
      curMin <- readSTRef (mdMin md)
      curMax <- readSTRef (mdMax md)
      curTotal <- readSTRef (mdTotalWeight md)
      writeSTRef (mdMin md) (min curMin x)
      writeSTRef (mdMax md) (max curMax x)
      writeSTRef (mdTotalWeight md) (curTotal + w)

      bl <- readSTRef (mdBufLen md)
      bcap <- readSTRef (mdBufCap md)
      if bl >= bcap
        then do
          compress md
          bl' <- readSTRef (mdBufLen md)
          bm <- readSTRef (mdBufMeans md)
          bw <- readSTRef (mdBufWeights md)
          writePrimArray bm bl' x
          writePrimArray bw bl' w
          writeSTRef (mdBufLen md) (bl' + 1)
        else do
          bm <- readSTRef (mdBufMeans md)
          bw <- readSTRef (mdBufWeights md)
          writePrimArray bm bl x
          writePrimArray bw bl w
          writeSTRef (mdBufLen md) (bl + 1)

-- ---------------------------------------------------------------------------
-- Compression
-- ---------------------------------------------------------------------------

-- | Flush the buffer and perform greedy merge.
compress :: MDigest s -> ST s ()
compress md = do
  bl <- readSTRef (mdBufLen md)
  cc <- readSTRef (mdCentroidCount md)
  let totalItems = cc + bl
  if totalItems == 0
    then do
      writeSTRef (mdBufLen md) 0
      writeSTRef (mdCentroidCount md) 0
    else do
      combM <- newPrimArray totalItems
      combW <- newPrimArray totalItems
      cM <- readSTRef (mdMeans md)
      cW <- readSTRef (mdWeights md)
      copyMutablePrimArray combM 0 cM 0 cc
      copyMutablePrimArray combW 0 cW 0 cc

      bM <- readSTRef (mdBufMeans md)
      bW <- readSTRef (mdBufWeights md)
      copyMutablePrimArray combM cc bM 0 bl
      copyMutablePrimArray combW cc bW 0 bl

      -- In-place sort
      TD.sortCentroids combM combW 0 (totalItems - 1)

      -- In-place merge
      sf <- readSTRef (mdScaleFunction md)
      delta <- readSTRef (mdDelta md)
      n <- readSTRef (mdTotalWeight md)

      outM <- newPrimArray totalItems
      outW <- newPrimArray totalItems
      mergedCount <- TD.greedyMergePrim sf delta n combM combW totalItems outM outW

      writeSTRef (mdMeans md) outM
      writeSTRef (mdWeights md) outW
      writeSTRef (mdCentroidCount md) mergedCount
      writeSTRef (mdBufLen md) 0

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Estimate value at quantile \(q \in [0, 1]\).
quantile :: Double -> MDigest s -> ST s (Maybe Double)
quantile q md = do
  compress md
  pureTd <- freeze md
  pure (TD.quantile q pureTd)

-- | Estimate cumulative distribution function at value \(x\).
cdf :: Double -> MDigest s -> ST s (Maybe Double)
cdf x md = do
  compress md
  pureTd <- freeze md
  pure (TD.cdf x pureTd)

-- ---------------------------------------------------------------------------
-- Accessors & Conversion
-- ---------------------------------------------------------------------------

-- | Total weight of all data points ingested.
totalWeight :: MDigest s -> ST s Double
totalWeight md = readSTRef (mdTotalWeight md)

-- | Centroid count.
centroidCount :: MDigest s -> ST s Int
centroidCount md = do
  compress md
  readSTRef (mdCentroidCount md)

-- | List of centroids.
centroidList :: MDigest s -> ST s [TD.Centroid]
centroidList md = do
  compress md
  cc <- readSTRef (mdCentroidCount md)
  cM <- readSTRef (mdMeans md)
  cW <- readSTRef (mdWeights md)
  let loop i
        | i >= cc = pure []
        | otherwise = do
            m <- readPrimArray cM i
            w <- readPrimArray cW i
            rest <- loop (i + 1)
            pure (TD.Centroid m w : rest)
  loop 0

-- | Delta parameter.
getDelta :: MDigest s -> ST s Double
getDelta md = readSTRef (mdDelta md)

-- | Minimum value observed.
getMin :: MDigest s -> ST s (Maybe Double)
getMin md = do
  w <- readSTRef (mdTotalWeight md)
  if w <= 0
    then pure Nothing
    else Just <$> readSTRef (mdMin md)

-- | Maximum value observed.
getMax :: MDigest s -> ST s (Maybe Double)
getMax md = do
  w <- readSTRef (mdTotalWeight md)
  if w <= 0
    then pure Nothing
    else Just <$> readSTRef (mdMax md)

-- | Scale function.
getScaleFunction :: MDigest s -> ST s TD.ScaleFunction
getScaleFunction md = readSTRef (mdScaleFunction md)

-- | Convert a mutable t-digest to a pure 'TDigest'.
freeze :: MDigest s -> ST s TD.TDigest
freeze md = do
  compress md
  cc <- readSTRef (mdCentroidCount md)
  cM <- readSTRef (mdMeans md)
  cW <- readSTRef (mdWeights md)
  fM <- newPrimArray cc
  fW <- newPrimArray cc
  copyMutablePrimArray fM 0 cM 0 cc
  copyMutablePrimArray fW 0 cW 0 cc
  frozenM <- unsafeFreezePrimArray fM
  frozenW <- unsafeFreezePrimArray fW
  tw <- readSTRef (mdTotalWeight md)
  mn <- readSTRef (mdMin md)
  mx <- readSTRef (mdMax md)
  delta <- readSTRef (mdDelta md)
  sf <- readSTRef (mdScaleFunction md)
  pure
    ( TD.fromComponents
        [indexPrimArray frozenM i | i <- [0 .. cc - 1]]
        [indexPrimArray frozenW i | i <- [0 .. cc - 1]]
        tw
        mn
        mx
        delta
        sf
    )

-- | Create a mutable t-digest from a pure 'TDigest'.
thaw :: TD.TDigest -> ST s (MDigest s)
thaw rawTd = do
  let td = TD.compress rawTd
      cc = TD.centroidCount td
      cs = TD.centroidList td
      initCap = max 64 (ceiling (10 * TD.getDelta td) :: Int)
      bufCap = max 64 (ceiling (5 * TD.getDelta td) :: Int)
  mM <- newPrimArray initCap
  mW <- newPrimArray initCap
  bM <- newPrimArray bufCap
  bW <- newPrimArray bufCap

  let loop [] _ = pure ()
      loop (TD.Centroid m w : rest) i = do
        writePrimArray mM i m
        writePrimArray mW i w
        loop rest (i + 1)
  loop cs 0

  refM <- newSTRef mM
  refW <- newSTRef mW
  refCC <- newSTRef cc
  refBM <- newSTRef bM
  refBW <- newSTRef bW
  refBL <- newSTRef 0
  refBCap <- newSTRef bufCap
  refTW <- newSTRef (TD.totalWeight td)
  refMin <- newSTRef (maybe (1 / 0) id (TD.getMin td))
  refMax <- newSTRef (maybe (-(1 / 0)) id (TD.getMax td))
  refDelta <- newSTRef (TD.getDelta td)
  refSF <- newSTRef (TD.getScaleFunction td)

  pure
    MDigest
      { mdMeans = refM,
        mdWeights = refW,
        mdCentroidCount = refCC,
        mdBufMeans = refBM,
        mdBufWeights = refBW,
        mdBufLen = refBL,
        mdBufCap = refBCap,
        mdTotalWeight = refTW,
        mdMin = refMin,
        mdMax = refMax,
        mdDelta = refDelta,
        mdScaleFunction = refSF
      }

-- | Execute a mutable t-digest computation in the 'ST' monad and return the pure result.
runTDigest :: (forall s. ST s a) -> a
runTDigest = runST
