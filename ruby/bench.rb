#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark / asymptotic-behavior tests for the Ruby t-digest implementation.

require_relative "tdigest"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def time_block
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  (t1 - t0) * 1000.0 # milliseconds
end

$pass_count = 0
$fail_count = 0

def check(label, ok)
  if ok
    $pass_count += 1
    puts "  #{label}  PASS"
  else
    $fail_count += 1
    puts "  #{label}  FAIL"
  end
end

def ratio_ok?(ratio, expected, lo_factor = 0.5, hi_factor = 3.0)
  ratio >= expected * lo_factor && ratio <= expected * hi_factor
end

puts "=== T-Digest Asymptotic Behavior Tests (Ruby) ==="
puts

# ---------------------------------------------------------------------------
# Test 1: add() is amortized O(1)
# ---------------------------------------------------------------------------

puts "--- Test 1: add() is amortized O(1) ---"

sizes = [1_000, 10_000, 100_000, 1_000_000]
times = sizes.map do |n|
  td = TDigest.new(100)
  ms = time_block { n.times { |i| td.add(i.to_f / n) } }
  printf("  N=%-9d  time=%.1fms\n", n, ms)
  ms
end

(1...sizes.size).each do |i|
  expected_ratio = sizes[i].to_f / sizes[i - 1]
  actual_ratio = times[i] / times[i - 1]
  ok = ratio_ok?(actual_ratio, expected_ratio)
  check(format("N=%d  ratio=%.2f (expected ~%.1f)", sizes[i], actual_ratio, expected_ratio), ok)
end

puts

# ---------------------------------------------------------------------------
# Test 2: Centroid count bounded by O(delta)
# ---------------------------------------------------------------------------

puts "--- Test 2: Centroid count bounded by O(delta) ---"

delta = 100
sizes.each do |n|
  td = TDigest.new(delta)
  n.times { |i| td.add(i.to_f / n) }
  cc = td.centroid_count
  # The number of centroids should stay bounded by a constant related to delta,
  # regardless of n. Typically around 2*delta for K1.
  ok = cc <= 5 * delta
  check(format("N=%-9d  centroids=%-4d  (delta=%d, limit=%d)", n, cc, delta, 5 * delta), ok)
end

puts

# ---------------------------------------------------------------------------
# Test 3: Query time independent of N (O(k) where k ~ delta)
# ---------------------------------------------------------------------------

puts "--- Test 3: Query time independent of N ---"

query_sizes = [1_000, 10_000, 100_000]
query_times = query_sizes.map do |n|
  td = TDigest.new(100)
  n.times { |i| td.add(i.to_f / n) }
  td.compress!
  iterations = 10_000
  ms = time_block do
    iterations.times { td.quantile(0.5); td.cdf(0.5) }
  end
  us_per = (ms * 1000.0) / iterations
  printf("  N=%-9d  query_time=%.2fus\n", n, us_per)
  us_per
end

(1...query_sizes.size).each do |i|
  ratio = query_times[i] / query_times[i - 1]
  # Query time should be roughly constant (ratio ~ 1.0)
  ok = ratio_ok?(ratio, 1.0, 0.2, 5.0)
  check(format("N=%d  ratio=%.2f (expected ~1.0)", query_sizes[i], ratio), ok)
end

puts

# ---------------------------------------------------------------------------
# Test 4: Tail accuracy improves with delta
# ---------------------------------------------------------------------------

puts "--- Test 4: Tail accuracy improves with delta ---"

deltas = [50, 100, 200]
tail_quantiles = [0.01, 0.001, 0.99, 0.999]
n_acc = 100_000

tail_quantiles.each do |q|
  errors = deltas.map do |d|
    td = TDigest.new(d)
    n_acc.times { |i| td.add(i.to_f / n_acc) }
    est = td.quantile(q)
    err = (est - q).abs
    printf("  delta=%-5d  q=%-6.3f  error=%.6f\n", d, q, err)
    err
  end

  # Check that error generally decreases (or at least does not increase drastically)
  (1...deltas.size).each do |i|
    # Allow small tolerance: larger delta should not make accuracy worse
    ok = errors[i] <= errors[i - 1] * 1.5 + 0.001
    check(format("delta=%d q=%.3f error decreases (%.6f <= %.6f)", deltas[i], q, errors[i], errors[i - 1]), ok)
  end
end

puts

# ---------------------------------------------------------------------------
# Test 5: Merge preserves weight and accuracy
# ---------------------------------------------------------------------------

puts "--- Test 5: Merge preserves weight and accuracy ---"

n_merge = 10_000
td1 = TDigest.new(100)
td2 = TDigest.new(100)
(n_merge / 2).times { |i| td1.add(i.to_f / n_merge) }
(n_merge / 2).times { |i| td2.add((i + n_merge / 2).to_f / n_merge) }

weight_before = td1.total_weight + td2.total_weight
td1.merge(td2)
weight_after = td1.total_weight

check(format("weight_before=%.0f  weight_after=%.0f  (equal)", weight_before, weight_after),
      (weight_before - weight_after).abs < 1e-9)

median = td1.quantile(0.5)
median_err = (median - 0.5).abs
check(format("median_error=%.6f  (< 0.05)", median_err), median_err < 0.05)

p99 = td1.quantile(0.99)
p99_err = (p99 - 0.99).abs
check(format("p99_error=%.6f  (< 0.05)", p99_err), p99_err < 0.05)

puts

# ---------------------------------------------------------------------------
# Test 6: compress is O(n log n) where n is buffer size
# ---------------------------------------------------------------------------

puts "--- Test 6: compress is O(n log n) ---"

compress_sizes = [500, 5_000, 50_000]
compress_times = compress_sizes.map do |buf_n|
  # Use a very large buffer cap so we can control when compress happens
  td = TDigest.new(100)
  # Bypass buffer cap by directly inserting into buffer
  buf_n.times { |i| td.instance_variable_get(:@buffer) << TDigest::Centroid.new(rand, 1.0) }
  td.instance_variable_set(:@total_weight, buf_n.to_f)
  ms = time_block { td.compress! }
  printf("  buf_n=%-8d  compress_time=%.2fms\n", buf_n, ms)
  ms
end

(1...compress_sizes.size).each do |i|
  n0 = compress_sizes[i - 1]
  n1 = compress_sizes[i]
  expected = (n1.to_f * Math.log2(n1)) / (n0.to_f * Math.log2(n0))
  ratio = compress_times[i] / compress_times[i - 1]
  ok = ratio_ok?(ratio, expected, 0.3, 4.0)
  check(format("buf_n=%d  ratio=%.2f (expected ~%.1f)", n1, ratio, expected), ok)
end

puts

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

total = $pass_count + $fail_count
puts "Summary: #{$pass_count}/#{total} tests passed"
