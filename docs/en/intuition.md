# Building Intuition

This chapter walks through the ideas behind the t-digest slowly, with lots
of ASCII diagrams. If you know what a median is, you have enough background
to follow along.

---

## 1. The Histogram Analogy

Suppose you have 100 numbers drawn uniformly from 0 to 100, and you want to
summarize them. The most familiar tool is a histogram: divide the range into
fixed-width bins and count how many values fall into each bin.

Here is a histogram with 10 equal-width bins for 1000 uniform values in
[0, 100). Each `#` represents roughly 10 values:

```
  Count
  120 |
  110 |
  100 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   90 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   80 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   70 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   60 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   50 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   40 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   30 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   20 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
   10 | ##   ##   ##   ##   ##   ##   ##   ##   ##   ##
    0 +----+----+----+----+----+----+----+----+----+----
      0   10   20   30   40   50   60   70   80   90  100
```

This looks fine for uniform data, but real data is rarely uniform. Now
consider latency data where most requests are fast but a few are very slow.
If we use the same 10 bins:

```
  Count
  500 | ##
  450 | ##
  400 | ##
  350 | ##   ##
  300 | ##   ##
  250 | ##   ##
  200 | ##   ##   ##
  150 | ##   ##   ##
  100 | ##   ##   ##   ##
   50 | ##   ##   ##   ##   ##
    0 +----+----+----+----+----+----+----+----+----+----
      0   10   20   30   40   50   60   70   80   90  100
```

The last few bins (the "tail") have very few samples. If you ask "what is
the 99th percentile?", you get a very rough answer because all you know is
that it falls _somewhere_ in the 90--100 bin. You cannot tell whether it is
91 or 99.

**Problem:** Fixed-width bins waste resolution in the middle (where you have
plenty of data) and starve the tails (where you need precision).

---

## 2. Variable-Width Bins

What if the bins were not all the same width? What if we made them _narrow_
at the edges and _wide_ in the middle?

```
                     Variable-width bins

  Narrow    Wider         Widest         Wider    Narrow
  |  |  |   |    |    |          |    |    |   |  |  |
  v  v  v   v    v    v          v    v    v   v  v  v

  +--+--+---+----+----+----------+----+----+---+--+--+
  0                      50                         100
  <------->                                <--------->
  More bins                                 More bins
  in the tail                              in the tail
```

Now the tails have narrow bins (high resolution) and the middle has wide
bins (low resolution, but that is fine because we have lots of data there
and don't need to distinguish 49 from 51 very precisely).

**This is the core insight of the t-digest.** It uses variable-width
"bins" -- called _centroids_ -- that are narrow at the tails and wide in
the middle. The question is: how wide should each one be? That is where
the _scale function_ comes in (Section 4).

---

## 3. Centroids as Adaptive Bins

A centroid is a pair: **(mean, weight)**.

- **mean** -- the average of all values that were merged into this centroid.
- **weight** -- how many values were merged in (or the sum of their weights
  if they had non-unit weights).

Let's watch five values get added to a t-digest with delta = 4 (very small,
just for illustration).

**Step 1: Add 0.5.** The buffer gets one entry.

```
  Buffer: [(0.5, 1)]
  Centroids: (none)
```

**Step 2: Add 0.1.** Buffer grows.

```
  Buffer: [(0.5, 1), (0.1, 1)]
  Centroids: (none)
```

**Step 3: Add 0.9.** Buffer grows.

```
  Buffer: [(0.5, 1), (0.1, 1), (0.9, 1)]
  Centroids: (none)
```

**Step 4: Add 0.2.** Buffer grows. Suppose our buffer capacity is 4
(= delta * 1, kept small for this example). We add one more:

**Step 5: Add 0.8.** Buffer is now full! Time to compress.

```
  Buffer: [(0.5, 1), (0.1, 1), (0.9, 1), (0.2, 1), (0.8, 1)]
```

**Compression step:**

1. Combine centroids and buffer, sort by mean:

```
  Sorted: [(0.1, 1), (0.2, 1), (0.5, 1), (0.8, 1), (0.9, 1)]
```

2. Walk left to right. Try to merge each centroid into the current one.
   The scale function decides if the merged centroid would be "too wide."

   With delta = 4, the scale function allows very little merging at the
   edges (near q=0 or q=1) but allows more merging in the middle.

   - Start with (0.1, 1). Current = (0.1, 1).
   - Try to merge (0.2, 1): near the left tail, scale function says NO.
     Finalize (0.1, 1). Current = (0.2, 1).
   - Try to merge (0.5, 1): now we are farther from the edge. Scale
     function says YES. Current = (0.35, 2).
   - Try to merge (0.8, 1): scale function says YES. Current = (0.50, 3).
   - Try to merge (0.9, 1): near the right tail. Scale function says NO.
     Finalize (0.50, 3). Current = (0.9, 1). Finalize it.

