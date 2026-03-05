# Algorithm Details

This chapter gives formal pseudocode for every operation, describes the
scale function variants, analyzes accuracy, and compares the t-digest
with other quantile sketches.

---

## Data Structure

```
Centroid:
    mean   : float
    weight : float

TDigest:
    centroids    : list of Centroid, sorted by mean
    buffer       : list of Centroid (unsorted)
    total_weight : float
    min_val      : float
    max_val      : float
    delta         : float          -- compression parameter
    buffer_cap   : int            -- floor(delta * 5)
```

---

## Scale Functions

A scale function k : [0, 1] -> R maps quantile space to index space.
The compression invariant is:

    For every centroid with quantile range [q_L, q_R]:
        k(q_R) - k(q_L) <= 1

The derivative k'(q) controls the maximum centroid size at quantile q.
A large k'(q) means small centroids; a small k'(q) means large centroids.

### K0 (Uniform)

```
k0(q, delta) = (delta / 2) * q
```

This gives uniform bin widths -- equivalent to a regular histogram. No
tail bias. Rarely useful in practice.

### K1 (Arcsine) -- DEFAULT

```
k1(q, delta) = (delta / (2 * pi)) * arcsin(2*q - 1)
```

Derivative:

```
k1'(q) = delta / (pi * sqrt(q * (1 - q)))
```

This diverges at q = 0 and q = 1, forcing centroids at the tails to be
vanishingly small. It is the scale function used by all eight
implementations in this project.

### K2 (Logit-based)

```
k2(q, delta) = (delta / (4 * log(n/delta) + 24)) * log(q / (1 - q))
```

where n is the total number of values seen. This gives even stronger
tail compression than K1 but depends on n, making it slightly more
complex to implement.

### K3 (Quadratic)

```
k3(q, delta) = (delta / 2) * (q <= 0.5 ? 2*q^2 : 1 - 2*(1-q)^2)
```

A polynomial alternative that avoids transcendental functions. Faster
to compute than K1 but with slightly weaker tail guarantees.

---

## Operations

### CREATE(delta)

```
function CREATE(delta):
    return TDigest {
        centroids    = []
        buffer       = []
        total_weight = 0.0
        min_val      = +infinity
        max_val      = -infinity
        delta         = delta
        buffer_cap   = ceiling(delta * 5)
    }
```

### ADD(td, value, weight)

```
function ADD(td, value, weight):
    append Centroid(value, weight) to td.buffer
    td.total_weight += weight
    td.min_val = min(td.min_val, value)
    td.max_val = max(td.max_val, value)
    if length(td.buffer) >= td.buffer_cap:
        COMPRESS(td)
```

Amortized time: O(1) for fixed delta.

### COMPRESS(td)

```
function COMPRESS(td):
    if td.buffer is empty and length(td.centroids) <= 1:
        return

    all = td.centroids ++ td.buffer
    sort all by centroid mean (ascending)
    td.buffer = []

    new_centroids = [all[0]]          -- start with the first centroid
    weight_so_far = 0.0
    n = td.total_weight

    for i = 1 to length(all) - 1:
        current = last element of new_centroids
        item = all[i]
        proposed = current.weight + item.weight
        q0 = weight_so_far / n
        q1 = (weight_so_far + proposed) / n

        if proposed <= 1.0:                       -- always merge singletons
            merge item into current
        else if k(q1, delta) - k(q0, delta) <= 1.0:  -- scale function allows it
            merge item into current
        else:
            weight_so_far += current.weight       -- finalize current
            append item as new centroid to new_centroids

    td.centroids = new_centroids
```

Where "merge item into current" means:

```
function MERGE_CENTROID(dst, src):
    new_weight = dst.weight + src.weight
    dst.mean = (dst.mean * dst.weight + src.mean * src.weight) / new_weight
    dst.weight = new_weight
```

Time: O(m log m) where m = |centroids| + |buffer| = O(delta).

### QUANTILE(td, q)

```
function QUANTILE(td, q):
    if td.buffer is not empty:
        COMPRESS(td)

    cs = td.centroids
    if cs is empty: return NIL
    if length(cs) == 1: return cs[0].mean

    q = clamp(q, 0.0, 1.0)
    n = td.total_weight
    target = q * n

    cumulative = 0.0
    for i = 0 to length(cs) - 1:
        c = cs[i]
        half_w = c.weight / 2.0
        mid = cumulative + half_w

        -- Left boundary: interpolate between min and first centroid
        if i == 0 and target < half_w:
            if c.weight == 1: return td.min_val
            return td.min_val + (c.mean - td.min_val) * (target / half_w)

        -- Right boundary: interpolate between last centroid and max
        if i == length(cs) - 1:
            right_start = n - half_w
            if target > right_start:
                if c.weight == 1: return td.max_val
                return c.mean + (td.max_val - c.mean) *
                       ((target - right_start) / half_w)
            return c.mean

        -- Interior: interpolate between adjacent centroid midpoints
        next_c = cs[i + 1]
        next_mid = cumulative + c.weight + next_c.weight / 2.0
        if target <= next_mid:
            frac = (target - mid) / (next_mid - mid)
            return c.mean + frac * (next_c.mean - c.mean)

        cumulative += c.weight

    return td.max_val   -- fallback
```

