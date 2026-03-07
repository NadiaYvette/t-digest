# API Reference

This project provides t-digest implementations in 28 languages. All
implementations use the merging digest variant with the K1 (arcsine)
scale function. This chapter documents the public API of each.

The implementations fall into four architectural categories:

- **Purely functional** (Haskell, Mercury pure, SML): finger trees /
  balanced BSTs with four-component monoidal measures
- **Mutable with substructural types** (Haskell monadic, Mercury mutable):
  mutable 2-3-4 trees with uniqueness/linearity tracking
- **Mutable with 2-3-4 trees** (C, C++, Rust, Go, Java, Python, Kotlin,
  C#, Swift, D, Zig, Nim, Ada, Fortran, OCaml, Ruby, Perl, Lua, R,
  Common Lisp, Julia): array-backed 2-3-4 trees with monoidal measures
- **Purely functional, list-based** (Scheme, Prolog, Erlang, Elixir):
  sorted lists with buffer-and-compress

---

## Universal Operations

All 28 implementations provide these core operations:

| Operation | Description |
|-----------|-------------|
| **Create** | Construct a new t-digest with a compression parameter (default 100) |
| **Add** | Insert a value with optional weight (default 1.0) |
| **Compress** | Force compression of buffered values into centroids |
| **Quantile** | Estimate the value at quantile q (0 to 1) |
| **CDF** | Estimate the cumulative distribution function at value x |
| **Merge** | Combine two digests into one |
| **Centroid count** | Number of centroids after compression |
| **Total weight** | Sum of all weights added |

