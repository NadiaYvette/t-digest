# Revision history for dunning-t-digest

## 0.1.0.1 -- 2025-06-14

* Add package README for Hackage and GitHub.
* Rename modules from `Data.TDigest.Dunning` to `Data.Sketch.TDigest`.
* Fix GHC 9.14 redundant import warning, Haddock ambiguity warnings.
* Clean up hlint hints and ormolu formatting in benchmarks.

## 0.1.0.0 -- 2025-06-01

* Initial release.
* Pure functional t-digest using finger trees (`Data.Sketch.TDigest`).
* Mutable t-digest using mutable vectors in ST (`Data.Sketch.TDigest.Mutable`).
* K1 (arcsine) scale function with O(log n) insertion and queries.
* O(δ log n) split-based compression.
* Freeze/thaw interop between pure and mutable variants.
