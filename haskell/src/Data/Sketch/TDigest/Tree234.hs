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
