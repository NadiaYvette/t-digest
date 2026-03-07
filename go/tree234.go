// Package tdigest provides a generic array-backed 2-3-4 tree with monoidal
// measures. The tree supports top-down insertion (splitting 4-nodes on the
// way down), in-order traversal, weight-based search, and neighbor finding.
package tdigest

// MeasureOps defines the operations needed for a monoidal measure over keys.
type MeasureOps[K any, M any] struct {
	Measure  func(K) M
	Combine  func(M, M) M
	Identity func() M
	Compare  func(K, K) int
}

// node234 is an internal node in the 2-3-4 tree, stored in a flat array.
// n is the number of keys (1, 2, or 3). children[i] == -1 means no child.
type node234[K any, M any] struct {
	n        int
	keys     [3]K
	children [4]int32
	measure  M
}

// Tree234 is a generic array-backed 2-3-4 tree with monoidal measures.
type Tree234[K any, M any] struct {
	nodes    []node234[K, M]
	freeList []int32
	root     int32
	count    int
	ops      MeasureOps[K, M]
}

// NeighborResult holds the result of a neighbor search.
type NeighborResult[K any] struct {
	HasPred bool
	Pred    K
	HasSucc bool
	Succ    K
	Found   bool // whether exact match was found
	Key     K    // the exact match if Found
}

// NewTree234 creates a new empty 2-3-4 tree with the given measure operations.
func NewTree234[K any, M any](ops MeasureOps[K, M]) *Tree234[K, M] {
	return &Tree234[K, M]{
		root: -1,
		ops:  ops,
	}
}

// Size returns the number of keys in the tree.
func (t *Tree234[K, M]) Size() int {
	return t.count
}

// Clear removes all keys from the tree.
func (t *Tree234[K, M]) Clear() {
	t.nodes = t.nodes[:0]
	t.freeList = t.freeList[:0]
	t.root = -1
	t.count = 0
}

// RootMeasure returns the monoidal measure of the entire tree.
func (t *Tree234[K, M]) RootMeasure() M {
	if t.root == -1 {
		return t.ops.Identity()
	}
	return t.nodes[t.root].measure
}

// allocNode allocates a new node, reusing from free list if possible.
func (t *Tree234[K, M]) allocNode() int32 {
	if len(t.freeList) > 0 {
		idx := t.freeList[len(t.freeList)-1]
		t.freeList = t.freeList[:len(t.freeList)-1]
		nd := &t.nodes[idx]
		nd.n = 0
		nd.children = [4]int32{-1, -1, -1, -1}
		nd.measure = t.ops.Identity()
		return idx
	}
	idx := int32(len(t.nodes))
	t.nodes = append(t.nodes, node234[K, M]{
		children: [4]int32{-1, -1, -1, -1},
		measure:  t.ops.Identity(),
	})
	return idx
}

// freeNode returns a node to the free list.
func (t *Tree234[K, M]) freeNode(idx int32) {
	t.freeList = append(t.freeList, idx)
}

// isLeaf returns true if the node has no children.
func (t *Tree234[K, M]) isLeaf(idx int32) bool {
	return t.nodes[idx].children[0] == -1
}

// isFull returns true if the node has 3 keys (a 4-node).
func (t *Tree234[K, M]) isFull(idx int32) bool {
	return t.nodes[idx].n == 3
}

// recomputeMeasure recomputes the monoidal measure for a node from its keys
// and children.
func (t *Tree234[K, M]) recomputeMeasure(idx int32) {
	nd := &t.nodes[idx]
	m := t.ops.Identity()
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			m = t.ops.Combine(m, t.nodes[nd.children[i]].measure)
		}
		if i < nd.n {
			m = t.ops.Combine(m, t.ops.Measure(nd.keys[i]))
		}
	}
	nd.measure = m
}

// insertKeyChild inserts a key and right child into a non-full node at the
// given position, shifting existing keys/children to the right.
func (t *Tree234[K, M]) insertKeyChild(idx int32, pos int, key K, rightChild int32) {
	nd := &t.nodes[idx]
	// Shift keys and children right
	for i := nd.n; i > pos; i-- {
		nd.keys[i] = nd.keys[i-1]
		nd.children[i+1] = nd.children[i]
	}
	nd.keys[pos] = key
	nd.children[pos+1] = rightChild
	nd.n++
}

