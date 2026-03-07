// Package tdigest implements the Dunning t-digest algorithm for online
// quantile estimation. This is the merging digest variant with the K1
// (arcsine) scale function: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1).
//
// Internally, centroids are stored in an array-backed 2-3-4 tree with a
// four-component monoidal measure (Weight, Count, MaxMean, MeanWeightSum).
package tdigest

import (
	"math"
)

const (
	// DefaultDelta is the default compression parameter.
	DefaultDelta = 100.0
	// bufferFactor controls how many unmerged points trigger auto-compress.
	bufferFactor = 3
)

// Centroid represents a cluster of values with a mean and total weight.
type Centroid struct {
	Mean   float64
	Weight float64
}

// TdMeasure is the four-component monoidal measure cached in 2-3-4 tree nodes.
type TdMeasure struct {
	Weight        float64 // sum of weights in subtree
	Count         int     // number of centroids in subtree
	MaxMean       float64 // maximum mean in subtree
	MeanWeightSum float64 // sum of mean*weight in subtree
}

// centroidOps provides the MeasureOps for Centroid/TdMeasure.
var centroidOps = MeasureOps[Centroid, TdMeasure]{
	Measure: func(c Centroid) TdMeasure {
		return TdMeasure{c.Weight, 1, c.Mean, c.Mean * c.Weight}
	},
	Combine: func(a, b TdMeasure) TdMeasure {
		return TdMeasure{
			Weight:        a.Weight + b.Weight,
			Count:         a.Count + b.Count,
			MaxMean:       math.Max(a.MaxMean, b.MaxMean),
			MeanWeightSum: a.MeanWeightSum + b.MeanWeightSum,
		}
	},
	Identity: func() TdMeasure {
		return TdMeasure{0, 0, math.Inf(-1), 0}
	},
	Compare: func(a, b Centroid) int {
		if a.Mean < b.Mean {
			return -1
		}
		if a.Mean > b.Mean {
			return 1
		}
		return 0
	},
}

// TDigest is a merging t-digest data structure backed by a 2-3-4 tree.
type TDigest struct {
	delta         float64
	tree          *Tree234[Centroid, TdMeasure]
	totalWeight   float64
	min           float64
	max           float64
	maxCentroids  int
}

// New creates a new TDigest with the given compression parameter delta.
func New(delta float64) *TDigest {
	return &TDigest{
		delta:        delta,
		tree:         NewTree234[Centroid, TdMeasure](centroidOps),
		min:          math.Inf(1),
		max:          math.Inf(-1),
		maxCentroids: int(math.Ceil(delta)),
	}
}

// k is the K1 (arcsine) scale function.
func (td *TDigest) k(q float64) float64 {
	return (td.delta / (2.0 * math.Pi)) * math.Asin(2.0*q-1.0)
}

// Add inserts a value with the given weight into the digest.
// New values are inserted directly into the 2-3-4 tree. When the tree
// exceeds bufferFactor * delta centroids, Compress is called to merge
// centroids according to the K1 scale function.
func (td *TDigest) Add(value, weight float64) {
	td.totalWeight += weight
	if value < td.min {
		td.min = value
	}
	if value > td.max {
		td.max = value
	}

	td.tree.Insert(Centroid{Mean: value, Weight: weight})

	// Auto-compress when tree gets too large
	if td.tree.Size() > bufferFactor*td.maxCentroids {
		td.Compress()
	}
}

// Compress merges centroids using the greedy K1 merge algorithm.
func (td *TDigest) Compress() {
	if td.tree.Size() <= 1 {
		return
	}

	all := td.tree.ToSlice()
	// all is already sorted by mean (in-order traversal)

	td.tree.Clear()

	// Greedy merge
	curMean := all[0].Mean
	curWeight := all[0].Weight
	weightSoFar := 0.0
	n := td.totalWeight

	for i := 1; i < len(all); i++ {
		proposed := curWeight + all[i].Weight
		q0 := weightSoFar / n
		q1 := (weightSoFar + proposed) / n

		if proposed <= 1 && len(all) > 1 {
			// Always merge singletons
			newWeight := curWeight + all[i].Weight
			curMean = (curMean*curWeight + all[i].Mean*all[i].Weight) / newWeight
			curWeight = newWeight
		} else if td.k(q1)-td.k(q0) <= 1.0 {
			newWeight := curWeight + all[i].Weight
			curMean = (curMean*curWeight + all[i].Mean*all[i].Weight) / newWeight
			curWeight = newWeight
		} else {
			td.tree.Insert(Centroid{Mean: curMean, Weight: curWeight})
			weightSoFar += curWeight
			curMean = all[i].Mean
			curWeight = all[i].Weight
		}
	}
	// Insert the last accumulated centroid
	td.tree.Insert(Centroid{Mean: curMean, Weight: curWeight})
}

