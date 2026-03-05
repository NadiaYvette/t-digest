-- |
-- Module      : TDigestM
-- Description : Mutable (ST/IO) interface for the Dunning t-digest
-- Stability   : experimental
-- Maintainer  : Nadia Yvette Chambers
--
-- This module provides a mutable wrapper around the pure 'TDigest.TDigest'
-- type, using 'STRef' for in-place mutation within the 'ST' monad. This
-- is convenient when building a digest imperatively (e.g., in a loop)
-- without threading state manually.
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
    MDigest
    -- * Construction
  , new, newWith
    -- * Insertion
  , add, addWeighted
    -- * Compression
  , compress
    -- * Queries
  , quantile, cdf
    -- * Merging
  , merge
    -- * Conversion
  , freeze, thaw
    -- * Accessors
  , totalWeight, centroidCount
    -- * Runner
  , runTDigest
  ) where

import Control.Monad.ST (ST, runST)
import Data.STRef        (STRef, newSTRef, readSTRef, writeSTRef, modifySTRef')

import qualified TDigest as TD

-- ---------------------------------------------------------------------------
-- Type
-- ---------------------------------------------------------------------------

-- | A mutable t-digest backed by an 'STRef' pointing to a pure 'TD.TDigest'.
--
-- The type parameter @s@ is the state thread token from the 'ST' monad,
-- preventing the mutable reference from escaping its scope.
newtype MDigest s = MDigest (STRef s TD.TDigest)

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create a new mutable t-digest with the default compression (delta = 100).
--
-- >>> runTDigest (new >>= totalWeight)
-- 0.0
new :: ST s (MDigest s)
new = MDigest <$> newSTRef TD.empty

-- | Create a new mutable t-digest with a given compression parameter.
--
-- Higher delta values yield more centroids and better accuracy.
newWith :: Double -> ST s (MDigest s)
newWith delta = MDigest <$> newSTRef (TD.emptyWith delta)

-- ---------------------------------------------------------------------------
-- Mutation
-- ---------------------------------------------------------------------------

-- | Add a single value (weight 1) to the digest in place.
--
-- Triggers automatic compression when the buffer fills up.
add :: Double -> MDigest s -> ST s ()
add x (MDigest ref) = modifySTRef' ref (TD.add x)

-- | Add a value with a given weight to the digest in place.
--
-- Useful for ingesting pre-aggregated data.
addWeighted :: Double -> Double -> MDigest s -> ST s ()
addWeighted x w (MDigest ref) = modifySTRef' ref (TD.addWeighted x w)

-- | Force compression of the internal buffer into the centroid list.
--
-- This is normally triggered automatically; call it explicitly only if you
-- need the digest in a fully-compressed state (e.g., before serialization).
compress :: MDigest s -> ST s ()
compress (MDigest ref) = modifySTRef' ref TD.compress

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

-- | Estimate the value at quantile @q@ (0 <= q <= 1).
--
-- Returns 'Nothing' if the digest is empty.
quantile :: Double -> MDigest s -> ST s (Maybe Double)
quantile q (MDigest ref) = TD.quantile q <$> readSTRef ref

-- | Estimate the cumulative distribution function (CDF) at value @x@.
--
-- Returns 'Nothing' if the digest is empty.
cdf :: Double -> MDigest s -> ST s (Maybe Double)
cdf x (MDigest ref) = TD.cdf x <$> readSTRef ref

-- | Return the total weight of all values added to the digest.
totalWeight :: MDigest s -> ST s Double
totalWeight (MDigest ref) = TD.totalWeight <$> readSTRef ref

-- | Return the number of centroids, compressing any pending buffer first.
centroidCount :: MDigest s -> ST s Int
centroidCount (MDigest ref) = do
  td <- readSTRef ref
  let td' = TD.compress td
  writeSTRef ref td'
  return (TD.centroidCount td')

-- ---------------------------------------------------------------------------
-- Merge
-- ---------------------------------------------------------------------------

-- | Merge the contents of a pure 'TD.TDigest' into the mutable digest.
--
-- The pure digest is read-only; only the mutable digest is modified.
-- This is useful for combining a digest received from another worker
-- into a local accumulator.
merge :: TD.TDigest -> MDigest s -> ST s ()
merge other (MDigest ref) = modifySTRef' ref (\td -> TD.merge td other)

-- ---------------------------------------------------------------------------
-- Freeze / Thaw
-- ---------------------------------------------------------------------------

-- | Snapshot the mutable digest into a pure 'TD.TDigest' value.
--
-- The mutable digest is not affected; subsequent mutations will not
-- change the returned pure value.
freeze :: MDigest s -> ST s TD.TDigest
freeze (MDigest ref) = readSTRef ref

-- | Create a mutable digest from a pure 'TD.TDigest' value.
--
-- The pure value is copied into a fresh 'STRef'; subsequent mutations
-- of the mutable digest do not affect the original pure value.
thaw :: TD.TDigest -> ST s (MDigest s)
thaw td = MDigest <$> newSTRef td

-- ---------------------------------------------------------------------------
-- Convenience runner
-- ---------------------------------------------------------------------------

-- | Run an 'ST' computation that uses a mutable t-digest and return the
-- pure result.
--
-- This is simply 'runST' re-exported for convenience.
--
-- @
-- median :: Maybe Double
-- median = 'runTDigest' $ do
--   td <- 'new'
--   'add' 1.0 td
--   'add' 2.0 td
--   'add' 3.0 td
--   'quantile' 0.5 td
-- @
runTDigest :: (forall s. ST s a) -> a
runTDigest = runST