// splitChild splits the child at position childPos of parent parentIdx.
// The child must be a 4-node (3 keys). The middle key is promoted to the
// parent, and the child is split into two 1-key nodes.
func (t *Tree234[K, M]) splitChild(parentIdx int32, childPos int) {
	childIdx := t.nodes[parentIdx].children[childPos]
	child := &t.nodes[childIdx]

	// Create new right node with the third key and right children
	newRight := t.allocNode()
	nr := &t.nodes[newRight]
	nr.n = 1
	nr.keys[0] = child.keys[2]
	nr.children[0] = child.children[2]
	nr.children[1] = child.children[3]

	// Middle key to promote
	midKey := child.keys[1]

	// Shrink child to 1-key node (left part)
	child.n = 1
	child.children[2] = -1
	child.children[3] = -1

	// Recompute measures for the two halves
	t.recomputeMeasure(childIdx)
	t.recomputeMeasure(newRight)

	// Insert middle key into parent, with newRight as the right child
	t.insertKeyChild(parentIdx, childPos, midKey, newRight)
	t.recomputeMeasure(parentIdx)
}

// Insert inserts a key into the tree using top-down insertion.
// 4-nodes are split on the way down.
func (t *Tree234[K, M]) Insert(key K) {
	t.count++

	if t.root == -1 {
		t.root = t.allocNode()
		nd := &t.nodes[t.root]
		nd.n = 1
		nd.keys[0] = key
		nd.measure = t.ops.Measure(key)
		return
	}

	// If root is a 4-node, split it first
	if t.isFull(t.root) {
		oldRoot := t.root
		newRoot := t.allocNode()
		t.nodes[newRoot].children[0] = oldRoot
		t.root = newRoot
		t.splitChild(newRoot, 0)
	}

	cur := t.root
	for {
		nd := &t.nodes[cur]

		// Find insertion position
		pos := 0
		for pos < nd.n {
			cmp := t.ops.Compare(key, nd.keys[pos])
			if cmp <= 0 {
				break
			}
			pos++
		}

		if t.isLeaf(cur) {
			// Insert directly into this leaf
			t.insertKeyChild(cur, pos, key, -1)
			t.recomputeMeasure(cur)
			// Update measures up the path (handled by walking back up)
			// Since we do top-down, we update on the way back via
			// the recursive measure recomputation after insertion.
			t.updateMeasuresRoot()
			return
		}

		// Internal node: descend into the appropriate child
		childIdx := nd.children[pos]
		if t.isFull(childIdx) {
			t.splitChild(cur, pos)
			// After split, re-check which child to descend into
			nd = &t.nodes[cur]
			cmp := t.ops.Compare(key, nd.keys[pos])
			if cmp > 0 {
				pos++
			}
			childIdx = nd.children[pos]
		}

		cur = childIdx
	}
}

// updateMeasuresRoot recomputes measures for all nodes from root.
// For simplicity, we do a recursive recomputation from root.
// This is O(n) but happens only once per insert. A path-based approach
// would be O(log n) but requires tracking the path.
func (t *Tree234[K, M]) updateMeasuresRoot() {
	if t.root != -1 {
		t.updateMeasuresRec(t.root)
	}
}

func (t *Tree234[K, M]) updateMeasuresRec(idx int32) {
	nd := &t.nodes[idx]
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			t.updateMeasuresRec(nd.children[i])
		}
	}
	t.recomputeMeasure(idx)
}

// ToSlice returns all keys in the tree in sorted (in-order) order.
func (t *Tree234[K, M]) ToSlice() []K {
	result := make([]K, 0, t.count)
	if t.root != -1 {
		t.inOrder(t.root, &result)
	}
	return result
}

func (t *Tree234[K, M]) inOrder(idx int32, result *[]K) {
	nd := &t.nodes[idx]
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			t.inOrder(nd.children[i], result)
		}
		if i < nd.n {
			*result = append(*result, nd.keys[i])
		}
	}
}

// FindByWeight walks the tree using the monoidal measure to find a key by
// cumulative weight. weightOf extracts the weight component from a measure.
// Returns the key, cumulative weight before it, its index in sorted order,
// and whether it was found.
func (t *Tree234[K, M]) FindByWeight(target float64, weightOf func(M) float64) (key K, cumBefore float64, index int, found bool) {
	if t.root == -1 {
		return
	}

	cur := t.root
	cumBefore = 0.0
	index = 0

	for {
		nd := &t.nodes[cur]
		for i := 0; i <= nd.n; i++ {
			// Check left subtree weight
			if nd.children[i] != -1 {
				childWeight := weightOf(t.nodes[nd.children[i]].measure)
				if cumBefore+childWeight >= target {
					// Descend into this child
					cur = nd.children[i]
					goto next
				}
				cumBefore += childWeight
				index += t.subtreeCount(nd.children[i])
			}

			if i < nd.n {
				keyWeight := weightOf(t.ops.Measure(nd.keys[i]))
				if cumBefore+keyWeight >= target {
					key = nd.keys[i]
					found = true
					return
				}
				cumBefore += keyWeight
				index++
			}
		}
		// Should not reach here if target <= total weight
		// Return last key
		return

	next:
		continue
	}
}

