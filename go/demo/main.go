package main

import (
	"fmt"
	"math"

	"github.com/NadiaYvette/t-digest/go"
)

func main() {
	td := tdigest.New(100)

	// Insert 10000 uniformly spaced values in [0, 1)
	n := 10000
	for i := 0; i < n; i++ {
		td.Add(float64(i)/float64(n), 1.0)
	}

	fmt.Printf("T-Digest demo: %d uniform values in [0, 1)\n", n)
	fmt.Printf("Centroids: %d\n\n", td.CentroidCount())

	fmt.Println("Quantile estimates (expected ~ q for uniform):")
	quantiles := []float64{0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999}
	for _, q := range quantiles {
		est := td.Quantile(q)
		fmt.Printf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, math.Abs(est-q))
	}

	fmt.Println("\nCDF estimates (expected ~ x for uniform):")
	for _, x := range quantiles {
		est := td.CDF(x)
		fmt.Printf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, math.Abs(est-x))
	}

	// Test merge
	td1 := tdigest.New(100)
	td2 := tdigest.New(100)
	for i := 0; i < 5000; i++ {
		td1.Add(float64(i)/10000.0, 1.0)
	}
	for i := 5000; i < 10000; i++ {
		td2.Add(float64(i)/10000.0, 1.0)
	}
	td1.Merge(td2)

	fmt.Println("\nAfter merge:")
	fmt.Printf("  median=%.6f (expected ~0.5)\n", td1.Quantile(0.5))
	fmt.Printf("  p99   =%.6f (expected ~0.99)\n", td1.Quantile(0.99))
}
