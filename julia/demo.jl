#!/usr/bin/env julia
"""Demo / self-test for the t-digest implementation."""

include("TDigest.jl")
using .TDigestModule
using Printf

function main()
    td = TDigest(100)

    n = 10_000
    for i in 0:n-1
        add!(td, i / n)
    end

    println("T-Digest demo: $n uniform values in [0, 1)")
    println("Centroids: $(centroid_count(td))")
    println()

    println("Quantile estimates (expected ~ q for uniform):")
    for q in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]
        est = quantile(td, q)
        @printf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, abs(est - q))
    end

    println()
    println("CDF estimates (expected ~ x for uniform):")
    for x in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]
        est = cdf(td, x)
        @printf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, abs(est - x))
    end

    # Test merge
    td1 = TDigest(100)
    td2 = TDigest(100)
    for i in 0:4999
        add!(td1, i / 10_000)
    end
    for i in 5000:9999
        add!(td2, i / 10_000)
    end
    TDigestModule.merge!(td1, td2)

    println()
    println("After merge:")
    @printf("  median=%.6f (expected ~0.5)\n", quantile(td1, 0.5))
    @printf("  p99   =%.6f (expected ~0.99)\n", quantile(td1, 0.99))
end

main()
