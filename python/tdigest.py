"""Dunning t-digest for online quantile estimation.

Merging digest variant with K_1 (arcsine) scale function.
Pure Python -- only uses the math standard library.

Uses an array-backed 2-3-4 tree with four-component monoidal measures
for O(log n) quantile lookups, CDF queries, and neighbor finding.
"""

import math
from dataclasses import dataclass

from tree234 import Tree234


@dataclass
class Centroid:
    mean: float
    weight: float


class TdMeasure:
    """Four-component monoidal measure for t-digest centroids."""
    __slots__ = ['weight', 'count', 'max_mean', 'mean_weight_sum']

    def __init__(self, w=0.0, c=0, mm=float('-inf'), mws=0.0):
        self.weight = w
        self.count = c
        self.max_mean = mm
        self.mean_weight_sum = mws


def _centroid_measure(c):
    """Measure for a single centroid key."""
    return TdMeasure(c.weight, 1, c.mean, c.mean * c.weight)


def _combine(a, b):
    """Monoidal combine of two measures."""
    return TdMeasure(
        a.weight + b.weight,
        a.count + b.count,
        max(a.max_mean, b.max_mean),
        a.mean_weight_sum + b.mean_weight_sum,
    )


def _identity():
    """Monoidal identity."""
    return TdMeasure()


def _compare_centroids(a, b):
    """Compare centroids by mean, breaking ties by weight then id."""
    if a.mean < b.mean:
        return -1
    if a.mean > b.mean:
        return 1
    # Tie-break by weight for stability
    if a.weight < b.weight:
        return -1
    if a.weight > b.weight:
        return 1
    return 0


def _weight_of(measure):
    """Extract weight from a TdMeasure."""
    return measure.weight


