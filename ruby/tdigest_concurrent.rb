#!/usr/bin/env ruby
# frozen_string_literal: true

# Thread-safe wrapper around TDigest using a Mutex for synchronization.
# All public methods acquire the lock before delegating to the underlying
# TDigest instance.

require_relative "tdigest"

class TDigestConcurrent
  def initialize(delta = TDigest::DEFAULT_DELTA)
    @mutex = Mutex.new
    @digest = TDigest.new(delta)
  end

  # Add a single value (with optional weight) to the digest.
  def add(value, weight = 1.0)
    @mutex.synchronize { @digest.add(value, weight) }
    self
  end

  # Force compression of buffered values into the centroid list.
  def compress!
    @mutex.synchronize { @digest.compress! }
    self
  end

  # Estimate the value at quantile q (0..1).
  def quantile(q)
    @mutex.synchronize { @digest.quantile(q) }
  end

  # Estimate the CDF at value x.
  def cdf(x)
    @mutex.synchronize { @digest.cdf(x) }
  end

  # Merge another TDigest or TDigestConcurrent into this one.
  def merge(other)
    # If the other digest is also concurrent, snapshot it first to avoid
    # holding two locks simultaneously (which could deadlock).
    if other.is_a?(TDigestConcurrent)
      snap = other.snapshot
      @mutex.synchronize { @digest.merge(snap) }
    else
      @mutex.synchronize { @digest.merge(other) }
    end
    self
  end

  # Return the total weight of all values added.
  def total_weight
    @mutex.synchronize { @digest.total_weight }
  end

  # Return the number of centroids (compresses pending buffer first).
  def centroid_count
    @mutex.synchronize { @digest.centroid_count }
  end

  # Return the compression parameter (delta).
  def delta
    @mutex.synchronize { @digest.delta }
  end

  # Return the observed minimum value.
  def min
    @mutex.synchronize { @digest.min }
  end

  # Return the observed maximum value.
  def max
    @mutex.synchronize { @digest.max }
  end

  # Return a frozen (immutable), non-thread-safe copy of the current state.
  # Useful for taking a consistent snapshot for read-heavy workloads.
  def snapshot
    @mutex.synchronize do
      # Marshal round-trip produces a deep copy; we build a fresh TDigest
      # by replaying the compressed centroids.
      @digest.compress! unless @digest.send(:flush_for_merge).empty?
      copy = TDigest.new(@digest.delta)
      @digest.send(:flush_for_merge).each do |c|
        copy.add(c.mean, c.weight)
      end
      copy
    end
  end
end

# --- Demo / Self-test ---
if __FILE__ == $PROGRAM_NAME
  td = TDigestConcurrent.new(100)

  threads = 4.times.map do |t|
    Thread.new do
      2500.times do |i|
        val = (t * 2500 + i).to_f / 10_000
        td.add(val)
      end
    end
  end
  threads.each(&:join)

  puts "TDigestConcurrent demo: 10000 values from 4 threads"
  puts "Centroids: #{td.centroid_count}"
  puts "Total weight: #{td.total_weight}"
  puts
  puts "Quantile estimates:"
  [0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99].each do |q|
    est = td.quantile(q)
    printf("  q=%-5.2f  estimated=%.6f\n", q, est)
  end
end
