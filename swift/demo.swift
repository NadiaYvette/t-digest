// Demo for t-digest Swift implementation.

#if canImport(Glibc)
import Glibc
#endif

func fmt(_ v: Double, _ decimals: Int = 6) -> String {
    let factor = pow(10.0, Double(decimals))
    let intVal = Int((abs(v) * factor + 0.5).rounded(.down))
    let sign = v < 0 ? "-" : ""
    let wholePart = intVal / Int(factor)
    let fracPart = intVal % Int(factor)
    let fracStr = String(repeating: "0", count: Swift.max(0, decimals - "\(fracPart)".count)) + "\(fracPart)"
    return "\(sign)\(wholePart).\(fracStr)"
}

@main
struct Demo {
    static func main() {
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
            print("  q=\(fmt(q, 3))  estimated=\(fmt(est))  error=\(fmt(error))")
        }

        print()
        print("CDF estimates (expected ~ x for uniform):")

        for x in testPoints {
            let est = td.cdf(x)!
            let error = abs(est - x)
            print("  x=\(fmt(x, 3))  estimated=\(fmt(est))  error=\(fmt(error))")
        }

        // Test merge
        var td1 = TDigest(delta: 100)
        var td2 = TDigest(delta: 100)
        for i in 0..<5000 { td1.add(Double(i) / 10000.0) }
        for i in 5000..<10000 { td2.add(Double(i) / 10000.0) }
        td1.merge(&td2)

        print()
        print("After merge:")
        print("  median=\(fmt(td1.quantile(0.5)!)) (expected ~0.5)")
        print("  p99   =\(fmt(td1.quantile(0.99)!)) (expected ~0.99)")
    }
}
