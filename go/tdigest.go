// Package tdigest implements the Dunning t-digest algorithm for online
// quantile estimation. This is the merging digest variant with the K1
// (arcsine) scale function: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1).
package tdigest

import (
	"math"
	"sort"
)

const (
	// DefaultDelta is the default compression parameter.
	DefaultDelta = 100.0
	// bufferFactor controls how many unmerged points trigger auto-compress.
	bufferFactor = 5
)

// Centroid represents a cluster of values with a mean and total weight.
type Centroid struct {
	Mean   float64
	Weight float64
}

// TDigest is a merging t-digest data structure.
type TDigest struct {
	delta       float64
	centroids   []Centroid
	buffer      []Centroid
	totalWeight float64
	min         float64
	max         float64
	bufferCap   int
	fenwick     []float64 // Fenwick tree (BIT) over centroid weights for O(log n) quantile queries
}

// New creates a new TDigest with the given compression parameter delta.
func New(delta float64) *TDigest {
	return &TDigest{
		delta:     delta,
		centroids: nil,
		buffer:    nil,
		min:       math.Inf(1),
		max:       math.Inf(-1),
		bufferCap: int(math.Ceil(delta * bufferFactor)),
	}
}

// Add inserts a value with the given weight into the digest.
func (td *TDigest) Add(value, weight float64) {
	td.buffer = append(td.buffer, Centroid{Mean: value, Weight: weight})
	td.totalWeight += weight
	if value < td.min {
		td.min = value
	}
	if value > td.max {
		td.max = value
	}
	if len(td.buffer) >= td.bufferCap {
		td.Compress()
	}
}

// k is the K1 (arcsine) scale function.
func (td *TDigest) k(q float64) float64 {
	return (td.delta / (2.0 * math.Pi)) * math.Asin(2.0*q-1.0)
}

// Compress merges the buffer into the centroid list using the greedy merge algorithm.
func (td *TDigest) Compress() {
	if len(td.buffer) == 0 && len(td.centroids) <= 1 {
		return
	}

	all := make([]Centroid, 0, len(td.centroids)+len(td.buffer))
	all = append(all, td.centroids...)
	all = append(all, td.buffer...)
	td.buffer = td.buffer[:0]

	sort.Slice(all, func(i, j int) bool {
		return all[i].Mean < all[j].Mean
	})

	newCentroids := make([]Centroid, 1, len(all))
	newCentroids[0] = Centroid{Mean: all[0].Mean, Weight: all[0].Weight}
	weightSoFar := 0.0
	n := td.totalWeight

	for i := 1; i < len(all); i++ {
		last := &newCentroids[len(newCentroids)-1]
		proposed := last.Weight + all[i].Weight
		q0 := weightSoFar / n
		q1 := (weightSoFar + proposed) / n

		if proposed <= 1 && len(all) > 1 {
			// Always merge singletons
			mergeIntoLast(last, all[i])
		} else if td.k(q1)-td.k(q0) <= 1.0 {
			mergeIntoLast(last, all[i])
		} else {
			weightSoFar += last.Weight
			newCentroids = append(newCentroids, Centroid{Mean: all[i].Mean, Weight: all[i].Weight})
		}
	}

	td.centroids = newCentroids
	td.fenwickBuild()
}

// fenwickBuild constructs the Fenwick tree (Binary Indexed Tree) from centroid weights.
func (td *TDigest) fenwickBuild() {
	n := len(td.centroids)
	td.fenwick = make([]float64, n+1) // 1-indexed
	for i, c := range td.centroids {
		idx := i + 1
		td.fenwick[idx] += c.Weight
		parent := idx + (idx & -idx)
		if parent <= n {
			td.fenwick[parent] += td.fenwick[idx]
		}
	}
}

// fenwickPrefixSum returns the prefix sum of weights for centroids [0..i] (0-indexed, inclusive).
func (td *TDigest) fenwickPrefixSum(i int) float64 {
	sum := 0.0
	idx := i + 1 // convert to 1-indexed
	for idx > 0 {
		sum += td.fenwick[idx]
		idx -= idx & -idx
	}
	return sum
}

