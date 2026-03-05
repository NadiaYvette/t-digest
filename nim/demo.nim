# Demo / self-test for t-digest Nim implementation

import strformat, math
import tdigest

proc main() =
  let td = newTDigest(100.0)
  let n = 10000

  for i in 0 ..< n:
    td.add(float(i) / float(n))

  echo &"T-Digest demo: {n} uniform values in [0, 1)"
  echo &"Centroids: {td.centroidCount()}"
  echo ""

  echo "Quantile estimates (expected ~ q for uniform):"
  for q in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]:
    let est = td.quantile(q)
    echo &"  q={q:<6.3f}  estimated={est:.6f}  error={abs(est - q):.6f}"

  echo ""
  echo "CDF estimates (expected ~ x for uniform):"
  for x in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]:
    let est = td.cdf(x)
    echo &"  x={x:<6.3f}  estimated={est:.6f}  error={abs(est - x):.6f}"

  # Test merge
  let td1 = newTDigest(100.0)
  let td2 = newTDigest(100.0)
  for i in 0 ..< 5000:
    td1.add(float(i) / 10000.0)
  for i in 5000 ..< 10000:
    td2.add(float(i) / 10000.0)
  td1.merge(td2)

  echo ""
  echo "After merge:"
  echo &"  median={td1.quantile(0.5):.6f} (expected ~0.5)"
  echo &"  p99   ={td1.quantile(0.99):.6f} (expected ~0.99)"

main()
