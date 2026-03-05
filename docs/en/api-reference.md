# API Reference

This project provides t-digest implementations in eight languages. All
implementations use the merging digest variant with the K1 (arcsine)
scale function. This chapter documents the public API of each.

---

## Cross-Language API Comparison

| Operation         | Haskell         | Ruby              | Ada               | Common Lisp          | Scheme           | SML              | Prolog                  | Mercury               |
|-------------------|-----------------|-------------------|-------------------|----------------------|------------------|------------------|-------------------------|------------------------|
| Create            | `empty`, `emptyWith` | `TDigest.new(d)` | `Create(d)`    | `create-tdigest d`   | `make-tdigest d` | `TDigest.create d` | `tdigest_new(D, TD)`  | `tdigest.new(D)`       |
| Add value         | `add x td`      | `td.add(x, w)`   | `Add(TD, V, W)`  | `tdigest-add td v w` | `td-add! td v w` | `TDigest.add td v w` | `tdigest_add(TD0,V,W,TD1)` | `tdigest.add(TD,V,W)` |
| Compress          | `compress td`   | `td.compress!`    | `Compress(TD)`    | `tdigest-compress td` | `td-compress! td` | `TDigest.compress td` | `tdigest_compress(TD0,TD1)` | `tdigest.compress(TD)` |
| Quantile          | `quantile q td` | `td.quantile(q)`  | `Quantile(TD, Q)` | `tdigest-quantile td q` | `td-quantile td q` | `TDigest.quantile td q` | `tdigest_quantile(TD,Q,V)` | `tdigest.quantile(TD,Q)` |
| CDF               | `cdf x td`      | `td.cdf(x)`       | `CDF(TD, X)`     | `tdigest-cdf td x`   | `td-cdf td x`    | `TDigest.cdf td x`   | `tdigest_cdf(TD,X,Q)`  | `tdigest.cdf(TD,X)`    |
| Merge             | `merge td1 td2` | `td1.merge(td2)`  | `Merge(TD1, TD2)` | `tdigest-merge td1 td2` | `td-merge! td1 td2` | `TDigest.merge td1 td2` | `tdigest_merge(TD1,TD2,TD3)` | `tdigest.merge_digests(TD1,TD2)` |
| Centroid count    | `centroidCount td` | `td.centroid_count` | `Centroid_Count(TD)` | `tdigest-centroid-count td` | `td-centroid-count td` | `TDigest.centroidCount td` | `tdigest_centroid_count(TD,N)` | `tdigest.centroid_count(TD)` |
| Total weight      | `totalWeight td` | `td.total_weight` | `TD.Total_Weight` | `tdigest-total-weight td` | `td-total-weight td` | `TDigest.totalWeight td` | (field access)         | `TD ^ total_weight`    |

---

## Haskell

**File:** `haskell/TDigest.hs`

The Haskell implementation is purely functional. Every operation returns
a new `TDigest` value; nothing is mutated.

### Types

```haskell
data Centroid = Centroid
  { cMean   :: !Double
  , cWeight :: !Double
  }

data TDigest  -- opaque; fields are tdCentroids, tdBuffer, tdTotalWeight,
              -- tdMin, tdMax, tdDelta, tdBufferCap
```

### Functions

```haskell
empty :: TDigest
```
Create an empty t-digest with default delta = 100.

```haskell
emptyWith :: Double -> TDigest
```
Create an empty t-digest with a given compression parameter.

```haskell
add :: Double -> TDigest -> TDigest
```
Add a single value (weight 1) to the digest.

```haskell
addWeighted :: Double -> Double -> TDigest -> TDigest
```
Add a value with a given weight. Triggers compression when the buffer
reaches capacity.

```haskell
compress :: TDigest -> TDigest
```
Force compression of the buffer into the centroid list.

```haskell
quantile :: Double -> TDigest -> Maybe Double
```
Estimate the value at quantile q (0 <= q <= 1). Returns `Nothing` if
the digest is empty.

```haskell
cdf :: Double -> TDigest -> Maybe Double
```
Estimate the CDF at value x. Returns `Nothing` if the digest is empty.

```haskell
merge :: TDigest -> TDigest -> TDigest
```
Merge two digests. All centroids from the second are added into the
first and compressed.

