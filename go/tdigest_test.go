package tdigest

import (
	"math"
	"testing"
)

func TestBasicQuantiles(t *testing.T) {
	td := New(100)
	n := 10000
	for i := 0; i < n; i++ {
		td.Add(float64(i)/float64(n), 1.0)
	}

	tests := []struct {
		q    float64
		want float64
		tol  float64
	}{
		{0.5, 0.5, 0.02},
		{0.1, 0.1, 0.02},
		{0.9, 0.9, 0.02},
		{0.01, 0.01, 0.005},
		{0.99, 0.99, 0.005},
	}

	for _, tt := range tests {
		got := td.Quantile(tt.q)
		if math.Abs(got-tt.want) > tt.tol {
			t.Errorf("Quantile(%v) = %v, want %v +/- %v", tt.q, got, tt.want, tt.tol)
		}
	}
}

func TestBasicCDF(t *testing.T) {
	td := New(100)
	n := 10000
	for i := 0; i < n; i++ {
		td.Add(float64(i)/float64(n), 1.0)
	}

	tests := []struct {
		x    float64
		want float64
		tol  float64
	}{
		{0.5, 0.5, 0.02},
		{0.1, 0.1, 0.02},
		{0.9, 0.9, 0.02},
	}

	for _, tt := range tests {
		got := td.CDF(tt.x)
		if math.Abs(got-tt.want) > tt.tol {
			t.Errorf("CDF(%v) = %v, want %v +/- %v", tt.x, got, tt.want, tt.tol)
		}
	}
}

func TestMerge(t *testing.T) {
	td1 := New(100)
	td2 := New(100)

	for i := 0; i < 5000; i++ {
		td1.Add(float64(i)/10000.0, 1.0)
	}
	for i := 5000; i < 10000; i++ {
		td2.Add(float64(i)/10000.0, 1.0)
	}
	td1.Merge(td2)

	median := td1.Quantile(0.5)
	if math.Abs(median-0.5) > 0.02 {
		t.Errorf("Merged median = %v, want ~0.5", median)
	}
}

func TestEmpty(t *testing.T) {
	td := New(100)
	q := td.Quantile(0.5)
	if !math.IsNaN(q) {
		t.Errorf("Quantile on empty digest should be NaN, got %v", q)
	}
	c := td.CDF(0.5)
	if !math.IsNaN(c) {
		t.Errorf("CDF on empty digest should be NaN, got %v", c)
	}
}

func TestSingleValue(t *testing.T) {
	td := New(100)
	td.Add(42.0, 1.0)
	got := td.Quantile(0.5)
	if got != 42.0 {
		t.Errorf("Quantile(0.5) on single value = %v, want 42.0", got)
	}
}

func TestCentroidCount(t *testing.T) {
	td := New(100)
	for i := 0; i < 10000; i++ {
		td.Add(float64(i), 1.0)
	}
	count := td.CentroidCount()
	if count <= 0 || count > 10000 {
		t.Errorf("CentroidCount = %d, expected between 1 and 10000", count)
	}
	// With delta=100, should compress significantly
	if count > 500 {
		t.Errorf("CentroidCount = %d, expected significant compression with delta=100", count)
	}
}