// subtreeCount returns the number of keys in the subtree rooted at idx.
func (t *Tree234[K, M]) subtreeCount(idx int32) int {
	if idx == -1 {
		return 0
	}
	nd := &t.nodes[idx]
	count := nd.n
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			count += t.subtreeCount(nd.children[i])
		}
	}
	return count
}

// countOf extracts the count component from a measure (number of keys in subtree).
func (t *Tree234[K, M]) countOf(idx int32) int {
	if idx == -1 {
		return 0
	}
	nd := &t.nodes[idx]
	c := nd.n
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			c += t.countOf(nd.children[i])
		}
	}
	return c
}

// FindNeighbors finds the predecessor and successor of a key in the tree.
// If the key exists in the tree, it is returned in the Found/Key fields.
func (t *Tree234[K, M]) FindNeighbors(key K) NeighborResult[K] {
	var result NeighborResult[K]
	if t.root == -1 {
		return result
	}
	t.findNeighborsRec(t.root, key, &result)
	return result
}

func (t *Tree234[K, M]) findNeighborsRec(idx int32, key K, result *NeighborResult[K]) {
	nd := &t.nodes[idx]
	for i := 0; i < nd.n; i++ {
		cmp := t.ops.Compare(key, nd.keys[i])
		if cmp == 0 {
			result.Found = true
			result.Key = nd.keys[i]
			// Predecessor: rightmost key in left subtree, or previous key
			if nd.children[i] != -1 {
				pred := t.rightmost(nd.children[i])
				result.HasPred = true
				result.Pred = pred
			}
			// Successor: leftmost key in right subtree, or next key
			if nd.children[i+1] != -1 {
				succ := t.leftmost(nd.children[i+1])
				result.HasSucc = true
				result.Succ = succ
			} else if i+1 < nd.n {
				result.HasSucc = true
				result.Succ = nd.keys[i+1]
			}
			// If no child-based pred, check previous keys in this node
			if !result.HasPred && i > 0 {
				result.HasPred = true
				result.Pred = nd.keys[i-1]
			}
			return
		} else if cmp < 0 {
			// key < nd.keys[i], so nd.keys[i] is a potential successor
			result.HasSucc = true
			result.Succ = nd.keys[i]
			if nd.children[i] != -1 {
				t.findNeighborsRec(nd.children[i], key, result)
			}
			return
		} else {
			// key > nd.keys[i], so nd.keys[i] is a potential predecessor
			result.HasPred = true
			result.Pred = nd.keys[i]
		}
	}
	// key > all keys in this node, descend into rightmost child
	if nd.children[nd.n] != -1 {
		t.findNeighborsRec(nd.children[nd.n], key, result)
	}
}

// rightmost returns the rightmost (largest) key in the subtree rooted at idx.
func (t *Tree234[K, M]) rightmost(idx int32) K {
	nd := &t.nodes[idx]
	if nd.children[nd.n] != -1 {
		return t.rightmost(nd.children[nd.n])
	}
	return nd.keys[nd.n-1]
}

// leftmost returns the leftmost (smallest) key in the subtree rooted at idx.
func (t *Tree234[K, M]) leftmost(idx int32) K {
	nd := &t.nodes[idx]
	if nd.children[0] != -1 {
		return t.leftmost(nd.children[0])
	}
	return nd.keys[0]
}

