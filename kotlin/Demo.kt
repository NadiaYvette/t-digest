import kotlin.math.abs

/**
 * Demo and self-test for TDigest.
 */
fun main() {
    val td = TDigest(100.0)

    val n = 10000
    for (i in 0 until n) {
        td.add(i.toDouble() / n)
    }

    println("T-Digest demo: $n uniform values in [0, 1)")
    println("Centroids: ${td.centroidCount()}")
    println()

    val quantiles = doubleArrayOf(0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999)

    println("Quantile estimates (expected ~ q for uniform):")
    for (q in quantiles) {
        val est = td.quantile(q)
        println("  q=%-6.3f  estimated=%.6f  error=%.6f".format(q, est, abs(est - q)))
    }

    println()
    println("CDF estimates (expected ~ x for uniform):")
    for (x in quantiles) {
        val est = td.cdf(x)
        println("  x=%-6.3f  estimated=%.6f  error=%.6f".format(x, est, abs(est - x)))
    }

    // Test merge
    val td1 = TDigest(100.0)
    val td2 = TDigest(100.0)
    for (i in 0 until 5000) {
        td1.add(i.toDouble() / 10000)
    }
    for (i in 5000 until 10000) {
        td2.add(i.toDouble() / 10000)
    }
    td1.merge(td2)

    println()
    println("After merge:")
    println("  median=%.6f (expected ~0.5)".format(td1.quantile(0.5)))
    println("  p99   =%.6f (expected ~0.99)".format(td1.quantile(0.99)))
}
