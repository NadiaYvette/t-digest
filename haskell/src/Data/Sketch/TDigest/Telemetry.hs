{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- Module      : Data.Sketch.TDigest.Telemetry
-- Description : Polytropos.Record-backed multi-metric telemetry t-digest bundle
-- Copyright   : (c) 2026 Nadia Yvette Chambers
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
-- Stability   : experimental
-- Portability : GHC
--
-- Multi-dimensional telemetry tracking backed by a flat 'Polytropos.Record'.
-- Enables simultaneous tracking of extreme tail quantiles (\(p_{50}, p_{90}, p_{95}, p_{99}, p_{99.9}\))
-- across named execution channels (e.g. @"stepsConsumed"@, @"stepsPerByte"@,
-- @"utf8ByteWidth"@, @"peakBacktrackDepth"@) packed into a single contiguous 'SmallArray#'
-- allocation with zero pointer-chasing.
module Data.Sketch.TDigest.Telemetry
  ( -- * Core Data Types
    DigestRecord (..),
    TailQuantiles (..),
    digestTailQuantiles,

    -- * Channel Typeclasses & Metadata
    HasChannel (..),
    KnownRow (..),
    Field (..),
    Row,
    Pair (..),

    -- * Construction
    empty,
    emptyWith,
    emptyWithScale,
    singleton,

    -- * Ingestion & Observations
    observe,
    observeWeighted,
    observeSample,
    compressRecord,

    -- * Merging
    mergeRecord,

    -- * Channel Statistics & Queries
    channelDigest,
    channelQuantile,
    channelCdf,
    channelTailQuantiles,
    channelTotalWeight,
    channelCentroidCount,

    -- * Reporting & Extraction
    summaryMap,
    formatSummary,

    -- * Canonical Smirk / PCRE Telemetry Row
    SmirkTelemetryRow,
    stepsConsumed,
    stepsPerByte,
    utf8ByteWidth,
    peakBacktrackDepth,
    emptySmirkTelemetry,
  )
where

import Control.Monad.ST (runST)
import Data.Functor.Identity (Identity (..))
import Data.Maybe (fromMaybe)
import Data.Primitive.SmallArray
  ( freezeSmallArray,
    indexSmallArray,
    newSmallArray,
    sizeofSmallArray,
    thawSmallArray,
    writeSmallArray,
  )
import qualified Data.Sketch.TDigest as TD
import GHC.Exts (Any)
import GHC.Generics (Generic)
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Polytropos (Field (..), Pair (..), Record, Row, emptyRecord, insertField)
import Polytropos.Core (Rep (..), RowRep (..), repVals)
import Text.Printf (printf)
import Unsafe.Coerce (unsafeCoerce)

-- ---------------------------------------------------------------------------
-- Unsafe Coercion Helpers
-- ---------------------------------------------------------------------------

{-# INLINE slot #-}
slot :: a -> Identity Any
slot = unsafeCoerce

{-# INLINE unslot #-}
unslot :: Identity Any -> a
unslot = unsafeCoerce

-- ---------------------------------------------------------------------------
-- Tail Quantiles
-- ---------------------------------------------------------------------------

-- | Quantile summary capturing median and extreme high tails.
data TailQuantiles = TailQuantiles
  { p50 :: !Double,
    p90 :: !Double,
    p95 :: !Double,
    p99 :: !Double,
    p999 :: !Double
  }
  deriving (Eq, Show, Generic)

-- | Extract the 5-point tail quantile summary from a 'TD.TDigest'.
digestTailQuantiles :: TD.TDigest -> Maybe TailQuantiles
digestTailQuantiles td
  | TD.totalWeight td <= 0 = Nothing
  | otherwise =
      let !p50' = fromMaybe 0.0 (TD.quantile 0.500 td)
          !p90' = fromMaybe 0.0 (TD.quantile 0.900 td)
          !p95' = fromMaybe 0.0 (TD.quantile 0.950 td)
          !p99' = fromMaybe 0.0 (TD.quantile 0.990 td)
          !p999' = fromMaybe 0.0 (TD.quantile 0.999 td)
       in Just (TailQuantiles p50' p90' p95' p99' p999')

-- ---------------------------------------------------------------------------
-- Channel Indexing & Row Knowledge
-- ---------------------------------------------------------------------------

-- | Class witnessing that channel @n@ is present in row @r@ at 0-based offset 'getChannelIndex'.
class HasChannel (n :: Symbol) (r :: Row) where
  getChannelIndex :: Int

instance {-# OVERLAPPING #-} HasChannel n ((n ':= TD.TDigest) ': rest) where
  getChannelIndex = 0

instance {-# OVERLAPPABLE #-} (HasChannel n rest) => HasChannel n (field ': rest) where
  getChannelIndex = 1 + getChannelIndex @n @rest

-- | Class witnessing that row @r@ is a fully concrete telemetry row of 'TD.TDigest' fields.
class KnownRow (r :: Row) where
  rowFieldNames :: [String]
  rowArity :: Int
  initRecord :: TD.TDigest -> Record r

instance KnownRow '[] where
  rowFieldNames = []
  rowArity = 0
  initRecord _ = emptyRecord

instance (KnownSymbol n, KnownRow rest) => KnownRow ((n ':= TD.TDigest) ': rest) where
  rowFieldNames = symbolVal (Field @n) : rowFieldNames @rest
  rowArity = 1 + rowArity @rest
  initRecord td = insertField (Field @n) td (initRecord @rest td)

-- ---------------------------------------------------------------------------
-- DigestRecord
-- ---------------------------------------------------------------------------

-- | Multi-dimensional telemetry digest backed by a flat 'Polytropos.Record'.
--
-- The runtime representation is 'Rep 0 (SmallArray Any)', storing \(N\) 'TD.TDigest'
-- values in a contiguous flat array.
newtype DigestRecord (row :: Row) = DigestRecord
  { unDigestRecord :: Record row
  }

instance Show (DigestRecord row) where
  show (DigestRecord (RowRep r)) =
    "<DigestRecord channels=" ++ show (sizeofSmallArray (repVals r)) ++ ">"

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- | Create an empty 'DigestRecord' with default parameter (\(\delta = 100\), \(K_1\) scale function).
empty :: forall row. KnownRow row => DigestRecord row
empty = DigestRecord (initRecord TD.empty)

-- | Create an empty 'DigestRecord' with custom \(\delta\).
emptyWith :: forall row. KnownRow row => Double -> DigestRecord row
emptyWith delta = DigestRecord (initRecord (TD.emptyWith delta))

-- | Create an empty 'DigestRecord' with custom scale function and \(\delta\).
emptyWithScale :: forall row. KnownRow row => TD.ScaleFunction -> Double -> DigestRecord row
emptyWithScale sf delta = DigestRecord (initRecord (TD.emptyWithScale sf delta))

-- | Create a 'DigestRecord' initialized with a single observation on channel @n@.
singleton ::
  forall n row.
  (KnownSymbol n, KnownRow row, HasChannel n row) =>
  Field n ->
  Double ->
  DigestRecord row
singleton f x = observe f x (empty @row)

-- ---------------------------------------------------------------------------
-- Ingestion & Observations
-- ---------------------------------------------------------------------------

-- | Add an observation to channel @n@ in the telemetry bundle.
observe ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  Double ->
  DigestRecord row ->
  DigestRecord row
observe _ x (DigestRecord (RowRep (Rep _ v))) =
  let !idx = getChannelIndex @n @row
      !curTd = unslot (indexSmallArray v idx) :: TD.TDigest
      !newTd = TD.add x curTd
      !v' = runST $ do
        mv <- thawSmallArray v 0 (sizeofSmallArray v)
        writeSmallArray mv idx (slot newTd)
        freezeSmallArray mv 0 (sizeofSmallArray v)
   in DigestRecord (RowRep (Rep 0 v'))

-- | Add a weighted observation to channel @n@.
observeWeighted ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  Double ->
  Double ->
  DigestRecord row ->
  DigestRecord row
observeWeighted _ x w (DigestRecord (RowRep (Rep _ v))) =
  let !idx = getChannelIndex @n @row
      !curTd = unslot (indexSmallArray v idx) :: TD.TDigest
      !newTd = TD.addWeighted x w curTd
      !v' = runST $ do
        mv <- thawSmallArray v 0 (sizeofSmallArray v)
        writeSmallArray mv idx (slot newTd)
        freezeSmallArray mv 0 (sizeofSmallArray v)
   in DigestRecord (RowRep (Rep 0 v'))

-- | Ingest a batch of key-value channel observations.
observeSample ::
  forall row.
  KnownRow row =>
  [(String, Double)] ->
  DigestRecord row ->
  DigestRecord row
observeSample [] dr = dr
observeSample ((k, v) : rest) (DigestRecord (RowRep (Rep _ arr))) =
  let !names = rowFieldNames @row
      !n = sizeofSmallArray arr
      !idxOpt = lookupIndex 0 names
      lookupIndex _ [] = Nothing
      lookupIndex i (name : ns)
        | name == k = Just i
        | otherwise = lookupIndex (i + 1) ns
   in case idxOpt of
        Nothing -> observeSample rest (DigestRecord (RowRep (Rep 0 arr)))
        Just idx ->
          let !curTd = unslot (indexSmallArray arr idx) :: TD.TDigest
              !newTd = TD.add v curTd
              !arr' = runST $ do
                mv <- thawSmallArray arr 0 n
                writeSmallArray mv idx (slot newTd)
                freezeSmallArray mv 0 n
           in observeSample rest (DigestRecord (RowRep (Rep 0 arr')))

-- | Force compression on all channels in the bundle.
compressRecord :: DigestRecord row -> DigestRecord row
compressRecord (DigestRecord (RowRep (Rep _ arr))) =
  let !n = sizeofSmallArray arr
      !arr' = runST $ do
        mv <- newSmallArray n (slot (TD.empty :: TD.TDigest))
        let loop i
              | i >= n = pure ()
              | otherwise = do
                  let !td = unslot (indexSmallArray arr i) :: TD.TDigest
                  writeSmallArray mv i (slot (TD.compress td))
                  loop (i + 1)
        loop 0
        freezeSmallArray mv 0 n
   in DigestRecord (RowRep (Rep 0 arr'))

-- ---------------------------------------------------------------------------
-- Merging
-- ---------------------------------------------------------------------------

-- | Channel-wise merge of two telemetry digest bundles into a single flat bundle.
mergeRecord :: DigestRecord row -> DigestRecord row -> DigestRecord row
mergeRecord (DigestRecord (RowRep (Rep _ v1))) (DigestRecord (RowRep (Rep _ v2))) =
  let !n = min (sizeofSmallArray v1) (sizeofSmallArray v2)
      !arr' = runST $ do
        mv <- newSmallArray n (slot (TD.empty :: TD.TDigest))
        let loop i
              | i >= n = pure ()
              | otherwise = do
                  let !td1 = unslot (indexSmallArray v1 i) :: TD.TDigest
                      !td2 = unslot (indexSmallArray v2 i) :: TD.TDigest
                  writeSmallArray mv i (slot (TD.merge td1 td2))
                  loop (i + 1)
        loop 0
        freezeSmallArray mv 0 n
   in DigestRecord (RowRep (Rep 0 arr'))

instance Semigroup (DigestRecord row) where
  (<>) = mergeRecord

instance KnownRow row => Monoid (DigestRecord row) where
  mempty = empty
  mappend = (<>)

-- ---------------------------------------------------------------------------
-- Channel Statistics & Queries
-- ---------------------------------------------------------------------------

-- | Extract the raw 'TD.TDigest' for channel @n@.
channelDigest ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  DigestRecord row ->
  TD.TDigest
channelDigest _ (DigestRecord (RowRep (Rep _ v))) =
  let !idx = getChannelIndex @n @row
   in unslot (indexSmallArray v idx)

-- | Query quantile \(q \in [0, 1]\) on channel @n@.
channelQuantile ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  Double ->
  DigestRecord row ->
  Maybe Double
channelQuantile f q dr = TD.quantile q (channelDigest f dr)

-- | Query CDF value on channel @n@.
channelCdf ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  Double ->
  DigestRecord row ->
  Maybe Double
channelCdf f x dr = TD.cdf x (channelDigest f dr)

-- | Query the 5-point tail quantile summary (\(p_{50}, p_{90}, p_{95}, p_{99}, p_{99.9}\)) on channel @n@.
channelTailQuantiles ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  DigestRecord row ->
  Maybe TailQuantiles
channelTailQuantiles f dr = digestTailQuantiles (channelDigest f dr)

-- | Total sample weight on channel @n@.
channelTotalWeight ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  DigestRecord row ->
  Double
channelTotalWeight f dr = TD.totalWeight (channelDigest f dr)

-- | Centroid count on channel @n@.
channelCentroidCount ::
  forall n row.
  (KnownSymbol n, HasChannel n row) =>
  Field n ->
  DigestRecord row ->
  Int
channelCentroidCount f dr = TD.centroidCount (channelDigest f dr)

-- ---------------------------------------------------------------------------
-- Reporting & Extraction
-- ---------------------------------------------------------------------------

-- | Extract tail quantile summaries for all channels into an association list.
summaryMap :: forall row. KnownRow row => DigestRecord row -> [(String, TailQuantiles)]
summaryMap (DigestRecord (RowRep (Rep _ arr))) =
  let !names = rowFieldNames @row
      !n = sizeofSmallArray arr
      loop i
        | i >= n = []
        | otherwise =
            let !td = unslot (indexSmallArray arr i) :: TD.TDigest
                !name = if i < length names then names !! i else "channel_" ++ show i
             in case digestTailQuantiles td of
                  Just tq -> (name, tq) : loop (i + 1)
                  Nothing -> loop (i + 1)
   in loop 0

-- | Pretty-print a multi-channel ASCII telemetry report.
formatSummary :: forall row. KnownRow row => DigestRecord row -> String
formatSummary dr =
  let !entries = summaryMap dr
      header = printf "%-24s %10s %10s %10s %10s %10s\n" ("Channel" :: String) ("p50" :: String) ("p90" :: String) ("p95" :: String) ("p99" :: String) ("p99.9" :: String)
      sep = replicate 79 '-' ++ "\n"
      formatEntry (name, tq) =
        printf "%-24s %10.2f %10.2f %10.2f %10.2f %10.2f\n" name (p50 tq) (p90 tq) (p95 tq) (p99 tq) (p999 tq)
   in header ++ sep ++ concatMap formatEntry entries

-- ---------------------------------------------------------------------------
-- Canonical Smirk / PCRE Telemetry Row
-- ---------------------------------------------------------------------------

-- | Canonical multi-metric telemetry row specified in TP-SMIRK-001B.
type SmirkTelemetryRow =
  '[ "stepsConsumed" ':= TD.TDigest,
     "stepsPerByte" ':= TD.TDigest,
     "utf8ByteWidth" ':= TD.TDigest,
     "peakBacktrackDepth" ':= TD.TDigest
   ]

-- | Field token for @"stepsConsumed"@.
stepsConsumed :: Field "stepsConsumed"
stepsConsumed = Field

-- | Field token for @"stepsPerByte"@.
stepsPerByte :: Field "stepsPerByte"
stepsPerByte = Field

-- | Field token for @"utf8ByteWidth"@.
utf8ByteWidth :: Field "utf8ByteWidth"
utf8ByteWidth = Field

-- | Field token for @"peakBacktrackDepth"@.
peakBacktrackDepth :: Field "peakBacktrackDepth"
peakBacktrackDepth = Field

-- | Empty canonical Smirk telemetry digest bundle.
emptySmirkTelemetry :: DigestRecord SmirkTelemetryRow
emptySmirkTelemetry = empty
