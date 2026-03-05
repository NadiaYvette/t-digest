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
}

// mergeIntoLast merges centroid c into the last centroid.
func mergeIntoLast(last *Centroid, c Centroid) {
	newWeight := last.Weight + c.Weight
	last.Mean = (last.Mean*last.Weight + c.Mean*c.Weight) / newWeight
	last.Weight = newWeight
}

// Quantile returns the estimated value at quantile q (0 <= q <= 1).
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
	cumulative := 0.0

	for i, c := range td.centroids {
		if i == 0 {
			if target < c.Weight/2.0 {
				if c.Weight == 1 {
					return td.min
				}
				return td.min + (c.Mean-td.min)*(target/(c.Weight/2.0))
			}
		}

		if i == len(td.centroids)-1 {
			if target > n-c.Weight/2.0 {
				if c.Weight == 1 {
					return td.max
				}
				remaining := n - c.Weight/2.0
				return c.Mean + (td.max-c.Mean)*((target-remaining)/(c.Weight/2.0))
			}
			return c.Mean
		}

		mid := cumulative + c.Weight/2.0
		nextC := td.centroids[i+1]
		nextMid := cumulative + c.Weight + nextC.Weight/2.0

		if target <= nextMid {
			frac := 0.5
			if nextMid != mid {
				frac = (target - mid) / (nextMid - mid)
			}
			return c.Mean + frac*(nextC.Mean-c.Mean)
		}

		cumulative += c.Weight
	}

	return td.max
}

// CDF returns the estimated cumulative distribution function value at x.
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
	cumulative := 0.0

	for i, c := range td.centroids {
		if i == 0 {
			if x < c.Mean {
				innerW := c.Weight / 2.0
				frac := 1.0
				if c.Mean != td.min {
					frac = (x - td.min) / (c.Mean - td.min)
				}
				return (innerW * frac) / n
			} else if x == c.Mean {
				return (c.Weight / 2.0) / n
			}
		}

		if i == len(td.centroids)-1 {
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

		cumulative += c.Weight
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
