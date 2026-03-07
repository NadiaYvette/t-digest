#!/usr/bin/env ruby
# frozen_string_literal: true

# Dunning t-digest for online quantile estimation.
# Merging digest variant with K_1 (arcsine) scale function.
# Uses an array-backed 2-3-4 tree with four-component monoidal measures.

require_relative 'tree234'

class TDigest
  Centroid = Struct.new(:mean, :weight)

  # Measure: {weight, count, max_mean, mean_weight_sum}
  Measure = Struct.new(:weight, :count, :max_mean, :mean_weight_sum)

  DEFAULT_DELTA = 100
  BUFFER_FACTOR = 5

  attr_reader :delta, :total_weight, :min, :max

  MEASURE_FN = ->(c) {
    Measure.new(c.weight, 1, c.mean, c.mean * c.weight)
  }

  COMBINE_FN = ->(a, b) {
    Measure.new(
      a.weight + b.weight,
      a.count + b.count,
      [a.max_mean, b.max_mean].max,
      a.mean_weight_sum + b.mean_weight_sum
    )
  }

  IDENTITY_FN = -> {
    Measure.new(0, 0, -Float::INFINITY, 0)
  }

  COMPARE_FN = ->(a, b) {
    a.mean <=> b.mean
  }

  def initialize(delta = DEFAULT_DELTA)
    @delta = delta.to_f
    @tree = Tree234.new(
      measure_fn:  MEASURE_FN,
      combine_fn:  COMBINE_FN,
      identity_fn: IDENTITY_FN,
      compare_fn:  COMPARE_FN
    )
    @buffer = []
    @total_weight = 0.0
    @min = Float::INFINITY
    @max = -Float::INFINITY
    @buffer_cap = (delta * BUFFER_FACTOR).ceil
  end

  def add(value, weight = 1.0)
    value = value.to_f
    weight = weight.to_f
    @buffer << Centroid.new(value, weight)
    @total_weight += weight
    @min = value if value < @min
    @max = value if value > @max
    compress! if @buffer.size >= @buffer_cap
    self
  end

  def compress!
    return if @buffer.empty? && @tree.size <= 1

    # Collect all centroids from tree and buffer
    all = @tree.collect + @buffer
    @buffer = []
    all.sort_by!(&:mean)

    merged = [Centroid.new(all[0].mean, all[0].weight)]
    weight_so_far = 0.0
    n = @total_weight

    (1...all.size).each do |i|
      proposed = merged.last.weight + all[i].weight
      q0 = weight_so_far / n
      q1 = (weight_so_far + proposed) / n

      if (proposed <= 1 && all.size > 1) || (k(q1) - k(q0) <= 1.0)
        merge_into_last!(merged, all[i])
      else
        weight_so_far += merged.last.weight
        merged << Centroid.new(all[i].mean, all[i].weight)
      end
    end

    # Rebuild tree from sorted merged centroids
    @tree.build_from_sorted(merged)
    self
  end

  def quantile(q)
    compress! unless @buffer.empty?
    centroids = @tree.collect
    return nil if centroids.empty?
    return centroids[0].mean if centroids.size == 1

    q = 0.0 if q < 0.0
    q = 1.0 if q > 1.0

    n = @total_weight
    target = q * n

    # Walk centroids; each centroid midpoint is at cumulative + weight/2
    cumulative = 0.0
    centroids.each_with_index do |c, i|
      mid = cumulative + c.weight / 2.0

      if i == 0
        # Left boundary: interpolate between min and first centroid
        if target < c.weight / 2.0
          return @min if c.weight == 1
          return @min + (c.mean - @min) * (target / (c.weight / 2.0))
        end
      end

      if i == centroids.size - 1
        # Right boundary: interpolate between last centroid and max
        if target > n - c.weight / 2.0
          return @max if c.weight == 1
          remaining = n - c.weight / 2.0
          return c.mean + (@max - c.mean) * ((target - remaining) / (c.weight / 2.0))
        end
        return c.mean
      end

      next_c = centroids[i + 1]
      next_mid = cumulative + c.weight + next_c.weight / 2.0

      if target <= next_mid
        frac = if next_mid == mid
                 0.5
               else
                 (target - mid) / (next_mid - mid)
               end
        return c.mean + frac * (next_c.mean - c.mean)
      end

      cumulative += c.weight
    end

    @max
  end

  def cdf(x)
    compress! unless @buffer.empty?
    centroids = @tree.collect
    return nil if centroids.empty?
    return 0.0 if x <= @min
    return 1.0 if x >= @max

    n = @total_weight
    cumulative = 0.0

    centroids.each_with_index do |c, i|
      if i == 0
        # Left boundary: between min and first centroid
        if x < c.mean
          inner_w = c.weight / 2.0
          frac = if c.mean == @min then 1.0 else (x - @min) / (c.mean - @min) end
          return (inner_w * frac) / n
        elsif x == c.mean
          return (c.weight / 2.0) / n
        end
      end

      if i == centroids.size - 1
        # Right boundary
        if x > c.mean
          inner_w = c.weight / 2.0
          right_w = n - cumulative - c.weight / 2.0
          frac = if @max == c.mean then 0.0 else (x - c.mean) / (@max - c.mean) end
          return (cumulative + c.weight / 2.0 + right_w * frac) / n
        else
          return (cumulative + c.weight / 2.0) / n
        end
      end

      mid = cumulative + c.weight / 2.0
      next_c = centroids[i + 1]
      next_cumulative = cumulative + c.weight
      next_mid = next_cumulative + next_c.weight / 2.0

      if x < next_c.mean
        if c.mean == next_c.mean
          return (mid + (next_mid - mid) / 2.0) / n
        end
        frac = (x - c.mean) / (next_c.mean - c.mean)
        return (mid + frac * (next_mid - mid)) / n
      end

      cumulative += c.weight
    end

    1.0
  end

  def merge(other)
    other.send(:flush_for_merge).each do |c|
      add(c.mean, c.weight)
    end
    self
  end

  def size
    @tree.size + @buffer.size
  end

  def centroid_count
    compress! unless @buffer.empty?
    @tree.size
  end

  private

  def flush_for_merge
    compress! unless @buffer.empty?
    @tree.collect
  end

  def k(q)
    (@delta / (2.0 * Math::PI)) * Math.asin(2.0 * q - 1.0)
  end

  def merge_into_last!(centroids, c)
    last = centroids.last
    new_weight = last.weight + c.weight
    last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight
    last.weight = new_weight
  end
end

# --- Demo / Self-test ---
if __FILE__ == $PROGRAM_NAME
  td = TDigest.new(100)

  # Insert 10000 uniformly spaced values in [0, 1)
  n = 10_000
  n.times do |i|
    td.add(i.to_f / n)
  end

  puts "T-Digest demo: #{n} uniform values in [0, 1)"
  puts "Centroids: #{td.centroid_count}"
  puts
  puts "Quantile estimates (expected ~ q for uniform):"
  [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999].each do |q|
    est = td.quantile(q)
    printf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, (est - q).abs)
  end

  puts
  puts "CDF estimates (expected ~ x for uniform):"
  [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999].each do |x|
    est = td.cdf(x)
    printf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, (est - x).abs)
  end

  # Test merge
  td1 = TDigest.new(100)
  td2 = TDigest.new(100)
  5000.times { |i| td1.add(i.to_f / 10_000) }
  5000.times { |i| td2.add((i + 5000).to_f / 10_000) }
  td1.merge(td2)

  puts
  puts "After merge:"
  printf("  median=%.6f (expected ~0.5)\n", td1.quantile(0.5))
  printf("  p99   =%.6f (expected ~0.99)\n", td1.quantile(0.99))
end
