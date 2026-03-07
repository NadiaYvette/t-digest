// Generic array-backed 2-3-4 tree with monoidal measures.
//
// Type parameters (via comptime Traits struct):
//   K      - key/element type (stored in sorted order)
//   M      - measure type (monoidal annotation on subtrees)
//   Traits - a struct providing:
//       fn measure(K) M              - measure a single element
//       fn combine(M, M) M           - monoidal combine
//       fn identity() M              - monoidal identity
//       fn compare(K, K) i32         - <0, 0, >0

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Tree234(comptime K: type, comptime M: type, comptime Traits: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            n: u8, // number of keys: 1, 2, or 3
            keys: [3]K,
            children: [4]i32,
            measure: M,

            fn init() Node {
                return .{
                    .n = 0,
                    .keys = undefined,
                    .children = .{ -1, -1, -1, -1 },
                    .measure = Traits.identity(),
                };
            }
        };

        pub const WeightResult = struct {
            key: K,
            cum_before: f64,
            index: i32,
            found: bool,
        };

        nodes: std.ArrayListUnmanaged(Node),
        free_list: std.ArrayListUnmanaged(i32),
        root: i32,
        count: i32,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{
                .nodes = .empty,
                .free_list = .empty,
                .root = -1,
                .count = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.nodes.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        fn allocNode(self: *Self) !i32 {
            if (self.free_list.items.len > 0) {
                const idx = self.free_list.items[self.free_list.items.len - 1];
                self.free_list.items.len -= 1;
                self.nodes.items[@intCast(@as(u32, @bitCast(idx)))] = Node.init();
                return idx;
            } else {
                const idx: i32 = @intCast(self.nodes.items.len);
                try self.nodes.append(self.allocator, Node.init());
                return idx;
            }
        }

        fn ix(self: *const Self, idx: i32) *Node {
            return &self.nodes.items[@intCast(@as(u32, @bitCast(idx)))];
        }

        fn ixConst(self: *const Self, idx: i32) *const Node {
            return &self.nodes.items[@intCast(@as(u32, @bitCast(idx)))];
        }

        fn isLeaf(self: *const Self, idx: i32) bool {
            return self.ixConst(idx).children[0] == -1;
        }

        fn is4Node(self: *const Self, idx: i32) bool {
            return self.ixConst(idx).n == 3;
        }

        fn recomputeMeasure(self: *Self, idx: i32) void {
            const nd = self.ixConst(idx);
            var m = Traits.identity();
            for (0..@as(usize, nd.n) + 1) |i| {
                if (nd.children[i] != -1) {
                    m = Traits.combine(m, self.ixConst(nd.children[i]).measure);
                }
                if (i < nd.n) {
                    m = Traits.combine(m, Traits.measure(nd.keys[i]));
                }
            }
            self.ix(idx).measure = m;
        }

        // Split a 4-node child at position child_pos of parent.
        fn splitChild(self: *Self, parent_idx: i32, child_pos: usize) !void {
            const child_idx = self.ixConst(parent_idx).children[child_pos];

            // Save child data before allocNode may invalidate pointers
            const k0 = self.ixConst(child_idx).keys[0];
            const k1 = self.ixConst(child_idx).keys[1];
            const k2 = self.ixConst(child_idx).keys[2];
            const c0 = self.ixConst(child_idx).children[0];
            const c1 = self.ixConst(child_idx).children[1];
            const c2 = self.ixConst(child_idx).children[2];
            const c3 = self.ixConst(child_idx).children[3];

            // Create right node with k2, c2, c3
            const right_idx = try self.allocNode();
            // After allocNode, re-access by index
            self.ix(right_idx).n = 1;
            self.ix(right_idx).keys[0] = k2;
            self.ix(right_idx).children[0] = c2;
            self.ix(right_idx).children[1] = c3;

            // Shrink child (left) to k0, c0, c1
            self.ix(child_idx).n = 1;
            self.ix(child_idx).keys[0] = k0;
            self.ix(child_idx).children[0] = c0;
            self.ix(child_idx).children[1] = c1;
            self.ix(child_idx).children[2] = -1;
            self.ix(child_idx).children[3] = -1;

            // Recompute measures for left and right
            self.recomputeMeasure(child_idx);
            self.recomputeMeasure(right_idx);

            // Insert mid_key (k1) into parent at child_pos
            const parent_n = self.ixConst(parent_idx).n;
            {
                var i: usize = parent_n;
                while (i > child_pos) : (i -= 1) {
                    self.ix(parent_idx).keys[i] = self.ixConst(parent_idx).keys[i - 1];
                    self.ix(parent_idx).children[i + 1] = self.ixConst(parent_idx).children[i];
                }
            }
            self.ix(parent_idx).keys[child_pos] = k1;
            self.ix(parent_idx).children[child_pos + 1] = right_idx;
            self.ix(parent_idx).n += 1;

            self.recomputeMeasure(parent_idx);
        }

        // Insert key into a non-full node's subtree.
        fn insertNonFull(self: *Self, idx: i32, key: K) !void {
            if (self.isLeaf(idx)) {
                // Insert key in sorted position
                var pos: usize = self.ixConst(idx).n;
                while (pos > 0 and Traits.compare(key, self.ixConst(idx).keys[pos - 1]) < 0) {
                    self.ix(idx).keys[pos] = self.ixConst(idx).keys[pos - 1];
                    pos -= 1;
                }
                self.ix(idx).keys[pos] = key;
                self.ix(idx).n += 1;
                self.recomputeMeasure(idx);
                return;
            }

            // Find child to descend into
            var pos: usize = 0;
            while (pos < self.ixConst(idx).n and Traits.compare(key, self.ixConst(idx).keys[pos]) >= 0) {
                pos += 1;
            }

            // If that child is a 4-node, split it first
            if (self.is4Node(self.ixConst(idx).children[pos])) {
                try self.splitChild(idx, pos);
                // After split, mid_key is at keys[pos]. Decide which side.
                if (Traits.compare(key, self.ixConst(idx).keys[pos]) >= 0) {
                    pos += 1;
                }
            }

            try self.insertNonFull(self.ixConst(idx).children[pos], key);
            self.recomputeMeasure(idx);
        }

        pub fn insert(self: *Self, key: K) !void {
            if (self.root == -1) {
                self.root = try self.allocNode();
                self.ix(self.root).n = 1;
                self.ix(self.root).keys[0] = key;
                self.recomputeMeasure(self.root);
                self.count += 1;
                return;
            }

            // If root is a 4-node, split it.
            if (self.is4Node(self.root)) {
                const old_root = self.root;
                self.root = try self.allocNode();
                self.ix(self.root).children[0] = old_root;
                try self.splitChild(self.root, 0);
            }

            try self.insertNonFull(self.root, key);
            self.count += 1;
        }

        pub fn clear(self: *Self) void {
            self.nodes.clearRetainingCapacity();
            self.free_list.clearRetainingCapacity();
            self.root = -1;
            self.count = 0;
        }

        pub fn size(self: *const Self) i32 {
            return self.count;
        }

        pub fn rootMeasure(self: *const Self) M {
            if (self.root == -1) return Traits.identity();
            return self.ixConst(self.root).measure;
        }

        // In-order traversal
        fn forEachImpl(self: *const Self, idx: i32, callback: anytype) void {
            if (idx == -1) return;
            const nd = self.ixConst(idx);
            for (0..@as(usize, nd.n) + 1) |i| {
                if (nd.children[i] != -1) {
                    self.forEachImpl(nd.children[i], callback);
                }
                if (i < nd.n) {
                    callback.call(nd.keys[i]);
                }
            }
        }

        // Collect all keys in-order into a slice
        pub fn collect(self: *const Self, out: *std.ArrayListUnmanaged(K), allocator: Allocator) !void {
            out.clearRetainingCapacity();
            try out.ensureTotalCapacity(allocator, @intCast(@as(u32, @bitCast(self.count))));
            self.collectImpl(self.root, out);
        }

        fn collectImpl(self: *const Self, idx: i32, out: *std.ArrayListUnmanaged(K)) void {
            if (idx == -1) return;
            const nd = self.ixConst(idx);
            for (0..@as(usize, nd.n) + 1) |i| {
                if (nd.children[i] != -1) {
                    self.collectImpl(nd.children[i], out);
                }
                if (i < nd.n) {
                    // We already ensured capacity, so this won't fail
                    out.appendAssumeCapacity(nd.keys[i]);
                }
            }
        }

        fn subtreeCount(self: *const Self, idx: i32) i32 {
            if (idx == -1) return 0;
            const nd = self.ixConst(idx);
            var c: i32 = @intCast(nd.n);
            for (0..@as(usize, nd.n) + 1) |i| {
                if (nd.children[i] != -1) {
                    c += self.subtreeCount(nd.children[i]);
                }
            }
            return c;
        }

        pub fn findByWeight(self: *const Self, target: f64, comptime weightOf: fn (M) f64) WeightResult {
            if (self.root == -1) return .{ .key = undefined, .cum_before = 0, .index = 0, .found = false };
            return self.findByWeightImpl(self.root, target, 0.0, 0, weightOf);
        }

        fn findByWeightImpl(self: *const Self, idx: i32, target: f64, cum: f64, global_idx: i32, comptime weightOf: fn (M) f64) WeightResult {
            if (idx == -1) return .{ .key = undefined, .cum_before = 0, .index = 0, .found = false };

            const nd = self.ixConst(idx);
            var running_cum = cum;
            var running_idx = global_idx;

            for (0..@as(usize, nd.n) + 1) |i| {
                // Process child
                if (nd.children[i] != -1) {
                    const child_weight = weightOf(self.ixConst(nd.children[i]).measure);
                    if (running_cum + child_weight >= target) {
                        return self.findByWeightImpl(nd.children[i], target, running_cum, running_idx, weightOf);
                    }
                    running_cum += child_weight;
                    running_idx += self.subtreeCount(nd.children[i]);
                }

                if (i < nd.n) {
                    const key_weight = weightOf(Traits.measure(nd.keys[i]));
                    if (running_cum + key_weight >= target) {
                        return .{ .key = nd.keys[i], .cum_before = running_cum, .index = running_idx, .found = true };
                    }
                    running_cum += key_weight;
                    running_idx += 1;
                }
            }

            return .{ .key = undefined, .cum_before = 0, .index = 0, .found = false };
        }

        pub fn buildFromSorted(self: *Self, sorted: []const K) !void {
            self.clear();
            if (sorted.len == 0) return;
            self.count = @intCast(sorted.len);
            self.root = try self.buildRecursive(sorted, 0, @intCast(sorted.len));
        }

        fn buildRecursive(self: *Self, sorted: []const K, lo: i32, hi: i32) !i32 {
            const n = hi - lo;
            if (n <= 0) return -1;

            if (n <= 3) {
                const idx = try self.allocNode();
                self.ix(idx).n = @intCast(@as(u32, @bitCast(n)));
                for (0..@as(usize, @intCast(@as(u32, @bitCast(n))))) |i| {
                    self.ix(idx).keys[i] = sorted[@intCast(@as(u32, @bitCast(lo + @as(i32, @intCast(i)))))];
                }
                self.recomputeMeasure(idx);
                return idx;
            }

            if (n <= 7) {
                const mid = lo + @divTrunc(n, 2);
                const left = try self.buildRecursive(sorted, lo, mid);
                const right = try self.buildRecursive(sorted, mid + 1, hi);
                const idx = try self.allocNode();
                self.ix(idx).n = 1;
                self.ix(idx).keys[0] = sorted[@intCast(@as(u32, @bitCast(mid)))];
                self.ix(idx).children[0] = left;
                self.ix(idx).children[1] = right;
                self.recomputeMeasure(idx);
                return idx;
            }

            // For larger ranges, use 3-node
            const third = @divTrunc(n, 3);
            const m1 = lo + third;
            const m2 = lo + 2 * third + 1;
            const c0 = try self.buildRecursive(sorted, lo, m1);
            const c1 = try self.buildRecursive(sorted, m1 + 1, m2);
            const c2 = try self.buildRecursive(sorted, m2 + 1, hi);
            const idx = try self.allocNode();
            self.ix(idx).n = 2;
            self.ix(idx).keys[0] = sorted[@intCast(@as(u32, @bitCast(m1)))];
            self.ix(idx).keys[1] = sorted[@intCast(@as(u32, @bitCast(m2)))];
            self.ix(idx).children[0] = c0;
            self.ix(idx).children[1] = c1;
            self.ix(idx).children[2] = c2;
            self.recomputeMeasure(idx);
            return idx;
        }
    };
}
