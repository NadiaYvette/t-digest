// Dunning t-digest for online quantile estimation.
// Merging digest variant with K1 (arcsine) scale function.

import Foundation

struct Centroid {
    var mean: Double
    var weight: Double
}

struct TDigest {
    static let defaultDelta: Double = 100
    static let bufferFactor: Int = 5

    let delta: Double
    private(set) var centroids: [Centroid] = []
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
        if buffer.isEmpty && centroids.count <= 1 { return }

        var all = centroids + buffer
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

        centroids = newCentroids
    }

    mutating func quantile(_ q: Double) -> Double? {
        if !buffer.isEmpty { compress() }
        guard !centroids.isEmpty else { return nil }
        if centroids.count == 1 { return centroids[0].mean }

        let q = Swift.max(0.0, Swift.min(1.0, q))
        let n = totalWeight
        let target = q * n

        var cumulative = 0.0
        for i in 0..<centroids.count {
            let c = centroids[i]

            if i == 0 {
                if target < c.weight / 2.0 {
                    if c.weight == 1 { return min }
                    return min + (c.mean - min) * (target / (c.weight / 2.0))
                }
            }

            if i == centroids.count - 1 {
                if target > n - c.weight / 2.0 {
                    if c.weight == 1 { return max }
                    let remaining = n - c.weight / 2.0
                    return c.mean + (max - c.mean) * ((target - remaining) / (c.weight / 2.0))
                }
                return c.mean
            }

            let mid = cumulative + c.weight / 2.0
            let nextC = centroids[i + 1]
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
        guard !centroids.isEmpty else { return nil }
        if x <= min { return 0.0 }
        if x >= max { return 1.0 }

        let n = totalWeight
        var cumulative = 0.0

        for i in 0..<centroids.count {
            let c = centroids[i]

            if i == 0 {
                if x < c.mean {
                    let innerW = c.weight / 2.0
                    let frac = c.mean == min ? 1.0 : (x - min) / (c.mean - min)
                    return (innerW * frac) / n
                } else if x == c.mean {
                    return (c.weight / 2.0) / n
                }
            }

            if i == centroids.count - 1 {
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
            let nextC = centroids[i + 1]
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
        for c in other.centroids {
            add(c.mean, weight: c.weight)
        }
    }

    var centroidCount: Int {
        mutating get {
            if !buffer.isEmpty { compress() }
            return centroids.count
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
