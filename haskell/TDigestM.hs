-- |
-- Module      : TDigestM
-- Description : Truly mutable t-digest using mutable vectors in ST
-- Stability   : experimental
-- Maintainer  : Nadia Yvette Chambers
--
-- A mutable t-digest implementation backed by mutable vectors from the
-- @vector@ package. Centroids are stored in a mutable unboxed-style vector
-- of (mean, weight) pairs kept sorted by mean. Prefix sums of weights are
-- maintained for O(log n) quantile and CDF queries via binary search.
--
-- == Quick start
--
-- @
-- import TDigestM
-- import Control.Monad (forM_)
--
-- example :: Maybe Double
-- example = 'runTDigest' $ do
--   td <- 'new'
--   forM_ [1.0 .. 10000.0] $ \\v -> 'add' v td
--   'quantile' 0.99 td
-- @
module TDigestM
  ( -- * Type
    MDigest,

    -- * Construction
    new,
    newWith,

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

    -- * Conversion
    freeze,
    thaw,

    -- * Accessors
    totalWeight,
    centroidCount,

    -- * Runner
    runTDigest,
  )
where

import Control.Monad (when)
import Control.Monad.ST (ST, runST)
import Data.STRef
  ( STRef,
    modifySTRef',
    newSTRef,
    readSTRef,
    writeSTRef,
  )
import qualified Data.Vector.Mutable as MV
import qualified TDigest as TD

-- ---------------------------------------------------------------------------
-- Type
-- ---------------------------------------------------------------------------

-- | A truly mutable t-digest using mutable vectors for centroids, prefix
-- sums, and a pending-additions buffer.
data MDigest s = MDigest
  { -- | Mutable vector of (mean, weight) pairs, sorted by mean.
    mdCentroids :: !(STRef s (MV.MVector s (Double, Double))),
    -- | Prefix sums: prefixSum[0] = 0, prefixSum[i] = sum of weights 0..i-1.
    mdPrefixSums :: !(STRef s (MV.MVector s Double)),
    -- | Buffer for pending additions.
    mdBuffer :: !(STRef s (MV.MVector s (Double, Double))),
    mdTotalWeight :: !(STRef s Double),
    mdMin :: !(STRef s Double),
    mdMax :: !(STRef s Double),
    mdBufferLen :: !(STRef s Int),
    mdCentroidCount :: !(STRef s Int),
    mdDelta :: !(STRef s Double),
    mdBufferCap :: !(STRef s Int)
  }

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create a new mutable t-digest with the default compression (delta = 100).
new :: ST s (MDigest s)
new = newWith 100

-- | Create a new mutable t-digest with a given compression parameter.
newWith :: Double -> ST s (MDigest s)
newWith delta = do
  let bufCap = ceiling (delta * 5) :: Int
      initCentroidCap = bufCap * 2
  centroids <- MV.new initCentroidCap
  prefix <- MV.new 1
  MV.write prefix 0 0.0
  buf <- MV.new bufCap
  cRef <- newSTRef centroids
  pRef <- newSTRef prefix
  bRef <- newSTRef buf
  twRef <- newSTRef 0.0
  mnRef <- newSTRef (1 / 0)
  mxRef <- newSTRef (-(1 / 0))
  blRef <- newSTRef 0
  ccRef <- newSTRef 0
  dRef <- newSTRef delta
  bcRef <- newSTRef bufCap
  return
    MDigest
      { mdCentroids = cRef,
        mdPrefixSums = pRef,
        mdBuffer = bRef,
        mdTotalWeight = twRef,
        mdMin = mnRef,
        mdMax = mxRef,
        mdBufferLen = blRef,
        mdCentroidCount = ccRef,
        mdDelta = dRef,
        mdBufferCap = bcRef
      }

-- ---------------------------------------------------------------------------
-- Insertion
-- ---------------------------------------------------------------------------

-- | Add a single value (weight 1) to the digest.
add :: Double -> MDigest s -> ST s ()
add x = addWeighted x 1

