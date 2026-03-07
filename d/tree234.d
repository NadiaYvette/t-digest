/// Generic array-backed 2-3-4 tree with monoidal measures.
///
/// Template parameters:
///   K      - key/element type (stored in sorted order)
///   M      - measure type (monoidal annotation on subtrees)
///   Traits - a struct providing:
///       static M measure(const K)       - measure a single element
///       static M combine(const M, const M) - monoidal combine
///       static M identity()              - monoidal identity
///       static int compare(const K, const K) - <0, 0, >0

module tree234;

struct Tree234(K, M, Traits) {

    struct Node {
        int n = 0;          // number of keys: 1, 2, or 3
        K[3] keys;
        int[4] children = [-1, -1, -1, -1];
        M measure;

        void init() {
            n = 0;
            children = [-1, -1, -1, -1];
            measure = Traits.identity();
        }
    }

    struct WeightResult {
        K key;
        double cumBefore;
        int index;
        bool found;
    }

    private Node[] nodes;
    private int[] freeList;
    private int root_ = -1;
    private int count_ = 0;

    private int allocNode() {
        int idx;
        if (freeList.length > 0) {
            idx = freeList[$ - 1];
            freeList.length = freeList.length - 1;
            nodes[idx].init();
        } else {
            idx = cast(int) nodes.length;
            Node nd;
            nd.init();
            nodes ~= nd;
        }
        return idx;
    }

    private void freeNode(int idx) {
        freeList ~= idx;
    }

    private bool isLeaf(int idx) const {
        return nodes[idx].children[0] == -1;
    }

    private bool is4Node(int idx) const {
        return nodes[idx].n == 3;
    }

    private void recomputeMeasure(int idx) {
        M m = Traits.identity();
        foreach (i; 0 .. nodes[idx].n + 1) {
            if (nodes[idx].children[i] != -1) {
                m = Traits.combine(m, nodes[nodes[idx].children[i]].measure);
            }
            if (i < nodes[idx].n) {
                m = Traits.combine(m, Traits.measure(nodes[idx].keys[i]));
            }
        }
        nodes[idx].measure = m;
    }

    /// Split a 4-node child at position childPos of parent.
    private void splitChild(int parentIdx, int childPos) {
        int childIdx = nodes[parentIdx].children[childPos];

        // Save child data before allocNode may reallocate
        K k0 = nodes[childIdx].keys[0];
        K k1 = nodes[childIdx].keys[1];
        K k2 = nodes[childIdx].keys[2];
        int c0 = nodes[childIdx].children[0];
        int c1 = nodes[childIdx].children[1];
        int c2 = nodes[childIdx].children[2];
        int c3 = nodes[childIdx].children[3];

        // Create right node with k2, c2, c3
        int rightIdx = allocNode();
        nodes[rightIdx].n = 1;
        nodes[rightIdx].keys[0] = k2;
        nodes[rightIdx].children[0] = c2;
        nodes[rightIdx].children[1] = c3;

        // Shrink child (left) to k0, c0, c1
        nodes[childIdx].n = 1;
        nodes[childIdx].keys[0] = k0;
        nodes[childIdx].children[0] = c0;
        nodes[childIdx].children[1] = c1;
        nodes[childIdx].children[2] = -1;
        nodes[childIdx].children[3] = -1;

        // Recompute measures for left and right
        recomputeMeasure(childIdx);
        recomputeMeasure(rightIdx);

        // Insert mid key (k1) into parent at childPos
        // Shift keys and children to make room
        for (int i = nodes[parentIdx].n; i > childPos; i--) {
            nodes[parentIdx].keys[i] = nodes[parentIdx].keys[i - 1];
            nodes[parentIdx].children[i + 1] = nodes[parentIdx].children[i];
        }
        nodes[parentIdx].keys[childPos] = k1;
        nodes[parentIdx].children[childPos + 1] = rightIdx;
        nodes[parentIdx].n++;

        recomputeMeasure(parentIdx);
    }

    /// Insert key into a non-full node's subtree.
    private void insertNonFull(int idx, const K key) {
        if (isLeaf(idx)) {
            // Insert key in sorted position
            int pos = nodes[idx].n;
            while (pos > 0 && Traits.compare(key, nodes[idx].keys[pos - 1]) < 0) {
                nodes[idx].keys[pos] = nodes[idx].keys[pos - 1];
                pos--;
            }
            nodes[idx].keys[pos] = key;
            nodes[idx].n++;
            recomputeMeasure(idx);
            return;
        }

        // Find child to descend into
        int pos = 0;
        while (pos < nodes[idx].n &&
               Traits.compare(key, nodes[idx].keys[pos]) >= 0) {
            pos++;
        }

        // If that child is a 4-node, split it first
        if (is4Node(nodes[idx].children[pos])) {
            splitChild(idx, pos);
            // After split, mid key is at keys[pos].
            if (Traits.compare(key, nodes[idx].keys[pos]) >= 0) {
                pos++;
            }
        }

        insertNonFull(nodes[idx].children[pos], key);
        recomputeMeasure(idx);
    }

