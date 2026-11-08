#!/usr/bin/env bash
set -euo pipefail

echo "=== [TP-SMIRK-001B Scaffold: dunning-t-digest Polytropos Telemetry Bundle] ==="

mkdir -p $(dirname cabal.project)
cat << 'EOF' > cabal.project
packages:
  haskell

source-repository-package
  type: git
  location: https://github.com/NadiaYvette/polytropos
  tag: 0.1.0.3
  subdir: packages/polytropos-core
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
    Data.Sketch.TDigest.Telemetry
    Data.Sketch.TDigest.Record

  build-depends:
    , base            >= 4.16 && < 5
    , polytropos-core >= 0.1
    , primitive       >= 0.7  && < 0.10
    , vector          >= 0.12 && < 0.14

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
    , polytropos-core   >= 0.1
    , primitive         >= 0.7  && < 0.10
  hs-source-dirs:   test
  default-language: Haskell2010
EOF

mkdir -p $(dirname haskell/src/Data/Sketch/TDigest/Telemetry.hs)
cat << 'EOF' > haskell/src/Data/Sketch/TDigest/Telemetry.hs
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
EOF

mkdir -p $(dirname haskell/src/Data/Sketch/TDigest/Record.hs)
cat << 'EOF' > haskell/src/Data/Sketch/TDigest/Record.hs
-- |
-- Module      : Data.Sketch.TDigest.Record
-- Description : Re-export of Data.Sketch.TDigest.Telemetry
-- Copyright   : (c) 2026 Nadia Yvette Chambers
-- License     : BSD-3-Clause
-- Maintainer  : nadia.yvette.chambers@gmail.com
--
-- Convenient alias for 'Data.Sketch.TDigest.Telemetry'.
module Data.Sketch.TDigest.Record
  ( module Data.Sketch.TDigest.Telemetry,
  )
where

import Data.Sketch.TDigest.Telemetry
EOF

