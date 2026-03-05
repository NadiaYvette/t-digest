Code.require_file("tdigest.ex", __DIR__)

n = 10_000
td = Enum.reduce(0..(n - 1), TDigest.new(100), fn i, acc ->
  TDigest.add(acc, i / n)
end)

IO.puts("T-Digest demo: #{n} uniform values in [0, 1)")
IO.puts("Centroids: #{TDigest.centroid_count(td)}")
IO.puts("")
IO.puts("Quantile estimates (expected ~ q for uniform):")

for q <- [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] do
  est = TDigest.quantile(td, q)
  error = abs(est - q)
  :io.format("  q=~-6.3f  estimated=~.6f  error=~.6f~n", [q, est, error])
end

IO.puts("")
IO.puts("CDF estimates (expected ~ x for uniform):")

for x <- [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] do
  est = TDigest.cdf(td, x)
  error = abs(est - x)
  :io.format("  x=~-6.3f  estimated=~.6f  error=~.6f~n", [x, est, error])
end

# Test merge
td1 = Enum.reduce(0..4999, TDigest.new(100), fn i, acc ->
  TDigest.add(acc, i / 10_000)
end)

td2 = Enum.reduce(5000..9999, TDigest.new(100), fn i, acc ->
  TDigest.add(acc, i / 10_000)
end)

merged = TDigest.merge(td1, td2)

IO.puts("")
IO.puts("After merge:")
:io.format("  median=~.6f (expected ~~0.5)~n", [TDigest.quantile(merged, 0.5)])
:io.format("  p99   =~.6f (expected ~~0.99)~n", [TDigest.quantile(merged, 0.99)])