```haskell
totalWeight :: TDigest -> Double
```
Total weight of all values added.

```haskell
centroidCount :: TDigest -> Int
```
Number of centroids after compressing any pending buffer.

---

## Ruby

**File:** `ruby/tdigest.rb`

The Ruby implementation is object-oriented and mutable. Methods modify
the digest in place and return `self` for chaining.

### Class: `TDigest`

```ruby
TDigest.new(delta = 100)
```
Create a new t-digest with the given compression parameter.

```ruby
td.add(value, weight = 1.0) -> self
```
Add a value with optional weight.

```ruby
td.compress! -> self
```
Force compression of buffered values.

```ruby
td.quantile(q) -> Float or nil
```
Estimate the value at quantile q (0..1). Returns `nil` if empty.

```ruby
td.cdf(x) -> Float or nil
```
Estimate the CDF at value x. Returns `nil` if empty.

```ruby
td.merge(other) -> self
```
Merge another digest into this one.

```ruby
td.centroid_count -> Integer
```
Number of centroids after flushing the buffer.

```ruby
td.total_weight -> Float
td.delta -> Float
td.min -> Float
td.max -> Float
```
Read-only accessors.

---

## Ada

**Files:** `ada/tdigest.ads` (spec), `ada/tdigest.adb` (body)

The Ada implementation uses an imperative, record-based style with
fixed-size arrays.

### Constants

```ada
Max_Centroids : constant := 1_000;
Max_Buffer    : constant := 5_000;
```

### Types

```ada
type Centroid is record
   Mean   : Long_Float := 0.0;
   Weight : Long_Float := 0.0;
end record;

type T_Digest is record ... end record;
```

### Subprograms

```ada
function Create (Compression : Long_Float := 100.0) return T_Digest;
```
Create a fresh t-digest.

```ada
procedure Add (TD : in out T_Digest; Value : Long_Float;
               Weight : Long_Float := 1.0);
```
Add a weighted value.

```ada
procedure Compress (TD : in out T_Digest);
```
Force compression.

```ada
function Quantile (TD : in out T_Digest; Q : Long_Float) return Long_Float;
```
Estimate the quantile value. Returns 0.0 if empty.

```ada
function CDF (TD : in out T_Digest; X : Long_Float) return Long_Float;
```
Estimate the CDF at X.

```ada
procedure Merge (TD : in out T_Digest; Other : in out T_Digest);
```
Merge `Other` into `TD`.

```ada
function Centroid_Count (TD : in out T_Digest) return Natural;
```
Number of centroids after compression.

---

## Common Lisp

**File:** `common-lisp/tdigest.lisp`

The Common Lisp implementation uses `defstruct` for centroids and the
digest. It is mutable (in-place updates via `setf`).

### Functions

```lisp
(create-tdigest &optional (delta 100.0d0)) -> tdigest
```
Create a new t-digest.

```lisp
(tdigest-add td value &optional (weight 1.0d0)) -> td
```
Add a value with optional weight.

```lisp
(tdigest-compress td) -> td
```
Force compression.

```lisp
(tdigest-quantile td q) -> double-float or nil
```
Estimate the value at quantile q.

```lisp
(tdigest-cdf td x) -> double-float or nil
```
Estimate the CDF at x.

```lisp
(tdigest-merge td other) -> td
```
Merge `other` into `td`.

```lisp
(tdigest-centroid-count td) -> fixnum
```
Number of centroids after compression.

### Accessors (via defstruct)

```lisp
(tdigest-total-weight td)
(tdigest-min-val td)
(tdigest-max-val td)
(tdigest-delta td)
```

---

## Scheme

**File:** `scheme/tdigest.scm`

The Scheme implementation is compatible with R5RS / R7RS. The digest is
stored as a 7-element vector with mutable fields. Centroids are cons
pairs `(mean . weight)`.

### Functions

```scheme
(make-tdigest [delta]) -> tdigest
```
Create a new t-digest. Default delta is 100.

```scheme
(td-add! td value [weight]) -> tdigest
```
Add a value with optional weight (default 1.0).

```scheme
(td-compress! td) -> tdigest
```
Force compression.