class TDigest:
    DEFAULT_DELTA = 100
    BUFFER_FACTOR = 5

    def __init__(self, delta: float = DEFAULT_DELTA) -> None:
        self.delta = float(delta)
        self._tree = Tree234(_centroid_measure, _combine, _identity, _compare_centroids)
        self._buffer: list[Centroid] = []
        self.total_weight = 0.0
        self.min = math.inf
        self.max = -math.inf
        self._buffer_cap = math.ceil(self.delta * self.BUFFER_FACTOR)

    # -- mutation ---------------------------------------------------------

    def add(self, value: float, weight: float = 1.0) -> "TDigest":
        value = float(value)
        weight = float(weight)
        self._buffer.append(Centroid(value, weight))
        self.total_weight += weight
        if value < self.min:
            self.min = value
        if value > self.max:
            self.max = value
        if len(self._buffer) >= self._buffer_cap:
            self.compress()
        return self

    def compress(self) -> "TDigest":
        if not self._buffer and self._tree.size() <= 1:
            return self

        all_c = self._tree.to_list() + self._buffer
        self._buffer = []
        all_c.sort(key=lambda c: c.mean)

        new = [Centroid(all_c[0].mean, all_c[0].weight)]
        weight_so_far = 0.0
        n = self.total_weight

        for i in range(1, len(all_c)):
            proposed = new[-1].weight + all_c[i].weight
            q0 = weight_so_far / n
            q1 = (weight_so_far + proposed) / n

            if proposed <= 1 and len(all_c) > 1:
                self._merge_into_last(new, all_c[i])
            elif self._k(q1) - self._k(q0) <= 1.0:
                self._merge_into_last(new, all_c[i])
            else:
                weight_so_far += new[-1].weight
                new.append(Centroid(all_c[i].mean, all_c[i].weight))

        self._tree.clear()
        for c in new:
            self._tree.insert(c)
        return self

    def merge(self, other: "TDigest") -> "TDigest":
        for c in other._flush_for_merge():
            self.add(c.mean, c.weight)
        return self

    # -- queries ----------------------------------------------------------

    def quantile(self, q: float) -> float | None:
        if self._buffer:
            self.compress()
        count = self._tree.size()
        if count == 0:
            return None

        centroids = self._tree.to_list()
        if count == 1:
            return centroids[0].mean

        q = max(0.0, min(1.0, q))
        n = self.total_weight
        target = q * n

        # Use find_by_weight for O(log n) lookup
        result = self._tree.find_by_weight(target, _weight_of)
        if result is None:
            return None

        c, cumulative, i = result

        if i == 0:
            if target < c.weight / 2.0:
                if c.weight == 1:
                    return self.min
                return self.min + (c.mean - self.min) * (target / (c.weight / 2.0))

        if i == count - 1:
            if target > n - c.weight / 2.0:
                if c.weight == 1:
                    return self.max
                remaining = n - c.weight / 2.0
                return c.mean + (self.max - c.mean) * ((target - remaining) / (c.weight / 2.0))
            return c.mean

        mid = cumulative + c.weight / 2.0
        # Need next centroid - get it from centroids list
        next_c = centroids[i + 1]
        next_mid = cumulative + c.weight + next_c.weight / 2.0

        if target <= next_mid:
            frac = 0.5 if next_mid == mid else (target - mid) / (next_mid - mid)
            return c.mean + frac * (next_c.mean - c.mean)

        return self.max

    def cdf(self, x: float) -> float | None:
        if self._buffer:
            self.compress()
        count = self._tree.size()
        if count == 0:
            return None
        if x <= self.min:
            return 0.0
        if x >= self.max:
            return 1.0

        n = self.total_weight
        centroids = self._tree.to_list()

        # Binary search for position among centroid means
        # Find leftmost centroid whose mean >= x
        lo, hi = 0, len(centroids)
        while lo < hi:
            mid = (lo + hi) // 2
            if centroids[mid].mean < x:
                lo = mid + 1
            else:
                hi = mid
        pos = lo

        # Compute cumulative weight before pos using a running sum
        # (we already have the centroids list)
        cum_weights = [0.0] * (len(centroids) + 1)
        for j in range(len(centroids)):
            cum_weights[j + 1] = cum_weights[j] + centroids[j].weight

        if pos == 0:
            c = centroids[0]
            inner_w = c.weight / 2.0
            frac = 1.0 if c.mean == self.min else (x - self.min) / (c.mean - self.min)
            return (inner_w * frac) / n

        if pos >= len(centroids):
            c = centroids[-1]
            cumulative = cum_weights[len(centroids) - 1]
            inner_w = c.weight / 2.0
            right_w = n - cumulative - c.weight / 2.0
            frac = 0.0 if self.max == c.mean else (x - c.mean) / (self.max - c.mean)
            return (cumulative + c.weight / 2.0 + right_w * frac) / n

        i = pos - 1
        c = centroids[i]
        next_c = centroids[pos]
        cumulative = cum_weights[i]

        if i == 0 and x < c.mean:
            inner_w = c.weight / 2.0
            frac = 1.0 if c.mean == self.min else (x - self.min) / (c.mean - self.min)
            return (inner_w * frac) / n
        if i == 0 and x == c.mean:
            return (c.weight / 2.0) / n

        if pos == len(centroids) - 1 and x > next_c.mean:
            next_cumulative = cumulative + c.weight
            inner_w = next_c.weight / 2.0
            right_w = n - next_cumulative - next_c.weight / 2.0
            frac = 0.0 if self.max == next_c.mean else (x - next_c.mean) / (self.max - next_c.mean)
            return (next_cumulative + next_c.weight / 2.0 + right_w * frac) / n

        next_cumulative = cumulative + c.weight
        mid_w = cumulative + c.weight / 2.0
        next_mid = next_cumulative + next_c.weight / 2.0

        if x < next_c.mean:
            if c.mean == next_c.mean:
                return (mid_w + (next_mid - mid_w) / 2.0) / n
            frac = (x - c.mean) / (next_c.mean - c.mean)
            return (mid_w + frac * (next_mid - mid_w)) / n

        return next_mid / n

    def centroid_count(self) -> int:
        if self._buffer:
            self.compress()
        return self._tree.size()

    # -- internals --------------------------------------------------------

    def _flush_for_merge(self) -> list[Centroid]:
        if self._buffer:
            self.compress()
        return self._tree.to_list()

    def _k(self, q: float) -> float:
        return (self.delta / (2.0 * math.pi)) * math.asin(2.0 * q - 1.0)

    @staticmethod
    def _merge_into_last(centroids: list[Centroid], c: Centroid) -> None:
        last = centroids[-1]
        new_weight = last.weight + c.weight
        last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight
        last.weight = new_weight
