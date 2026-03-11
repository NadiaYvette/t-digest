-- |
-- Module      : Data.Sketch.TDigest
-- Description : Dunning t-digest for online quantile estimation
-- Copyright   : (c) Nadia Yvette Chambers, 2025
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
--
-- A pure functional implementation of the Dunning t-digest data structure,
-- using the merging digest variant with the \(K_1\) (arcsine) scale function.
-- The t-digest provides streaming, mergeable, memory-bounded approximation
-- of quantile (percentile) queries with high accuracy in the tails.
--
-- == Background
--
-- The /streaming quantile problem/ asks: given a (possibly unbounded) stream
-- of real-valued observations, answer queries of the form "what is the value
-- at the \(q\)-th quantile?" using bounded memory.
-- Munro & Paterson (1980) established that exact selection from a stream of
-- \(n\) elements requires \(\Omega(n)\) space in the comparison model
-- (<https://doi.org/10.1016/0304-3975(80)90061-4>), so any sub-linear space
-- algorithm must accept approximation.  Greenwald & Khanna (2001) gave the
-- first \(\varepsilon\)-approximate streaming quantile summary with space
-- \(O\!\bigl(\frac{1}{\varepsilon}\log(\varepsilon n)\bigr)\)
-- (<https://doi.org/10.1145/375663.375670>), guaranteeing uniform error across
-- all quantiles.  The t-digest takes a different approach: it trades uniform
-- guarantees for much higher accuracy in the extreme tails (\(q \approx 0\) or
-- \(q \approx 1\)), which is the regime most relevant to SLA monitoring,
-- anomaly detection, and financial risk measurement.
--
-- == The t-digest
--
-- The t-digest, introduced by Ted Dunning
-- (<https://doi.org/10.1016/j.simpa.2020.100049>; see also Dunning & Ertl,
-- <https://arxiv.org/abs/1902.04023>), represents an empirical distribution as
-- an ordered sequence of /centroids/ \((m_i, w_i)\), where \(m_i\) is a
-- weighted mean and \(w_i\) is a count of observations.  Centroids are kept
-- sorted by mean.  The key idea is to use a /scale function/ \(k(q, \delta)\)
-- that maps the quantile axis \([0, 1]\) to a "scale space" in which uniform
-- spacing corresponds to the desired non-uniform resolution in quantile space.
--
-- This module implements the /merging digest/ variant with the \(K_1\)
-- (arcsine) scale function:
--
-- \[
--   k(q, \delta) \;=\; \frac{\delta}{2\pi}\,\arcsin(2q - 1)
-- \]
--
-- The \(K_1\) function has infinite derivative at \(q = 0\) and \(q = 1\),
-- meaning it allocates proportionally more centroids near the tails.  Its
-- inverse is:
--
-- \[
--   q(k, \delta) \;=\; \frac{1 + \sin\!\bigl(\frac{2\pi k}{\delta}\bigr)}{2}
-- \]
--
-- A new observation may be merged into an existing centroid \(i\) only if the
-- resulting centroid would satisfy the /size constraint/:
--
-- \[
--   k\!\bigl(q_{\mathrm{upper}},\, \delta\bigr) \;-\; k\!\bigl(q_{\mathrm{lower}},\, \delta\bigr) \;\le\; 1
-- \]
--
-- where \(q_{\mathrm{lower}}\) and \(q_{\mathrm{upper}}\) are the quantile
-- boundaries of the (proposed) merged centroid.  This constraint ensures that
-- centroids near \(q = 0\) and \(q = 1\) remain small (even singletons),
-- while centroids near the median may absorb many observations.
--
-- == Space bounds
--
-- The number of centroids in a t-digest is bounded by \(O(\delta)\)
-- /regardless/ of the number of observations \(n\).  Specifically, the integer
-- range of the scale function is
-- \(\lceil k(0,\delta)\rceil \ldots \lfloor k(1,\delta)\rfloor =
-- \lceil -\delta/2\rceil \ldots \lfloor \delta/2\rfloor\),
-- giving at most \(\delta + 1\) unit intervals and therefore at most
-- \(\delta + 1\) centroids after compression.  In practice the compression
-- threshold is set to \(3\delta\) centroids (before triggering a compress
-- pass), so the working-set size is at most \(3\delta\) centroids.  With the
-- default \(\delta = 100\), this means at most 300 centroids regardless of
-- whether the stream contains \(10^3\) or \(10^{12}\) observations.
--
-- == Implementation: finger trees with a four-component measure
--
-- This module stores centroids in a @'Data.FingerTree.FingerTree'@ from the
-- @fingertree@ package, as described by Hinze & Paterson (2006)
-- (<https://doi.org/10.1017/S0956796805005769>).  Finger trees support
-- amortised \(O(\log n)\) split and concatenation, and \(O(1)\) access to
-- extremal elements, making them well suited for the sorted-centroid
-- representation.
--
-- The monoidal measure carried by the tree has four components:
--
-- 1. @mWeight@ \(= \sum w_i\): cumulative weight, enabling split-by-weight
--    for quantile queries.
-- 2. @mCount@ \(= |\{i\}|\): centroid count, enabling \(O(1)\)
--    'centroidCount'.
-- 3. @mMaxMean@ \(= \max\{m_i\}\): maximum mean over the subtree, enabling
--    split-by-mean for insertion and CDF queries.  Because centroids are
--    stored in sorted order, @mMaxMean@ is monotone over prefixes.
-- 4. @mMeanWeightSum@ \(= \sum m_i w_i\): the sum of products of mean and
--    weight.  This enables \(O(1)\) computation of the merged mean of any
--    contiguous chunk: \(\bar{m} = \texttt{mMeanWeightSum} /
--    \texttt{mWeight}\).  This is the key to achieving \(O(\delta \log n)\)
--    compression: each of the \(O(\delta)\) chunks produced by splitting at
--    scale-function unit boundaries can be collapsed into a single centroid
--    without traversing its elements.
--
-- == Companion implementations: array-backed 2-3-4 trees
--
-- Twenty-two mutable implementations in this project (in C, C++, Rust, Go,
-- Zig, Java, C#, and others) use array-backed 2-3-4 trees instead of
-- finger trees.  The 2-3-4 tree is a B-tree of order 4 (Bayer & McCreight,
-- 1972; <https://doi.org/10.1007/BF00288683>), isomorphic to a red-black tree
-- via the correspondence established by Guibas & Sedgewick (1978)
-- (<https://doi.org/10.1109/SFCS.1978.3>; see also Sedgewick, 2008,
-- <https://sedgewick.io/wp-content/themes/flavor/papers/2008LLRB.pdf>),
-- provides worst-case \(O(\log n)\) insertion, deletion, and search with
-- excellent cache locality when nodes are packed into a flat array.  This is
-- particularly important for robustness at very fine-grained quantile queries
-- (e.g., \(q = 0.9999\)) where the tail centroids that determine accuracy
-- must be located quickly and updated with minimal overhead.  The array-backed
-- layout avoids pointer-chasing and improves branch-prediction behaviour,
-- yielding 2--5\(\times\) speedups in practice over pointer-based trees.
--
-- == Quick start
--
-- @
-- import Data.Sketch.TDigest
-- import Data.List ('Data.List.foldl\'')
--
-- main :: IO ()
-- main = do
--   let td = 'Data.List.foldl\'' (flip 'add') 'empty' [1.0 .. 10000.0]
--   print ('quantile' 0.99 td)   -- Just ~9900.5
--   print ('cdf' 5000.0 td)      -- Just ~0.5
-- @
module Data.Sketch.TDigest
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

-- ---------------------------------------------------------------------------
-- Measure (monoidal annotation for the finger tree)
-- ---------------------------------------------------------------------------

-- | Monoidal measure carried by every internal node of the finger tree.
--
-- Following Hinze & Paterson (2006)
-- (<https://doi.org/10.1017/S0956796805005769>), a finger tree is
-- parameterised by a monoid whose cached values enable efficient splitting.
-- The t-digest requires /four/ independent capabilities from the tree, so the
-- measure is a four-component product monoid:
--
-- * @mWeight@ — cumulative weight \(\sum w_i\).  Used by 'quantile' to
--   split the tree at a target cumulative weight in \(O(\log n)\).
--
-- * @mCount@ — number of centroids \(|\{i\}|\).  Provides \(O(1)\)
--   'centroidCount' and is used during quantile interpolation to detect
--   boundary centroids.
--
-- * @mMaxMean@ — maximum centroid mean \(\max\{m_i\}\) in the subtree.
--   Because centroids are sorted by mean, this value is monotone over
--   prefixes, enabling 'FT.split' by mean value for insertion ('addWeighted')
--   and CDF queries ('cdf').
--
-- * @mMeanWeightSum@ — the sum \(\sum m_i w_i\).  Combined with @mWeight@,
--   this allows the weighted mean of any contiguous subtree to be computed in
--   \(O(1)\): \(\bar{m} = \texttt{mMeanWeightSum}\,/\,\texttt{mWeight}\).
--   This is the critical component that makes 'compress' run in
--   \(O(\delta \log n)\) rather than \(O(n)\): each chunk produced by
--   splitting at \(K_1\) unit boundaries is collapsed into a single centroid
--   without iterating over its elements.
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

-- | A single centroid in the t-digest, representing a cluster of nearby
-- values by their weighted mean and total weight.
--
-- In the t-digest framework (Dunning, 2021;
-- <https://doi.org/10.1016/j.simpa.2020.100049>), the empirical distribution
-- is approximated by an ordered sequence of centroids \((m_i, w_i)\).  When a
-- new observation \(x\) with weight \(w\) is merged into an existing centroid
-- \((m_i, w_i)\), the weighted mean update rule is applied:
--
-- \[
--   m_i' \;=\; \frac{m_i \, w_i \;+\; x \, w}{w_i + w},
--   \qquad
--   w_i' \;=\; w_i + w
-- \]
--
-- This is the standard incremental weighted mean, which is exact in
-- floating-point arithmetic up to the usual rounding.  Note that the centroid
-- does /not/ store individual observations — only the summary statistics
-- \((m_i, w_i)\) are retained, which is what gives the t-digest its bounded
-- space.
data Centroid = Centroid
  { -- | Weighted mean of all values merged into this centroid.
    cMean :: {-# UNPACK #-} !Double,
    -- | Total weight (count) of values in this centroid.  For unweighted
    -- streams, this is simply the number of observations that have been
    -- merged into this centroid.
    cWeight :: {-# UNPACK #-} !Double
  }
  deriving (Show)

instance Measured Measure Centroid where
  measure c = Measure (cWeight c) 1 (cMean c) (cMean c * cWeight c)

-- | The t-digest data structure for online quantile estimation.
--
-- Internally, a t'TDigest' consists of:
--
-- * A 'FingerTree' of t'Centroid's, sorted by mean.  The tree carries the
--   four-component @Measure@ described above, enabling \(O(\log n)\) split
--   operations by both mean and cumulative weight.
--
-- * Cached metadata: the total weight \(N = \sum w_i\), the global minimum
--   and maximum of all observed values, the compression parameter \(\delta\),
--   and the compression threshold \(3\delta\).
--
-- __Invariants:__
--
-- 1. Centroids are sorted in non-decreasing order of 'cMean'.
-- 2. @tdTotalWeight@ equals @mWeight (measure tdCentroids)@ and equals the
--    sum of all 'cWeight' values.
-- 3. @tdMin@ \(\le m_1\) and @tdMax@ \(\ge m_k\) (where \(k\) is the number
--    of centroids), with equality in the singleton case.
-- 4. After 'compress', every centroid satisfies the \(K_1\) size constraint:
--    \(k(q_{\mathrm{upper}}, \delta) - k(q_{\mathrm{lower}}, \delta) \le 1\),
--    where \(q_{\mathrm{lower}}\) and \(q_{\mathrm{upper}}\) are the
--    normalised cumulative weight boundaries of the centroid.
-- 5. The centroid count never exceeds \(3\delta\) for sustained periods;
--    insertions that push the count above this threshold trigger an automatic
--    'compress' pass.
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

-- | Create an empty t-digest with the default compression parameter
-- \(\delta = 100\).
--
-- This is a good starting point for most applications.  With \(\delta = 100\),
-- the digest will use at most 300 centroids (the compression threshold is
-- \(3\delta\)), occupying roughly 4.8 KB of centroid data.  Empirically, this
-- yields quantile errors below \(10^{-4}\) at the median and below
-- \(10^{-6}\) for \(q < 0.01\) or \(q > 0.99\)
-- (Dunning & Ertl, 2019; <https://arxiv.org/abs/1902.04023>).
empty :: TDigest
empty = emptyWith 100

-- | Create an empty t-digest with a given compression parameter \(\delta\).
--
-- The compression parameter controls the trade-off between accuracy and space:
--
-- * __Larger \(\delta\)__ (e.g., 200–500) means more centroids are retained,
--   giving higher accuracy — especially at extreme quantiles — at the cost of
--   more memory and slower queries.
-- * __Smaller \(\delta\)__ (e.g., 20–50) means fewer centroids, saving
--   memory but increasing quantile estimation error.
--
-- The maximum number of centroids after compression is \(\delta + 1\)
-- (one per integer unit in the range of \(K_1\)), and the compression
-- threshold (the point at which automatic compression is triggered during
-- insertion) is set to \(\lceil 3\delta \rceil\).  Typical values used in
-- production systems are \(\delta \in [50, 300]\).
--
-- Setting \(\delta \le 0\) is not meaningful and will result in a digest that
-- compresses aggressively to zero or one centroid.
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

-- | The \(K_1\) (arcsine) scale function:
--
-- \[
--   k(q, \delta) \;=\; \frac{\delta}{2\pi}\,\arcsin(2q - 1)
-- \]
--
-- This function maps the quantile domain \([0, 1]\) to the "scale space"
-- \([-\delta/2,\; \delta/2]\).  Its derivative
-- \(k'(q) = \frac{\delta}{\pi\sqrt{q(1-q)}}\) diverges at \(q = 0\) and
-- \(q = 1\), causing centroids near the tails to be allocated much more
-- finely than centroids near the median — which is the defining feature of
-- the t-digest's accuracy profile.
kScale :: Double -> Double -> Double
kScale delta q = (delta / (2 * pi)) * asin (2 * q - 1)

-- | Inverse of the \(K_1\) scale function:
--
-- \[
--   q(k, \delta) \;=\; \frac{1 + \sin\!\bigl(\frac{2\pi k}{\delta}\bigr)}{2}
-- \]
--
-- Used during 'compress' to compute the quantile boundaries corresponding to
-- integer scale-function values, i.e., the boundaries of the unit intervals
-- in scale space.
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

-- | Add a single value with weight 1 to the digest.
--
-- \(O(\log n)\) amortised, where \(n\) is the number of centroids.
-- Equivalent to @'addWeighted' x 1@.
add :: Double -> TDigest -> TDigest
add x = addWeighted x 1

-- | Add a value \(x\) with a given weight \(w\) to the digest.
--
-- The algorithm proceeds as follows:
--
-- 1. __Split__ the finger tree at the insertion point using
--    @'FT.split' (\m -> mMaxMean m >= x)@, yielding a left subtree (all
--    centroids with mean \(< x\)) and a right subtree (mean \(\ge x\)).
--    This is \(O(\log n)\) by the finger tree split theorem
--    (Hinze & Paterson, 2006; <https://doi.org/10.1017/S0956796805005769>).
--
-- 2. __Find nearest neighbour:__ examine the rightmost centroid of the left
--    subtree and the leftmost centroid of the right subtree.  For each
--    candidate neighbour \((m_i, w_i)\), compute the proposed merged weight
--    \(w_i + w\) and check the \(K_1\) scale-function constraint:
--
--    \[
--      k\!\bigl(q_{\mathrm{upper}},\, \delta\bigr)
--      \;-\; k\!\bigl(q_{\mathrm{lower}},\, \delta\bigr)
--      \;\le\; 1
--    \]
--
--    where \(q_{\mathrm{lower}}\) and \(q_{\mathrm{upper}}\) are the
--    normalised cumulative weight boundaries of the proposed merged centroid.
--
-- 3. __Merge or insert:__ if one or both neighbours can absorb the new value,
--    merge with the /closer/ one (by distance \(|m_i - x|\)) using the
--    weighted mean update rule.  If neither can absorb it (because doing so
--    would violate the size constraint), insert a new singleton centroid
--    \((x, w)\) into the tree.
--
-- 4. __Auto-compress:__ if the centroid count exceeds the threshold
--    \(3\delta\), trigger a 'compress' pass.
--
-- The overall amortised cost is \(O(\log n)\), dominated by the finger tree
-- split and concatenation.
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

-- | Merge two centroids using the weighted mean update rule:
--
-- \[
--   m' = \frac{m_a \, w_a + m_b \, w_b}{w_a + w_b},
--   \qquad
--   w' = w_a + w_b
-- \]
mergeCentroid :: Centroid -> Centroid -> Centroid
mergeCentroid a b =
  let w = cWeight a + cWeight b
      m = (cMean a * cWeight a + cMean b * cWeight b) / w
   in Centroid m w

-- ---------------------------------------------------------------------------
-- Compression (split-based greedy merge)
-- ---------------------------------------------------------------------------

-- | Compress the digest by merging centroids that fall within the same
-- \(K_1\) scale-function unit interval.
--
-- The compression algorithm works as follows:
--
-- 1. Compute the integer range of the \(K_1\) scale function:
--    \(j_{\min} = \lceil k(0, \delta) \rceil = \lceil -\delta/2 \rceil\) and
--    \(j_{\max} = \lfloor k(1, \delta) \rfloor = \lfloor \delta/2 \rfloor\).
--
-- 2. For each integer \(j \in \{j_{\min}+1, \ldots, j_{\max}\}\), compute the
--    cumulative weight boundary \(b_j = k^{-1}(j, \delta) \cdot N\), where
--    \(N\) is the total weight.
--
-- 3. Split the finger tree at each boundary \(b_j\) by cumulative weight
--    (using @'FT.split' (\m -> mWeight m > b_j)@), yielding \(O(\delta)\)
--    contiguous chunks.
--
-- 4. Collapse each chunk into a single centroid using the @mMeanWeightSum@
--    and @mWeight@ components of the monoidal measure:
--    \(\bar{m} = \texttt{mMeanWeightSum}\,/\,\texttt{mWeight}\).  This is
--    \(O(1)\) per chunk — no traversal of individual centroids is needed.
--
-- __Complexity:__ \(O(\delta \log n)\), because there are \(O(\delta)\) split
-- operations, each costing \(O(\log n)\) where \(n\) is the pre-compression
-- centroid count.  After compression, the centroid count is at most
-- \(\delta + 1\).
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
-- chunk into a single centroid.  This is the inner loop of 'compress'.
--
-- The function walks through the list of weight boundaries, performing
-- an @'FT.split'@ at each one.  Each resulting chunk (a contiguous sub-tree
-- of centroids whose combined weight falls within a single \(K_1\) unit
-- interval) is collapsed via 'mergeChunk' into a single centroid and appended
-- to the accumulator.
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
-- using the monoidal measure.  Runs in \(O(1)\) — no traversal of
-- individual centroids is needed, because the measure already caches
-- \(\sum w_i\) and \(\sum m_i w_i\).
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

-- | Estimate the value at quantile \(q\) (\(0 \le q \le 1\)).
--
-- The algorithm uses an interpolation scheme that treats each centroid as
-- representing a point mass at its mean, spread uniformly over a weight
-- interval centred at the centroid's cumulative midpoint.  Between
-- consecutive centroid midpoints, the estimated quantile function is linearly
-- interpolated:
--
-- \[
--   \hat{x}(q) \;=\; m_i + \frac{q \cdot N - \mathrm{mid}_i}
--   {\mathrm{mid}_{i+1} - \mathrm{mid}_i} \cdot (m_{i+1} - m_i)
-- \]
--
-- where \(\mathrm{mid}_i = \sum_{j<i} w_j + w_i/2\) is the cumulative
-- midpoint of centroid \(i\), and \(N = \sum w_j\).
--
-- __Boundary handling:__ for the leftmost centroid, if \(q \cdot N\) falls
-- below \(w_1 / 2\), the function interpolates between the global minimum
-- (@tdMin@) and \(m_1\).  Symmetrically, for the rightmost centroid, it
-- interpolates between \(m_k\) and the global maximum (@tdMax@).  This
-- ensures that 'quantile' returns @tdMin@ at \(q = 0\) and @tdMax@ at
-- \(q = 1\).
--
-- __Complexity:__ \(O(\log n)\) via @'FT.split'@ on cumulative weight,
-- followed by a constant amount of local interpolation work.
--
-- Returns 'Nothing' if the digest is empty.
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
    interpolateRight c _cumulative target =
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

-- | Estimate the cumulative distribution function (CDF) at value \(x\),
-- i.e., the fraction of the distribution that lies at or below \(x\).
--
-- The CDF is estimated by piecewise-linear interpolation between centroid
-- midpoints.  For a query point \(x\) falling between the means of
-- consecutive centroids \(m_i\) and \(m_{i+1}\), the estimated CDF is:
--
-- \[
--   \hat{F}(x) \;=\; \frac{1}{N}\left(
--     \mathrm{mid}_i + \frac{x - m_i}{m_{i+1} - m_i}
--     \cdot (\mathrm{mid}_{i+1} - \mathrm{mid}_i)
--   \right)
-- \]
--
-- where \(\mathrm{mid}_i = \sum_{j<i} w_j + w_i/2\).
--
-- __Boundary handling:__ if \(x \le \texttt{tdMin}\) the function returns 0;
-- if \(x \ge \texttt{tdMax}\) it returns 1.  For \(x\) below the first
-- centroid mean or above the last, the function interpolates between the
-- global extreme and the nearest centroid mean, mirroring the boundary
-- treatment in 'quantile'.
--
-- __Complexity:__ \(O(\log n)\) via @'FT.split'@ on the @mMaxMean@ component
-- of the monoidal measure, which locates the pair of centroids straddling
-- the query point without scanning.
--
-- Returns 'Nothing' if the digest is empty.
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

-- | Merge two t-digests into one, preserving accuracy.
--
-- The merge operation inserts every centroid of the second digest into the
-- first (using 'addWeighted' with the centroid's mean and weight), then
-- applies 'compress' to restore the \(K_1\) size invariant.
--
-- This is the standard approach for combining digests computed on
-- disjoint data partitions, enabling distributed and parallel quantile
-- estimation.  In a MapReduce-style pipeline, each mapper builds a local
-- t'TDigest' and the reducer merges them with 'merge'.  Because 'compress'
-- enforces the same \(O(\delta)\) centroid bound, the merged result has
-- the same space footprint as a single-stream digest.
--
-- See Dunning (2021), Section 4.3 (<https://doi.org/10.1016/j.simpa.2020.100049>)
-- for a discussion of mergeability and its applications.
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
-- This is \(O(1)\), as the total weight is cached in the t'TDigest' record.
-- For an unweighted stream, this equals the number of observations.
totalWeight :: TDigest -> Double
totalWeight = tdTotalWeight

-- | Return the number of centroids currently stored in the digest.
--
-- This is \(O(1)\) via the @mCount@ component of the finger tree's monoidal
-- measure.  The count is always at most \(3\delta\) (and at most
-- \(\delta + 1\) immediately after 'compress').
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
-- Additional accessors (for Mutable interop)
-- ---------------------------------------------------------------------------

-- | Return the list of centroids in sorted order (by mean).
--
-- Useful for serialisation, interoperability with mutable implementations,
-- debugging, and visualisation of the digest's internal distribution.  The
-- list is produced by an in-order traversal of the finger tree in
-- \(O(n)\).
centroidList :: TDigest -> [Centroid]
centroidList = ftToList . tdCentroids

-- | Return the compression parameter \(\delta\).
--
-- This is needed for serialisation and for reconstructing a digest with
-- 'fromComponents'.
getDelta :: TDigest -> Double
getDelta = tdDelta

-- | Return the minimum observed value.
--
-- The global minimum is tracked separately from the centroids because the
-- first centroid's mean may be larger than the minimum (if multiple values
-- have been merged into it).  The minimum is used for boundary interpolation
-- in 'quantile' and 'cdf' at \(q \to 0\) and \(x \to \min\).
getMin :: TDigest -> Double
getMin = tdMin

-- | Return the maximum observed value.
--
-- Symmetric to 'getMin': the global maximum is used for boundary
-- interpolation in 'quantile' and 'cdf' at \(q \to 1\) and \(x \to \max\).
getMax :: TDigest -> Double
getMax = tdMax

-- | Reconstruct a t-digest from its serialised components: a list of
-- centroids (which /must/ be in non-decreasing order of mean), the total
-- weight, the global minimum and maximum, and the compression parameter
-- \(\delta\).
--
-- This function trusts the caller to provide correctly sorted centroids and
-- consistent metadata.  It is intended for deserialisation and for
-- transferring digests between this pure implementation and the mutable
-- array-backed implementations in other languages.  No validation or
-- re-compression is performed.
--
-- __Usage example:__
--
-- @
-- let cs = 'centroidList' td
--     tw = 'totalWeight' td
--     mn = 'getMin' td
--     mx = 'getMax' td
--     d  = 'getDelta' td
--     td' = 'fromComponents' cs tw mn mx d
-- -- td' is equivalent to td
-- @
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
