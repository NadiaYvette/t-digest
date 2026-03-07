# Dunning t-digest for online quantile estimation.
# Merging digest variant with K_1 (arcsine) scale function.
# Uses an array-backed 2-3-4 tree with monoidal measures.

import math, algorithm
import tree234

const
  DefaultDelta* = 100.0
  BufferFactor = 5

type
  Centroid* = object
    mean*: float
    weight*: float

  TdMeasure* = object
    weight*: float
    count*: int
    maxMean*: float
    meanWeightSum*: float

  TDigest* = ref object
    delta*: float
    tree: Tree234[Centroid, TdMeasure]
    buffer: seq[Centroid]
    totalWeight*: float
    minVal*: float
    maxVal*: float
    bufferCap: int

proc centroidMeasure(c: Centroid): TdMeasure {.noSideEffect.} =
  TdMeasure(weight: c.weight, count: 1, maxMean: c.mean,
      meanWeightSum: c.mean * c.weight)

proc combineMeasure(a, b: TdMeasure): TdMeasure {.noSideEffect.} =
  TdMeasure(weight: a.weight + b.weight, count: a.count + b.count,
      maxMean: max(a.maxMean, b.maxMean),
      meanWeightSum: a.meanWeightSum + b.meanWeightSum)

proc identityMeasure(): TdMeasure {.noSideEffect.} =
  TdMeasure(weight: 0, count: 0, maxMean: NegInf, meanWeightSum: 0)

proc compareCentroid(a, b: Centroid): int {.noSideEffect.} =
  cmp(a.mean, b.mean)

proc newTDigest*(delta: float = DefaultDelta): TDigest =
  TDigest(
    delta: delta,
    tree: newTree234[Centroid, TdMeasure](
      centroidMeasure, combineMeasure, identityMeasure, compareCentroid),
    buffer: @[],
    totalWeight: 0.0,
    minVal: Inf,
    maxVal: NegInf,
    bufferCap: int(ceil(delta * float(BufferFactor)))
  )

proc k(td: TDigest, q: float): float =
  (td.delta / (2.0 * PI)) * arcsin(2.0 * q - 1.0)

proc compress*(td: TDigest) =
  if td.buffer.len == 0 and td.tree.size() <= 1:
    return

  # Collect all centroids from tree and buffer
  var all: seq[Centroid] = @[]
  td.tree.collect(all)
  all.add(td.buffer)
  td.buffer.setLen(0)
  all.sort(proc(a, b: Centroid): int = cmp(a.mean, b.mean))

  var newCentroids = @[Centroid(mean: all[0].mean, weight: all[0].weight)]
  var weightSoFar = 0.0
  let n = td.totalWeight

  for i in 1 ..< all.len:
    let proposed = newCentroids[^1].weight + all[i].weight
    let q0 = weightSoFar / n
    let q1 = (weightSoFar + proposed) / n

    if (proposed <= 1.0 and all.len > 1) or (td.k(q1) - td.k(q0) <= 1.0):
      let last = addr newCentroids[^1]
      let newWeight = last.weight + all[i].weight
      last.mean = (last.mean * last.weight + all[i].mean * all[i].weight) / newWeight
      last.weight = newWeight
    else:
      weightSoFar += newCentroids[^1].weight
      newCentroids.add(Centroid(mean: all[i].mean, weight: all[i].weight))

  # Rebuild tree from sorted merged centroids
  td.tree.buildFromSorted(newCentroids)

proc add*(td: TDigest, value: float, weight: float = 1.0) =
  td.buffer.add(Centroid(mean: value, weight: weight))
  td.totalWeight += weight
  if value < td.minVal: td.minVal = value
  if value > td.maxVal: td.maxVal = value
  if td.buffer.len >= td.bufferCap:
    td.compress()

proc quantile*(td: TDigest, q: float): float =
  if td.buffer.len > 0: td.compress()
  if td.tree.size() == 0: return NaN
  if td.tree.size() == 1:
    var centroids: seq[Centroid] = @[]
    td.tree.collect(centroids)
    return centroids[0].mean

  let q = clamp(q, 0.0, 1.0)
  let n = td.totalWeight
  let target = q * n

  # Collect centroids for interpolation
  var centroids: seq[Centroid] = @[]
  td.tree.collect(centroids)

  var cumulative = 0.0
  for i in 0 ..< centroids.len:
    let c = centroids[i]
    let mid = cumulative + c.weight / 2.0

    # Left boundary
    if i == 0 and target < c.weight / 2.0:
      if c.weight == 1.0: return td.minVal
      return td.minVal + (c.mean - td.minVal) * (target / (c.weight / 2.0))

    # Right boundary
    if i == centroids.len - 1:
      if target > n - c.weight / 2.0:
        if c.weight == 1.0: return td.maxVal
        let remaining = n - c.weight / 2.0
        return c.mean + (td.maxVal - c.mean) * ((target - remaining) / (c.weight / 2.0))
      return c.mean

    # Interpolation between centroids
    let nextC = centroids[i + 1]
    let nextMid = cumulative + c.weight + nextC.weight / 2.0

    if target <= nextMid:
      let frac = if nextMid == mid: 0.5
                 else: (target - mid) / (nextMid - mid)
      return c.mean + frac * (nextC.mean - c.mean)

    cumulative += c.weight

  return td.maxVal

proc cdf*(td: TDigest, x: float): float =
  if td.buffer.len > 0: td.compress()
  if td.tree.size() == 0: return NaN
  if x <= td.minVal: return 0.0
  if x >= td.maxVal: return 1.0

  let n = td.totalWeight
  var cumulative = 0.0

  # Collect centroids for interpolation
  var centroids: seq[Centroid] = @[]
  td.tree.collect(centroids)

  for i in 0 ..< centroids.len:
    let c = centroids[i]

    if i == 0:
      if x < c.mean:
        let innerW = c.weight / 2.0
        let frac = if c.mean == td.minVal: 1.0
                   else: (x - td.minVal) / (c.mean - td.minVal)
        return (innerW * frac) / n
      elif x == c.mean:
        return (c.weight / 2.0) / n

    if i == centroids.len - 1:
      if x > c.mean:
        let rightW = n - cumulative - c.weight / 2.0
        let frac = if td.maxVal == c.mean: 0.0
                   else: (x - c.mean) / (td.maxVal - c.mean)
        return (cumulative + c.weight / 2.0 + rightW * frac) / n
      else:
        return (cumulative + c.weight / 2.0) / n

    let midVal = cumulative + c.weight / 2.0
    let nextC = centroids[i + 1]
    let nextCumulative = cumulative + c.weight
    let nextMid = nextCumulative + nextC.weight / 2.0

    if x < nextC.mean:
      if c.mean == nextC.mean:
        return (midVal + (nextMid - midVal) / 2.0) / n
      let frac = (x - c.mean) / (nextC.mean - c.mean)
      return (midVal + frac * (nextMid - midVal)) / n

    cumulative += c.weight

  return 1.0

proc merge*(td: TDigest, other: TDigest) =
  if other.buffer.len > 0: other.compress()
  var otherCentroids: seq[Centroid] = @[]
  other.tree.collect(otherCentroids)
  for c in otherCentroids:
    td.add(c.mean, c.weight)

proc centroidCount*(td: TDigest): int =
  if td.buffer.len > 0: td.compress()
  td.tree.size()