// Quantile returns the estimated value at quantile q (0 <= q <= 1).
func (td *TDigest) Quantile(q float64) float64 {
	if td.tree.Size() == 0 {
		return math.NaN()
	}
	if td.tree.Size() == 1 {
		all := td.tree.ToSlice()
		return all[0].Mean
	}

	if q < 0.0 {
		q = 0.0
	}
	if q > 1.0 {
		q = 1.0
	}

	n := td.totalWeight
	target := q * n
	nc := td.tree.Size()
	all := td.tree.ToSlice()

	// Handle first centroid edge case
	c0 := all[0]
	if target < c0.Weight/2.0 {
		if c0.Weight == 1 {
			return td.min
		}
		return td.min + (c0.Mean-td.min)*(target/(c0.Weight/2.0))
	}

	// Handle last centroid edge case
	last := all[nc-1]
	if target > n-last.Weight/2.0 {
		if last.Weight == 1 {
			return td.max
		}
		remaining := n - last.Weight/2.0
		return last.Mean + (td.max-last.Mean)*((target-remaining)/(last.Weight/2.0))
	}

	// Linear scan for interpolation using midpoints
	cumulative := 0.0
	for i := 0; i < nc-1; i++ {
		c := all[i]
		mid := cumulative + c.Weight/2.0
		nextC := all[i+1]
		nextMid := cumulative + c.Weight + nextC.Weight/2.0

		if target >= mid && target <= nextMid {
			frac := 0.5
			if nextMid != mid {
				frac = (target - mid) / (nextMid - mid)
			}
			return c.Mean + frac*(nextC.Mean-c.Mean)
		}
		cumulative += c.Weight
	}

	return all[nc-1].Mean
}

// CDF returns the estimated cumulative distribution function value at x.
func (td *TDigest) CDF(x float64) float64 {
	if td.tree.Size() == 0 {
		return math.NaN()
	}
	if x <= td.min {
		return 0.0
	}
	if x >= td.max {
		return 1.0
	}

	n := td.totalWeight
	nc := td.tree.Size()
	all := td.tree.ToSlice()

	// Handle x < first centroid mean
	if x < all[0].Mean {
		c := all[0]
		innerW := c.Weight / 2.0
		frac := 1.0
		if c.Mean != td.min {
			frac = (x - td.min) / (c.Mean - td.min)
		}
		return (innerW * frac) / n
	}

	// Find the centroid pair that brackets x
	cumulative := 0.0
	for i := 0; i < nc; i++ {
		c := all[i]

		if i == nc-1 {
			// Last centroid
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

		nextC := all[i+1]
		mid := cumulative + c.Weight/2.0
		nextCumulative := cumulative + c.Weight
		nextMid := nextCumulative + nextC.Weight/2.0

		if x >= c.Mean && x < nextC.Mean {
			if c.Mean == nextC.Mean {
				return (mid + (nextMid-mid)/2.0) / n
			}
			frac := (x - c.Mean) / (nextC.Mean - c.Mean)
			return (mid + frac*(nextMid-mid)) / n
		}

		cumulative += c.Weight
	}

	return 1.0
}

// Merge incorporates all centroids from another TDigest into this one.
func (td *TDigest) Merge(other *TDigest) {
	otherAll := other.tree.ToSlice()
	for _, c := range otherAll {
		td.Add(c.Mean, c.Weight)
	}
}

// CentroidCount returns the number of centroids after compressing.
func (td *TDigest) CentroidCount() int {
	return td.tree.Size()
}
