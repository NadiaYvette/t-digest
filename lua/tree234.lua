-- Generic array-backed 2-3-4 tree with monoidal measures.
--
-- Constructor takes a traits table with:
--   measure_fn(key)           - measure a single element
--   combine_fn(a, b)          - monoidal combine
--   identity_fn()             - monoidal identity
--   compare_fn(a, b)          - returns <0, 0, >0

local Tree234 = {}
Tree234.__index = Tree234

-- Create a new node table
local function make_node(identity)
    return {
        n = 0,
        keys = {},       -- keys[1..3]
        children = {0, 0, 0, 0},  -- 0 means no child
        measure = identity,
    }
end

function Tree234.new(traits)
    local self = setmetatable({}, Tree234)
    self.measure_fn = traits.measure_fn
    self.combine_fn = traits.combine_fn
    self.identity_fn = traits.identity_fn
    self.compare_fn = traits.compare_fn
    self.nodes = {}       -- array-backed node pool
    self.free_list = {}   -- stack of free node indices
    self.root = 0         -- 0 means no root
    self.count = 0
    return self
end

function Tree234:_alloc_node()
    local fl = self.free_list
    local idx
    if #fl > 0 then
        idx = fl[#fl]
        fl[#fl] = nil
        local nd = self.nodes[idx]
        nd.n = 0
        nd.keys = {}
        nd.children = {0, 0, 0, 0}
        nd.measure = self.identity_fn()
    else
        idx = #self.nodes + 1
        self.nodes[idx] = make_node(self.identity_fn())
    end
    return idx
end

function Tree234:_free_node(idx)
    self.free_list[#self.free_list + 1] = idx
end

function Tree234:_is_leaf(idx)
    return self.nodes[idx].children[1] == 0
end

function Tree234:_is_4node(idx)
    return self.nodes[idx].n == 3
end

function Tree234:_recompute_measure(idx)
    local nd = self.nodes[idx]
    local m = self.identity_fn()
    local combine = self.combine_fn
    local measure = self.measure_fn
    local nodes = self.nodes
    for i = 1, nd.n + 1 do
        local child = nd.children[i]
        if child ~= 0 then
            m = combine(m, nodes[child].measure)
        end
        if i <= nd.n then
            m = combine(m, measure(nd.keys[i]))
        end
    end
    nd.measure = m
end

-- Split a 4-node child at position child_pos of parent.
function Tree234:_split_child(parent_idx, child_pos)
    local nodes = self.nodes
    local child_idx = nodes[parent_idx].children[child_pos]

    -- Save child data before alloc_node may grow the pool
    local k1 = nodes[child_idx].keys[1]
    local k2 = nodes[child_idx].keys[2]
    local k3 = nodes[child_idx].keys[3]
    local c1 = nodes[child_idx].children[1]
    local c2 = nodes[child_idx].children[2]
    local c3 = nodes[child_idx].children[3]
    local c4 = nodes[child_idx].children[4]

    -- Create right node with k3, c3, c4
    local right_idx = self:_alloc_node()
    nodes = self.nodes  -- re-fetch after alloc
    nodes[right_idx].n = 1
    nodes[right_idx].keys[1] = k3
    nodes[right_idx].children[1] = c3
    nodes[right_idx].children[2] = c4

    -- Shrink child (left) to k1, c1, c2
    nodes[child_idx].n = 1
    nodes[child_idx].keys[1] = k1
    nodes[child_idx].keys[2] = nil
    nodes[child_idx].keys[3] = nil
    nodes[child_idx].children[1] = c1
    nodes[child_idx].children[2] = c2
    nodes[child_idx].children[3] = 0
    nodes[child_idx].children[4] = 0

    -- Recompute measures for left and right
    self:_recompute_measure(child_idx)
    self:_recompute_measure(right_idx)

    -- Insert mid_key (k2) into parent at child_pos
    local parent = nodes[parent_idx]
    for i = parent.n, child_pos, -1 do
        parent.keys[i + 1] = parent.keys[i]
        parent.children[i + 2] = parent.children[i + 1]
    end
    parent.keys[child_pos] = k2
    parent.children[child_pos + 1] = right_idx
    parent.n = parent.n + 1

    self:_recompute_measure(parent_idx)
end

-- Insert key into a non-full node's subtree.
function Tree234:_insert_non_full(idx, key)
    local nodes = self.nodes
    local nd = nodes[idx]

    if self:_is_leaf(idx) then
        -- Insert key in sorted position
        local pos = nd.n + 1
        while pos > 1 and self.compare_fn(key, nd.keys[pos - 1]) < 0 do
            nd.keys[pos] = nd.keys[pos - 1]
            pos = pos - 1
        end
        nd.keys[pos] = key
        nd.n = nd.n + 1
        self:_recompute_measure(idx)
        return
    end

    -- Find child to descend into
    local pos = 1
    while pos <= nd.n and self.compare_fn(key, nd.keys[pos]) >= 0 do
        pos = pos + 1
    end

    -- If that child is a 4-node, split it first
    if self:_is_4node(nd.children[pos]) then
        self:_split_child(idx, pos)
        -- After split, mid_key is at keys[pos]. Decide which side.
        nd = self.nodes[idx]  -- re-fetch
        if self.compare_fn(key, nd.keys[pos]) >= 0 then
            pos = pos + 1
        end
    end

    self:_insert_non_full(self.nodes[idx].children[pos], key)
    self:_recompute_measure(idx)
end

function Tree234:insert(key)
    if self.root == 0 then
        self.root = self:_alloc_node()
        local nd = self.nodes[self.root]
        nd.n = 1
        nd.keys[1] = key
        self:_recompute_measure(self.root)
        self.count = self.count + 1
        return
    end

    -- If root is a 4-node, split it
    if self:_is_4node(self.root) then
        local old_root = self.root
        self.root = self:_alloc_node()
        self.nodes[self.root].children[1] = old_root
        self:_split_child(self.root, 1)
    end

    self:_insert_non_full(self.root, key)
    self.count = self.count + 1
end

function Tree234:clear()
    self.nodes = {}
    self.free_list = {}
    self.root = 0
    self.count = 0
end

function Tree234:size()
    return self.count
end

function Tree234:root_measure()
    if self.root == 0 then
        return self.identity_fn()
    end
    return self.nodes[self.root].measure
end

-- In-order traversal, collecting keys into result table
function Tree234:_for_each_impl(idx, result)
    if idx == 0 then return end
    local nd = self.nodes[idx]
    for i = 1, nd.n + 1 do
        if nd.children[i] ~= 0 then
            self:_for_each_impl(nd.children[i], result)
        end
        if i <= nd.n then
            result[#result + 1] = nd.keys[i]
        end
    end
end

-- Collect all keys in-order into a new table
function Tree234:collect()
    local result = {}
    self:_for_each_impl(self.root, result)
    return result
end

-- Count elements in subtree
function Tree234:_subtree_count(idx)
    if idx == 0 then return 0 end
    local nd = self.nodes[idx]
    local c = nd.n
    for i = 1, nd.n + 1 do
        if nd.children[i] ~= 0 then
            c = c + self:_subtree_count(nd.children[i])
        end
    end
    return c
end

-- Find by weight: walks down tracking cumulative weight.
-- weight_of is a function that extracts weight from a measure.
-- Returns {key=, cum_before=, index=, found=}
function Tree234:find_by_weight(target, weight_of)
    if self.root == 0 then
        return {found = false}
    end
    return self:_find_by_weight_impl(self.root, target, 0.0, 0, weight_of)
end

function Tree234:_find_by_weight_impl(idx, target, cum, global_idx, weight_of)
    if idx == 0 then
        return {found = false}
    end

    local nd = self.nodes[idx]
    local running_cum = cum
    local running_idx = global_idx
    local nodes = self.nodes

    for i = 1, nd.n + 1 do
        -- Process child
        local child = nd.children[i]
        if child ~= 0 then
            local child_weight = weight_of(nodes[child].measure)
            if running_cum + child_weight >= target then
                return self:_find_by_weight_impl(child, target, running_cum,
                    running_idx, weight_of)
            end
            running_cum = running_cum + child_weight
            running_idx = running_idx + self:_subtree_count(child)
        end

        if i <= nd.n then
            local key_weight = weight_of(self.measure_fn(nd.keys[i]))
            if running_cum + key_weight >= target then
                return {
                    key = nd.keys[i],
                    cum_before = running_cum,
                    index = running_idx,
                    found = true,
                }
            end
            running_cum = running_cum + key_weight
            running_idx = running_idx + 1
        end
    end

    return {found = false}
end

-- Build balanced tree from sorted array
function Tree234:build_from_sorted(sorted)
    self:clear()
    if #sorted == 0 then return end
    self.count = #sorted
    self.root = self:_build_recursive(sorted, 1, #sorted + 1)
end

-- Build recursively from sorted[lo..hi-1] (half-open, 1-based)
function Tree234:_build_recursive(sorted, lo, hi)
    local n = hi - lo
    if n <= 0 then return 0 end

    if n <= 3 then
        local idx = self:_alloc_node()
        local nd = self.nodes[idx]
        nd.n = n
        for i = 1, n do
            nd.keys[i] = sorted[lo + i - 1]
        end
        self:_recompute_measure(idx)
        return idx
    end

    if n <= 7 then
        -- 2-node
        local mid = lo + math.floor(n / 2)
        local left = self:_build_recursive(sorted, lo, mid)
        local right = self:_build_recursive(sorted, mid + 1, hi)
        local idx = self:_alloc_node()
        local nd = self.nodes[idx]
        nd.n = 1
        nd.keys[1] = sorted[mid]
        nd.children[1] = left
        nd.children[2] = right
        self:_recompute_measure(idx)
        return idx
    end

    -- 3-node for larger ranges
    local third = math.floor(n / 3)
    local m1 = lo + third
    local m2 = lo + 2 * third + 1
    local c0 = self:_build_recursive(sorted, lo, m1)
    local c1 = self:_build_recursive(sorted, m1 + 1, m2)
    local c2 = self:_build_recursive(sorted, m2 + 1, hi)
    local idx = self:_alloc_node()
    local nd = self.nodes[idx]
    nd.n = 2
    nd.keys[1] = sorted[m1]
    nd.keys[2] = sorted[m2]
    nd.children[1] = c0
    nd.children[2] = c1
    nd.children[3] = c2
    self:_recompute_measure(idx)
    return idx
end

return Tree234
