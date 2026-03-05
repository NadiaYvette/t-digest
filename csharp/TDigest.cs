// Dunning t-digest for online quantile estimation.
// Merging digest variant with K1 (arcsine) scale function.

using System;
using System.Collections.Generic;

namespace TDigestLib
{
    public class TDigest
    {
        private struct Centroid
        {
            public double Mean;
            public double Weight;

            public Centroid(double mean, double weight)
            {
                Mean = mean;
                Weight = weight;
            }
        }

        private const double DefaultDelta = 100;
        private const int BufferFactor = 5;

        private readonly double _delta;
        private List<Centroid> _centroids = new List<Centroid>();
        private List<Centroid> _buffer = new List<Centroid>();
        private double _totalWeight;
        private double _min = double.PositiveInfinity;
        private double _max = double.NegativeInfinity;
        private readonly int _bufferCap;

        public double Delta => _delta;
        public double TotalWeight => _totalWeight;
        public double Min => _min;
        public double Max => _max;

        public TDigest(double delta = DefaultDelta)
        {
            _delta = delta;
            _bufferCap = (int)Math.Ceiling(delta * BufferFactor);
        }

        public void Add(double value, double weight = 1.0)
        {
            _buffer.Add(new Centroid(value, weight));
            _totalWeight += weight;
            if (value < _min) _min = value;
            if (value > _max) _max = value;
            if (_buffer.Count >= _bufferCap)
                Compress();
        }

        public void Compress()
        {
            if (_buffer.Count == 0 && _centroids.Count <= 1) return;

            var all = new List<Centroid>(_centroids.Count + _buffer.Count);
            all.AddRange(_centroids);
            all.AddRange(_buffer);
            _buffer.Clear();
            all.Sort((a, b) => a.Mean.CompareTo(b.Mean));

            var newCentroids = new List<Centroid> { all[0] };
            double weightSoFar = 0.0;
            double n = _totalWeight;

            for (int i = 1; i < all.Count; i++)
            {
                double proposed = newCentroids[newCentroids.Count - 1].Weight + all[i].Weight;
                double q0 = weightSoFar / n;
                double q1 = (weightSoFar + proposed) / n;

                if ((proposed <= 1 && all.Count > 1) || (K(q1) - K(q0) <= 1.0))
                {
                    MergeIntoLast(newCentroids, all[i]);
                }
                else
                {
                    weightSoFar += newCentroids[newCentroids.Count - 1].Weight;
                    newCentroids.Add(all[i]);
                }
            }

            _centroids = newCentroids;
        }

        public double? Quantile(double q)
        {
            if (_buffer.Count > 0) Compress();
            if (_centroids.Count == 0) return null;
            if (_centroids.Count == 1) return _centroids[0].Mean;

            if (q < 0.0) q = 0.0;
            if (q > 1.0) q = 1.0;

            double n = _totalWeight;
            double target = q * n;
            double cumulative = 0.0;

            for (int i = 0; i < _centroids.Count; i++)
            {
                var c = _centroids[i];

                if (i == 0)
                {
                    if (target < c.Weight / 2.0)
                    {
                        if (c.Weight == 1) return _min;
                        return _min + (c.Mean - _min) * (target / (c.Weight / 2.0));
                    }
                }

                if (i == _centroids.Count - 1)
                {
                    if (target > n - c.Weight / 2.0)
                    {
                        if (c.Weight == 1) return _max;
                        double remaining = n - c.Weight / 2.0;
                        return c.Mean + (_max - c.Mean) * ((target - remaining) / (c.Weight / 2.0));
                    }
                    return c.Mean;
                }

                double mid = cumulative + c.Weight / 2.0;
                var nextC = _centroids[i + 1];
                double nextMid = cumulative + c.Weight + nextC.Weight / 2.0;

                if (target <= nextMid)
                {
                    double frac = (nextMid == mid) ? 0.5 : (target - mid) / (nextMid - mid);
                    return c.Mean + frac * (nextC.Mean - c.Mean);
                }

                cumulative += c.Weight;
            }

            return _max;
        }

        public double? Cdf(double x)
        {
            if (_buffer.Count > 0) Compress();
            if (_centroids.Count == 0) return null;
            if (x <= _min) return 0.0;
            if (x >= _max) return 1.0;

            double n = _totalWeight;
            double cumulative = 0.0;

            for (int i = 0; i < _centroids.Count; i++)
            {
                var c = _centroids[i];

                if (i == 0)
                {
                    if (x < c.Mean)
                    {
                        double innerW = c.Weight / 2.0;
                        double frac = (c.Mean == _min) ? 1.0 : (x - _min) / (c.Mean - _min);
                        return (innerW * frac) / n;
                    }
                    else if (x == c.Mean)
                    {
                        return (c.Weight / 2.0) / n;
                    }
                }

                if (i == _centroids.Count - 1)
                {
                    if (x > c.Mean)
                    {
                        double innerW = c.Weight / 2.0;
                        double rightW = n - cumulative - innerW;
                        double frac = (_max == c.Mean) ? 0.0 : (x - c.Mean) / (_max - c.Mean);
                        return (cumulative + innerW + rightW * frac) / n;
                    }
                    else
                    {
                        return (cumulative + c.Weight / 2.0) / n;
                    }
                }

                double mid = cumulative + c.Weight / 2.0;
                var nextC = _centroids[i + 1];
                double nextCumulative = cumulative + c.Weight;
                double nextMid = nextCumulative + nextC.Weight / 2.0;

                if (x < nextC.Mean)
                {
                    if (c.Mean == nextC.Mean)
                        return (mid + (nextMid - mid) / 2.0) / n;
                    double frac = (x - c.Mean) / (nextC.Mean - c.Mean);
                    return (mid + frac * (nextMid - mid)) / n;
                }

                cumulative += c.Weight;
            }

            return 1.0;
        }

        public void Merge(TDigest other)
        {
            if (other._buffer.Count > 0) other.Compress();
            foreach (var c in other._centroids)
            {
                Add(c.Mean, c.Weight);
            }
        }

        public int CentroidCount
        {
            get
            {
                if (_buffer.Count > 0) Compress();
                return _centroids.Count;
            }
        }

        // K1 scale function: k(q) = (delta / (2*pi)) * asin(2*q - 1)
        private double K(double q)
        {
            return (_delta / (2.0 * Math.PI)) * Math.Asin(2.0 * q - 1.0);
        }

        private static void MergeIntoLast(List<Centroid> centroids, Centroid c)
        {
            int idx = centroids.Count - 1;
            var last = centroids[idx];
            double newWeight = last.Weight + c.Weight;
            double newMean = (last.Mean * last.Weight + c.Mean * c.Weight) / newWeight;
            centroids[idx] = new Centroid(newMean, newWeight);
        }
    }
}