    /// In-order traversal helper
    private void forEachImpl(int idx, scope void delegate(const K) f) const {
        if (idx == -1) return;
        foreach (i; 0 .. nodes[idx].n + 1) {
            if (nodes[idx].children[i] != -1) {
                forEachImpl(nodes[idx].children[i], f);
            }
            if (i < nodes[idx].n) {
                f(nodes[idx].keys[i]);
            }
        }
    }

    /// Count elements in subtree
    private int subtreeCount(int idx) const {
        if (idx == -1) return 0;
        int c = nodes[idx].n;
        foreach (i; 0 .. nodes[idx].n + 1) {
            if (nodes[idx].children[i] != -1)
                c += subtreeCount(nodes[idx].children[i]);
        }
        return c;
    }

    /// find_by_weight walks down tracking cumulative weight
    private WeightResult findByWeightImpl(
        int idx, double target, double cum, int globalIdx,
        scope double delegate(const M) weightOf) const
    {
        if (idx == -1)
            return WeightResult.init;

        double runningCum = cum;
        int runningIdx = globalIdx;

        foreach (i; 0 .. nodes[idx].n + 1) {
            // Process child
            if (nodes[idx].children[i] != -1) {
                double childWeight = weightOf(nodes[nodes[idx].children[i]].measure);
                if (runningCum + childWeight >= target) {
                    return findByWeightImpl(nodes[idx].children[i], target, runningCum,
                                            runningIdx, weightOf);
                }
                runningCum += childWeight;
                runningIdx += subtreeCount(nodes[idx].children[i]);
            }

            if (i < nodes[idx].n) {
                double keyWeight = weightOf(Traits.measure(nodes[idx].keys[i]));
                if (runningCum + keyWeight >= target) {
                    WeightResult r;
                    r.key = nodes[idx].keys[i];
                    r.cumBefore = runningCum;
                    r.index = runningIdx;
                    r.found = true;
                    return r;
                }
                runningCum += keyWeight;
                runningIdx++;
            }
        }

        return WeightResult.init;
    }

    /// Build balanced tree from sorted array recursively.
    private int buildRecursive(const K[] sorted, int lo, int hi) {
        int n = hi - lo;
        if (n <= 0) return -1;

        if (n <= 3) {
            int idx = allocNode();
            nodes[idx].n = n;
            foreach (i; 0 .. n)
                nodes[idx].keys[i] = sorted[lo + i];
            recomputeMeasure(idx);
            return idx;
        }

        if (n <= 7) {
            int mid = lo + n / 2;
            int left = buildRecursive(sorted, lo, mid);
            int right = buildRecursive(sorted, mid + 1, hi);
            int idx = allocNode();
            nodes[idx].n = 1;
            nodes[idx].keys[0] = sorted[mid];
            nodes[idx].children[0] = left;
            nodes[idx].children[1] = right;
            recomputeMeasure(idx);
            return idx;
        }

        // For larger ranges, use 3-node
        int third = n / 3;
        int m1 = lo + third;
        int m2 = lo + 2 * third + 1;
        int c0 = buildRecursive(sorted, lo, m1);
        int c1 = buildRecursive(sorted, m1 + 1, m2);
        int c2 = buildRecursive(sorted, m2 + 1, hi);
        int idx = allocNode();
        nodes[idx].n = 2;
        nodes[idx].keys[0] = sorted[m1];
        nodes[idx].keys[1] = sorted[m2];
        nodes[idx].children[0] = c0;
        nodes[idx].children[1] = c1;
        nodes[idx].children[2] = c2;
        recomputeMeasure(idx);
        return idx;
    }

    // ---- Public API ----

    void insert(const K key) {
        if (root_ == -1) {
            root_ = allocNode();
            nodes[root_].n = 1;
            nodes[root_].keys[0] = key;
            recomputeMeasure(root_);
            count_++;
            return;
        }

        // If root is a 4-node, split it.
        if (is4Node(root_)) {
            int oldRoot = root_;
            root_ = allocNode();
            nodes[root_].children[0] = oldRoot;
            splitChild(root_, 0);
        }

        insertNonFull(root_, key);
        count_++;
    }

    void clear() {
        nodes.length = 0;
        freeList.length = 0;
        root_ = -1;
        count_ = 0;
    }

    int size() const {
        return count_;
    }

    M rootMeasure() const {
        if (root_ == -1)
            return Traits.identity();
        return nodes[root_].measure;
    }

    void forEach(scope void delegate(const K) f) const {
        forEachImpl(root_, f);
    }

    /// Collect all keys in-order into an array
    K[] collect() const {
        K[] result;
        result.reserve(count_);
        forEach((const K k) { result ~= k; });
        return result;
    }

    WeightResult findByWeight(double target,
                              scope double delegate(const M) weightOf) const {
        if (root_ == -1)
            return WeightResult.init;
        return findByWeightImpl(root_, target, 0.0, 0, weightOf);
    }

    void buildFromSorted(const K[] sorted) {
        clear();
        if (sorted.length == 0) return;
        count_ = cast(int) sorted.length;
        root_ = buildRecursive(sorted, 0, cast(int) sorted.length);
    }
}