```
  After compression:
  Centroids: [(0.1, 1), (0.50, 3), (0.9, 1)]
                 ^          ^          ^
              tail:      middle:     tail:
            kept small  allowed     kept small
                       to be big
```

Notice: the tails kept their individual centroids (weight 1) while the
middle values got merged into a single big centroid (weight 3). This is
the t-digest in action.

---

## 4. The Scale Function

The scale function is the heart of the t-digest. It is a function
k(q) that maps quantile space [0, 1] to "index" space. The rule is:

> A centroid covering quantile range [q_L, q_R] is allowed to exist
> only if k(q_R) - k(q_L) <= 1.

Different scale functions give different trade-offs. The one used in
this project is **K1 (arcsine)**:

```
  k(q) = (delta / (2 * pi)) * arcsin(2*q - 1)
```

Let's plot k(q) for delta = 10 (keeping numbers small for the diagram).
The output ranges from about -1.6 to +1.6:

```
  k(q)
   1.6 |                                              .**
       |                                           ..*
       |                                         .*
   0.8 |                                      .**
       |                                   .**
       |                               ..**
   0.0 +-----------+-----------..**----------+--------
       |                  ..**
       |              ..**
  -0.8 |           .**
       |        .*
       |      .*
  -1.6 | .**
       +---+---+---+---+---+---+---+---+---+---+---
       0      0.1    0.2    0.3   0.4   0.5   0.6
                                   0.7   0.8   0.9  1.0
```

The key feature is the **slope** (derivative) of k(q):

- Near q = 0 and q = 1, the curve is **steep**. A small change in q
  produces a large change in k. This means the constraint
  k(q_R) - k(q_L) <= 1 forces centroids to cover a very narrow quantile
  range -- i.e., they must be **small**.

- Near q = 0.5, the curve is **flat**. A large change in q produces only
  a small change in k. The constraint allows centroids to cover a wide
  quantile range -- i.e., they can be **big**.

Here is the derivative, k'(q):

```
  k'(q) = delta / (pi * sqrt(q * (1-q)))

  k'(q)
   30  |*                                            *
       | *                                          *
   25  |  *                                        *
       |   *                                      *
   20  |    *                                    *
       |     *                                  *
   15  |      **                              **
       |        **                          **
   10  |          ***                    ***
       |             ****          *****
    5  |                 *********
       |
    0  +---+---+---+---+---+---+---+---+---+---+---
       0      0.1    0.2    0.3   0.4   0.5   0.6
                                   0.7   0.8   0.9  1.0
```

Near the edges, k' is enormous -- centroids are forced to be tiny.
Near the center, k' is small -- centroids can be large.

**Comparison with a linear scale function (uniform bins):**

If we used k(q) = delta * q (a straight line), the derivative would be
constant everywhere, giving uniform-width bins like a regular histogram.
The K1 arcsine function re-allocates resolution from the boring middle
to the interesting tails.

---

## 5. The Compression Invariant

The fundamental invariant maintained by the t-digest is:

> For every centroid whose quantile range is [q_L, q_R]:
>     k(q_R) - k(q_L) <= 1

Let's walk through a compression pass with a concrete example. Suppose
we have 10 centroids with total weight N = 20, and delta = 10:

```
  Before compression:

  Index:    0     1     2     3     4     5     6     7     8     9
  Mean:   1.0   2.0   3.0   4.0   5.0   6.0   7.0   8.0   9.0  10.0
  Weight:   1     1     2     3     4     4     2     1     1     1
                                                          (total = 20)
```

We walk left to right. At each step we track weight_so_far (the total
weight of all finalized centroids before the current one) and compute
q values.