-- | Add a value with a given weight to the digest.
addWeighted :: Double -> Double -> MDigest s -> ST s ()
addWeighted x w md = do
  -- Update min/max
  mn <- readSTRef (mdMin md)
  when (x < mn) $ writeSTRef (mdMin md) x
  mx <- readSTRef (mdMax md)
  when (x > mx) $ writeSTRef (mdMax md) x
  -- Update total weight
  modifySTRef' (mdTotalWeight md) (+ w)
  -- Append to buffer
  bl <- readSTRef (mdBufferLen md)
  buf <- readSTRef (mdBuffer md)
  let bufLen = MV.length buf
  -- Grow buffer if needed
  buf' <-
    if bl >= bufLen
      then do
        newBuf <- MV.grow buf bufLen
        writeSTRef (mdBuffer md) newBuf
        return newBuf
      else return buf
  MV.write buf' bl (x, w)
  let bl' = bl + 1
  writeSTRef (mdBufferLen md) bl'
  -- Compress if buffer is full
  bc <- readSTRef (mdBufferCap md)
  when (bl' >= bc) $ compress md

-- ---------------------------------------------------------------------------
-- Compression
-- ---------------------------------------------------------------------------

-- | Force compression of the buffer into the centroid list.
compress :: MDigest s -> ST s ()
compress md = do
  bl <- readSTRef (mdBufferLen md)
  cc <- readSTRef (mdCentroidCount md)
  when (bl > 0 || cc > 1) $ do
    -- Collect all items: existing centroids + buffer
    let totalItems = cc + bl
    allItems <- MV.new totalItems
    -- Copy centroids
    centroids <- readSTRef (mdCentroids md)
    copyN centroids allItems cc 0 0
    -- Copy buffer
    buf <- readSTRef (mdBuffer md)
    copyN buf allItems bl 0 cc
    -- Sort all items by mean (insertion sort is fine for small arrays)
    insertionSort allItems totalItems
    -- Greedy merge
    delta <- readSTRef (mdDelta md)
    n <- readSTRef (mdTotalWeight md)
    if totalItems == 0
      then do
        writeSTRef (mdCentroidCount md) 0
        writeSTRef (mdBufferLen md) 0
        rebuildPrefixSums md
      else do
        -- Merge in-place into a result vector
        merged <- MV.new totalItems
        (m0, w0) <- MV.read allItems 0
        -- Walk and merge
        newCount <- greedyMergeVec delta n allItems totalItems merged m0 w0
        -- Write back
        writeSTRef (mdCentroids md) merged
        writeSTRef (mdCentroidCount md) newCount
        writeSTRef (mdBufferLen md) 0
        rebuildPrefixSums md

-- Copy n elements from src starting at srcOff to dst starting at dstOff
copyN :: MV.MVector s (Double, Double) -> MV.MVector s (Double, Double) -> Int -> Int -> Int -> ST s ()
copyN src dst n srcOff dstOff = go 0
  where
    go i
      | i >= n = return ()
      | otherwise = do
          v <- MV.read src (srcOff + i)
          MV.write dst (dstOff + i) v
          go (i + 1)

-- Insertion sort by first element of pair
insertionSort :: MV.MVector s (Double, Double) -> Int -> ST s ()
insertionSort vec n = go 1
  where
    go i
      | i >= n = return ()
      | otherwise = do
          val@(key, _) <- MV.read vec i
          j <- findInsertPos vec key (i - 1)
          -- Shift elements right
          shiftRight vec (j + 1) i
          MV.write vec (j + 1) val
          go (i + 1)

    findInsertPos :: MV.MVector s (Double, Double) -> Double -> Int -> ST s Int
    findInsertPos _ _ (-1) = return (-1)
    findInsertPos v key j = do
      (jKey, _) <- MV.read v j
      if jKey > key
        then findInsertPos v key (j - 1)
        else return j

    shiftRight :: MV.MVector s (Double, Double) -> Int -> Int -> ST s ()
    shiftRight v from to
      | from >= to = return ()
      | otherwise = go' (to - 1)
      where
        go' j
          | j < from = return ()
          | otherwise = do
              val <- MV.read v j
              MV.write v (j + 1) val
              go' (j - 1)

-- Greedy merge: walk sorted items, merge adjacent when scale function allows.
-- Returns the number of merged centroids written to 'out'.
greedyMergeVec ::
  Double ->
  Double ->
  MV.MVector s (Double, Double) ->
  Int ->
  MV.MVector s (Double, Double) ->
  Double ->
  Double ->
  ST s Int
greedyMergeVec delta n items totalItems out initMean initWeight = go 1 0 initMean initWeight 0
  where
    k q = (delta / (2 * pi)) * asin (2 * q - 1)

    go idx weightSoFar curMean curWeight outIdx
      | idx >= totalItems = do
          -- Emit final centroid
          MV.write out outIdx (curMean, curWeight)
          return (outIdx + 1)
      | otherwise = do
          (itemMean, itemWeight) <- MV.read items idx
          let proposed = curWeight + itemWeight
              q0 = weightSoFar / n
              q1 = (weightSoFar + proposed) / n
              canMerge =
                (proposed <= 1 && idx < totalItems - 1)
                  || (k q1 - k q0 <= 1.0)
          if canMerge
            then do
              -- Merge: weighted mean
              let newW = curWeight + itemWeight
                  newM = (curMean * curWeight + itemMean * itemWeight) / newW
              go (idx + 1) weightSoFar newM newW outIdx
            else do
              -- Emit current centroid, start new one
              MV.write out outIdx (curMean, curWeight)
              go (idx + 1) (weightSoFar + curWeight) itemMean itemWeight (outIdx + 1)

-- Rebuild prefix sums from current centroids.
-- prefixSum has (centroidCount + 1) entries:
--   prefixSum[0] = 0
--   prefixSum[i] = sum of weights of centroids 0..i-1
rebuildPrefixSums :: MDigest s -> ST s ()
rebuildPrefixSums md = do
  cc <- readSTRef (mdCentroidCount md)
  prefix <- MV.new (cc + 1)
  MV.write prefix 0 0.0
  centroids <- readSTRef (mdCentroids md)
  buildPS centroids prefix cc 0 0.0
  writeSTRef (mdPrefixSums md) prefix
  where
    buildPS _ _ n i _
      | i >= n = return ()
    buildPS cs ps n i acc = do
      (_, w) <- MV.read cs i
      let acc' = acc + w
      MV.write ps (i + 1) acc'
      buildPS cs ps n (i + 1) acc'

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile @q@ (0 <= q <= 1).
-- Returns 'Nothing' if the digest is empty.
quantile :: Double -> MDigest s -> ST s (Maybe Double)
quantile q md = do
  compress md
  cc <- readSTRef (mdCentroidCount md)
  if cc == 0
    then return Nothing
    else
      if cc == 1
        then do
          centroids <- readSTRef (mdCentroids md)
          (m, _) <- MV.read centroids 0
          return (Just m)
        else do
          n <- readSTRef (mdTotalWeight md)
          mn <- readSTRef (mdMin md)
          mx <- readSTRef (mdMax md)
          let q' = clamp 0 1 q
              target = q' * n
          centroids <- readSTRef (mdCentroids md)
          prefix <- readSTRef (mdPrefixSums md)
          -- Binary search: find largest i such that prefixSum[i] <= target
          -- i is in [0, cc], and represents the centroid index boundary
          i <- bsearchPrefix prefix (cc + 1) target
          -- i is the index into prefix sums; the centroid index is (i - 1)
          -- but we need to handle boundary cases
          let ci = max 0 (min (cc - 1) (i - 1))
          -- Now interpolate
          (cMean, cWeight) <- MV.read centroids ci
          cumBefore <- MV.read prefix ci
          let mid = cumBefore + cWeight / 2.0
          if ci == 0 && target < cWeight / 2.0
            then do
              -- Left boundary: interpolate between min and first centroid
              let result =
                    if cWeight == 1
                      then mn
                      else mn + (cMean - mn) * (target / (cWeight / 2.0))
              return (Just result)
            else
              if ci == cc - 1
                then do
                  -- Right boundary
                  let remaining = n - cWeight / 2.0
                  if target > n - cWeight / 2.0
                    then do
                      let result =
                            if cWeight == 1
                              then mx
                              else cMean + (mx - cMean) * ((target - remaining) / (cWeight / 2.0))
                      return (Just result)
                    else return (Just cMean)
                else do
                  -- Middle: interpolate between adjacent centroid midpoints
                  (nextMean, nextWeight) <- MV.read centroids (ci + 1)
                  cumNext <- MV.read prefix (ci + 1)
                  let nextMid = cumNext + nextWeight / 2.0
                  if target <= nextMid
                    then do
                      let frac =
                            if nextMid == mid
                              then 0.5
                              else (target - mid) / (nextMid - mid)
                      return (Just (cMean + frac * (nextMean - cMean)))
                    else do
                      -- Walk forward from ci+1
                      walkQuantile centroids prefix cc n mn mx target (ci + 1)

-- Walk forward to find the right centroid for the target
walkQuantile ::
  MV.MVector s (Double, Double) ->
  MV.MVector s Double ->
  Int ->
  Double ->
  Double ->
  Double ->
  Double ->
  Int ->
  ST s (Maybe Double)
walkQuantile centroids prefix cc n mn mx target startIdx = go startIdx
  where
    go i
      | i >= cc = return (Just mx)
      | otherwise = do
          (cMean, cWeight) <- MV.read centroids i
          cumBefore <- MV.read prefix i
          let mid = cumBefore + cWeight / 2.0
          if i == 0 && target < cWeight / 2.0
            then do
              let result =
                    if cWeight == 1
                      then mn
                      else mn + (cMean - mn) * (target / (cWeight / 2.0))
              return (Just result)
            else
              if i == cc - 1
                then do
                  let remaining = n - cWeight / 2.0
                  if target > remaining
                    then do
                      let result =
                            if cWeight == 1
                              then mx
                              else cMean + (mx - cMean) * ((target - remaining) / (cWeight / 2.0))
                      return (Just result)
                    else return (Just cMean)
                else do
                  (nextMean, nextWeight) <- MV.read centroids (i + 1)
                  cumNext <- MV.read prefix (i + 1)
                  let nextMid = cumNext + nextWeight / 2.0
                  if target <= nextMid
                    then do
                      let frac =
                            if nextMid == mid
                              then 0.5
                              else (target - mid) / (nextMid - mid)
                      return (Just (cMean + frac * (nextMean - cMean)))
                    else go (i + 1)

-- Binary search on prefix sums: find largest i in [0, len-1] such that
-- prefix[i] <= target.
bsearchPrefix :: MV.MVector s Double -> Int -> Double -> ST s Int
bsearchPrefix prefix len target = go 0 (len - 1)
  where
    go lo hi
      | lo >= hi = return lo
      | otherwise = do
          let mid = (lo + hi + 1) `div` 2
          v <- MV.read prefix mid
          if v <= target
            then go mid hi
            else go lo (mid - 1)

-- | Estimate the CDF at value @x@.
-- Returns 'Nothing' if the digest is empty.
cdf :: Double -> MDigest s -> ST s (Maybe Double)
cdf x md = do
  compress md
  cc <- readSTRef (mdCentroidCount md)
  if cc == 0
    then return Nothing
    else do
      mn <- readSTRef (mdMin md)
      mx <- readSTRef (mdMax md)
      if x <= mn
        then return (Just 0)
        else
          if x >= mx
            then return (Just 1)
            else do
              n <- readSTRef (mdTotalWeight md)
              centroids <- readSTRef (mdCentroids md)
              prefix <- readSTRef (mdPrefixSums md)
              walkCdf centroids prefix cc n mn mx x

walkCdf ::
  MV.MVector s (Double, Double) ->
  MV.MVector s Double ->
  Int ->
  Double ->
  Double ->
  Double ->
  Double ->
  ST s (Maybe Double)
walkCdf centroids prefix cc n mn mx x = go 0
  where
    lastIdx = cc - 1

    go i
      | i >= cc = return (Just 1.0)
      | otherwise = do
          (cMean, cWeight) <- MV.read centroids i
          cumBefore <- MV.read prefix i
          if i == 0 && x < cMean
            then do
              let innerW = cWeight / 2.0
                  frac =
                    if cMean == mn
                      then 1.0
                      else (x - mn) / (cMean - mn)
              return (Just ((innerW * frac) / n))
            else
              if i == 0 && x == cMean
                then return (Just ((cWeight / 2.0) / n))
                else
                  if i == lastIdx && x > cMean
                    then do
                      let halfW = cWeight / 2.0
                          rightW = n - cumBefore - halfW
                          frac =
                            if mx == cMean
                              then 0.0
                              else (x - cMean) / (mx - cMean)
                      return (Just ((cumBefore + halfW + rightW * frac) / n))
                    else
                      if i == lastIdx
                        then return (Just ((cumBefore + cWeight / 2.0) / n))
                        else do
                          let mid = cumBefore + cWeight / 2.0
                          (nextMean, nextWeight) <- MV.read centroids (i + 1)
                          cumNext <- MV.read prefix (i + 1)
                          let nextMid = cumNext + nextWeight / 2.0
                          if x < nextMean
                            then do
                              let frac =
                                    if cMean == nextMean
                                      then 0.5
                                      else (x - cMean) / (nextMean - cMean)
                              return (Just ((mid + frac * (nextMid - mid)) / n))
                            else go (i + 1)

-- ---------------------------------------------------------------------------
-- Accessors
-- ---------------------------------------------------------------------------

-- | Return the total weight of all values added to the digest.
totalWeight :: MDigest s -> ST s Double
totalWeight md = readSTRef (mdTotalWeight md)

-- | Return the number of centroids, compressing any pending buffer first.
centroidCount :: MDigest s -> ST s Int
centroidCount md = do
  compress md
  readSTRef (mdCentroidCount md)

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge a pure 'TD.TDigest' into the mutable digest.
merge :: TD.TDigest -> MDigest s -> ST s ()
merge other md = do
  let otherCompressed = TD.compress other
      otherCs = TD.centroidList otherCompressed
  mapM_ (\c -> addWeighted (TD.cMean c) (TD.cWeight c) md) otherCs

-- ---------------------------------------------------------------------------
-- Freeze / Thaw
-- ---------------------------------------------------------------------------

-- | Snapshot the mutable digest into a pure 'TD.TDigest'.
freeze :: MDigest s -> ST s TD.TDigest
freeze md = do
  compress md
  cc <- readSTRef (mdCentroidCount md)
  centroids <- readSTRef (mdCentroids md)
  cs <- readCentroids centroids cc 0 []
  tw <- readSTRef (mdTotalWeight md)
  mn <- readSTRef (mdMin md)
  mx <- readSTRef (mdMax md)
  delta <- readSTRef (mdDelta md)
  return (TD.fromComponents cs tw mn mx delta)
  where
    readCentroids _ 0 _ acc = return (reverse acc)
    readCentroids v n i acc = do
      (m, w) <- MV.read v i
      readCentroids v (n - 1) (i + 1) (TD.Centroid m w : acc)

-- | Create a mutable digest from a pure 'TD.TDigest'.
thaw :: TD.TDigest -> ST s (MDigest s)
thaw td = do
  let td' = TD.compress td
      cs = TD.centroidList td'
      delta = TD.getDelta td'
  md <- newWith delta
  writeSTRef (mdTotalWeight md) (TD.totalWeight td')
  writeSTRef (mdMin md) (TD.getMin td')
  writeSTRef (mdMax md) (TD.getMax td')
  let n = length cs
  writeSTRef (mdCentroidCount md) n
  centroids <- MV.new (max n 1)
  writeCentroids centroids cs 0
  writeSTRef (mdCentroids md) centroids
  rebuildPrefixSums md
  return md
  where
    writeCentroids _ [] _ = return ()
    writeCentroids v (c : rest) i = do
      MV.write v i (TD.cMean c, TD.cWeight c)
      writeCentroids v rest (i + 1)

-- ---------------------------------------------------------------------------
-- Convenience runner
-- ---------------------------------------------------------------------------

-- | Run an 'ST' computation that uses a mutable t-digest and return the
-- pure result.
runTDigest :: (forall s. ST s a) -> a
runTDigest = runST

-- ---------------------------------------------------------------------------
-- Utility
-- ---------------------------------------------------------------------------

clamp :: Double -> Double -> Double -> Double
clamp lo hi x
  | x < lo = lo
  | x > hi = hi
  | otherwise = x
