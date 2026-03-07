// Dunning t-digest for online quantile estimation.
// Merging digest variant with K_1 (arcsine) scale function.
// Uses an array-backed 2-3-4 tree with monoidal measures.

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const tree234 = @import("tree234.zig");

pub const Centroid = struct {
    mean: f64,
    weight: f64,
};

pub const TdMeasure = struct {
    weight: f64 = 0,
    count: i32 = 0,
    max_mean: f64 = -math.inf(f64),
    mean_weight_sum: f64 = 0,
};

pub const CentroidTraits = struct {
    pub fn measure(c: Centroid) TdMeasure {
        return .{
            .weight = c.weight,
            .count = 1,
            .max_mean = c.mean,
            .mean_weight_sum = c.mean * c.weight,
        };
    }
    pub fn combine(a: TdMeasure, b: TdMeasure) TdMeasure {
        return .{
            .weight = a.weight + b.weight,
            .count = a.count + b.count,
            .max_mean = @max(a.max_mean, b.max_mean),
            .mean_weight_sum = a.mean_weight_sum + b.mean_weight_sum,
        };
    }
    pub fn identity() TdMeasure {
        return .{
            .weight = 0,
            .count = 0,
            .max_mean = -math.inf(f64),
            .mean_weight_sum = 0,
        };
    }
    pub fn compare(a: Centroid, b: Centroid) i32 {
        if (a.mean < b.mean) return -1;
        if (a.mean > b.mean) return 1;
        return 0;
    }
};

const CentroidTree = tree234.Tree234(Centroid, TdMeasure, CentroidTraits);

pub const default_delta: f64 = 100.0;
const buffer_factor: usize = 5;

fn weightOf(m: TdMeasure) f64 {
    return m.weight;
}

