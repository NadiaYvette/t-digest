/**
 * Generic array-backed 2-3-4 tree with monoidal measures.
 *
 * Type parameters:
 *   K - key/element type (stored in sorted order)
 *   M - measure type (monoidal annotation on subtrees)
 *
 * The [traits] parameter provides:
 *   measure(K) -> M          - measure a single element
 *   combine(M, M) -> M       - monoidal combine
 *   identity() -> M           - monoidal identity
 *   compare(K, K) -> Int      - <0, 0, >0
 */

class Tree234<K, M>(private val traits: TreeTraits<K, M>) {

    interface TreeTraits<K, M> {
        fun measure(key: K): M
        fun combine(a: M, b: M): M
        fun identity(): M
        fun compare(a: K, b: K): Int
    }

    class Node<K, M>(identity: M) {
        var n: Int = 0                          // number of keys: 1, 2, or 3
        val keys: Array<Any?> = arrayOfNulls(3)
        val children: IntArray = intArrayOf(-1, -1, -1, -1)
        var measure: M = identity
    }

    data class WeightResult<K>(
        val key: K,
        val cumBefore: Double,
        val index: Int,
        val found: Boolean
    )

    private val nodes = ArrayList<Node<K, M>>()
    private val freeList = ArrayList<Int>()
    private var root: Int = -1
    private var count: Int = 0

    val size: Int get() = count

    fun rootMeasure(): M {
        if (root == -1) return traits.identity()
        return nodes[root].measure
    }

    private fun allocNode(): Int {
        return if (freeList.isNotEmpty()) {
            val idx = freeList.removeAt(freeList.size - 1)
            val nd = nodes[idx]
            nd.n = 0
            nd.keys[0] = null; nd.keys[1] = null; nd.keys[2] = null
            nd.children[0] = -1; nd.children[1] = -1; nd.children[2] = -1; nd.children[3] = -1
            nd.measure = traits.identity()
            idx
        } else {
            val idx = nodes.size
            nodes.add(Node(traits.identity()))
            idx
        }
    }

    private fun freeNode(idx: Int) {
        freeList.add(idx)
    }

    private fun isLeaf(idx: Int): Boolean = nodes[idx].children[0] == -1
    private fun is4Node(idx: Int): Boolean = nodes[idx].n == 3

    @Suppress("UNCHECKED_CAST")
    private fun nodeKey(idx: Int, pos: Int): K = nodes[idx].keys[pos] as K

    private fun recomputeMeasure(idx: Int) {
        val nd = nodes[idx]
        var m = traits.identity()
        for (i in 0..nd.n) {
            if (nd.children[i] != -1) {
                m = traits.combine(m, nodes[nd.children[i]].measure)
            }
            if (i < nd.n) {
                @Suppress("UNCHECKED_CAST")
                m = traits.combine(m, traits.measure(nd.keys[i] as K))
            }
        }
        nd.measure = m
    }

    /**
     * Split a 4-node child at position [childPos] of parent at [parentIdx].
     * The child has keys k0,k1,k2 and children c0,c1,c2,c3.
     * After split: left gets (k0; c0,c1), right gets (k2; c2,c3),
     * k1 is pushed into parent at childPos.
     */
    private fun splitChild(parentIdx: Int, childPos: Int) {
        val childIdx = nodes[parentIdx].children[childPos]

        // Save child data before allocNode() may cause issues
        val k0 = nodes[childIdx].keys[0]
        val k1 = nodes[childIdx].keys[1]
        val k2 = nodes[childIdx].keys[2]
        val c0 = nodes[childIdx].children[0]
        val c1 = nodes[childIdx].children[1]
        val c2 = nodes[childIdx].children[2]
        val c3 = nodes[childIdx].children[3]

        // Create right node with k2, c2, c3
        val rightIdx = allocNode()
        nodes[rightIdx].n = 1
        nodes[rightIdx].keys[0] = k2
        nodes[rightIdx].children[0] = c2
        nodes[rightIdx].children[1] = c3

        // Shrink child (left) to k0, c0, c1
        nodes[childIdx].n = 1
        nodes[childIdx].keys[0] = k0
        nodes[childIdx].keys[1] = null
        nodes[childIdx].keys[2] = null
        nodes[childIdx].children[0] = c0
        nodes[childIdx].children[1] = c1
        nodes[childIdx].children[2] = -1
        nodes[childIdx].children[3] = -1

        recomputeMeasure(childIdx)
        recomputeMeasure(rightIdx)

        // Insert mid_key (k1) into parent at childPos
        val parent = nodes[parentIdx]
        for (i in parent.n downTo childPos + 1) {
            parent.keys[i] = parent.keys[i - 1]
            parent.children[i + 1] = parent.children[i]
        }
        parent.keys[childPos] = k1
        parent.children[childPos + 1] = rightIdx
        parent.n++

        recomputeMeasure(parentIdx)
    }

