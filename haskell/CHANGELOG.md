# Revision history for dunning-t-digest

## 0.1.0.0 -- 2025-06-01

* Initial release.
* Pure functional t-digest using finger trees (`Data.TDigest.Dunning`).
* Mutable t-digest using mutable vectors in ST (`Data.TDigest.Dunning.Mutable`).
* K1 (arcsine) scale function with O(log n) insertion and queries.
* O(δ log n) split-based compression.
* Freeze/thaw interop between pure and mutable variants.
