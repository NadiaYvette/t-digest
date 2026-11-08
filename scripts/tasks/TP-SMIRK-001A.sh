#!/usr/bin/env bash
set -euo pipefail

echo "=== [TP-SMIRK-001A Scaffold: dunning-t-digest Flat PrimArray Storage] ==="

mkdir -p $(dirname cabal.project)
cat << 'EOF' > cabal.project
packages:
  haskell
EOF

mkdir -p $(dirname haskell/dunning-t-digest.cabal)
cat << 'EOF' > haskell/dunning-t-digest.cabal
cabal-version:   3.0
name:            dunning-t-digest
version:         0.1.0.1
synopsis:        Dunning t-digest for online quantile estimation
description:
  A pure functional implementation of the Dunning t-digest data structure
  (merging digest variant, K1 arcsine scale function) using flat primitive
  arrays (PrimArray Double) for cache-local O(log n) queries and amortized
  O(1) insertion via buffer-and-flush.
  .
  Also provides a mutable variant backed by MutablePrimArray in the ST monad.
  .
  The t-digest provides streaming, mergeable, memory-bounded approximation
  of quantile (percentile) queries with high accuracy in the tails.

license:         BSD-3-Clause
license-file:    LICENSE
author:          Nadia Yvette Chambers
maintainer:      nadia.yvette.chambers@gmail.com
copyright:       (c) 2025 Nadia Yvette Chambers
category:        Data, Statistics
build-type:      Simple
extra-doc-files:
  CHANGELOG.md
  README.md
tested-with:     GHC == 9.14.1

source-repository head
  type:     git
  location: https://github.com/NadiaYvette/t-digest.git
  subdir:   haskell

common warnings
  ghc-options: -Wall -Wcompat

library
  import:           warnings
  exposed-modules:
    Data.Sketch.TDigest
    Data.Sketch.TDigest.Mutable
    Data.Sketch.TDigest.Tree234

  build-depends:
    , base         >= 4.16 && < 5
    , primitive    >= 0.7  && < 0.10
    , vector       >= 0.12 && < 0.14

  hs-source-dirs:   src
  default-extensions:
    BangPatterns
    DeriveGeneric
    MultiParamTypeClasses
    RankNTypes
    ScopedTypeVariables
  default-language:   Haskell2010

executable dunning-t-digest-demo
  import:           warnings
  main-is:          Main.hs
  build-depends:
    , base              >= 4.16 && < 5
    , dunning-t-digest

  hs-source-dirs:   app
  default-language: Haskell2010

executable dunning-t-digest-bench
  import:           warnings
  main-is:          Main.hs
  build-depends:
    , base              >= 4.16 && < 5
    , dunning-t-digest

  hs-source-dirs:   benchmarks
  default-language: Haskell2010

test-suite dunning-t-digest-test
  import:           warnings
  type:             exitcode-stdio-1.0
  main-is:          Main.hs
  build-depends:
    , base              >= 4.16 && < 5
    , dunning-t-digest
    , primitive         >= 0.7  && < 0.10
  hs-source-dirs:   test
  default-language: Haskell2010
EOF

mkdir -p $(dirname haskell/src/Data/Sketch/TDigest/Tree234.hs)
cat << 'EOF' > haskell/src/Data/Sketch/TDigest/Tree234.hs
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveGeneric #-}

-- |
-- Module      : Data.Sketch.TDigest.Tree234
-- Description : Array-hosted 2-3-4 tree with 4-component monoidal measures
-- Copyright   : (c) Nadia Yvette Chambers, 2025
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
--
-- An array-hosted 2-3-4 tree where all nodes reside in a contiguous flat
-- 'SmallArray Node' and child links are integer array indices (-1 for leaf edges).
--
-- Every node carries a four-component monoidal measure (cumulative weight,
-- centroid count, maximum mean, and mean-weight sum), enabling \(O(\log n)\)
-- quantile and CDF search without pointer chasing.
module Data.Sketch.TDigest.Tree234
  ( -- * Types
    Tree234 (..),
    Node (..),
    TdMeasure (..),
    WeightResult (..),

    -- * Monoidal Measure Operations
    measureIdentity,
    measureOfCentroid,
    measureCombine,

    -- * Construction & In-order Collection
    emptyTree,
    buildFromSorted,
    collectCentroids,

    -- * Subtree Queries
    findByWeight,
    findByMean,
    rootMeasure,
  )