    /**
     * Insert key into a non-full node's subtree.
     * Precondition: node at idx is not a 4-node.
     */
    private fun insertNonFull(idx: Int, key: K) {
        if (isLeaf(idx)) {
            val nd = nodes[idx]
            var pos = nd.n
            while (pos > 0 && traits.compare(key, nodeKey(idx, pos - 1)) < 0) {
                nd.keys[pos] = nd.keys[pos - 1]
                pos--
            }
            nd.keys[pos] = key
            nd.n++
            recomputeMeasure(idx)
            return
        }

        // Find child to descend into
        var pos = 0
        while (pos < nodes[idx].n && traits.compare(key, nodeKey(idx, pos)) >= 0) {
            pos++
        }

        // If that child is a 4-node, split it first
        if (is4Node(nodes[idx].children[pos])) {
            splitChild(idx, pos)
            if (traits.compare(key, nodeKey(idx, pos)) >= 0) {
                pos++
            }
        }

        insertNonFull(nodes[idx].children[pos], key)
        recomputeMeasure(idx)
    }

    fun insert(key: K) {
        if (root == -1) {
            root = allocNode()
            nodes[root].n = 1
            nodes[root].keys[0] = key
            recomputeMeasure(root)
            count++
            return
        }

        // If root is a 4-node, split it
        if (is4Node(root)) {
            val oldRoot = root
            root = allocNode()
            nodes[root].children[0] = oldRoot
            splitChild(root, 0)
        }

        insertNonFull(root, key)
        count++
    }

    fun clear() {
        nodes.clear()
        freeList.clear()
        root = -1
        count = 0
    }

    /** In-order traversal, calling [f] on each key. */
    fun forEach(f: (K) -> Unit) {
        forEachImpl(root, f)
    }

    @Suppress("UNCHECKED_CAST")
    private fun forEachImpl(idx: Int, f: (K) -> Unit) {
        if (idx == -1) return
        val nd = nodes[idx]
        for (i in 0..nd.n) {
            if (nd.children[i] != -1) {
                forEachImpl(nd.children[i], f)
            }
            if (i < nd.n) {
                f(nd.keys[i] as K)
            }
        }
    }

    /** Collect all keys in-order into a list. */
    fun collect(): MutableList<K> {
        val out = ArrayList<K>(count)
        forEach { out.add(it) }
        return out
    }

    private fun subtreeCount(idx: Int): Int {
        if (idx == -1) return 0
        val nd = nodes[idx]
        var c = nd.n
        for (i in 0..nd.n) {
            if (nd.children[i] != -1) c += subtreeCount(nd.children[i])
        }
        return c
    }

    /**
     * Find the element at which cumulative weight (as extracted by [weightOf])
     * reaches [target]. Returns a [WeightResult] with the key, the cumulative
     * weight before that key, the global index, and whether it was found.
     */
    fun findByWeight(target: Double, weightOf: (M) -> Double): WeightResult<K>? {
        if (root == -1) return null
        return findByWeightImpl(root, target, 0.0, 0, weightOf)
    }

    @Suppress("UNCHECKED_CAST")
    private fun findByWeightImpl(
        idx: Int, target: Double, cum: Double, globalIdx: Int,
        weightOf: (M) -> Double
    ): WeightResult<K>? {
        if (idx == -1) return null
        val nd = nodes[idx]
        var runningCum = cum
        var runningIdx = globalIdx

        for (i in 0..nd.n) {
            // Process child
            if (nd.children[i] != -1) {
                val childWeight = weightOf(nodes[nd.children[i]].measure)
                if (runningCum + childWeight >= target) {
                    return findByWeightImpl(nd.children[i], target, runningCum, runningIdx, weightOf)
                }
                runningCum += childWeight
                runningIdx += subtreeCount(nd.children[i])
            }

            if (i < nd.n) {
                val keyWeight = weightOf(traits.measure(nd.keys[i] as K))
                if (runningCum + keyWeight >= target) {
                    return WeightResult(nd.keys[i] as K, runningCum, runningIdx, true)
                }
                runningCum += keyWeight
                runningIdx++
            }
        }

        return null
    }

    /** Build a balanced tree from a sorted list. */
    fun buildFromSorted(sorted: List<K>) {
        clear()
        if (sorted.isEmpty()) return
        count = sorted.size
        root = buildRecursive(sorted, 0, sorted.size)
    }

    private fun buildRecursive(sorted: List<K>, lo: Int, hi: Int): Int {
        val n = hi - lo
        if (n <= 0) return -1

        if (n <= 3) {
            val idx = allocNode()
            nodes[idx].n = n
            for (i in 0 until n) nodes[idx].keys[i] = sorted[lo + i]
            recomputeMeasure(idx)
            return idx
        }

        if (n <= 7) {
            val mid = lo + n / 2
            val left = buildRecursive(sorted, lo, mid)
            val right = buildRecursive(sorted, mid + 1, hi)
            val idx = allocNode()
            nodes[idx].n = 1
            nodes[idx].keys[0] = sorted[mid]
            nodes[idx].children[0] = left
            nodes[idx].children[1] = right
            recomputeMeasure(idx)
            return idx
        }

        // For larger ranges, use 3-node
        val third = n / 3
        val m1 = lo + third
        val m2 = lo + 2 * third + 1
        val c0 = buildRecursive(sorted, lo, m1)
        val c1 = buildRecursive(sorted, m1 + 1, m2)
        val c2 = buildRecursive(sorted, m2 + 1, hi)
        val idx = allocNode()
        nodes[idx].n = 2
        nodes[idx].keys[0] = sorted[m1]
        nodes[idx].keys[1] = sorted[m2]
        nodes[idx].children[0] = c0
        nodes[idx].children[1] = c1
        nodes[idx].children[2] = c2
        recomputeMeasure(idx)
        return idx
    }
}
