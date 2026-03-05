// Demo / self-test for t-digest Zig implementation

const std = @import("std");
const tdigest = @import("tdigest.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var td = tdigest.TDigest.init(allocator, 100.0);
    defer td.deinit();

    const n: usize = 10000;
    for (0..n) |i| {
        try td.add(@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n)), 1.0);
    }

    const cc = try td.centroidCount();
    std.debug.print("T-Digest demo: {d} uniform values in [0, 1)\n", .{n});
    std.debug.print("Centroids: {d}\n\n", .{cc});

    std.debug.print("Quantile estimates (expected ~ q for uniform):\n", .{});
    const quantiles = [_]f64{ 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999 };
    for (quantiles) |q| {
        if (try td.quantile(q)) |est| {
            const err = @abs(est - q);
            std.debug.print("  q={d:<6.3}  estimated={d:.6}  error={d:.6}\n", .{ q, est, err });
        } else {
            std.debug.print("  q={d:<6.3}  no data\n", .{q});
        }
    }

    std.debug.print("\nCDF estimates (expected ~ x for uniform):\n", .{});
    for (quantiles) |x| {
        if (try td.cdf(x)) |est| {
            const err = @abs(est - x);
            std.debug.print("  x={d:<6.3}  estimated={d:.6}  error={d:.6}\n", .{ x, est, err });
        } else {
            std.debug.print("  x={d:<6.3}  no data\n", .{x});
        }
    }

    // Test merge
    var td1 = tdigest.TDigest.init(allocator, 100.0);
    defer td1.deinit();
    var td2 = tdigest.TDigest.init(allocator, 100.0);
    defer td2.deinit();

    for (0..5000) |i| {
        try td1.add(@as(f64, @floatFromInt(i)) / 10000.0, 1.0);
    }
    for (5000..10000) |i| {
        try td2.add(@as(f64, @floatFromInt(i)) / 10000.0, 1.0);
    }
    try td1.mergeFrom(&td2);

    std.debug.print("\nAfter merge:\n", .{});
    if (try td1.quantile(0.5)) |v| {
        std.debug.print("  median={d:.6} (expected ~0.5)\n", .{v});
    }
    if (try td1.quantile(0.99)) |v| {
        std.debug.print("  p99   ={d:.6} (expected ~0.99)\n", .{v});
    }
}
