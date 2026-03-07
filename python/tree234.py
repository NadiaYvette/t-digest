"""Generic array-backed 2-3-4 tree with monoidal measures.

Each node can hold 1, 2, or 3 keys (2-node, 3-node, 4-node).
Nodes are stored in a flat list with a free-list for reuse.
Measures are aggregated bottom-up for efficient weight-based lookups.
"""


class _Node:
    __slots__ = ['n', 'keys', 'children', 'measure']

    def __init__(self):
        self.n = 0
        self.keys = [None, None, None]
        self.children = [-1, -1, -1, -1]
        self.measure = None


class Tree234:
    """Array-backed 2-3-4 tree with monoidal measures."""

    def __init__(self, measure_fn, combine_fn, identity_fn, compare_fn):
        """
        measure_fn: key -> measure (leaf measure for a single key)
        combine_fn: (measure, measure) -> measure (monoidal combine)
        identity_fn: () -> measure (monoidal identity)
        compare_fn: (key, key) -> int (-1, 0, 1)
        """
        self._nodes = []
        self._free = []
        self._root = -1
        self._count = 0
        self._measure_fn = measure_fn
        self._combine = combine_fn
        self._identity = identity_fn
        self._compare = compare_fn

    # -- node allocation ---------------------------------------------------

    def _alloc(self):
        """Allocate a node, reusing from free list if possible."""
        if self._free:
            idx = self._free.pop()
            node = self._nodes[idx]
            node.n = 0
            node.keys = [None, None, None]
            node.children = [-1, -1, -1, -1]
            node.measure = None
            return idx
        idx = len(self._nodes)
        self._nodes.append(_Node())
        return idx

    def _nd(self, idx):
        return self._nodes[idx]

    def _is_leaf(self, idx):
        return self._nodes[idx].children[0] == -1

    # -- measure maintenance -----------------------------------------------

    def _recompute_measure(self, idx):
        """Recompute the aggregate measure for node idx from its children and keys."""
        nd = self._nodes[idx]
        m = self._identity()
        for i in range(nd.n + 1):
            if nd.children[i] != -1:
                m = self._combine(m, self._nodes[nd.children[i]].measure)
            if i < nd.n:
                m = self._combine(m, self._measure_fn(nd.keys[i]))
        nd.measure = m

    # -- public interface --------------------------------------------------

    def size(self):
        """Return the number of keys in the tree."""
        return self._count

    def root_measure(self):
        """Return the aggregate measure of the entire tree."""
        if self._root == -1:
            return self._identity()
        return self._nodes[self._root].measure

    def clear(self):
        """Remove all keys."""
        self._nodes.clear()
        self._free.clear()
        self._root = -1
        self._count = 0

    def insert(self, key):
        """Insert a key using top-down 4-node splitting."""
        if self._root == -1:
            self._root = self._alloc()
            nd = self._nd(self._root)
            nd.n = 1
            nd.keys[0] = key
            nd.measure = self._measure_fn(key)
            self._count = 1
            return

        # If root is a 4-node, split it
        if self._nodes[self._root].n == 3:
            old_root = self._root
            self._root = self._alloc()
            nd = self._nd(self._root)
            nd.n = 0
            nd.children[0] = old_root
            self._split_child(self._root, 0)

        self._insert_topdown(self._root, key)
        self._count += 1

    def to_list(self):
        """In-order traversal returning all keys as a list."""
        result = []
        if self._root != -1:
            self._inorder(self._root, result)
        return result

    def find_by_weight(self, target, weight_fn):
        """Walk down the tree tracking cumulative weight.

        weight_fn: measure -> float (extracts a scalar weight from a measure)

        Returns (key, cumulative_weight_before, in_order_index) or None.
        """
        if self._root == -1:
            return None
        return self._find_by_weight_rec(self._root, target, weight_fn, 0.0, 0)

    def find_neighbors(self, key, weight_fn):
        """Find a key's position and its in-order neighbors.

        weight_fn: measure -> float (extracts scalar weight)

        Returns a dict:
          'found': bool
          'node_key': the actual key object if found, else None
          'left': predecessor key or None
          'right': successor key or None
          'cum_weight': cumulative weight before found/insert position
          'index': in-order index of found key or insertion point
        """
        result = {
            'found': False,
            'node_key': None,
            'left': None,
            'right': None,
            'cum_weight': 0.0,
            'index': 0,
        }
        if self._root != -1:
            self._find_neighbors_rec(self._root, key, weight_fn, result, 0.0, 0)
        return result

    def update_measures_for_key(self, key_obj, weight_fn):
        """Given a key object already in the tree (identity match), recompute
        measures on the path from that key to the root.

        key_obj must be the exact object (is-check) stored in the tree.
        Returns True if found and updated.
        """
        if self._root == -1:
            return False
        return self._update_measures_rec(self._root, key_obj, weight_fn)

    # -- top-down insert internals -----------------------------------------

    def _split_child(self, parent_idx, child_pos):
        """Split a 4-node child at child_pos, pushing middle key to parent."""
        parent = self._nd(parent_idx)
        child_idx = parent.children[child_pos]
        child = self._nd(child_idx)

        mid_key = child.keys[1]

        # Create right sibling with key[2] and children[2..3]
        right_idx = self._alloc()
        right = self._nd(right_idx)
        right.n = 1
        right.keys[0] = child.keys[2]
        right.children[0] = child.children[2]
        right.children[1] = child.children[3]

        # Shrink child to keep only key[0] and children[0..1]
        child.n = 1
        child.keys[1] = None
        child.keys[2] = None
        child.children[2] = -1
        child.children[3] = -1

        # Make room in parent
        for i in range(parent.n, child_pos, -1):
            parent.keys[i] = parent.keys[i - 1]
        for i in range(parent.n + 1, child_pos + 1, -1):
            parent.children[i] = parent.children[i - 1]

        parent.keys[child_pos] = mid_key
        parent.children[child_pos + 1] = right_idx
        parent.n += 1

        self._recompute_measure(child_idx)
        self._recompute_measure(right_idx)
        self._recompute_measure(parent_idx)

    def _insert_topdown(self, idx, key):
        """Recursively insert into a non-full node, splitting 4-node children
        on the way down."""
        nd = self._nd(idx)

        if self._is_leaf(idx):
            # Find insertion position
            pos = nd.n
            for i in range(nd.n):
                if self._compare(key, nd.keys[i]) <= 0:
                    pos = i
                    break
            # Shift keys right
            for i in range(nd.n, pos, -1):
                nd.keys[i] = nd.keys[i - 1]
            nd.keys[pos] = key
            nd.n += 1
            self._recompute_measure(idx)
            return

        # Find child to descend into
        pos = nd.n
        for i in range(nd.n):
            if self._compare(key, nd.keys[i]) <= 0:
                pos = i
                break

        child_idx = nd.children[pos]

        # Pre-split if child is a 4-node
        if self._nodes[child_idx].n == 3:
            self._split_child(idx, pos)
            # Decide which side of the promoted key to go
            if self._compare(key, nd.keys[pos]) > 0:
                pos += 1
            child_idx = nd.children[pos]

        self._insert_topdown(child_idx, key)
        self._recompute_measure(idx)

    # -- traversal ---------------------------------------------------------

    def _inorder(self, idx, result):
        nd = self._nodes[idx]
        for i in range(nd.n):
            if nd.children[i] != -1:
                self._inorder(nd.children[i], result)
            result.append(nd.keys[i])
        if nd.children[nd.n] != -1:
            self._inorder(nd.children[nd.n], result)

    # -- weight-based search -----------------------------------------------

    def _find_by_weight_rec(self, idx, target, weight_fn, cum, io_idx):
        nd = self._nodes[idx]
        for i in range(nd.n):
            # Add left child subtree weight
            if nd.children[i] != -1:
                child_w = weight_fn(self._nodes[nd.children[i]].measure)
                if cum + child_w >= target:
                    return self._find_by_weight_rec(
                        nd.children[i], target, weight_fn, cum, io_idx)
                cum += child_w
                io_idx += self._subtree_size(nd.children[i])
            # Check this key
            key_w = weight_fn(self._measure_fn(nd.keys[i]))
            if cum + key_w >= target:
                return (nd.keys[i], cum, io_idx)
            cum += key_w
            io_idx += 1

        # Last child
        if nd.children[nd.n] != -1:
            return self._find_by_weight_rec(
                nd.children[nd.n], target, weight_fn, cum, io_idx)

        # Edge case: target exceeds total weight; return last key
        return (nd.keys[nd.n - 1], cum - weight_fn(self._measure_fn(nd.keys[nd.n - 1])),
                io_idx - 1)

    def _subtree_size(self, idx):
        """Count total keys in subtree. Uses the measure's count field if
        available, otherwise walks the tree."""
        if idx == -1:
            return 0
        # Try to use the count component of measure
        m = self._nodes[idx].measure
        if hasattr(m, 'count'):
            return m.count
        # Fallback: walk
        nd = self._nodes[idx]
        c = nd.n
        for i in range(nd.n + 1):
            if nd.children[i] != -1:
                c += self._subtree_size(nd.children[i])
        return c

    # -- neighbor finding --------------------------------------------------

    def _find_neighbors_rec(self, idx, key, weight_fn, result, cum, io_idx):
        nd = self._nodes[idx]
        for i in range(nd.n):
            # Left child
            if nd.children[i] != -1:
                child_w = weight_fn(self._nodes[nd.children[i]].measure)
                child_sz = self._subtree_size(nd.children[i])
            else:
                child_w = 0.0
                child_sz = 0

            cmp = self._compare(key, nd.keys[i])

            if cmp < 0:
                # key < nd.keys[i]: answer is in left subtree
                result['right'] = nd.keys[i]
                if nd.children[i] != -1:
                    self._find_neighbors_rec(
                        nd.children[i], key, weight_fn, result, cum, io_idx)
                else:
                    result['cum_weight'] = cum
                    result['index'] = io_idx
                return

            if cmp == 0:
                # Found
                cum += child_w
                io_idx += child_sz
                result['found'] = True
                result['node_key'] = nd.keys[i]
                result['cum_weight'] = cum
                result['index'] = io_idx

                # Left neighbor: rightmost in left subtree or last tracked
                if nd.children[i] != -1:
                    result['left'] = self._rightmost(nd.children[i])

                # Right neighbor: leftmost in right subtree or next key
                right_child = nd.children[i + 1] if i + 1 <= nd.n else -1
                if right_child != -1:
                    result['right'] = self._leftmost(right_child)
                elif i + 1 < nd.n:
                    result['right'] = nd.keys[i + 1]
                return

            # cmp > 0: key > nd.keys[i], continue right
            cum += child_w
            io_idx += child_sz

            result['left'] = nd.keys[i]
            cum += weight_fn(self._measure_fn(nd.keys[i]))
            io_idx += 1

        # Descended past all keys; check last child
        if nd.children[nd.n] != -1:
            self._find_neighbors_rec(
                nd.children[nd.n], key, weight_fn, result, cum, io_idx)
        else:
            result['cum_weight'] = cum
            result['index'] = io_idx

    def _rightmost(self, idx):
        """Return the rightmost key in the subtree rooted at idx."""
        nd = self._nodes[idx]
        if nd.children[nd.n] != -1:
            return self._rightmost(nd.children[nd.n])
        return nd.keys[nd.n - 1]

    def _leftmost(self, idx):
        """Return the leftmost key in the subtree rooted at idx."""
        nd = self._nodes[idx]
        if nd.children[0] != -1:
            return self._leftmost(nd.children[0])
        return nd.keys[0]

    # -- in-place key update -----------------------------------------------

    def _update_measures_rec(self, idx, key_obj, weight_fn):
        """Find key_obj by identity (is-check) and recompute measures upward."""
        nd = self._nodes[idx]
        for i in range(nd.n):
            if nd.keys[i] is key_obj:
                self._recompute_measure(idx)
                return True

            cmp = self._compare(key_obj, nd.keys[i])
            if cmp < 0:
                if nd.children[i] != -1:
                    if self._update_measures_rec(nd.children[i], key_obj, weight_fn):
                        self._recompute_measure(idx)
                        return True
                return False

            # cmp >= 0: might be equal but different object, or greater
            if cmp == 0:
                # Same sort key but different object; could be in left subtree
                if nd.children[i] != -1:
                    if self._update_measures_rec(nd.children[i], key_obj, weight_fn):
                        self._recompute_measure(idx)
                        return True

        # Check last child
        if nd.children[nd.n] != -1:
            if self._update_measures_rec(nd.children[nd.n], key_obj, weight_fn):
                self._recompute_measure(idx)
                return True
        return False