mkdir -p $(dirname haskell/test/Main.hs)
cat << 'EOF' > haskell/test/Main.hs
{-# LANGUAGE BangPatterns #-}

module Main (main) where

import Control.Monad (forM_)
import Data.Maybe (isNothing)
import qualified Data.Sketch.TDigest as TD
import qualified Data.Sketch.TDigest.Mutable as TDM
import qualified Data.Sketch.TDigest.Telemetry as Telemetry
import qualified Data.Sketch.TDigest.Tree234 as Tree234
import System.Exit (exitFailure, exitSuccess)
import Text.Printf (printf)

main :: IO ()
main = do
  putStrLn "=== [dunning-t-digest Flat PrimArray & Telemetry Test Suite] ==="
  let tests =
        [ ("testEmptyDigest", testEmptyDigest),
          ("testSingletonDigest", testSingletonDigest),
          ("testUniformTailAccuracy", testUniformTailAccuracy),
          ("testCdfAccuracy", testCdfAccuracy),
          ("testCentroidCountBound", testCentroidCountBound),
          ("testMergePreservation", testMergePreservation),
          ("testScaleFunctions", testScaleFunctions),
          ("testMutableParity", testMutableParity),
          ("testTree234ArrayHosted", testTree234ArrayHosted),
          ("testTelemetryEmptyRecord", testTelemetryEmptyRecord),
          ("testTelemetryObservations", testTelemetryObservations),
          ("testTelemetryTailQuantiles", testTelemetryTailQuantiles),
          ("testTelemetryMergePreservation", testTelemetryMergePreservation),
          ("testTelemetryFormatSummary", testTelemetryFormatSummary)
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

testTelemetryEmptyRecord :: IO Bool
testTelemetryEmptyRecord = do
  let dr = Telemetry.emptySmirkTelemetry
  pure $
    Telemetry.channelTotalWeight Telemetry.stepsConsumed dr == 0.0
      && Telemetry.channelTotalWeight Telemetry.stepsPerByte dr == 0.0
      && Telemetry.channelTotalWeight Telemetry.utf8ByteWidth dr == 0.0
      && Telemetry.channelTotalWeight Telemetry.peakBacktrackDepth dr == 0.0
      && isNothing (Telemetry.channelQuantile Telemetry.stepsConsumed 0.5 dr)
      && isNothing (Telemetry.channelTailQuantiles Telemetry.stepsConsumed dr)

testTelemetryObservations :: IO Bool
testTelemetryObservations = do
  let dr0 = Telemetry.emptySmirkTelemetry
      dr1 = Telemetry.observe Telemetry.stepsConsumed 120.0 dr0
      dr2 = Telemetry.observe Telemetry.stepsPerByte 1.5 dr1
      dr3 = Telemetry.observe Telemetry.utf8ByteWidth 4.0 dr2
      dr4 = Telemetry.observe Telemetry.peakBacktrackDepth 8.0 dr3
  pure $
    Telemetry.channelTotalWeight Telemetry.stepsConsumed dr4 == 1.0
      && Telemetry.channelTotalWeight Telemetry.stepsPerByte dr4 == 1.0
      && Telemetry.channelTotalWeight Telemetry.utf8ByteWidth dr4 == 1.0
      && Telemetry.channelTotalWeight Telemetry.peakBacktrackDepth dr4 == 1.0
      && Telemetry.channelQuantile Telemetry.stepsConsumed 0.5 dr4 == Just 120.0
      && Telemetry.channelQuantile Telemetry.stepsPerByte 0.5 dr4 == Just 1.5
      && Telemetry.channelQuantile Telemetry.utf8ByteWidth 0.5 dr4 == Just 4.0
      && Telemetry.channelQuantile Telemetry.peakBacktrackDepth 0.5 dr4 == Just 8.0

testTelemetryTailQuantiles :: IO Bool
testTelemetryTailQuantiles = do
  let n = 10000 :: Int
      vals = [1.0 .. fromIntegral n]
      dr = foldl (\acc x -> Telemetry.observe Telemetry.stepsConsumed x acc) Telemetry.emptySmirkTelemetry vals
  case Telemetry.channelTailQuantiles Telemetry.stepsConsumed dr of
    Nothing -> pure False
    Just tq ->
      pure $
        abs (Telemetry.p50 tq - 5000.0) < 50.0
          && abs (Telemetry.p90 tq - 9000.0) < 50.0
          && abs (Telemetry.p95 tq - 9500.0) < 50.0
          && abs (Telemetry.p99 tq - 9900.0) < 50.0
          && abs (Telemetry.p999 tq - 9990.0) < 50.0

testTelemetryMergePreservation :: IO Bool
testTelemetryMergePreservation = do
  let n = 5000 :: Int
      dr1 = foldl (\acc i -> Telemetry.observe Telemetry.stepsConsumed i acc) Telemetry.emptySmirkTelemetry [1 .. fromIntegral n]
      dr2 = foldl (\acc i -> Telemetry.observe Telemetry.stepsConsumed i acc) Telemetry.emptySmirkTelemetry [fromIntegral n + 1 .. 2 * fromIntegral n]
      drMerged = Telemetry.mergeRecord dr1 dr2
      w = Telemetry.channelTotalWeight Telemetry.stepsConsumed drMerged
      med = Telemetry.channelQuantile Telemetry.stepsConsumed 0.5 drMerged
  pure $
    w == fromIntegral (2 * n)
      && case med of
        Just m -> abs (m - fromIntegral n) < 50.0
        Nothing -> False

testTelemetryFormatSummary :: IO Bool
testTelemetryFormatSummary = do
  let dr0 = Telemetry.emptySmirkTelemetry
      dr1 = Telemetry.observeSample [("stepsConsumed", 50.0), ("stepsPerByte", 2.0), ("utf8ByteWidth", 1.0), ("peakBacktrackDepth", 4.0)] dr0
      sMap = Telemetry.summaryMap dr1
      formatted = Telemetry.formatSummary dr1
  pure $
    length sMap == 4
      && not (null formatted)
      && length (lines formatted) >= 6
EOF

echo "=== [TP-SMIRK-001B Scaffold Applied Successfully] ==="