pub const TDigest = struct {
    delta: f64,
    tree: CentroidTree,
    buf: std.ArrayListUnmanaged(Centroid),
    total_weight: f64,
    min_val: f64,
    max_val: f64,
    buffer_cap: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, delta: f64) TDigest {
        const cap: usize = @intFromFloat(@ceil(delta * @as(f64, @floatFromInt(buffer_factor))));
        return TDigest{
            .delta = delta,
            .tree = CentroidTree.init(allocator),
            .buf = .empty,
            .total_weight = 0.0,
            .min_val = math.inf(f64),
            .max_val = -math.inf(f64),
            .buffer_cap = cap,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TDigest) void {
        self.tree.deinit();
        self.buf.deinit(self.allocator);
    }

    fn k(self: *const TDigest, q: f64) f64 {
        return (self.delta / (2.0 * math.pi)) * math.asin(2.0 * q - 1.0);
    }

    fn mergeIntoLast(centroids: *std.ArrayListUnmanaged(Centroid), c: Centroid) void {
        const last = &centroids.items[centroids.items.len - 1];
        const new_weight = last.weight + c.weight;
        last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight;
        last.weight = new_weight;
    }

    pub fn compress(self: *TDigest) !void {
        if (self.buf.items.len == 0 and self.tree.size() <= 1) return;

        // Collect all centroids from tree and buffer
        var all: std.ArrayListUnmanaged(Centroid) = .empty;
        defer all.deinit(self.allocator);

        const tree_size: usize = @intCast(@as(u32, @bitCast(self.tree.size())));
        try all.ensureTotalCapacity(self.allocator, tree_size + self.buf.items.len);

        try self.tree.collect(&all, self.allocator);
        for (self.buf.items) |c_item| {
            all.appendAssumeCapacity(c_item);
        }
        self.buf.clearRetainingCapacity();

        std.mem.sort(Centroid, all.items, {}, struct {
            fn lessThan(_: void, a: Centroid, b: Centroid) bool {
                return a.mean < b.mean;
            }
        }.lessThan);

        // Merge centroids according to K1 scale function
        var merged: std.ArrayListUnmanaged(Centroid) = .empty;
        defer merged.deinit(self.allocator);
        try merged.ensureTotalCapacity(self.allocator, all.items.len);
        merged.appendAssumeCapacity(.{ .mean = all.items[0].mean, .weight = all.items[0].weight });

        var weight_so_far: f64 = 0.0;
        const n = self.total_weight;

        for (all.items[1..]) |item| {
            const last_idx = merged.items.len - 1;
            const proposed = merged.items[last_idx].weight + item.weight;
            const q0 = weight_so_far / n;
            const q1 = (weight_so_far + proposed) / n;

            if ((proposed <= 1.0 and all.items.len > 1) or (self.k(q1) - self.k(q0) <= 1.0)) {
                mergeIntoLast(&merged, item);
            } else {
                weight_so_far += merged.items[last_idx].weight;
                merged.appendAssumeCapacity(.{ .mean = item.mean, .weight = item.weight });
            }
        }

        // Rebuild tree from sorted merged centroids
        try self.tree.buildFromSorted(merged.items);
    }

    pub fn add(self: *TDigest, value: f64, weight: f64) !void {
        try self.buf.append(self.allocator, Centroid{ .mean = value, .weight = weight });
        self.total_weight += weight;
        if (value < self.min_val) self.min_val = value;
        if (value > self.max_val) self.max_val = value;
        if (self.buf.items.len >= self.buffer_cap) {
            try self.compress();
        }
    }

    pub fn quantile(self: *TDigest, q_in: f64) !?f64 {
        if (self.buf.items.len > 0) try self.compress();
        if (self.tree.size() == 0) return null;
        if (self.tree.size() == 1) {
            // Single centroid - find it via weight search
            const result = self.tree.findByWeight(0.0, weightOf);
            if (result.found) return result.key.mean;
            return null;
        }

        const q = @max(0.0, @min(1.0, q_in));
        const n = self.total_weight;
        const target = q * n;

        // Collect centroids for interpolation
        var centroids: std.ArrayListUnmanaged(Centroid) = .empty;
        defer centroids.deinit(self.allocator);
        try self.tree.collect(&centroids, self.allocator);
        const sz = centroids.items.len;

        // Build prefix sums for cumulative weights
        var cum = try std.ArrayListUnmanaged(f64).initCapacity(self.allocator, sz);
        defer cum.deinit(self.allocator);
        cum.appendAssumeCapacity(centroids.items[0].weight);
        for (1..sz) |i| {
            cum.appendAssumeCapacity(cum.items[i - 1] + centroids.items[i].weight);
        }

        // Handle first centroid edge case
        const first = centroids.items[0];
        if (target < first.weight / 2.0) {
            if (first.weight == 1.0) return self.min_val;
            return self.min_val + (first.mean - self.min_val) * (target / (first.weight / 2.0));
        }

        // Handle last centroid edge case
        const last = centroids.items[sz - 1];
        if (target > n - last.weight / 2.0) {
            if (last.weight == 1.0) return self.max_val;
            const remaining = n - last.weight / 2.0;
            return last.mean + (self.max_val - last.mean) * ((target - remaining) / (last.weight / 2.0));
        }

        // Find the centroid whose cumulative weight range contains target
        var idx: usize = 0;
        {
            var lo: usize = 0;
            var hi: usize = sz - 1;
            while (lo < hi) {
                const mid = (lo + hi) / 2;
                if (cum.items[mid] < target) {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            idx = lo;
        }

        if (idx >= sz - 1) idx = sz - 2;

        const cumulative = if (idx > 0) cum.items[idx - 1] else 0.0;
        const c = centroids.items[idx];
        const mid_val = cumulative + c.weight / 2.0;

        if (idx > 0 and target < mid_val) {
            const prev_idx = idx - 1;
            const prev_cumulative = if (prev_idx > 0) cum.items[prev_idx - 1] else 0.0;
            const c2 = centroids.items[prev_idx];
            const mid2 = prev_cumulative + c2.weight / 2.0;
            const next_c = centroids.items[prev_idx + 1];
            const next_mid = prev_cumulative + c2.weight + next_c.weight / 2.0;
            const frac = if (next_mid == mid2) 0.5 else (target - mid2) / (next_mid - mid2);
            return c2.mean + frac * (next_c.mean - c2.mean);
        }

        if (idx == sz - 1) return c.mean;

        const next_c = centroids.items[idx + 1];
        const next_mid = cumulative + c.weight + next_c.weight / 2.0;

        if (target <= next_mid) {
            const frac = if (next_mid == mid_val) 0.5 else (target - mid_val) / (next_mid - mid_val);
            return c.mean + frac * (next_c.mean - c.mean);
        }

        return self.max_val;
    }

    pub fn cdf(self: *TDigest, x: f64) !?f64 {
        if (self.buf.items.len > 0) try self.compress();
        if (self.tree.size() == 0) return null;
        if (x <= self.min_val) return 0.0;
        if (x >= self.max_val) return 1.0;

        // Collect centroids for interpolation
        var centroids: std.ArrayListUnmanaged(Centroid) = .empty;
        defer centroids.deinit(self.allocator);
        try self.tree.collect(&centroids, self.allocator);
        const sz = centroids.items.len;
        const n = self.total_weight;

        // Build prefix sums
        var cum = try std.ArrayListUnmanaged(f64).initCapacity(self.allocator, sz);
        defer cum.deinit(self.allocator);
        cum.appendAssumeCapacity(centroids.items[0].weight);
        for (1..sz) |i| {
            cum.appendAssumeCapacity(cum.items[i - 1] + centroids.items[i].weight);
        }

        // Binary search for position
        var pos: usize = sz;
        {
            var lo: usize = 0;
            var hi: usize = sz;
            while (lo < hi) {
                const mid = (lo + hi) / 2;
                if (centroids.items[mid].mean < x) {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            pos = lo;
        }

        // x is less than the first centroid's mean
        if (pos == 0) {
            const c = centroids.items[0];
            if (x < c.mean) {
                const inner_w = c.weight / 2.0;
                const frac = if (c.mean == self.min_val) 1.0 else (x - self.min_val) / (c.mean - self.min_val);
                return (inner_w * frac) / n;
            }
            return (c.weight / 2.0) / n;
        }

        // x is >= all centroid means
        if (pos == sz) {
            const c = centroids.items[sz - 1];
            const cumulative = if (sz > 1) cum.items[sz - 2] else 0.0;
            if (x > c.mean) {
                const right_w = n - cumulative - c.weight / 2.0;
                const frac = if (self.max_val == c.mean) 0.0 else (x - c.mean) / (self.max_val - c.mean);
                return (cumulative + c.weight / 2.0 + right_w * frac) / n;
            }
            return (cumulative + c.weight / 2.0) / n;
        }

        // x is between centroids[pos-1].mean and centroids[pos].mean
        const i = pos - 1;
        const c = centroids.items[i];
        const next_c = centroids.items[pos];

        const cumulative = if (i > 0) cum.items[i - 1] else 0.0;
        const mid_val = cumulative + c.weight / 2.0;
        const next_cumulative = cumulative + c.weight;
        const next_mid = next_cumulative + next_c.weight / 2.0;

        if (i == sz - 1) {
            if (x > c.mean) {
                const right_w = n - cumulative - c.weight / 2.0;
                const frac = if (self.max_val == c.mean) 0.0 else (x - c.mean) / (self.max_val - c.mean);
                return (cumulative + c.weight / 2.0 + right_w * frac) / n;
            }
            return (cumulative + c.weight / 2.0) / n;
        }

        if (x < next_c.mean) {
            if (c.mean == next_c.mean) {
                return (mid_val + (next_mid - mid_val) / 2.0) / n;
            }
            const frac = (x - c.mean) / (next_c.mean - c.mean);
            return (mid_val + frac * (next_mid - mid_val)) / n;
        }

        return next_mid / n;
    }

    pub fn mergeFrom(self: *TDigest, other: *TDigest) !void {
        if (other.buf.items.len > 0) try other.compress();
        var other_centroids: std.ArrayListUnmanaged(Centroid) = .empty;
        defer other_centroids.deinit(self.allocator);
        try other.tree.collect(&other_centroids, self.allocator);
        for (other_centroids.items) |c| {
            try self.add(c.mean, c.weight);
        }
    }

    pub fn centroidCount(self: *TDigest) !usize {
        if (self.buf.items.len > 0) try self.compress();
        return @intCast(@as(u32, @bitCast(self.tree.size())));
    }
};
