-- |
-- Module      : Data.Sketch.TDigest.Mutable
-- Description : Mutable t-digest via buffer-and-flush with greedy merge in the ST monad
-- Copyright   : (c) Nadia Yvette Chambers, 2025
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
--
-- A mutable t-digest implementation backed by mutable vectors from the
-- @vector@ package, operating entirely within the 'Control.Monad.ST.ST'
-- monad.  Centroids are stored in a mutable unboxed-style vector of
-- @(mean, weight)@ pairs kept sorted by mean.  Prefix sums of weights
-- are maintained for \(O(\log n)\) quantile and CDF queries via binary
-- search.
--
-- == Background
--
-- The /t-digest/ is a streaming, mergeable sketch for approximate quantile
-- estimation, introduced by Dunning (2021)
-- (<https://doi.org/10.1016/j.simpa.2020.100049>).  It belongs to the
-- family of quantile summaries that trade bounded space for approximate
-- answers, a line of work originating with Munro & Paterson (1980)
-- (<https://doi.org/10.1016/0304-3975(80)90061-4>) and continued by
-- Greenwald & Khanna (2001)
-- (<https://doi.org/10.1145/375663.375670>).  The key innovation of the
-- t-digest is the use of a /scale function/ to allow larger centroids in
-- the interior of the distribution while keeping centroids near the tails
-- small, yielding high relative accuracy at extreme quantiles (e.g.,
-- \(q = 0.99\) or \(q = 0.001\)).
--
-- This module provides the /mutable/ variant, which follows a
-- /buffer-and-flush/ strategy: incoming data points are appended to an
-- unsorted buffer in amortised \(O(1)\) time; when the buffer reaches
-- capacity, the entire buffer is flushed into the sorted centroid array
-- via insertion sort followed by a single-pass greedy merge.  This
-- amortised design is the approach recommended by Dunning & Ertl (2019)
-- (<https://arxiv.org/abs/1902.04023>) for high-throughput ingestion.
--
-- == The ST monad approach
--
-- This module uses 'Control.Monad.ST.ST' rather than 'IO' for in-place
-- mutation.  The 'ST' monad provides:
--
-- * /True in-place mutation/ — centroid vectors, prefix-sum arrays, and
--   the pending-addition buffer are modified destructively, avoiding the
--   allocation overhead of persistent data structures.
-- * /Rank-2 type safety/ — the universally quantified state token @s@ in
--   'runTDigest' (equivalently 'Control.Monad.ST.runST') guarantees that
--   no mutable reference can escape the computation.  This is enforced
--   statically by the type system, with no runtime cost.
-- * /No IO escape/ — unlike @IORef@ or @IOVector@, 'STRef' and
--   'Data.Vector.Mutable.MVector' in 'ST' cannot perform arbitrary
--   side-effects.  The result of 'runTDigest' is a pure value.
--
-- For a purely functional alternative that avoids mutable state entirely,
-- see "Data.Sketch.TDigest", which stores centroids in a finger tree
-- (Hinze & Paterson, 2006;
-- <https://doi.org/10.1017/S0956796805005769>) with a four-component
-- monoidal measure, providing \(O(\log n)\) insertion without buffering
-- and \(O(\delta \log n)\) compression via split-based merge.
--
-- == Space bounds
--
-- The t-digest maintains at most \(O(\delta)\) centroids after each
-- compression pass, where \(\delta\) is the compression parameter
-- (default 100).  Between compressions the buffer may hold up to
-- \(5\delta\) pending additions, so peak memory usage is bounded by
-- \(O(\delta)\) centroid slots plus \(O(\delta)\) buffer slots, for a
-- total working set of \(O(\delta)\).  The initial centroid vector is
-- allocated with capacity \(10\delta\) to accommodate the merge of the
-- buffer contents with the existing centroids without reallocation in
-- steady state.
--
-- Because \(\delta\) is a user-chosen constant (typically 100–300), space
-- usage is /independent of the number of data points/ ingested —
-- precisely the guarantee required for streaming applications.
--
-- == Algorithm
--
-- The core algorithm is /buffer-and-flush with greedy merge/:
--
-- 1. __Buffer phase.__  Each call to 'addWeighted' appends the
--    @(mean, weight)@ pair to the end of the buffer in \(O(1)\)
--    amortised time (the buffer is doubled if it overflows).  When the
--    buffer length reaches the capacity \(5\delta\), 'compress' is
--    triggered automatically.
--
-- 2. __Sort phase.__  On compress, all existing centroids and buffered
--    points are collected into a single temporary array and sorted by
--    mean using insertion sort.  Insertion sort is chosen because the
--    existing centroids are already sorted, so the merge of two sorted
--    runs is nearly linear; in practice the buffer is small relative to
--    the total.
--
-- 3. __Greedy merge phase.__  The sorted array is traversed left to
--    right.  A running centroid accumulates incoming points as long as
--    the K1 scale function constraint is satisfied:
--
--    \[
--      k_1(q, \delta) = \frac{\delta}{2\pi} \arcsin(2q - 1)
--    \]
--
--    Two adjacent quantile positions \(q_0\) and \(q_1\) may share a
--    centroid if and only if \(k_1(q_1) - k_1(q_0) \le 1\).  When
--    the constraint would be violated, the accumulated centroid is
--    emitted and a new accumulation begins.  The merged centroid's mean
--    is the standard weighted mean:
--
--    \[
--      \mu_{\text{new}} = \frac{\mu_a \, w_a + \mu_b \, w_b}{w_a + w_b}
--    \]
--
-- 4. __Prefix-sum rebuild.__  After merging, the prefix-sum array is
--    rebuilt in a single linear pass so that @prefixSum[i]@ equals the
--    cumulative weight of centroids \(0, 1, \ldots, i{-}1\).  This
--    array enables \(O(\log n)\) quantile and CDF queries via binary
--    search.
--
-- == Companion implementations
--
-- This project contains 28 language implementations of the merging
-- t-digest.  While this Haskell module uses flat mutable vectors for
-- simplicity, 22 of the other mutable implementations store centroids
-- in /array-backed 2-3-4 trees/.  The 2-3-4 tree is a B-tree of order 4
-- (Bayer & McCreight, 1972; <https://doi.org/10.1007/BF00288683>),
-- equivalent via the well-known isomorphism to a red-black tree (Guibas
-- & Sedgewick, 1978;
-- <https://doi.org/10.1109/SFCS.1978.3>; see also Sedgewick, 2008;
-- <https://sedgewick.io/wp-content/themes/flavor/papers/2008LLRB.pdf>
-- for the left-leaning specialisation).
--
-- The 2-3-4 tree representation offers several advantages for
-- fine-grained quantile workloads:
--
-- * /Cache locality/ — storing nodes in a contiguous array rather than
--   heap-allocated pointers improves spatial locality and reduces cache
--   misses, which matters when the centroid count \(\delta\) is in the
--   hundreds.
-- * /Worst-case \(O(\log n)\) insertion and deletion/ — unlike the
--   amortised buffer-and-flush approach here, the tree-based variants
--   can absorb each data point immediately with a guaranteed logarithmic
--   bound, which is useful in latency-sensitive contexts.
-- * /Robustness for fine-grained queries/ — maintaining a balanced tree
--   of centroids at all times (rather than deferring organisation to
--   periodic compressions) ensures that quantile and CDF queries always
--   see a fully up-to-date structure.
--
-- == Quick start
--
-- @
-- import Data.Sketch.TDigest.Mutable
-- import Control.Monad (forM_)
--
-- example :: Maybe Double
-- example = 'runTDigest' $ do
--   td <- 'new'
--   forM_ [1.0 .. 10000.0] $ \\v -> 'add' v td
--   'quantile' 0.99 td
-- @
module Data.Sketch.TDigest.Mutable
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
import qualified Data.Sketch.TDigest as TD
import qualified Data.Vector.Mutable as MV

-- ---------------------------------------------------------------------------
-- Type
-- ---------------------------------------------------------------------------

-- | A truly mutable t-digest operating within the 'ST' monad, using
-- mutable vectors for centroids, prefix sums, and a pending-additions
-- buffer.
--
-- The internal state comprises:
--
-- * __Centroid vector__ (@mdCentroids@) — a mutable vector of
--   @(mean, weight)@ pairs maintained in sorted order by mean.  After
--   each call to 'compress', this vector contains at most \(O(\delta)\)
--   entries.
--
-- * __Prefix-sum vector__ (@mdPrefixSums@) — a mutable vector of length
--   \(n_c + 1\) (where \(n_c\) is the centroid count) satisfying
--   @prefixSum[0] = 0@ and @prefixSum[i] = \sum_{j=0}^{i-1} w_j@.
--   This enables \(O(\log n_c)\) quantile and CDF queries via binary
--   search without a linear scan.
--
-- * __Buffer__ (@mdBuffer@) — an unsorted staging area for incoming
--   data points.  Points are appended in \(O(1)\) amortised time.
--   When the buffer length reaches the capacity \(5\delta\), a
--   compress cycle is triggered automatically, flushing the buffer
--   into the centroid vector.
--
-- * __Scalar accumulators__ — @mdTotalWeight@, @mdMin@, and @mdMax@
--   track the running total weight and extrema across all points ever
--   ingested (including buffered ones not yet compressed).
--
-- __Invariants.__  Between calls to exported functions:
--
-- 1. The centroid vector is sorted by mean.
-- 2. The prefix-sum vector is consistent with the centroid vector.
-- 3. The buffer length is in \([0, 5\delta)\).
-- 4. @totalWeight@ equals the sum of all centroid weights plus all
--    buffered point weights.
--
-- Invariants (1) and (2) may be temporarily violated while the buffer
-- is non-empty; they are restored by 'compress'.
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

-- | Create a new, empty mutable t-digest with the default compression
-- parameter \(\delta = 100\).
--
-- This is equivalent to @'newWith' 100@.  A \(\delta\) of 100 yields
-- roughly 100 centroids after compression and provides relative accuracy
-- on the order of \(10^{-3}\) at extreme quantiles — sufficient for most
-- monitoring and analytics workloads.  See Dunning & Ertl (2019)
-- (<https://arxiv.org/abs/1902.04023>) for empirical accuracy tables.
new :: ST s (MDigest s)
new = newWith 100

-- | Create a new, empty mutable t-digest with a given compression
-- parameter \(\delta\).
--
-- The compression parameter controls the trade-off between accuracy and
-- space.  Larger values of \(\delta\) produce more centroids (up to
-- \(O(\delta)\)) and therefore higher accuracy, at the cost of increased
-- memory and compression time.  Typical values range from 50 (coarse) to
-- 300 (very accurate).
--
-- __Buffer capacity.__  The internal buffer is sized to hold
-- \(\lceil 5\delta \rceil\) pending additions.  This factor of 5 is an
-- empirical choice: it amortises the cost of compression (which is
-- \(O(\delta)\) per flush) over enough insertions to make the per-insert
-- cost effectively \(O(1)\).
--
-- __Initial centroid allocation.__  The centroid vector is pre-allocated
-- with capacity \(10\delta\) — enough to hold the existing centroids
-- (at most \(\sim\delta\) after the previous compression) plus a full
-- buffer of \(5\delta\) points, without reallocation during the merge
-- phase.
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

-- | Add a single value with unit weight to the digest.
--
-- @'add' x md = 'addWeighted' x 1 md@
--
-- This is the common case for unweighted data streams.  The value is
-- appended to the internal buffer in \(O(1)\) amortised time;
-- compression is triggered automatically when the buffer is full.
add :: Double -> MDigest s -> ST s ()
add x = addWeighted x 1

-- | Add a value with a given weight to the digest.
--
-- __Complexity.__  Amortised \(O(1)\).  The value is appended to the
-- tail of the unsorted buffer; no sorting or merging occurs at this
-- stage.  The running minimum, maximum, and total weight are updated
-- eagerly so that they are always available without a compress cycle.
--
-- __Auto-compress.__  When the buffer length reaches the buffer capacity
-- \(\lceil 5\delta \rceil\), 'compress' is called automatically.  This
-- ensures that memory usage never exceeds \(O(\delta)\) beyond the
-- allocated capacity.
--
-- __Buffer growth.__  If the buffer's underlying vector is full (which
-- can happen if the buffer capacity has been reached but 'compress' has
-- not yet been triggered by a prior code path), the vector is doubled in
-- size via 'Data.Vector.Mutable.grow'.  In steady-state operation this
-- branch is not taken because auto-compress fires at the capacity
-- threshold.
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
--
-- Compression implements the /buffer-and-flush/ strategy described by
-- Dunning & Ertl (2019) (<https://arxiv.org/abs/1902.04023>).  The
-- algorithm proceeds in four stages:
--
-- 1. __Collect.__  All existing centroids and buffered points are copied
--    into a single temporary array of length \(n_c + n_b\).
--
-- 2. __Sort.__  The temporary array is sorted by centroid mean using
--    insertion sort.  Because the first \(n_c\) entries are already in
--    sorted order (they come from the centroid vector), the sort is
--    adaptive: it performs at most \(O(n_b \cdot (n_c + n_b))\)
--    comparisons, which is efficient when \(n_b \ll n_c\).
--
-- 3. __Greedy merge.__  The sorted array is traversed left to right.  A
--    running centroid accumulates successive entries as long as the K1
--    scale function constraint is satisfied.  The K1 scale function is
--    defined as:
--
--    \[
--      k_1(q, \delta) \;=\; \frac{\delta}{2\pi}\,\arcsin(2q - 1)
--    \]
--
--    Given a running accumulated weight \(W_{\text{so far}}\) and a
--    total digest weight \(N\), the quantile interval of the proposed
--    merged centroid spans \([q_0, q_1]\) where
--    \(q_0 = W_{\text{so far}} / N\) and
--    \(q_1 = (W_{\text{so far}} + w_{\text{proposed}}) / N\).
--    The merge is permitted if:
--
--    \[
--      k_1(q_1, \delta) - k_1(q_0, \delta) \;\le\; 1
--    \]
--
--    When this constraint would be violated, the accumulated centroid is
--    emitted and a fresh accumulation begins.  Singletons (weight \(\le 1\))
--    are always merged with their neighbour when not at the boundary, to
--    prevent centroid count blow-up from unit-weight insertions.
--
-- 4. __Rebuild prefix sums.__  A single linear pass rebuilds the
--    prefix-sum array for subsequent \(O(\log n)\) queries.
--
-- __Complexity.__  \(O((n_c + n_b)^2)\) worst-case due to insertion sort,
-- but \(O(n_c + n_b)\) in the common case when the buffer is small
-- relative to the sorted centroid array.  The output centroid count is
-- bounded by \(O(\delta)\).
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

-- | Estimate the value at quantile \(q\) where \(0 \le q \le 1\).
--
-- Returns 'Nothing' if the digest is empty (no data points have been
-- added).
--
-- __Algorithm.__  The digest is first compressed (flushing any buffered
-- points) to ensure the centroid vector and prefix sums are up to date.
-- A binary search on the prefix-sum array locates the centroid \(c_i\)
-- whose cumulative weight interval contains the target rank
-- \(t = q \cdot N\).  The returned value is then computed by linear
-- interpolation between adjacent centroid midpoints:
--
-- * For the /leftmost/ centroid (\(i = 0\)), the target rank
--   \(t < w_0 / 2\) triggers interpolation between the observed minimum
--   and \(\mu_0\).
-- * For the /rightmost/ centroid (\(i = n_c - 1\)), the target rank
--   \(t > N - w_{n_c - 1} / 2\) triggers interpolation between
--   \(\mu_{n_c - 1}\) and the observed maximum.
-- * For /interior/ centroids, the result is linearly interpolated
--   between the midpoints of \(c_i\) and \(c_{i+1}\):
--
--   \[
--     \hat{x} = \mu_i + \frac{t - m_i}{m_{i+1} - m_i} \cdot (\mu_{i+1} - \mu_i)
--   \]
--
--   where \(m_i = \text{cumBefore}_i + w_i / 2\) is the midpoint rank
--   of centroid \(i\).
--
-- __Complexity.__  \(O(\delta)\) due to the initial compress (if the
-- buffer is non-empty), then \(O(\log \delta)\) for the binary search.
-- If the buffer is already empty, the cost is \(O(\log \delta)\).
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
walkQuantile centroids prefix cc n mn mx target = go
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

-- | Estimate the cumulative distribution function (CDF) at value \(x\),
-- i.e., the fraction of the distribution that lies at or below \(x\).
--
-- Returns 'Nothing' if the digest is empty.
--
-- __Algorithm.__  Like 'quantile', this function first compresses any
-- buffered points.  It then performs a linear walk over the centroid
-- vector to locate the pair of centroids straddling \(x\), and
-- interpolates:
--
-- * If \(x \le x_{\min}\), the result is 0.
-- * If \(x \ge x_{\max}\), the result is 1.
-- * If \(x\) falls in the half-weight region of the first centroid
--   (i.e., \(x < \mu_0\)), the result is interpolated between 0 and
--   \(w_0 / (2N)\).
-- * If \(x\) falls in the half-weight region of the last centroid,
--   the result is interpolated between
--   \((\sum w - w_{n-1}/2) / N\) and 1.
-- * Otherwise, the result is linearly interpolated between the midpoint
--   ranks of the two bracketing centroids, yielding:
--
--   \[
--     \widehat{F}(x) = \frac{m_i + \frac{x - \mu_i}{\mu_{i+1} - \mu_i} \cdot (m_{i+1} - m_i)}{N}
--   \]
--
-- __Complexity.__  \(O(\delta)\) due to compression plus a linear walk
-- over centroids.
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
--
-- This includes both compressed centroids and pending buffer entries.
-- The value is maintained eagerly (updated on every 'addWeighted' call),
-- so this accessor is \(O(1)\) and does not trigger compression.
totalWeight :: MDigest s -> ST s Double
totalWeight md = readSTRef (mdTotalWeight md)

-- | Return the number of centroids, compressing any pending buffer first.
--
-- Because the true centroid count is only well-defined after all buffered
-- points have been merged, this function calls 'compress' before reading
-- the count.  If no buffer entries are pending, the compress is a no-op
-- (the guard @bl > 0 || cc > 1@ shortcuts immediately).
--
-- __Complexity.__  \(O(\delta)\) if compression is needed, \(O(1)\)
-- otherwise.
centroidCount :: MDigest s -> ST s Int
centroidCount md = do
  compress md
  readSTRef (mdCentroidCount md)

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge a pure 'TD.TDigest' into the mutable digest.
--
-- The pure digest is first compressed, then its centroids are extracted
-- as a list and fed one by one into 'addWeighted'.  This triggers the
-- standard buffer-and-flush lifecycle: centroids accumulate in the
-- buffer and are flushed when the buffer fills.
--
-- This operation is useful in /parallel and distributed/ settings: each
-- worker thread can build a local pure 'TD.TDigest' (or a local
-- t'MDigest' frozen via 'freeze'), and a coordinator can merge all
-- partial digests into a single mutable accumulator.  Because the
-- t-digest is a mergeable sketch (Dunning, 2021;
-- <https://doi.org/10.1016/j.simpa.2020.100049>), the merged result has
-- accuracy comparable to a single-pass digest over the combined data.
--
-- __Complexity.__  \(O(m)\) insertions where \(m\) is the centroid count
-- of the source digest, plus any triggered compressions.
merge :: TD.TDigest -> MDigest s -> ST s ()
merge other md = do
  let otherCompressed = TD.compress other
      otherCs = TD.centroidList otherCompressed
  mapM_ (\c -> addWeighted (TD.cMean c) (TD.cWeight c) md) otherCs

-- ---------------------------------------------------------------------------
-- Freeze / Thaw
-- ---------------------------------------------------------------------------

-- | Snapshot the mutable digest into a pure 'TD.TDigest'.
--
-- The mutable digest is compressed first (flushing any buffered points),
-- then its centroids, total weight, extrema, and compression parameter
-- are read out and packaged into a pure 'TD.TDigest' via
-- 'TD.fromComponents'.
--
-- The resulting pure digest is backed by a finger tree (Hinze &
-- Paterson, 2006; <https://doi.org/10.1017/S0956796805005769>) and
-- supports \(O(\log n)\) queries and further pure insertions.
--
-- __Use case.__  'freeze' is the primary exit path from a mutable
-- computation when the result must be returned to pure code or
-- serialised.  It is also the mechanism for snapshotting a running
-- digest — the mutable digest remains usable after 'freeze'.
--
-- __Complexity.__  \(O(\delta)\) for the compress plus a linear
-- traversal to extract centroids.
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
--
-- The pure digest is compressed, its centroids are written into a fresh
-- mutable vector, and the scalar accumulators (total weight, min, max,
-- delta) are initialised from the pure digest's fields.  Prefix sums
-- are rebuilt immediately.
--
-- __Use case.__  'thaw' is the entry path for converting a pure digest
-- (e.g., received from another thread or deserialised from storage) into
-- a mutable digest for continued high-throughput ingestion.  In a
-- parallel/distributed pipeline, each worker can 'thaw' a shared seed
-- digest, ingest a partition of the data mutably, 'freeze' the result,
-- and return it for merging.
--
-- __Complexity.__  \(O(\delta)\) for the copy and prefix-sum rebuild.
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
--
-- This is a thin wrapper around 'Control.Monad.ST.runST'.  The rank-2
-- type @(forall s. 'ST' s a) -> a@ ensures that no mutable reference
-- (including the t'MDigest' itself, its internal 'STRef's, and its
-- 'Data.Vector.Mutable.MVector's) can escape the scope of the
-- computation.  This guarantee is enforced statically by the Haskell
-- type checker via the universally quantified state token @s@ — any
-- attempt to return or store a value whose type mentions @s@ is a type
-- error.  See Launchbury & Peyton Jones (1994), /Lazy Functional State
-- Threads/, for the theoretical foundation.
--
-- __Usage pattern.__  Typically, one creates a digest with 'new' or
-- 'newWith', performs insertions with 'add' or 'addWeighted', and
-- extracts a result with 'quantile', 'cdf', or 'freeze' — all within
-- the 'runTDigest' block:
--
-- @
-- result :: Maybe Double
-- result = 'runTDigest' $ do
--   td <- 'new'
--   'add' 42.0 td
--   'quantile' 0.5 td
-- @
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
