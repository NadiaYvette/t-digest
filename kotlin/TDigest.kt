import kotlin.math.*

/**
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K1 (arcsine) scale function.
 */

data class Centroid(var mean: Double, var weight: Double)

class TDigest(val delta: Double = DEFAULT_DELTA) {

    companion object {
        const val DEFAULT_DELTA = 100.0
        const val BUFFER_FACTOR = 5
    }

    private var centroids = mutableListOf<Centroid>()
    private var buffer = mutableListOf<Centroid>()
    var totalWeight: Double = 0.0
        private set
    var min: Double = Double.POSITIVE_INFINITY
        private set
    var max: Double = Double.NEGATIVE_INFINITY
        private set
    private val bufferCap = ceil(delta * BUFFER_FACTOR).toInt()

    fun add(value: Double, weight: Double = 1.0) {
        buffer.add(Centroid(value, weight))
        totalWeight += weight
        if (value < min) min = value
        if (value > max) max = value
        if (buffer.size >= bufferCap) compress()
    }

    fun compress() {
        if (buffer.isEmpty() && centroids.size <= 1) return

        val all = mutableListOf<Centroid>().apply {
            addAll(centroids)
            addAll(buffer)
        }
        buffer = mutableListOf()
        all.sortBy { it.mean }

        val newCentroids = mutableListOf(Centroid(all[0].mean, all[0].weight))
        var weightSoFar = 0.0
        val n = totalWeight

        for (i in 1 until all.size) {
            val last = newCentroids.last()
            val proposed = last.weight + all[i].weight
            val q0 = weightSoFar / n
            val q1 = (weightSoFar + proposed) / n

            if (proposed <= 1.0 && all.size > 1) {
                mergeIntoLast(newCentroids, all[i])
            } else if (k(q1) - k(q0) <= 1.0) {
                mergeIntoLast(newCentroids, all[i])
            } else {
                weightSoFar += last.weight
                newCentroids.add(Centroid(all[i].mean, all[i].weight))
            }
        }

        centroids = newCentroids
    }

    fun quantile(q: Double): Double {
        if (buffer.isNotEmpty()) compress()
        if (centroids.isEmpty()) return Double.NaN
        if (centroids.size == 1) return centroids[0].mean

        val qc = q.coerceIn(0.0, 1.0)
        val n = totalWeight
        val target = qc * n
        var cumulative = 0.0

        for (i in centroids.indices) {
            val c = centroids[i]

            if (i == 0) {
                if (target < c.weight / 2.0) {
                    if (c.weight == 1.0) return min
                    return min + (c.mean - min) * (target / (c.weight / 2.0))
                }
            }

            if (i == centroids.size - 1) {
                if (target > n - c.weight / 2.0) {
                    if (c.weight == 1.0) return max
                    val remaining = n - c.weight / 2.0
                    return c.mean + (max - c.mean) * ((target - remaining) / (c.weight / 2.0))
                }
                return c.mean
            }

            val nextC = centroids[i + 1]
            val mid = cumulative + c.weight / 2.0
            val nextMid = cumulative + c.weight + nextC.weight / 2.0

            if (target <= nextMid) {
                val frac = if (nextMid == mid) 0.5 else (target - mid) / (nextMid - mid)
                return c.mean + frac * (nextC.mean - c.mean)
            }

            cumulative += c.weight
        }

        return max
    }

    fun cdf(x: Double): Double {
        if (buffer.isNotEmpty()) compress()
        if (centroids.isEmpty()) return Double.NaN
        if (x <= min) return 0.0
        if (x >= max) return 1.0

        val n = totalWeight
        var cumulative = 0.0

        for (i in centroids.indices) {
            val c = centroids[i]

            if (i == 0) {
                if (x < c.mean) {
                    val innerW = c.weight / 2.0
                    val frac = if (c.mean == min) 1.0 else (x - min) / (c.mean - min)
                    return (innerW * frac) / n
                } else if (x == c.mean) {
                    return (c.weight / 2.0) / n
                }
            }

            if (i == centroids.size - 1) {
                if (x > c.mean) {
                    val rightW = n - cumulative - c.weight / 2.0
                    val frac = if (max == c.mean) 0.0 else (x - c.mean) / (max - c.mean)
                    return (cumulative + c.weight / 2.0 + rightW * frac) / n
                } else {
                    return (cumulative + c.weight / 2.0) / n
                }
            }

            val mid = cumulative + c.weight / 2.0
            val nextC = centroids[i + 1]
            val nextCumulative = cumulative + c.weight
            val nextMid = nextCumulative + nextC.weight / 2.0

            if (x < nextC.mean) {
                if (c.mean == nextC.mean) {
                    return (mid + (nextMid - mid) / 2.0) / n
                }
                val frac = (x - c.mean) / (nextC.mean - c.mean)
                return (mid + frac * (nextMid - mid)) / n
            }

            cumulative += c.weight
        }

        return 1.0
    }

    fun merge(other: TDigest) {
        other.compress()
        for (c in other.centroids) {
            add(c.mean, c.weight)
        }
    }

    fun centroidCount(): Int {
        if (buffer.isNotEmpty()) compress()
        return centroids.size
    }

    private fun k(q: Double): Double {
        return (delta / (2.0 * PI)) * asin(2.0 * q - 1.0)
    }

    private fun mergeIntoLast(centroids: MutableList<Centroid>, c: Centroid) {
        val last = centroids.last()
        val newWeight = last.weight + c.weight
        last.mean = (last.mean * last.weight + c.mean * c.weight) / newWeight
        last.weight = newWeight
    }
}