```
  Start: current = (1.0, 1), weight_so_far = 0

  Try to merge (2.0, 1) into current:
    proposed_weight = 1 + 1 = 2
    q0 = 0/20 = 0.00
    q1 = 2/20 = 0.10
    k(0.10) - k(0.00) = ... about 0.67    <= 1?  YES -> merge!
    current = (1.5, 2)

  Try to merge (3.0, 2) into current:
    proposed_weight = 2 + 2 = 4
    q0 = 0/20 = 0.00
    q1 = 4/20 = 0.20
    k(0.20) - k(0.00) = ... about 1.08    <= 1?  NO -> finalize!
    Emit (1.5, 2). weight_so_far = 2. current = (3.0, 2)

  Try to merge (4.0, 3) into current:
    proposed_weight = 2 + 3 = 5
    q0 = 2/20 = 0.10
    q1 = 7/20 = 0.35
    k(0.35) - k(0.10) = ... about 0.85    <= 1?  YES -> merge!
    current = (3.6, 5)

  Try to merge (5.0, 4) into current:
    proposed_weight = 5 + 4 = 9
    q0 = 2/20 = 0.10
    q1 = 11/20 = 0.55
    k(0.55) - k(0.10) = ... about 1.50    <= 1?  NO -> finalize!
    Emit (3.6, 5). weight_so_far = 7. current = (5.0, 4)

  Try to merge (6.0, 4) into current:
    proposed_weight = 4 + 4 = 8
    q0 = 7/20 = 0.35
    q1 = 15/20 = 0.75
    k(0.75) - k(0.35) = ... about 0.67    <= 1?  YES -> merge!
    current = (5.5, 8)

  Try to merge (7.0, 2) into current:
    proposed_weight = 8 + 2 = 10
    q0 = 7/20 = 0.35
    q1 = 17/20 = 0.85
    k(0.85) - k(0.35) = ... about 1.24    <= 1?  NO -> finalize!
    Emit (5.5, 8). weight_so_far = 15. current = (7.0, 2)

  Try to merge (8.0, 1) into current:
    proposed_weight = 2 + 1 = 3
    q0 = 15/20 = 0.75
    q1 = 18/20 = 0.90
    k(0.90) - k(0.75) = ... about 0.67    <= 1?  YES -> merge!
    current = (7.33, 3)

  Try to merge (9.0, 1) into current:
    proposed_weight = 3 + 1 = 4
    q0 = 15/20 = 0.75
    q1 = 19/20 = 0.95
    k(0.95) - k(0.75) = ... about 1.08    <= 1?  NO -> finalize!
    Emit (7.33, 3). weight_so_far = 18. current = (9.0, 1)

  Try to merge (10.0, 1) into current:
    proposed_weight = 1 + 1 = 2
    q0 = 18/20 = 0.90
    q1 = 20/20 = 1.00
    k(1.00) - k(0.90) = ... about 0.92    <= 1?  YES -> merge!
    current = (9.5, 2)

  No more items. Emit (9.5, 2).
```

```
  After compression:

  Index:    0       1         2       3       4
  Mean:   1.50    3.60      5.50    7.33    9.50
  Weight:    2       5         8       3       2
                                          (total = 20)
```

Before: 10 centroids. After: 5 centroids. The middle centroid (5.50, 8)
is the biggest -- it sits near the median where the scale function
allows large centroids. The edge centroids (1.50 and 9.50) are small --
the scale function forces them to stay narrow.

---

## 6. Quantile Estimation by Interpolation

Now let's use the compressed digest from Section 5 to answer queries.

```
  Centroids:  (1.50, 2)  (3.60, 5)  (5.50, 8)  (7.33, 3)  (9.50, 2)
  Total weight N = 20.     Min = 1.0.     Max = 10.0.
```

Each centroid is conceptually "centered" at its mean. Its left half
contributes weight/2 and its right half contributes weight/2. We walk
from left to right, accumulating weight, and interpolate.

### Estimating q = 0.50 (the median)

```
  target = 0.50 * 20 = 10.0

  Walk the centroids, tracking cumulative weight before each one:

  i=0: centroid (1.50, 2).  cumulative = 0.
       midpoint at weight 0 + 2/2 = 1.0
       next midpoint at weight 0 + 2 + 5/2 = 4.5
       Is target(10.0) <= 4.5?  NO.  Move on.  cumulative = 2.

  i=1: centroid (3.60, 5).  cumulative = 2.
       midpoint at weight 2 + 5/2 = 4.5
       next midpoint at weight 2 + 5 + 8/2 = 11.0
       Is target(10.0) <= 11.0?  YES!
       frac = (10.0 - 4.5) / (11.0 - 4.5) = 5.5 / 6.5 = 0.846
       value = 3.60 + 0.846 * (5.50 - 3.60) = 3.60 + 1.61 = 5.21

  Answer: quantile(0.50) ~ 5.21
```

(The true median of 1..10 with those weights would be around 5.5, so
5.21 is a reasonable estimate for a digest with only 5 centroids.)

### Estimating q = 0.99 (near the right tail)