Time: O(delta) in the worst case (linear walk).

### CDF(td, x)

```
function CDF(td, x):
    if td.buffer is not empty:
        COMPRESS(td)

    cs = td.centroids
    if cs is empty: return NIL
    if x <= td.min_val: return 0.0
    if x >= td.max_val: return 1.0

    n = td.total_weight
    cumulative = 0.0
    for i = 0 to length(cs) - 1:
        c = cs[i]
        mid = cumulative + c.weight / 2.0

        -- Left boundary
        if i == 0 and x < c.mean:
            frac = (x - td.min_val) / (c.mean - td.min_val)
            return (c.weight / 2.0 * frac) / n
        if i == 0 and x == c.mean:
            return (c.weight / 2.0) / n

        -- Right boundary
        if i == length(cs) - 1:
            if x > c.mean:
                right_w = n - cumulative - c.weight / 2.0
                frac = (x - c.mean) / (td.max_val - c.mean)
                return (cumulative + c.weight / 2.0 + right_w * frac) / n
            return (cumulative + c.weight / 2.0) / n

        -- Interior
        next_c = cs[i + 1]
        next_cum = cumulative + c.weight
        next_mid = next_cum + next_c.weight / 2.0
        if x < next_c.mean:
            frac = (x - c.mean) / (next_c.mean - c.mean)
            return (mid + frac * (next_mid - mid)) / n

        cumulative += c.weight

    return 1.0   -- fallback
```

Time: O(delta).

### MERGE(td1, td2)

```
function MERGE(td1, td2):
    if td2.buffer is not empty:
        COMPRESS(td2)

    for each centroid c in td2.centroids:
        ADD(td1, c.mean, c.weight)

    COMPRESS(td1)
```

Time: O(delta log delta).

---

## Accuracy Bounds

Dunning & Ertl (2019) establish the following properties for the
merging digest with K1:

1. **Number of centroids.** The digest contains at most
   ceil(delta / 2 * pi) + 1 centroids after compression. For delta = 100,
   this is about 17 centroids in theory, though in practice the count is
   higher (typically 50--100) because the greedy merge is not perfectly
   optimal.

2. **Quantile error.** For the K1 scale function, the maximum absolute
   error in quantile estimation at quantile q is bounded by:

   ```
   |estimated_q - true_q| <= O(1 / delta) * sqrt(q * (1 - q))
   ```

   This means:
   - At q = 0.5 (median), the error is O(1/delta).
   - At q = 0.01, the error is O(sqrt(0.01) / delta) ~ O(0.1 / delta).
   - At q = 0.001, the error is O(sqrt(0.001) / delta) ~ O(0.03 / delta).

   The error shrinks as you approach the tails -- exactly where you want
   precision.

3. **Space.** O(delta) centroids, each storing two floats. Total memory
   is O(delta) = O(1) for fixed delta.

---

## Comparison with Other Quantile Sketches

| Sketch         | Space       | Add Time    | Query Time | Mergeable | Tail Accuracy          |
|----------------|-------------|-------------|------------|-----------|------------------------|
| **t-digest**   | O(delta)    | O(1) amort. | O(delta)   | Yes       | High (via scale func.) |
| **Q-digest**   | O(1/eps * log U) | O(log U) | O(log U) | Yes    | Uniform                |
| **GK sketch**  | O(1/eps * log(eps*n)) | O(1/eps * log(eps*n)) | O(1/eps * log(eps*n)) | No | Uniform |
| **KLL sketch** | O(1/eps * log log(1/delta_p)) | O(1) amort. | O(log(1/eps)) | Yes | Uniform |
| **DDSketch**   | O(1/eps)    | O(1)        | O(1)       | Yes       | Relative (multiplicative) |
| **Moments**    | O(k)        | O(1)        | O(1)       | Yes       | Depends on distribution  |

Key distinctions:

- **Q-digest** operates on integer-valued data with a known universe
  size U. Not suitable for continuous data.

- **GK sketch** (Greenwald-Khanna) provides deterministic epsilon-rank
  guarantees but is not mergeable and has higher constant factors.

- **KLL sketch** (Karnin-Lang-Liberty) provides probabilistic
  epsilon-rank guarantees with optimal space. Mergeable. The accuracy
  is uniform across all quantiles -- it does not have special tail
  accuracy.

- **DDSketch** provides relative-error guarantees (i.e., the error is a
  multiplicative factor of the true quantile value). Excellent for
  latency data where relative error matters. It uses exponentially-spaced
  bins.

- **Moments sketch** stores the first k moments of the data and uses
  them to reconstruct the distribution. Accuracy depends heavily on the
  shape of the distribution; it can be poor for heavy-tailed or
  multimodal data.

The t-digest's main advantage is its combination of mergeability,
simplicity, and deliberately non-uniform accuracy that focuses on the
tails. Its main disadvantage compared to KLL or DDSketch is the lack
of formal worst-case guarantees (the error bounds are empirical and
depend on the scale function choice).
