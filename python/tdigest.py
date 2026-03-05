"""Dunning t-digest for online quantile estimation.

Merging digest variant with K_1 (arcsine) scale function.
Pure Python -- only uses the math standard library.
"""

import math
from dataclasses import dataclass


@dataclass
class Centroid:
    mean: float
    weight: float


class TDigest:
    DEFAULT_DELTA = 100
    BUFFER_FACTOR = 5

    def __init__(self, delta: float = DEFAULT_DELTA) -> None:
        self.delta = float(delta)
        self._centroids: list[Centroid] = []
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
        if not self._buffer and len(self._centroids) <= 1:
            return self

        all_c = self._centroids + self._buffer
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

        self._centroids = new
        return self

    def merge(self, other: "TDigest") -> "TDigest":
        for c in other._flush_for_merge():
            self.add(c.mean, c.weight)
        return self

    # -- queries ----------------------------------------------------------

    def quantile(self, q: float) -> float | None:
        if self._buffer:
            self.compress()
        if not self._centroids:
            return None
        if len(self._centroids) == 1:
            return self._centroids[0].mean

        q = max(0.0, min(1.0, q))
        n = self.total_weight
        target = q * n
        cumulative = 0.0

        for i, c in enumerate(self._centroids):
            mid = cumulative + c.weight / 2.0

            if i == 0:
                if target < c.weight / 2.0:
                    if c.weight == 1:
                        return self.min
                    return self.min + (c.mean - self.min) * (target / (c.weight / 2.0))

            if i == len(self._centroids) - 1:
                if target > n - c.weight / 2.0:
                    if c.weight == 1:
                        return self.max
                    remaining = n - c.weight / 2.0
                    return c.mean + (self.max - c.mean) * ((target - remaining) / (c.weight / 2.0))
                return c.mean

            next_c = self._centroids[i + 1]
            next_mid = cumulative + c.weight + next_c.weight / 2.0

            if target <= next_mid:
                frac = 0.5 if next_mid == mid else (target - mid) / (next_mid - mid)
                return c.mean + frac * (next_c.mean - c.mean)

            cumulative += c.weight

        return self.max

    def cdf(self, x: float) -> float | None:
        if self._buffer:
            self.compress()
        if not self._centroids:
            return None
        if x <= self.min:
            return 0.0
        if x >= self.max:
            return 1.0

        n = self.total_weight
        cumulative = 0.0

        for i, c in enumerate(self._centroids):
            if i == 0:
                if x < c.mean:
                    inner_w = c.weight / 2.0
                    frac = 1.0 if c.mean == self.min else (x - self.min) / (c.mean - self.min)
                    return (inner_w * frac) / n
                elif x == c.mean:
                    return (c.weight / 2.0) / n

            if i == len(self._centroids) - 1:
                if x > c.mean:
                    inner_w = c.weight / 2.0
                    right_w = n - cumulative - c.weight / 2.0
                    frac = 0.0 if self.max == c.mean else (x - c.mean) / (self.max - c.mean)
                    return (cumulative + c.weight / 2.0 + right_w * frac) / n
                else:
                    return (cumulative + c.weight / 2.0) / n

            next_c = self._centroids[i + 1]
            next_cumulative = cumulative + c.weight
            mid = cumulative + c.weight / 2.0
            next_mid = next_cumulative + next_c.weight / 2.0

            if x < next_c.mean:
                if c.mean == next_c.mean:
                    return (mid + (next_mid - mid) / 2.0) / n
                frac = (x - c.mean) / (next_c.mean - c.mean)
                return (mid + frac * (next_mid - mid)) / n

            cumulative += c.weight

        return 1.0

    def centroid_count(self) -> int:
        if self._buffer:
            self.compress()
        return len(self._centroids)

    # -- internals --------------------------------------------------------

    def _flush_for_merge(self) -> list[Centroid]:
        if self._buffer:
            self.compress()
        return self._centroids

    def _k(self, q: float) -> float:
        return (self.delta / (2.0 * math.pi)) * math.asin(2.0 * q - 1.0)

    @staticmethod
    def _merge_into_last(centroids: list[Centroid], c: Centroid) -> None:
        last = centroids[-1]
        new_weight = last.weight + c.weight
        last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight
        last.weight = new_weight