Naming conventions vary by language idiom (e.g., `snake_case` in
Python/Ruby/Rust/Erlang, `camelCase` in Java/Kotlin/Go/Swift, `PascalCase`
in C#). Empty-digest returns vary: `None`/`Nothing`/`nil`/`NaN`/`0.0`
depending on the language.

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

---

## C

**File:** `c/tdigest.h` (header), `c/tdigest.c` (implementation)

The C implementation provides an opaque pointer API. The digest is
heap-allocated and must be freed by the caller.

### Functions

```c
tdigest_t *tdigest_new(double delta);
```
Create a new t-digest. Caller must free with `tdigest_free`.

```c
void tdigest_free(tdigest_t *td);
```
Free all memory associated with the digest.

```c
void tdigest_add(tdigest_t *td, double value, double weight);
```
Add a value with the given weight.

```c
void tdigest_compress(tdigest_t *td);
```
Force compression.

```c
double tdigest_quantile(tdigest_t *td, double q);
```
Estimate the value at quantile q (0 to 1).

```c
double tdigest_cdf(tdigest_t *td, double x);
```
Estimate the CDF at value x.

```c
void tdigest_merge(tdigest_t *td, const tdigest_t *other);
```
Merge `other` into `td`.

```c
int tdigest_centroid_count(tdigest_t *td);
```
Number of centroids after compression.

```c
double tdigest_total_weight(const tdigest_t *td);
```
Total weight of all values added.

---

## C++

**File:** `cpp/tdigest.hpp`

The C++ implementation is a single class backed by a 2-3-4 tree.

### Class: `TDigest`

```cpp
explicit TDigest(double delta = 100.0);
```
Construct a new t-digest with the given compression parameter.

```cpp
void add(double value, double weight = 1.0);
```
Add a value with optional weight.

```cpp
void compress();
```
Force compression.

```cpp
double quantile(double q);
```
Estimate the value at quantile q.

```cpp
double cdf(double x);
```
Estimate the CDF at value x.

```cpp
void merge(const TDigest &other);
```
Merge `other` into this digest.

```cpp
int centroidCount();
```
Number of centroids after compression.

```cpp
double totalWeight() const;
```
Total weight of all values added.

---

## Go

**File:** `go/tdigest.go`

The Go implementation is in package `tdigest`. The digest is a mutable
struct accessed via pointer receiver methods.

### Functions

```go
func New(delta float64) *TDigest
```
Create a new t-digest with the given compression parameter.

```go
func (td *TDigest) Add(value, weight float64)
```
Add a value with the given weight.

```go
func (td *TDigest) Compress()
```
Force compression.

```go
func (td *TDigest) Quantile(q float64) float64
```
Estimate the value at quantile q.

```go
func (td *TDigest) CDF(x float64) float64
```
Estimate the CDF at value x.

```go
func (td *TDigest) Merge(other *TDigest)
```
Merge `other` into this digest.

```go
func (td *TDigest) CentroidCount() int
```
Number of centroids after compression.

---

## Rust

**File:** `rust/src/lib.rs`

The Rust implementation is a `pub struct TDigest` with mutable methods.
Quantile and CDF return `Option<f64>` (None when empty).

### Methods

```rust
pub fn new(delta: f64) -> Self
pub fn default() -> Self  // delta = 100
```
Create a new t-digest.

```rust
pub fn add(&mut self, value: f64, weight: f64)
```
Add a value with the given weight.

```rust
pub fn compress(&mut self)
```
Force compression.

```rust
pub fn quantile(&mut self, q: f64) -> Option<f64>
```
Estimate the value at quantile q. Returns `None` if empty.

```rust
pub fn cdf(&mut self, x: f64) -> Option<f64>
```
Estimate the CDF at value x. Returns `None` if empty.

```rust
pub fn merge(&mut self, other: &TDigest)
```
Merge `other` into this digest.

```rust
pub fn centroid_count(&mut self) -> usize
```
Number of centroids after compression.

---

## Java

**File:** `java/TDigest.java`

The Java implementation is a mutable class backed by a 2-3-4 tree.

### Class: `TDigest`

```java
public TDigest(double delta)
public TDigest()  // delta = 100
```
Construct a new t-digest.

```java
public void add(double value, double weight)
public void add(double value)  // weight = 1.0
```
Add a value with optional weight.

```java
public void compress()
```
Force compression.

```java
public double quantile(double q)
```
Estimate the value at quantile q. Returns `NaN` if empty.

```java
public double cdf(double x)
```
Estimate the CDF at value x. Returns `NaN` if empty.

```java
public void merge(TDigest other)
```
Merge `other` into this digest.

```java
public int centroidCount()
public double totalWeight()
public double getMin()
public double getMax()
```
Accessors.

---

## Kotlin

**File:** `kotlin/TDigest.kt`

The Kotlin implementation is a mutable class with a buffer-and-compress
strategy.

### Class: `TDigest`

```kotlin
class TDigest(val delta: Double = 100.0)
```
Construct a new t-digest.

```kotlin
fun add(value: Double, weight: Double = 1.0)
```
Add a value with optional weight.

```kotlin
fun compress()
```
Force compression.

```kotlin
fun quantile(q: Double): Double
```
Estimate the value at quantile q. Returns `NaN` if empty.

```kotlin
fun cdf(x: Double): Double
```
Estimate the CDF at value x. Returns `NaN` if empty.

```kotlin
fun merge(other: TDigest)
```
Merge `other` into this digest.

```kotlin
fun centroidCount(): Int
```
Number of centroids after compression.

```kotlin
val totalWeight: Double   // read-only property
val min: Double
val max: Double
```
Read-only accessors.

---

## Python

**File:** `python/tdigest.py`

The Python implementation is a mutable class. Pure Python with only
`math` as a dependency.

### Class: `TDigest`

```python
TDigest(delta: float = 100)
```
Create a new t-digest.

```python
td.add(value: float, weight: float = 1.0) -> TDigest
```
Add a value with optional weight. Returns `self` for chaining.

```python
td.compress() -> TDigest
```
Force compression. Returns `self`.

```python
td.quantile(q: float) -> float | None
```
Estimate the value at quantile q. Returns `None` if empty.

```python
td.cdf(x: float) -> float | None
```
Estimate the CDF at value x. Returns `None` if empty.

```python
td.merge(other: TDigest) -> TDigest
```
Merge `other` into this digest. Returns `self`.

```python
td.centroid_count() -> int
```
Number of centroids after compression.

```python
td.total_weight   # float
td.delta           # float
td.min             # float
td.max             # float
```
Public attributes.

---

## Julia

**File:** `julia/TDigest.jl`

The Julia implementation is in module `TDigestModule`. Mutating functions
follow the Julia convention of a `!` suffix.

### Exports

```julia
TDigest(delta::Real = 100.0)
```
Create a new t-digest.

```julia
add!(td::TDigest, value::Real, weight::Real = 1.0)
```
Add a value with optional weight.

```julia
compress!(td::TDigest)
```
Force compression.

```julia
quantile(td::TDigest, q::Float64)
```
Estimate the value at quantile q. Returns `nothing` if empty.

```julia
cdf(td::TDigest, x::Real)
```
Estimate the CDF at value x. Returns `nothing` if empty.

```julia
merge!(td::TDigest, other::TDigest)
```
Merge `other` into `td`.

```julia
centroid_count(td::TDigest) -> Int
```
Number of centroids after compression.

### Fields

```julia
td.total_weight   # Float64
td.min            # Float64
td.max            # Float64
td.delta          # Float64
```

---

## OCaml

**File:** `ocaml/tdigest.ml`

The OCaml implementation uses mutable records and an array-backed
2-3-4 tree. The digest type is `t`.

### Functions

```ocaml
val create : ?delta:float -> unit -> t
```
Create a new t-digest. Default delta is 100.

```ocaml
val add : t -> float -> ?weight:float -> unit -> unit
```
Add a value with optional weight (default 1.0).

```ocaml
val compress : t -> unit
```
Force compression.

```ocaml
val quantile : t -> float -> float option
```
Estimate the value at quantile q. Returns `None` if empty.

```ocaml
val cdf : t -> float -> float option
```
Estimate the CDF at value x. Returns `None` if empty.

```ocaml
val merge : t -> t -> unit
```
Merge the second digest into the first.

```ocaml
val centroid_count : t -> int
```
Number of centroids after compression.

```ocaml
val total_weight : t -> float
val min_val : t -> float
val max_val : t -> float
```
Accessors.

---

## Erlang

**File:** `erlang/tdigest.erl`

The Erlang implementation uses a record-based functional style with
sorted lists. All functions return a new `#tdigest{}` record.

### Exports

```erlang
new() -> tdigest()
new(Delta) -> tdigest()
```
Create a new t-digest. Default delta is 100.

```erlang
add(TD, Value) -> tdigest()
add(TD, Value, Weight) -> tdigest()
```
Add a value with optional weight (default 1.0).

```erlang
compress(TD) -> tdigest()
```
Force compression.

```erlang
quantile(TD, Q) -> float() | undefined
```
Estimate the value at quantile Q.

```erlang
cdf(TD, X) -> float() | undefined
```
Estimate the CDF at value X.

```erlang
merge(TD1, TD2) -> tdigest()
```
Merge two digests.

```erlang
centroid_count(TD) -> integer()
```
Number of centroids after compression.

---

## Elixir

**File:** `elixir/tdigest.ex`

The Elixir implementation is a functional module using a `%TDigest{}`
struct with sorted lists.

### Functions

```elixir
TDigest.new(delta \\ 100)
```
Create a new t-digest.

```elixir
TDigest.add(td, value, weight \\ 1.0)
```
Add a value with optional weight. Returns updated struct.

```elixir
TDigest.compress(td)
```
Force compression. Returns updated struct.

```elixir
TDigest.quantile(td, q)
```
Estimate the value at quantile q.

```elixir
TDigest.cdf(td, x)
```
Estimate the CDF at value x.

```elixir
TDigest.merge(td, other)
```
Merge `other` into `td`. Returns updated struct.

```elixir
TDigest.centroid_count(td)
```
Number of centroids after compression.

### Struct fields

```elixir
td.total_weight
td.delta
td.min
td.max
```

---

## Fortran

**File:** `fortran/tdigest.f90`

The Fortran implementation is in module `tdigest_mod`. It uses a
derived type with type-bound procedures (Fortran 2003+).

### Type: `tdigest`

```fortran
type(tdigest) :: td
call td%init(delta)          ! or use tdigest_create(delta)
```

### Type-bound procedures

```fortran
call td%init(delta)
```
Initialize a t-digest with the given compression parameter.

```fortran
call td%add(value, weight)
```
Add a value with the given weight.

```fortran
call td%compress()
```
Force compression.

```fortran
result = td%quantile(q)
```
Estimate the value at quantile q. Returns 0.0 if empty.

```fortran
result = td%cdf(x)
```
Estimate the CDF at value x.

```fortran
call td%merge(other)
```
Merge `other` into this digest.

```fortran
n = td%centroid_count()
```
Number of centroids after compression.

### Module function

```fortran
td = tdigest_create(delta)
```
Convenience constructor that returns an initialized digest.

---

## Perl

**File:** `perl/TDigest.pm`

The Perl implementation is an OO module using blessed hash references
and a 2-3-4 tree.

### Methods

```perl
TDigest->new(delta => 100)
```
Create a new t-digest.

```perl
$td->add($value, $weight)   # weight defaults to 1.0
```
Add a value with optional weight.

```perl
$td->compress()
```
Force compression.

```perl
$td->quantile($q)
```
Estimate the value at quantile q. Returns `undef` if empty.

```perl
$td->cdf($x)
```
Estimate the CDF at value x. Returns `undef` if empty.

```perl
$td->merge($other)
```
Merge `$other` into this digest.

```perl
$td->centroid_count()
```
Number of centroids after compression.

```perl
$td->total_weight()
```
Total weight of all values added.

---

## Lua

**File:** `lua/tdigest.lua`

The Lua implementation uses metatables for OOP. Backed by a 2-3-4 tree.

### Functions

```lua
TDigest.new(delta)   -- default 100
```
Create a new t-digest.

```lua
td:add(value, weight)   -- weight defaults to 1.0
```
Add a value with optional weight. Returns `self`.

```lua
td:compress()
```
Force compression.

```lua
td:quantile(q)
```
Estimate the value at quantile q. Returns `nil` if empty.

```lua
td:cdf(x)
```
Estimate the CDF at value x. Returns `nil` if empty.

```lua
td:merge(other)
```
Merge `other` into this digest.

```lua
td:centroid_count()
```
Number of centroids after compression.

### Fields

```lua
td.total_weight
td.min_val
td.max_val
td.delta
```

---

## R

**File:** `r/tdigest.R`

The R implementation uses environment-based OOP with free functions.

### Functions

```r
tdigest_new(delta = 100)
```
Create a new t-digest.

```r
tdigest_add(self, value, weight = 1.0)
```
Add a value with optional weight.

```r
tdigest_compress(self)
```
Force compression.

```r
tdigest_quantile(self, q)
```
Estimate the value at quantile q.

```r
tdigest_cdf(self, x)
```
Estimate the CDF at value x.

```r
tdigest_merge(self, other)
```
Merge `other` into `self`.

```r
tdigest_centroid_count(self)
```
Number of centroids after compression.

### Fields (environment members)

```r
self$total_weight
self$min_val
self$max_val
self$delta
```

---

## Zig

**File:** `zig/tdigest.zig`

The Zig implementation uses an allocator-aware struct. Errors are
returned via Zig's error union types.

### Functions

```zig
pub fn init(allocator: Allocator, delta: f64) TDigest
```
Create a new t-digest with the given allocator and delta.

```zig
pub fn deinit(self: *TDigest) void
```
Free all allocated memory.

```zig
pub fn add(self: *TDigest, value: f64, weight: f64) !void
```
Add a value with the given weight.

```zig
pub fn compress(self: *TDigest) !void
```
Force compression.

```zig
pub fn quantile(self: *TDigest, q_in: f64) !?f64
```
Estimate the value at quantile q. Returns `null` if empty.

```zig
pub fn cdf(self: *TDigest, x: f64) !?f64
```
Estimate the CDF at value x. Returns `null` if empty.

```zig
pub fn mergeFrom(self: *TDigest, other: *TDigest) !void
```
Merge `other` into this digest.

```zig
pub fn centroidCount(self: *TDigest) !usize
```
Number of centroids after compression.

---

## Nim

**File:** `nim/tdigest.nim`

The Nim implementation is a `ref object` with exported procedures
(marked with `*`).

### Procedures

```nim
proc newTDigest*(delta: float = 100.0): TDigest
```
Create a new t-digest.

```nim
proc add*(td: TDigest, value: float, weight: float = 1.0)
```
Add a value with optional weight.

```nim
proc compress*(td: TDigest)
```
Force compression.

```nim
proc quantile*(td: TDigest, q: float): float
```
Estimate the value at quantile q.

```nim
proc cdf*(td: TDigest, x: float): float
```
Estimate the CDF at value x.

```nim
proc merge*(td: TDigest, other: TDigest)
```
Merge `other` into `td`.

```nim
proc centroidCount*(td: TDigest): int
```
Number of centroids after compression.

### Fields

```nim
td.totalWeight*: float
td.minVal*: float
td.maxVal*: float
td.delta*: float
```

---

## D

**File:** `d/tdigest.d`

The D implementation is a struct with a static `create` factory method.

### Methods

```d
static TDigest create(double delta = 100.0)
```
Create a new t-digest.

```d
void add(double value, double weight = 1.0)
```
Add a value with optional weight.

```d
void compress()
```
Force compression.

```d
double quantile(double q)
```
Estimate the value at quantile q.

```d
double cdf(double x)
```
Estimate the CDF at value x.

```d
void merge(ref TDigest other)
```
Merge `other` into this digest.

```d
size_t centroidCount()
```
Number of centroids after compression.

### Fields

```d
double totalWeight;
double minVal;
double maxVal;
double delta;
```

---

## C\#

**File:** `csharp/TDigest.cs`

The C# implementation is in namespace `TDigestLib`. It is a class
backed by a generic 2-3-4 tree.

### Class: `TDigest`

```csharp
public TDigest(double delta = 100)
```
Construct a new t-digest.

```csharp
public void Add(double value, double weight = 1.0)
```
Add a value with optional weight.

```csharp
public void Compress()
```
Force compression.

```csharp
public double? Quantile(double q)
```
Estimate the value at quantile q. Returns `null` if empty.

```csharp
public double? Cdf(double x)
```
Estimate the CDF at value x. Returns `null` if empty.

```csharp
public void Merge(TDigest other)
```
Merge `other` into this digest.

```csharp
public int CentroidCount { get; }
```
Number of centroids after compression (property).

```csharp
public double TotalWeight { get; }
```
Total weight of all values added (property).

---

## Swift

**File:** `swift/tdigest.swift`

The Swift implementation is a value-type struct. Mutating methods are
marked with `mutating`.

### Struct: `TDigest`

```swift
init(delta: Double = 100.0)
```
Create a new t-digest.

```swift
mutating func add(_ value: Double, weight: Double = 1.0)
```
Add a value with optional weight.

```swift
mutating func compress()
```
Force compression.

```swift
mutating func quantile(_ q: Double) -> Double?
```
Estimate the value at quantile q. Returns `nil` if empty.

```swift
mutating func cdf(_ x: Double) -> Double?
```
Estimate the CDF at value x. Returns `nil` if empty.

```swift
mutating func merge(_ other: inout TDigest)
```
Merge `other` into this digest.

```swift
var centroidCount: Int { get }
```
Number of centroids after compression (computed property).

```swift
let delta: Double
private(set) var totalWeight: Double
private(set) var min: Double
private(set) var max: Double
```
Read-only properties.
