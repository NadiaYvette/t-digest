# Introduction

## What Is a T-Digest?

**For a five-year-old:** Imagine you have a huge jar of marbles of different
sizes. You want to know how big the "almost biggest" marble is without lining
them all up. A t-digest is like a clever friend who watches you drop marbles
into the jar one at a time and keeps a little notebook with just enough notes
to answer that question really well -- even though they never wrote down every
single marble.

**For a programmer:** A t-digest is an online, mergeable data structure that
approximates the quantile function (inverse CDF) of a dataset in bounded
memory. You feed it values one at a time -- or in batches, or from parallel
workers -- and it lets you ask questions like "what is the 99th-percentile
latency?" with high accuracy, especially in the tails. It uses roughly
O(delta) space regardless of how many values you have seen, where delta
(the compression parameter) is typically 100--200.

**For a statistician:** The t-digest maintains a sorted sequence of weighted
centroids that collectively approximate the empirical CDF of the ingested
data. A scale function -- by default K1, the arcsine function -- maps
quantile space to "index" space in such a way that centroids near q = 0
and q = 1 are kept small (preserving tail accuracy) while centroids near
the median may grow large (saving space). The key invariant is that for
any centroid spanning the quantile range [q_L, q_R], we have
k(q_R) - k(q_L) <= 1. This yields worst-case relative error that
decreases as q approaches 0 or 1, which is exactly the regime where
accurate quantile estimation matters most.

## Why Use a T-Digest?

- **Streaming data.** Values arrive one at a time. You cannot store them all
  and sort them later. A t-digest processes each value in amortized O(1)
  time and never needs to revisit old data.

- **Bounded memory.** No matter how many values you ingest -- millions,
  billions -- the digest stays small. With delta = 100 you will have at
  most a few hundred centroids, occupying a few kilobytes.

- **Tail accuracy.** Most quantile sketches give uniform relative error
  across all quantiles. The t-digest deliberately spends more of its
  budget on the extremes, so p99 and p99.9 estimates are much more
  accurate than a uniform sketch of the same size.

- **Mergeability.** Two t-digests can be merged in O(delta log delta) time.
  This is ideal for distributed systems: each node builds a local digest,
  a coordinator merges them all, and the result is as if you had seen every
  value on one machine.

## Quick Example (Pseudocode)

```
td = new TDigest(delta=100)

for each request_latency in stream:
    td.add(request_latency)

# "What latency is slower than 99% of requests?"
p99 = td.quantile(0.99)

# "What fraction of requests are faster than 200ms?"
fraction = td.cdf(200.0)

# Merge digests from two servers
combined = merge(server_a.digest, server_b.digest)
```