// FindByWeightMid is like FindByWeight but uses centroid midpoints:
// it finds the centroid where cumBefore + weight/2 >= target.
// This is useful for quantile interpolation in t-digests.
func (t *Tree234[K, M]) FindByWeightMid(target float64, weightOf func(M) float64, keyWeight func(K) float64) (key K, cumBefore float64, index int, found bool) {
	if t.root == -1 {
		return
	}

	cur := t.root
	cumBefore = 0.0
	index = 0

	for {
		nd := &t.nodes[cur]
		for i := 0; i <= nd.n; i++ {
			if nd.children[i] != -1 {
				childWeight := weightOf(t.nodes[nd.children[i]].measure)
				if cumBefore+childWeight > target {
					cur = nd.children[i]
					goto next2
				}
				cumBefore += childWeight
				index += t.subtreeCount(nd.children[i])
			}

			if i < nd.n {
				kw := keyWeight(nd.keys[i])
				if cumBefore+kw > target {
					key = nd.keys[i]
					found = true
					return
				}
				cumBefore += kw
				index++
			}
		}
		return

	next2:
		continue
	}
}

// CumulativeWeightBefore returns the total weight of all keys that compare
// less than the given key.
func (t *Tree234[K, M]) CumulativeWeightBefore(key K, weightOf func(M) float64, keyWeight func(K) float64) float64 {
	if t.root == -1 {
		return 0
	}
	return t.cumWeightBeforeRec(t.root, key, weightOf, keyWeight)
}

func (t *Tree234[K, M]) cumWeightBeforeRec(idx int32, key K, weightOf func(M) float64, keyWeight func(K) float64) float64 {
	nd := &t.nodes[idx]
	cum := 0.0
	for i := 0; i < nd.n; i++ {
		cmp := t.ops.Compare(key, nd.keys[i])
		if cmp <= 0 {
			// key <= nd.keys[i], descend left
			if nd.children[i] != -1 {
				cum += t.cumWeightBeforeRec(nd.children[i], key, weightOf, keyWeight)
			}
			return cum
		}
		// key > nd.keys[i]: add left child weight + this key weight
		if nd.children[i] != -1 {
			cum += weightOf(t.nodes[nd.children[i]].measure)
		}
		cum += keyWeight(nd.keys[i])
	}
	// key > all keys, add rightmost child
	if nd.children[nd.n] != -1 {
		cum += t.cumWeightBeforeRec(nd.children[nd.n], key, weightOf, keyWeight)
	}
	return cum
}

// FindByMean finds a centroid by its mean value. Returns the centroid,
// cumulative weight before it, its index, and whether it was found.
func (t *Tree234[K, M]) FindByMean(key K, weightOf func(M) float64, keyWeight func(K) float64) (foundKey K, cumBefore float64, index int, found bool) {
	if t.root == -1 {
		return
	}
	return t.findByMeanRec(t.root, key, 0.0, 0, weightOf, keyWeight)
}

func (t *Tree234[K, M]) findByMeanRec(idx int32, key K, cum float64, baseIdx int, weightOf func(M) float64, keyWeight func(K) float64) (foundKey K, cumBefore float64, index int, found bool) {
	nd := &t.nodes[idx]
	for i := 0; i < nd.n; i++ {
		if nd.children[i] != -1 {
			childCount := t.subtreeCount(nd.children[i])
			cmp := t.ops.Compare(key, nd.keys[i])
			if cmp < 0 {
				return t.findByMeanRec(nd.children[i], key, cum, baseIdx, weightOf, keyWeight)
			}
			cum += weightOf(t.nodes[nd.children[i]].measure)
			baseIdx += childCount
		}

		cmp := t.ops.Compare(key, nd.keys[i])
		if cmp == 0 {
			return nd.keys[i], cum, baseIdx, true
		}
		if cmp < 0 {
			return
		}
		cum += keyWeight(nd.keys[i])
		baseIdx++
	}
	if nd.children[nd.n] != -1 {
		return t.findByMeanRec(nd.children[nd.n], key, cum, baseIdx, weightOf, keyWeight)
	}
	return
}

// KeyAtIndex returns the key at the given 0-based sorted index.
func (t *Tree234[K, M]) KeyAtIndex(idx int) (K, bool) {
	if t.root == -1 || idx < 0 || idx >= t.count {
		var zero K
		return zero, false
	}
	return t.keyAtIndexRec(t.root, idx)
}

func (t *Tree234[K, M]) keyAtIndexRec(nodeIdx int32, target int) (K, bool) {
	nd := &t.nodes[nodeIdx]
	for i := 0; i <= nd.n; i++ {
		if nd.children[i] != -1 {
			childSize := t.subtreeCount(nd.children[i])
			if target < childSize {
				return t.keyAtIndexRec(nd.children[i], target)
			}
			target -= childSize
		}
		if i < nd.n {
			if target == 0 {
				return nd.keys[i], true
			}
			target--
		}
	}
	var zero K
	return zero, false
}