```
  target = 0.99 * 20 = 19.8

  Walk the centroids:

  i=0..3: midpoints are well below 19.8. Skip ahead.

  i=4: centroid (9.50, 2).  cumulative = 18.  This is the LAST centroid.
       Right boundary logic:
       right_start = N - weight/2 = 20 - 2/2 = 19.0
       Is target(19.8) > right_start(19.0)?  YES.
       frac = (19.8 - 19.0) / (2/2) = 0.8 / 1.0 = 0.8
       value = 9.50 + 0.8 * (10.0 - 9.50) = 9.50 + 0.40 = 9.90

  Answer: quantile(0.99) ~ 9.90
```

Notice how the tail estimate (9.90) is very close to the true 99th
percentile. This is not an accident -- the small centroids at the edges
preserve tail information.

---

## 7. Why O(1) Amortized Add?

Adding a value to the t-digest looks like this:

1. Append it to the buffer. This is O(1).
2. If the buffer is full, compress. This is O(m log m), where m is the
   number of centroids + buffer entries.

The buffer capacity is set to 5 * delta. So compression is triggered
every 5 * delta additions.

```
  Buffer capacity = 5 * delta

  One compression pass:
    m = (number of centroids) + (buffer size)
    m <= delta + 5*delta = 6*delta     (centroids are bounded by ~delta)
    Cost of compression = O(m log m) = O(delta * log(delta))

  Amortized cost per add:
    O(delta * log(delta))  /  (5 * delta)  =  O(log(delta) / 5)

  For fixed delta, this is O(1).
```

In practice, delta is a constant you choose at construction time
(typically 100). So the amortized cost per add is a small constant,
regardless of how many values you have seen.

```
  Time
    ^
    |                         ***  <-- compression pass
    |
    |  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  ***
    |  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^
    +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--> adds
       1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16

  Most adds are O(1) (just append to buffer).
  Every ~5*delta adds, one O(delta log delta) compression.
  Amortized: O(1) per add.
```

---

## 8. Merging Two Digests

Merging is what makes the t-digest shine in distributed systems.

Suppose Server A has been tracking request latencies and Server B has
been doing the same. Each has its own local t-digest. To get a global
view, we merge them:

```
  Server A's digest:              Server B's digest:

  Centroids:                      Centroids:
    (2.0, 10)                       (1.5,  8)
    (5.0, 30)                       (4.0, 25)
    (8.0, 15)                       (7.5, 20)
    (9.5,  5)                       (9.8,  3)
```

**Merge procedure:**

1. Take all centroids from both digests (treat them as weighted values).
2. Combine them into the buffer of one digest.
3. Compress.

```
  Step 1: All centroids, sorted by mean:

    (1.5, 8), (2.0, 10), (4.0, 25), (5.0, 30),
    (7.5, 20), (8.0, 15), (9.5, 5), (9.8, 3)

  Step 2: Run the greedy merge pass (same as regular compression).

    The scale function merges middle centroids aggressively
    and keeps tail centroids small.

  Step 3: Result -- a single digest summarizing all data from both
    servers, with the same accuracy guarantees as if all values
    had been added to one digest.
```

```
  +-------------+        +-------------+
  |  Server A   |        |  Server B   |
  |  t-digest   |        |  t-digest   |
  +------+------+        +------+------+
         |                      |
         v                      v
      centroids             centroids
         |                      |
         +----------+-----------+
                    |
                    v
              combine + sort
                    |
                    v
              greedy merge
              (compression)
                    |
                    v
            +-------+-------+
            | Merged digest |
            +---------------+
```

This property is what makes t-digest practical for:

- **MapReduce / Spark:** Each mapper builds a local digest. The reducer
  merges them.
- **Microservices:** Each instance reports a digest. A monitoring
  service merges them to get fleet-wide percentiles.
- **Time-windowed aggregation:** Keep a digest per minute. To get
  the last hour, merge 60 digests.

---

## Summary

The t-digest is built on a simple chain of ideas:

1. Fixed-width histograms waste resolution at the tails.
2. Use variable-width bins: narrow at the tails, wide in the middle.
3. Represent each bin as a centroid (mean, weight).
4. The scale function k(q) controls how wide each bin is allowed to be.
5. The K1 (arcsine) scale function makes k'(q) large at the edges
   (forcing small centroids) and small in the middle (allowing big ones).
6. The compression invariant k(q_R) - k(q_L) <= 1 is enforced by a
   greedy merge pass whenever the buffer fills up.
7. Quantile queries walk the sorted centroids and interpolate.
8. Everything is O(1) amortized per add and O(delta log delta) per merge.
