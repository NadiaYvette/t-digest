// Demo for t-digest Swift implementation.

import Foundation

let n = 10000
var td = TDigest(delta: 100)

for i in 0..<n {
    td.add(Double(i) / Double(n))
}

print("T-Digest demo: \(n) uniform values in [0, 1)")
print("Centroids: \(td.centroidCount)")
print()
print("Quantile estimates (expected ~ q for uniform):")

let testPoints: [Double] = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]

for q in testPoints {
    let est = td.quantile(q)!
    let error = abs(est - q)
    let qs = String(format: "%-6.3f", q)
    print("  q=\(qs)  estimated=\(String(format: "%.6f", est))  error=\(String(format: "%.6f", error))")
}

print()
print("CDF estimates (expected ~ x for uniform):")

for x in testPoints {
    let est = td.cdf(x)!
    let error = abs(est - x)
    let xs = String(format: "%-6.3f", x)
    print("  x=\(xs)  estimated=\(String(format: "%.6f", est))  error=\(String(format: "%.6f", error))")
}

// Test merge
var td1 = TDigest(delta: 100)
var td2 = TDigest(delta: 100)
for i in 0..<5000 { td1.add(Double(i) / 10000.0) }
for i in 5000..<10000 { td2.add(Double(i) / 10000.0) }
td1.merge(&td2)

print()
print("After merge:")
print("  median=\(String(format: "%.6f", td1.quantile(0.5)!)) (expected ~0.5)")
print("  p99   =\(String(format: "%.6f", td1.quantile(0.99)!)) (expected ~0.99)")