// fenwickFind returns the smallest 0-indexed position i such that
// prefix sum of weights [0..i] >= target. This runs in O(log n).
func (td *TDigest) fenwickFind(target float64) int {
	n := len(td.centroids)
	pos := 0
	// Find the highest bit
	bitMask := 1
	for bitMask <= n {
		bitMask <<= 1
	}
	bitMask >>= 1

	sum := 0.0
	for bitMask > 0 {
		next := pos + bitMask
		if next <= n && sum+td.fenwick[next] < target {
			sum += td.fenwick[next]
			pos = next
		}
		bitMask >>= 1
	}
	// pos is 1-indexed; convert to 0-indexed
	return pos // This is the 0-indexed result: prefix_sum(0..pos-1) < target <= prefix_sum(0..pos)
}

// mergeIntoLast merges centroid c into the last centroid.
func mergeIntoLast(last *Centroid, c Centroid) {
	newWeight := last.Weight + c.Weight
	last.Mean = (last.Mean*last.Weight + c.Mean*c.Weight) / newWeight
	last.Weight = newWeight
}

// Quantile returns the estimated value at quantile q (0 <= q <= 1).
// Uses a Fenwick tree for O(log n) centroid lookup.
func (td *TDigest) Quantile(q float64) float64 {
	if len(td.buffer) > 0 {
		td.Compress()
	}
	if len(td.centroids) == 0 {
		return math.NaN()
	}
	if len(td.centroids) == 1 {
		return td.centroids[0].Mean
	}

	if q < 0.0 {
		q = 0.0
	}
	if q > 1.0 {
		q = 1.0
	}

	n := td.totalWeight
	target := q * n

	// Handle first centroid edge case
	c0 := td.centroids[0]
	if target < c0.Weight/2.0 {
		if c0.Weight == 1 {
			return td.min
		}
		return td.min + (c0.Mean-td.min)*(target/(c0.Weight/2.0))
	}

	// Handle last centroid edge case
	last := td.centroids[len(td.centroids)-1]
	if target > n-last.Weight/2.0 {
		if last.Weight == 1 {
			return td.max
		}
		remaining := n - last.Weight/2.0
		return last.Mean + (td.max-last.Mean)*((target-remaining)/(last.Weight/2.0))
	}

	// Use Fenwick tree to find the centroid index in O(log n).
	// fenwickFind returns the 0-indexed position where cumulative weight first reaches target.
	// We need the centroid i such that cumulative(0..i-1) <= target < cumulative(0..i).
	// But for interpolation we need the pair of centroids that bracket target by midpoints.
	// We search for the centroid whose cumulative weight up to (but not including) it
	// plus half its own weight brackets the target.

	// Find i such that sum of weights[0..i] >= target (using half-weight midpoint logic).
	// The midpoint of centroid i is at cumulative(0..i-1) + weight[i]/2.
	// We want the largest i where midpoint_i <= target.
	// cumulative(0..i-1) = fenwickPrefixSum(i-1), midpoint_i = fenwickPrefixSum(i-1) + centroids[i].Weight/2

	// Use fenwickFind to quickly locate the neighborhood, then do the interpolation.
	// fenwickFind(target) gives us the first index where prefix sum >= target.
	idx := td.fenwickFind(target)

	// Clamp to valid range for interpolation
	if idx >= len(td.centroids)-1 {
		idx = len(td.centroids) - 2
	}

	// Compute cumulative weight before centroid idx using Fenwick tree
	var cumulative float64
	if idx > 0 {
		cumulative = td.fenwickPrefixSum(idx - 1)
	}

	c := td.centroids[idx]
	mid := cumulative + c.Weight/2.0
	nextC := td.centroids[idx+1]
	nextMid := cumulative + c.Weight + nextC.Weight/2.0

	// If target is before this midpoint, step back
	for idx > 0 && target < mid {
		idx--
		if idx > 0 {
			cumulative = td.fenwickPrefixSum(idx - 1)
		} else {
			cumulative = 0
		}
		c = td.centroids[idx]
		mid = cumulative + c.Weight/2.0
		nextC = td.centroids[idx+1]
		nextMid = cumulative + c.Weight + nextC.Weight/2.0
	}

	// Advance if target is beyond nextMid
	for idx < len(td.centroids)-2 && target > nextMid {
		idx++
		if idx > 0 {
			cumulative = td.fenwickPrefixSum(idx - 1)
		} else {
			cumulative = 0
		}
		c = td.centroids[idx]
		mid = cumulative + c.Weight/2.0
		nextC = td.centroids[idx+1]
		nextMid = cumulative + c.Weight + nextC.Weight/2.0
	}

	if idx == len(td.centroids)-1 {
		return c.Mean
	}

	frac := 0.5
	if nextMid != mid {
		frac = (target - mid) / (nextMid - mid)
	}
	return c.Mean + frac*(nextC.Mean-c.Mean)
}