```scheme
(td-quantile td q) -> number or #f
```
Estimate the value at quantile q. Returns `#f` if empty.

```scheme
(td-cdf td x) -> number or #f
```
Estimate the CDF at x. Returns `#f` if empty.

```scheme
(td-merge! td other) -> tdigest
```
Merge `other` into `td`.

```scheme
(td-centroid-count td) -> integer
```
Number of centroids after compression.

### Accessors

```scheme
(td-delta td)
(td-total-weight td)
(td-min td)
(td-max td)
(td-centroids td)
(td-buffer td)
```

---

## Standard ML

**File:** `sml/tdigest.sml`

The SML implementation is purely functional, exposed through a signature
and structure.

### Signature: `T_DIGEST`

```sml
type centroid = { mean : real, weight : real }
type t

val create       : real -> t
val add          : t -> real -> real -> t
val compress     : t -> t
val quantile     : t -> real -> real option
val cdf          : t -> real -> real option
val merge        : t -> t -> t
val totalWeight  : t -> real
val centroidCount : t -> int
```

### Functions

`create delta` -- Create a new digest with the given compression parameter.

`add td value weight` -- Add a weighted value. Returns the updated digest.

`compress td` -- Force compression. Returns the compressed digest.

`quantile td q` -- Estimate the quantile value. Returns `NONE` if empty.

`cdf td x` -- Estimate the CDF. Returns `NONE` if empty.

`merge td1 td2` -- Merge two digests. Returns a new digest.

`totalWeight td` -- Total weight of all values.

`centroidCount td` -- Number of centroids after compression.

---

## Prolog

**File:** `prolog/tdigest.pl`

The Prolog implementation (SWI-Prolog) uses a term-based data structure.
The digest is represented as:

```prolog
tdigest(Delta, Centroids, Buffer, TotalWeight, Min, Max)
```

Centroids and buffer entries are `centroid(Mean, Weight)` terms.

### Predicates

```prolog
tdigest_new(+Delta, -TD)
```
Create an empty t-digest.

```prolog
tdigest_add(+TD0, +Value, +Weight, -TD1)
```
Add a weighted value. Triggers compression when the buffer is full.

```prolog
tdigest_compress(+TD0, -TD1)
```
Force compression.

```prolog
tdigest_quantile(+TD, +Q, -Value)
```
Estimate the value at quantile Q.

```prolog
tdigest_cdf(+TD, +X, -Q)
```
Estimate the CDF at X.

```prolog
tdigest_merge(+TD1, +TD2, -TD3)
```
Merge two digests into a new one. Uses the maximum delta of the two.

```prolog
tdigest_centroid_count(+TD, -Count)
```
Number of centroids after compression.

---

## Mercury

**File:** `mercury/tdigest.m`

The Mercury implementation is purely functional, using Mercury's type
system and determinism declarations.

### Types

```mercury
:- type centroid ---> centroid(mean :: float, weight :: float).

:- type tdigest ---> tdigest(
    delta        :: float,
    centroids    :: list(centroid),
    buffer       :: list(centroid),
    total_weight :: float,
    td_min       :: float,
    td_max       :: float
).
```

### Functions

```mercury
:- func new(float) = tdigest.
```
Create a new digest with the given delta.

```mercury
:- func add(tdigest, float, float) = tdigest.
```
Add a value with weight. Returns the updated digest.

```mercury
:- func add_value(float, tdigest) = tdigest.
```
Convenience: add a value with weight 1.0. Arguments are reversed for
use with `foldl`.

```mercury
:- func compress(tdigest) = tdigest.
```
Force compression.

```mercury
:- func quantile(tdigest, float) = float.
```
Estimate the quantile value. Returns 0.0 if empty.

```mercury
:- func cdf(tdigest, float) = float.
```
Estimate the CDF at a given value.

```mercury
:- func merge_digests(tdigest, tdigest) = tdigest.
```
Merge two digests. Returns a new digest.

```mercury
:- func ensure_compressed(tdigest) = tdigest.
```
Compress if the buffer is non-empty; otherwise return unchanged.

```mercury
:- func centroid_count(tdigest) = int.
```
Number of centroids after compression.