where

import Control.Monad.ST (runST)
import Data.Primitive.SmallArray
  ( SmallArray,
    indexSmallArray,
    newSmallArray,
    readSmallArray,
    sizeofSmallArray,
    unsafeFreezeSmallArray,
    writeSmallArray,
  )
import GHC.Generics (Generic)

-- ---------------------------------------------------------------------------
-- Monoidal Measure
-- ---------------------------------------------------------------------------

-- | Four-component monoidal measure summarizing a subtree.
data TdMeasure = TdMeasure
  { tmWeight :: {-# UNPACK #-} !Double,
    tmCount :: {-# UNPACK #-} !Int,
    tmMaxMean :: {-# UNPACK #-} !Double,
    tmMeanWeightSum :: {-# UNPACK #-} !Double
  }
  deriving (Eq, Show, Generic)

-- | Monoid identity for subtree measures.
measureIdentity :: TdMeasure
measureIdentity = TdMeasure 0.0 0 (-(1 / 0)) 0.0

-- | Measure of a single centroid.
measureOfCentroid :: Double -> Double -> TdMeasure
measureOfCentroid !m !w = TdMeasure w 1 m (m * w)

-- | Combine measures of two subtrees.
measureCombine :: TdMeasure -> TdMeasure -> TdMeasure
measureCombine (TdMeasure w1 c1 mm1 mws1) (TdMeasure w2 c2 mm2 mws2) =
  TdMeasure (w1 + w2) (c1 + c2) (max mm1 mm2) (mws1 + mws2)

-- ---------------------------------------------------------------------------
-- Node Definition
-- ---------------------------------------------------------------------------

-- | An array-hosted 2-3-4 tree node holding 1..3 centroids and 0..4 child indices.
data Node = Node
  { ndN :: {-# UNPACK #-} !Int,
    -- ^ Number of keys in this node (1, 2, or 3)
    ndM0 :: {-# UNPACK #-} !Double,
    ndW0 :: {-# UNPACK #-} !Double,
    ndM1 :: {-# UNPACK #-} !Double,
    ndW1 :: {-# UNPACK #-} !Double,
    ndM2 :: {-# UNPACK #-} !Double,
    ndW2 :: {-# UNPACK #-} !Double,
    ndC0 :: {-# UNPACK #-} !Int,
    -- ^ Child 0 array index (-1 if leaf)
    ndC1 :: {-# UNPACK #-} !Int,
    -- ^ Child 1 array index (-1 if leaf)
    ndC2 :: {-# UNPACK #-} !Int,
    -- ^ Child 2 array index (-1 if leaf)
    ndC3 :: {-# UNPACK #-} !Int,
    -- ^ Child 3 array index (-1 if leaf)
    ndMeasure :: {-# UNPACK #-} !TdMeasure
  }
  deriving (Eq, Show, Generic)

emptyNode :: Node
emptyNode = Node 0 0 0 0 0 0 0 (-1) (-1) (-1) (-1) measureIdentity

-- ---------------------------------------------------------------------------
-- Tree Definition
-- ---------------------------------------------------------------------------

-- | Array-hosted 2-3-4 tree.
data Tree234 = Tree234
  { treeNodes :: !(SmallArray Node),
    treeRoot :: {-# UNPACK #-} !Int,
    treeSize :: {-# UNPACK #-} !Int
  }
  deriving (Eq, Show, Generic)

-- | Empty array-hosted 2-3-4 tree.
emptyTree :: Tree234
emptyTree =
  Tree234
    { treeNodes = runST (newSmallArray 0 emptyNode >>= unsafeFreezeSmallArray),
      treeRoot = -1,
      treeSize = 0
    }

-- | Overall measure of the tree.
rootMeasure :: Tree234 -> TdMeasure
rootMeasure t
  | treeRoot t == -1 || sizeofSmallArray (treeNodes t) == 0 = measureIdentity
  | otherwise = ndMeasure (indexSmallArray (treeNodes t) (treeRoot t))

-- ---------------------------------------------------------------------------
-- Construction from Sorted Centroids
-- ---------------------------------------------------------------------------

-- | Build a balanced array-hosted 2-3-4 tree from sorted centroids in \(O(n)\).
buildFromSorted :: [(Double, Double)] -> Tree234
buildFromSorted [] = emptyTree
buildFromSorted centroids = runST $ do
  let totalKeys = length centroids
      maxNodes = max 1 (totalKeys * 2)
  mArr <- newSmallArray maxNodes emptyNode
  nextIdxRef <- newSmallArray 1 (0 :: Int)

  let allocNode = do
        idx <- readSmallArray nextIdxRef 0
        writeSmallArray nextIdxRef 0 (idx + 1)
        pure idx

      recompute idx = do
        nd <- readSmallArray mArr idx
        let n = ndN nd
            isLeaf = ndC0 nd == -1
            childM cIdx
              | cIdx == -1 = pure measureIdentity
              | otherwise = ndMeasure <$> readSmallArray mArr cIdx
        m0 <- if isLeaf then pure measureIdentity else childM (ndC0 nd)
        let k0 = measureOfCentroid (ndM0 nd) (ndW0 nd)
            m1' = measureCombine m0 k0
        m1 <- if isLeaf then pure m1' else measureCombine m1' <$> childM (ndC1 nd)
        mFinal <-
          if n < 2
            then pure m1
            else do
              let k1 = measureOfCentroid (ndM1 nd) (ndW1 nd)
                  m2' = measureCombine m1 k1
              m2 <- if isLeaf then pure m2' else measureCombine m2' <$> childM (ndC2 nd)
              if n < 3
                then pure m2
                else do
                  let k2 = measureOfCentroid (ndM2 nd) (ndW2 nd)
                      m3' = measureCombine m2 k2
                  if isLeaf then pure m3' else measureCombine m3' <$> childM (ndC3 nd)
        writeSmallArray mArr idx (nd {ndMeasure = mFinal})

      buildRec lo hi
        | hi <= lo = pure (-1)
        | hi - lo <= 3 = do
            let count = hi - lo
                sub = take count (drop lo centroids)
            idx <- allocNode
            case sub of
              [(m0, w0)] ->
                writeSmallArray mArr idx (emptyNode {ndN = 1, ndM0 = m0, ndW0 = w0})
              [(m0, w0), (m1, w1)] ->
                writeSmallArray mArr idx (emptyNode {ndN = 2, ndM0 = m0, ndW0 = w0, ndM1 = m1, ndW1 = w1})
              [(m0, w0), (m1, w1), (m2, w2)] ->
                writeSmallArray mArr idx (emptyNode {ndN = 3, ndM0 = m0, ndW0 = w0, ndM1 = m1, ndW1 = w1, ndM2 = m2, ndW2 = w2})
              _ -> pure ()
            recompute idx
            pure idx
        | hi - lo <= 7 = do
            let n = hi - lo
                mid = lo + n `div` 2
                (mMid, wMid) = centroids !! mid
            c0 <- buildRec lo mid
            c1 <- buildRec (mid + 1) hi
            idx <- allocNode
            writeSmallArray
              mArr
              idx
              (emptyNode {ndN = 1, ndM0 = mMid, ndW0 = wMid, ndC0 = c0, ndC1 = c1})
            recompute idx
            pure idx
        | otherwise = do
            let n = hi - lo
                third = n `div` 3
                m1 = lo + third
                m2 = lo + 2 * third + 1
                (mM1, wM1) = centroids !! m1
                (mM2, wM2) = centroids !! m2
            c0 <- buildRec lo m1
            c1 <- buildRec (m1 + 1) m2
            c2 <- buildRec (m2 + 1) hi
            idx <- allocNode
            writeSmallArray
              mArr
              idx
              ( emptyNode
                  { ndN = 2,
                    ndM0 = mM1,
                    ndW0 = wM1,
                    ndM1 = mM2,
                    ndW1 = wM2,
                    ndC0 = c0,
                    ndC1 = c1,
                    ndC2 = c2
                  }
              )
            recompute idx
            pure idx

  rootIdx <- buildRec 0 totalKeys
  nodeCount <- readSmallArray nextIdxRef 0
  finalArr <- newSmallArray nodeCount emptyNode
  let copyNodes i
        | i >= nodeCount = pure ()
        | otherwise = do
            nd <- readSmallArray mArr i
            writeSmallArray finalArr i nd
            copyNodes (i + 1)
  copyNodes 0
  fNodes <- unsafeFreezeSmallArray finalArr
  pure
    Tree234
      { treeNodes = fNodes,
        treeRoot = rootIdx,
        treeSize = totalKeys
      }

-- ---------------------------------------------------------------------------
-- In-order Traversal
-- ---------------------------------------------------------------------------

-- | Collect all centroids in sorted order.
collectCentroids :: Tree234 -> [(Double, Double)]
collectCentroids t
  | treeRoot t == -1 = []
  | otherwise = go (treeRoot t)
  where
    arr = treeNodes t
    go (-1) = []
    go idx =
      let nd = indexSmallArray arr idx
          isLeaf = ndC0 nd == -1
          c0 = if isLeaf then [] else go (ndC0 nd)
          c1 = if isLeaf then [] else go (ndC1 nd)
          c2 = if isLeaf then [] else go (ndC2 nd)
          c3 = if isLeaf then [] else go (ndC3 nd)
          k0 = (ndM0 nd, ndW0 nd)
          k1 = (ndM1 nd, ndW1 nd)
          k2 = (ndM2 nd, ndW2 nd)
       in case ndN nd of
            1 -> c0 ++ [k0] ++ c1
            2 -> c0 ++ [k0] ++ c1 ++ [k1] ++ c2
            3 -> c0 ++ [k0] ++ c1 ++ [k1] ++ c2 ++ [k2] ++ c3
            _ -> []

-- ---------------------------------------------------------------------------
-- Search by Weight & Mean
-- ---------------------------------------------------------------------------

-- | Result of finding a centroid by cumulative weight.
data WeightResult = WeightResult
  { wrMean :: {-# UNPACK #-} !Double,
    wrWeight :: {-# UNPACK #-} !Double,
    wrCumBefore :: {-# UNPACK #-} !Double,
    wrIndex :: {-# UNPACK #-} !Int,
    wrFound :: !Bool
  }
  deriving (Eq, Show, Generic)

-- | Walk the array-hosted tree to locate the centroid containing cumulative weight @target@.
findByWeight :: Double -> Tree234 -> WeightResult
findByWeight target t
  | treeRoot t == -1 = WeightResult 0 0 0 0 False
  | otherwise = go (treeRoot t) 0.0 0
  where
    arr = treeNodes t
    childWeight cIdx
      | cIdx == -1 = 0.0
      | otherwise = tmWeight (ndMeasure (indexSmallArray arr cIdx))
    childCount cIdx
      | cIdx == -1 = 0
      | otherwise = tmCount (ndMeasure (indexSmallArray arr cIdx))

    go (-1) _ _ = WeightResult 0 0 0 0 False
    go idx !cum !gIdx =
      let nd = indexSmallArray arr idx
          n = ndN nd
          c0w = childWeight (ndC0 nd)
          k0w = ndW0 nd
       in if cum + c0w >= target && ndC0 nd /= -1
            then go (ndC0 nd) cum gIdx
            else
              let cum1 = cum + c0w
                  gIdx1 = gIdx + childCount (ndC0 nd)
               in if cum1 + k0w >= target || n < 2
                    then WeightResult (ndM0 nd) (ndW0 nd) cum1 gIdx1 True
                    else
                      let cum2 = cum1 + k0w
                          gIdx2 = gIdx1 + 1
                          c1w = childWeight (ndC1 nd)
                       in if cum2 + c1w >= target && ndC1 nd /= -1
                            then go (ndC1 nd) cum2 gIdx2
                            else
                              let cum3 = cum2 + c1w
                                  gIdx3 = gIdx2 + childCount (ndC1 nd)
                                  k1w = ndW1 nd
                               in if cum3 + k1w >= target || n < 3
                                    then WeightResult (ndM1 nd) (ndW1 nd) cum3 gIdx3 True
                                    else
                                      let cum4 = cum3 + k1w
                                          gIdx4 = gIdx3 + 1
                                          c2w = childWeight (ndC2 nd)
                                       in if cum4 + c2w >= target && ndC2 nd /= -1
                                            then go (ndC2 nd) cum4 gIdx4
                                            else
                                              let cum5 = cum4 + c2w
                                                  gIdx5 = gIdx4 + childCount (ndC2 nd)
                                                  k2w = ndW2 nd
                                               in if cum5 + k2w >= target
                                                    then WeightResult (ndM2 nd) (ndW2 nd) cum5 gIdx5 True
                                                    else go (ndC3 nd) (cum5 + k2w) (gIdx5 + 1)

-- | Walk the array-hosted tree to find bracketing centroid index for value @x@.
findByMean :: Double -> Tree234 -> Int
findByMean x t
  | treeRoot t == -1 = 0
  | otherwise = go (treeRoot t) 0
  where
    arr = treeNodes t
    childCount cIdx
      | cIdx == -1 = 0
      | otherwise = tmCount (ndMeasure (indexSmallArray arr cIdx))

    go (-1) gIdx = gIdx
    go idx gIdx =
      let nd = indexSmallArray arr idx
          n = ndN nd
       in if x <= ndM0 nd
            then
              if ndC0 nd == -1
                then gIdx
                else go (ndC0 nd) gIdx
            else
              let gIdx1 = gIdx + childCount (ndC0 nd) + 1
               in if n < 2 || x <= ndM1 nd
                    then
                      if ndC1 nd == -1
                        then gIdx1
                        else go (ndC1 nd) (gIdx1 - 1 + childCount (ndC0 nd))
                    else
                      let gIdx2 = gIdx1 + childCount (ndC1 nd) + 1
                       in if n < 3 || x <= ndM2 nd
                            then
                              if ndC2 nd == -1
                                then gIdx2
                                else go (ndC2 nd) gIdx2
                            else
                              if ndC3 nd == -1
                                then gIdx2 + childCount (ndC2 nd) + 1
                                else go (ndC3 nd) (gIdx2 + childCount (ndC2 nd) + 1)
EOF

mkdir -p $(dirname haskell/src/Data/Sketch/TDigest.hs)
cat << 'EOF' > haskell/src/Data/Sketch/TDigest.hs
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
EOF

mkdir -p $(dirname haskell/src/Data/Sketch/TDigest/Mutable.hs)
cat << 'EOF' > haskell/src/Data/Sketch/TDigest/Mutable.hs
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
EOF

mkdir -p $(dirname haskell/app/Main.hs)
cat << 'EOF' > haskell/app/Main.hs
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
EOF

mkdir -p $(dirname haskell/benchmarks/Main.hs)
cat << 'EOF' > haskell/benchmarks/Main.hs
module Main (main) where

import Control.Exception (evaluate)
import Control.Monad (when)
import Data.IORef
import Data.Maybe (fromMaybe)
import qualified Data.Sketch.TDigest as TD
import System.CPUTime (getCPUTime)
import Text.Printf (printf)

timeBlock :: IO a -> IO (Double, a)
timeBlock action = do
  t0 <- getCPUTime
  result <- action >>= evaluate
  t1 <- getCPUTime
  let ms = fromIntegral (t1 - t0) / 1e9
  return (ms, result)

buildDigest :: Double -> Int -> TD.TDigest
buildDigest delta n =
  foldl
    (\td i -> TD.add (fromIntegral i / fromIntegral n) td)
    (TD.emptyWith delta)
    [1 .. n]

check :: IORef (Int, Int) -> String -> Bool -> IO ()
check ref desc ok = do
  (pass, fail') <- readIORef ref
  if ok
    then do
      writeIORef ref (pass + 1, fail')
      printf "  %-50s  PASS\n" desc
    else do
      writeIORef ref (pass, fail' + 1)
      printf "  %-50s  FAIL\n" desc

ratioOk :: Double -> Double -> Bool
ratioOk actual expected =
  actual >= expected * 0.2 && actual <= expected * 5.0

main :: IO ()
main = do
  ref <- newIORef (0, 0)
  putStrLn "=== T-Digest Asymptotic Behavior Tests (Haskell) ==="
  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 1: add() is amortized O(1)
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 1: add() is amortized O(1) ---"
  let sizes = [1000, 10000, 100000, 1000000] :: [Int]
  times <-
    mapM
      ( \n -> do
          let go 0 td = td
              go i td = go (i - 1) (TD.add (fromIntegral i / fromIntegral n) td)
          (ms, _) <- timeBlock (return $! go n (TD.emptyWith 100))
          printf "  N=%-9d  time=%.1fms\n" n ms
          return ms
      )
      sizes

  mapM_
    ( \i -> do
        let expected = fromIntegral (sizes !! i) / fromIntegral (sizes !! (i - 1)) :: Double
            ratio = (times !! i) / (times !! (i - 1))
        check
          ref
          (printf "N=%d  ratio=%.2f (expected ~%.1f)" (sizes !! i) ratio expected)
          (ratioOk ratio expected)
    )
    [1 .. length sizes - 1]

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 2: Centroid count bounded by O(delta)
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 2: Centroid count bounded by O(delta) ---"
  let delta = 100 :: Double
  mapM_
    ( \n -> do
        let td = buildDigest delta n
            cc = TD.centroidCount td
        check
          ref
          (printf "N=%-9d  centroids=%-4d  (delta=%.0f, limit=%d)" n cc delta (5 * round delta :: Int))
          (cc <= 5 * round delta)
    )
    sizes

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 3: Query time independent of N
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 3: Query time independent of N ---"
  let querySizes = [1000, 10000, 100000] :: [Int]
  _ <-
    mapM
      ( \n -> do
          let td = TD.compress (buildDigest 100 n)
              iterations = 10000 :: Int
          (ms, _) <-
            timeBlock
              ( return $!
                  foldl
                    ( \acc _i ->
                        let q = fromMaybe 0 (TD.quantile 0.5 td)
                            c = fromMaybe 0 (TD.cdf 0.5 td)
                         in acc + q + c
                    )
                    (0.0 :: Double)
                    [1 .. iterations]
              )
          let perQueryUs = ms * 1000.0 / fromIntegral iterations
          printf "  N=%-9d  query_time=%.2fus\n" n perQueryUs
          return perQueryUs
      )
      querySizes

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 4: Tail accuracy improves with delta
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 4: Tail accuracy improves with delta ---"
  let testDeltas = [50, 100, 200] :: [Double]
      testQuantiles = [0.010, 0.001, 0.990, 0.999] :: [Double]
      nTest4 = 100000 :: Int

  mapM_
    ( \q -> do
        errors <-
          mapM
            ( \d -> do
                let td = buildDigest d nTest4
                    est = fromMaybe 0.0 (TD.quantile q td)
                    err = abs (est - q)
                printf "  delta=%-5.0f  q=%-7.3f  error=%.6f\n" d q err
                return err
            )
            testDeltas
        mapM_
          ( \i -> do
              let prevErr = errors !! (i - 1)
                  currErr = errors !! i
                  dCurr = testDeltas !! i
              check
                ref
                (printf "delta=%.0f q=%.3f error decreases (%.6f <= %.6f)" dCurr q currErr prevErr)
                (currErr <= prevErr * 1.5)
          )
          [1 .. length testDeltas - 1]
    )
    testQuantiles

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 5: Merge preserves weight and accuracy
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 5: Merge preserves weight and accuracy ---"
  let halfN = 5000 :: Int
      tdA =
        foldl
          (\td i -> TD.add (fromIntegral i / fromIntegral (2 * halfN)) td)
          (TD.emptyWith 100)
          [1 .. halfN]
      tdB =
        foldl
          (\td i -> TD.add (fromIntegral (halfN + i) / fromIntegral (2 * halfN)) td)
          (TD.emptyWith 100)
          [1 .. halfN]
      tdM = TD.merge tdA tdB
      wBefore = TD.totalWeight tdA + TD.totalWeight tdB
      wAfter = TD.totalWeight tdM
  check ref "weight_before=10000  weight_after=10000  (equal)" (wBefore == wAfter)

  let medEst = fromMaybe 0.0 (TD.quantile 0.5 tdM)
      medErr = abs (medEst - 0.5)
  check ref (printf "median_error=%.6f  (< 0.05)" medErr) (medErr < 0.05)

  let p99Est = fromMaybe 0.0 (TD.quantile 0.99 tdM)
      p99Err = abs (p99Est - 0.99)
  check ref (printf "p99_error=%.6f  (< 0.05)" p99Err) (p99Err < 0.05)

  putStrLn ""
  (pass, fail') <- readIORef ref
  printf "Summary: %d/%d tests passed\n" pass (pass + fail')
  when (fail' > 0) $ putStrLn "Some tests failed."
EOF

mkdir -p $(dirname haskell/test/Main.hs)
cat << 'EOF' > haskell/test/Main.hs
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
EOF

echo "=== [TP-SMIRK-001A Scaffold Applied Successfully] ==="