// CDF returns the estimated cumulative distribution function value at x.
// Uses sort.Search for O(log n) position finding among centroid means.
func (td *TDigest) CDF(x float64) float64 {
	if len(td.buffer) > 0 {
		td.Compress()
	}
	if len(td.centroids) == 0 {
		return math.NaN()
	}
	if x <= td.min {
		return 0.0
	}
	if x >= td.max {
		return 1.0
	}

	n := td.totalWeight
	nc := len(td.centroids)

	// Use sort.Search to find the first centroid with Mean > x in O(log n).
	// idx is the first centroid whose mean is strictly greater than x.
	idx := sort.Search(nc, func(i int) bool {
		return td.centroids[i].Mean > x
	})

	// Handle first centroid edge case: x < centroids[0].Mean
	if idx == 0 {
		c := td.centroids[0]
		innerW := c.Weight / 2.0
		frac := 1.0
		if c.Mean != td.min {
			frac = (x - td.min) / (c.Mean - td.min)
		}
		return (innerW * frac) / n
	}

	// The centroid at idx-1 has Mean <= x.
	i := idx - 1

	// Compute cumulative weight before centroid i using the Fenwick tree.
	var cumulative float64
	if i > 0 {
		cumulative = td.fenwickPrefixSum(i - 1)
	}
	c := td.centroids[i]

	// Handle last centroid edge case
	if i == nc-1 {
		if x > c.Mean {
			innerW := c.Weight / 2.0
			rightW := n - cumulative - innerW
			frac := 0.0
			if td.max != c.Mean {
				frac = (x - c.Mean) / (td.max - c.Mean)
			}
			return (cumulative + c.Weight/2.0 + rightW*frac) / n
		}
		return (cumulative + c.Weight/2.0) / n
	}

	// x == c.Mean exactly (or between c.Mean and next mean)
	mid := cumulative + c.Weight/2.0
	nextC := td.centroids[i+1]
	nextCumulative := cumulative + c.Weight
	nextMid := nextCumulative + nextC.Weight/2.0

	if x < nextC.Mean {
		if c.Mean == nextC.Mean {
			return (mid + (nextMid-mid)/2.0) / n
		}
		frac := (x - c.Mean) / (nextC.Mean - c.Mean)
		return (mid + frac*(nextMid-mid)) / n
	}

	return 1.0
}

// Merge incorporates all centroids from another TDigest into this one.
func (td *TDigest) Merge(other *TDigest) {
	if len(other.buffer) > 0 {
		other.Compress()
	}
	for _, c := range other.centroids {
		td.Add(c.Mean, c.Weight)
	}
}

// CentroidCount returns the number of centroids after compressing.
func (td *TDigest) CentroidCount() int {
	if len(td.buffer) > 0 {
		td.Compress()
	}
	return len(td.centroids)
}
