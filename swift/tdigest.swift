// Dunning t-digest for online quantile estimation.
// Merging digest variant with K1 (arcsine) scale function.
// Uses an array-backed 2-3-4 tree with monoidal measures.

#if canImport(Foundation)
import Foundation
#elseif canImport(Glibc)
import Glibc
#endif

struct Centroid {
    var mean: Double
    var weight: Double
}

// Four-component monoidal measure for t-digest centroids.
struct TdMeasure {
    var weight: Double = 0
    var count: Int = 0
    var maxMean: Double = -Double.infinity
    var meanWeightSum: Double = 0
}

// Traits for the 2-3-4 tree specialized for Centroid keys.
struct CentroidTraits: Tree234Traits {
    typealias K = Centroid
    typealias M = TdMeasure

    static func measure(_ c: Centroid) -> TdMeasure {
        return TdMeasure(weight: c.weight, count: 1,
                         maxMean: c.mean, meanWeightSum: c.mean * c.weight)
    }

    static func combine(_ a: TdMeasure, _ b: TdMeasure) -> TdMeasure {
        return TdMeasure(weight: a.weight + b.weight,
                         count: a.count + b.count,
                         maxMean: Swift.max(a.maxMean, b.maxMean),
                         meanWeightSum: a.meanWeightSum + b.meanWeightSum)
    }

    static func identity() -> TdMeasure {
        return TdMeasure(weight: 0, count: 0,
                         maxMean: -Double.infinity, meanWeightSum: 0)
    }

    static func compare(_ a: Centroid, _ b: Centroid) -> Int {
        if a.mean < b.mean { return -1 }
        if a.mean > b.mean { return 1 }
        return 0
    }
}

struct TDigest {
    static let defaultDelta: Double = 100
    static let bufferFactor: Int = 5

    let delta: Double
    private var tree = Tree234<CentroidTraits>()
    private var buffer: [Centroid] = []
    private(set) var totalWeight: Double = 0.0
    private(set) var min: Double = Double.infinity
    private(set) var max: Double = -Double.infinity
    private let bufferCap: Int

    init(delta: Double = defaultDelta) {
        self.delta = delta
        self.bufferCap = Int(ceil(delta * Double(TDigest.bufferFactor)))
    }

    mutating func add(_ value: Double, weight: Double = 1.0) {
        buffer.append(Centroid(mean: value, weight: weight))
        totalWeight += weight
        if value < min { min = value }
        if value > max { max = value }
        if buffer.count >= bufferCap {
            compress()
        }
    }

    mutating func compress() {
        if buffer.isEmpty && tree.size <= 1 { return }

        var all = tree.collect() + buffer
        buffer.removeAll()
        all.sort { $0.mean < $1.mean }

        var newCentroids = [all[0]]
        var weightSoFar = 0.0
        let n = totalWeight

        for i in 1..<all.count {
            let proposed = newCentroids[newCentroids.count - 1].weight + all[i].weight
            let q0 = weightSoFar / n
            let q1 = (weightSoFar + proposed) / n

            if (proposed <= 1 && all.count > 1) || (k(q1) - k(q0) <= 1.0) {
                mergeIntoLast(&newCentroids, all[i])
            } else {
                weightSoFar += newCentroids[newCentroids.count - 1].weight
                newCentroids.append(all[i])
            }
        }

        tree.buildFromSorted(newCentroids)
    }

    // Provide centroids access for compatibility (collects from tree).
    var centroids: [Centroid] {
        mutating get {
            if !buffer.isEmpty { compress() }
            return tree.collect()
        }
    }

    mutating func quantile(_ q: Double) -> Double? {
        if !buffer.isEmpty { compress() }
        let sz = tree.size
        if sz == 0 { return nil }

        let allCentroids = tree.collect()
        if sz == 1 { return allCentroids[0].mean }

        let q = Swift.max(0.0, Swift.min(1.0, q))
        let n = totalWeight
        let target = q * n

        var cumulative = 0.0
        for i in 0..<allCentroids.count {
            let c = allCentroids[i]

            if i == 0 {
                if target < c.weight / 2.0 {
                    if c.weight == 1 { return min }
                    return min + (c.mean - min) * (target / (c.weight / 2.0))
                }
            }

            if i == allCentroids.count - 1 {
                if target > n - c.weight / 2.0 {
                    if c.weight == 1 { return max }
                    let remaining = n - c.weight / 2.0
                    return c.mean + (max - c.mean) * ((target - remaining) / (c.weight / 2.0))
                }
                return c.mean
            }

            let mid = cumulative + c.weight / 2.0
            let nextC = allCentroids[i + 1]
            let nextMid = cumulative + c.weight + nextC.weight / 2.0

            if target <= nextMid {
                let frac = nextMid == mid ? 0.5 : (target - mid) / (nextMid - mid)
                return c.mean + frac * (nextC.mean - c.mean)
            }

            cumulative += c.weight
        }

        return max
    }

    mutating func cdf(_ x: Double) -> Double? {
        if !buffer.isEmpty { compress() }
        let sz = tree.size
        if sz == 0 { return nil }
        if x <= min { return 0.0 }
        if x >= max { return 1.0 }

        let allCentroids = tree.collect()
        let n = totalWeight
        var cumulative = 0.0

        for i in 0..<allCentroids.count {
            let c = allCentroids[i]

            if i == 0 {
                if x < c.mean {
                    let innerW = c.weight / 2.0
                    let frac = c.mean == min ? 1.0 : (x - min) / (c.mean - min)
                    return (innerW * frac) / n
                } else if x == c.mean {
                    return (c.weight / 2.0) / n
                }
            }

            if i == allCentroids.count - 1 {
                if x > c.mean {
                    let innerW = c.weight / 2.0
                    let rightW = n - cumulative - innerW
                    let frac = max == c.mean ? 0.0 : (x - c.mean) / (max - c.mean)
                    return (cumulative + innerW + rightW * frac) / n
                } else {
                    return (cumulative + c.weight / 2.0) / n
                }
            }

            let mid = cumulative + c.weight / 2.0
            let nextC = allCentroids[i + 1]
            let nextCumulative = cumulative + c.weight
            let nextMid = nextCumulative + nextC.weight / 2.0

            if x < nextC.mean {
                if c.mean == nextC.mean {
                    return (mid + (nextMid - mid) / 2.0) / n
                }
                let frac = (x - c.mean) / (nextC.mean - c.mean)
                return (mid + frac * (nextMid - mid)) / n
            }

            cumulative += c.weight
        }

        return 1.0
    }

    mutating func merge(_ other: inout TDigest) {
        if !other.buffer.isEmpty { other.compress() }
        let otherCentroids = other.tree.collect()
        for c in otherCentroids {
            add(c.mean, weight: c.weight)
        }
    }

    var centroidCount: Int {
        mutating get {
            if !buffer.isEmpty { compress() }
            return tree.size
        }
    }

    // K1 scale function: k(q) = (delta / (2*pi)) * asin(2*q - 1)
    private func k(_ q: Double) -> Double {
        return (delta / (2.0 * Double.pi)) * asin(2.0 * q - 1.0)
    }

    private func mergeIntoLast(_ centroids: inout [Centroid], _ c: Centroid) {
        let last = centroids[centroids.count - 1]
        let newWeight = last.weight + c.weight
        let newMean = (last.mean * last.weight + c.mean * c.weight) / newWeight
        centroids[centroids.count - 1] = Centroid(mean: newMean, weight: newWeight)
    }
}
