import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * Array-backed 2-3-4 tree with monoidal measures.
 *
 * @param <K> key type
 * @param <M> measure (monoid) type
 */
@SuppressWarnings("unchecked")
public class Tree234<K, M> {

    /** Monoidal measure over keys. */
    public interface Measure<K, M> {
        M measure(K key);
        M combine(M a, M b);
        M identity();
    }

    /** Key comparator. */
    public interface KeyCompare<K> {
        int compare(K a, K b);
    }

    /** Result of findByWeight. */
    public static class WeightResult<K, M> {
        public final K key;
        public final int nodeIdx;
        public final int keyPos;
        public final double cumulativeBefore;
        public final List<int[]> path; // each element: [nodeIdx, childSlot]

        WeightResult(K key, int nodeIdx, int keyPos, double cumulativeBefore, List<int[]> path) {
            this.key = key;
            this.nodeIdx = nodeIdx;
            this.keyPos = keyPos;
            this.cumulativeBefore = cumulativeBefore;
            this.path = path;
        }
    }

    /** Result of findNeighbors. */
    public static class NeighborResult<K> {
        public final K pred;       // null if none
        public final K succ;       // null if none
        public final double predCumWeight; // cumulative weight before pred (not including pred)
        public final double succCumWeight; // cumulative weight before succ (not including succ)
        public final int predNodeIdx;
        public final int predKeyPos;
        public final List<int[]> predPath;
        public final int succNodeIdx;
        public final int succKeyPos;
        public final List<int[]> succPath;

        NeighborResult(K pred, K succ, double predCumWeight, double succCumWeight,
                       int predNodeIdx, int predKeyPos, List<int[]> predPath,
                       int succNodeIdx, int succKeyPos, List<int[]> succPath) {
            this.pred = pred;
            this.succ = succ;
            this.predCumWeight = predCumWeight;
            this.succCumWeight = succCumWeight;
            this.predNodeIdx = predNodeIdx;
            this.predKeyPos = predKeyPos;
            this.predPath = predPath;
            this.succNodeIdx = succNodeIdx;
            this.succKeyPos = succKeyPos;
            this.succPath = succPath;
        }
    }

    private static class Node<K, M> {
        int n;            // number of keys: 1, 2, or 3
        Object[] keys;    // K[3]
        int[] children;   // int[4], -1 = no child
        M measure;        // cached subtree measure

        Node() {
            n = 0;
            keys = new Object[3];
            children = new int[]{-1, -1, -1, -1};
            measure = null;
        }

        boolean isLeaf() {
            return children[0] == -1;
        }
    }

    private ArrayList<Node<K, M>> nodes;
    private ArrayList<Integer> freeList;
    private int root = -1;
    private int count = 0;
    private final Measure<K, M> measureOps;
    private final KeyCompare<K> comparator;

    public Tree234(Measure<K, M> measureOps, KeyCompare<K> comparator) {
        this.measureOps = measureOps;
        this.comparator = comparator;
        this.nodes = new ArrayList<>();
        this.freeList = new ArrayList<>();
    }

    private int allocNode() {
        Node<K, M> node = new Node<>();
        node.measure = measureOps.identity();
        if (!freeList.isEmpty()) {
            int idx = freeList.remove(freeList.size() - 1);
            nodes.set(idx, node);
            return idx;
        }
        int idx = nodes.size();
        nodes.add(node);
        return idx;
    }

    private void freeNode(int idx) {
        nodes.set(idx, null);
        freeList.add(idx);
    }

    private Node<K, M> node(int idx) {
        return nodes.get(idx);
    }

    private void recomputeMeasure(int idx) {
        Node<K, M> nd = node(idx);
        M m = measureOps.identity();
        for (int i = 0; i <= nd.n; i++) {
            if (nd.children[i] != -1) {
                m = measureOps.combine(m, node(nd.children[i]).measure);
            }
            if (i < nd.n) {
                m = measureOps.combine(m, measureOps.measure((K) nd.keys[i]));
            }
        }
        nd.measure = m;
    }

    /** Split a 4-node child at childPos of parent parentIdx. */
    private void splitChild(int parentIdx, int childPos) {
        Node<K, M> parent = node(parentIdx);
        int childIdx = parent.children[childPos];
        Node<K, M> child = node(childIdx);

        // child has 3 keys: keys[0], keys[1], keys[2]
        // keys[1] goes up to parent
        // left gets keys[0], right gets keys[2]
        K midKey = (K) child.keys[1];

        int rightIdx = allocNode();
        Node<K, M> right = node(rightIdx);

        // Right node gets key[2] and children[2], children[3]
        right.n = 1;
        right.keys[0] = child.keys[2];
        right.children[0] = child.children[2];
        right.children[1] = child.children[3];

        // Left node (child) keeps key[0] and children[0], children[1]
        child.n = 1;
        child.keys[1] = null;
        child.keys[2] = null;
        child.children[2] = -1;
        child.children[3] = -1;

        // Shift parent keys/children right to make room
        for (int i = parent.n; i > childPos; i--) {
            parent.keys[i] = parent.keys[i - 1];
            parent.children[i + 1] = parent.children[i];
        }
        parent.keys[childPos] = midKey;
        parent.children[childPos + 1] = rightIdx;
        parent.n++;

        recomputeMeasure(childIdx);
        recomputeMeasure(rightIdx);
        recomputeMeasure(parentIdx);
    }

    /** Insert key into the tree (top-down splitting). */
    public void insert(K key) {
        count++;
        if (root == -1) {
            root = allocNode();
            Node<K, M> nd = node(root);
            nd.n = 1;
            nd.keys[0] = key;
            recomputeMeasure(root);
            return;
        }

        // If root is a 4-node, split it
        if (node(root).n == 3) {
            int oldRoot = root;
            root = allocNode();
            Node<K, M> newRoot = node(root);
            newRoot.n = 0;
            newRoot.children[0] = oldRoot;
            splitChild(root, 0);
        }

        int cur = root;
        while (true) {
            Node<K, M> nd = node(cur);

            // Find position
            int pos = 0;
            while (pos < nd.n && comparator.compare(key, (K) nd.keys[pos]) >= 0) {
                pos++;
            }

            if (nd.isLeaf()) {
                // Insert key at pos
                for (int i = nd.n; i > pos; i--) {
                    nd.keys[i] = nd.keys[i - 1];
                }
                nd.keys[pos] = key;
                nd.n++;
                recomputeMeasure(cur);
                return;
            }

            // Before descending, split 4-node child
            if (node(nd.children[pos]).n == 3) {
                splitChild(cur, pos);
                // After split, re-check which child to descend
                nd = node(cur); // re-fetch
                if (comparator.compare(key, (K) nd.keys[pos]) >= 0) {
                    pos++;
                }
            }

            cur = nd.children[pos];
        }
    }

    /** Insert and recompute measures along path from leaf to root. */
    public void insertWithPathUpdate(K key) {
        count++;
        if (root == -1) {
            root = allocNode();
            Node<K, M> nd = node(root);
            nd.n = 1;
            nd.keys[0] = key;
            recomputeMeasure(root);
            return;
        }

        // If root is a 4-node, split it
        if (node(root).n == 3) {
            int oldRoot = root;
            root = allocNode();
            Node<K, M> newRoot = node(root);
            newRoot.n = 0;
            newRoot.children[0] = oldRoot;
            splitChild(root, 0);
        }

        List<Integer> path = new ArrayList<>();
        int cur = root;

        while (true) {
            path.add(cur);
            Node<K, M> nd = node(cur);

            int pos = 0;
            while (pos < nd.n && comparator.compare(key, (K) nd.keys[pos]) >= 0) {
                pos++;
            }

            if (nd.isLeaf()) {
                for (int i = nd.n; i > pos; i--) {
                    nd.keys[i] = nd.keys[i - 1];
                }
                nd.keys[pos] = key;
                nd.n++;
                // Recompute measures upward
                for (int j = path.size() - 1; j >= 0; j--) {
                    recomputeMeasure(path.get(j));
                }
                return;
            }

            if (node(nd.children[pos]).n == 3) {
                splitChild(cur, pos);
                nd = node(cur);
                if (comparator.compare(key, (K) nd.keys[pos]) >= 0) {
                    pos++;
                }
            }

            cur = nd.children[pos];
        }
    }

    public void clear() {
        nodes.clear();
        freeList.clear();
        root = -1;
        count = 0;
    }

    public int size() {
        return count;
    }

    public M rootMeasure() {
        if (root == -1) return measureOps.identity();
        return node(root).measure;
    }

    /** In-order traversal. */
    public List<K> toList() {
        List<K> result = new ArrayList<>(count);
        if (root != -1) {
            inOrder(root, result);
        }
        return result;
    }

    private void inOrder(int idx, List<K> result) {
        Node<K, M> nd = node(idx);
        for (int i = 0; i <= nd.n; i++) {
            if (nd.children[i] != -1) {
                inOrder(nd.children[i], result);
            }
            if (i < nd.n) {
                result.add((K) nd.keys[i]);
            }
        }
    }

    /**
     * Find the key whose cumulative weight range contains target.
     * weightOf extracts the weight component from a measure.
     */
    public WeightResult<K, M> findByWeight(double target, Function<M, Double> weightOf) {
        if (root == -1) return null;
        List<int[]> path = new ArrayList<>();
        double cumul = 0.0;
        int cur = root;

        while (true) {
            Node<K, M> nd = node(cur);
            for (int i = 0; i <= nd.n; i++) {
                // Left subtree weight
                if (nd.children[i] != -1) {
                    double childW = weightOf.apply(node(nd.children[i]).measure);
                    if (cumul + childW > target) {
                        path.add(new int[]{cur, i});
                        cur = nd.children[i];
                        break; // restart loop with child
                    }
                    cumul += childW;
                }
                if (i < nd.n) {
                    K key = (K) nd.keys[i];
                    double keyW = weightOf.apply(measureOps.measure(key));
                    if (cumul + keyW > target) {
                        return new WeightResult<>(key, cur, i, cumul, path);
                    }
                    cumul += keyW;
                }
                if (i == nd.n) {
                    // Fell off the right side; return rightmost key
                    // Walk back to find rightmost
                    return findRightmost(cumul, path);
                }
            }
        }
    }

    private WeightResult<K, M> findRightmost(double cumul, List<int[]> path) {
        // Return the very last key in the tree
        int cur = root;
        while (true) {
            Node<K, M> nd = node(cur);
            if (nd.isLeaf()) {
                K key = (K) nd.keys[nd.n - 1];
                // cumulative before this key = totalWeight - keyWeight
                double keyW = 0;
                for (int i = 0; i < nd.n - 1; i++) {
                    keyW += getKeyWeight(nd, i);
                }
                return new WeightResult<>(key, cur, nd.n - 1, cumul, path);
            }
            cur = nd.children[nd.n];
        }
    }

    private double getKeyWeight(Node<K, M> nd, int i) {
        // placeholder - compute from measure
        return 0;
    }

    /**
     * Find predecessor and successor of key, with their cumulative weights.
     */
    public NeighborResult<K> findNeighbors(K key) {
        if (root == -1) {
            return new NeighborResult<>(null, null, 0, 0, -1, -1, null, -1, -1, null);
        }

        K pred = null, succ = null;
        double predCumW = 0, succCumW = 0;
        int predNodeIdx = -1, predKeyPos = -1;
        int succNodeIdx = -1, succKeyPos = -1;
        List<int[]> predPath = new ArrayList<>();
        List<int[]> succPath = new ArrayList<>();

        double cumul = 0.0;
        int cur = root;
        List<int[]> curPath = new ArrayList<>();

        while (cur != -1) {
            Node<K, M> nd = node(cur);
            boolean descended = false;

            for (int i = 0; i <= nd.n; i++) {
                double childW = 0;
                if (nd.children[i] != -1) {
                    childW = getSubtreeWeight(nd.children[i]);
                }

                if (i < nd.n) {
                    K curKey = (K) nd.keys[i];
                    int cmp = comparator.compare(key, curKey);

                    if (cmp <= 0) {
                        // curKey >= key, so it's a successor candidate
                        double cumulBeforeCurKey = cumul + childW;
                        succ = curKey;
                        succCumW = cumulBeforeCurKey;
                        succNodeIdx = cur;
                        succKeyPos = i;
                        succPath = new ArrayList<>(curPath);

                        // Descend left
                        if (nd.children[i] != -1) {
                            curPath.add(new int[]{cur, i});
                            cur = nd.children[i];
                            descended = true;
                            break;
                        } else {
                            cur = -1;
                            descended = true;
                            break;
                        }
                    } else {
                        // curKey < key, so it's a predecessor candidate
                        double cumulBeforeCurKey = cumul + childW;
                        pred = curKey;
                        predCumW = cumulBeforeCurKey;
                        predNodeIdx = cur;
                        predKeyPos = i;
                        predPath = new ArrayList<>(curPath);

                        double keyW = getKeyMeasureWeight(curKey);
                        cumul = cumulBeforeCurKey + keyW;
                    }
                } else {
                    // Past last key, descend right
                    if (nd.children[i] != -1) {
                        curPath.add(new int[]{cur, i});
                        cur = nd.children[i];
                        descended = true;
                        break;
                    } else {
                        cur = -1;
                        descended = true;
                        break;
                    }
                }
            }

            if (!descended) {
                break;
            }
        }

        return new NeighborResult<>(pred, succ, predCumW, succCumW,
                predNodeIdx, predKeyPos, predPath,
                succNodeIdx, succKeyPos, succPath);
    }

    private double getSubtreeWeight(int idx) {
        // Extract weight from cached measure. Caller must provide a way.
        // We'll use a simple approach: store a weightExtractor.
        // For now, we walk. This is replaced in practice.
        return weightExtractor != null ? weightExtractor.apply(node(idx).measure) : 0.0;
    }

    private double getKeyMeasureWeight(K key) {
        return weightExtractor != null ? weightExtractor.apply(measureOps.measure(key)) : 0.0;
    }

    private Function<M, Double> weightExtractor;

    /** Set the weight extractor function for neighbor/weight queries. */
    public void setWeightExtractor(Function<M, Double> extractor) {
        this.weightExtractor = extractor;
    }

    /**
     * Update a key in-place and recompute measures along path.
     */
    public void updateKey(int nodeIdx, int keyPos, K newKey, List<int[]> path) {
        Node<K, M> nd = node(nodeIdx);
        nd.keys[keyPos] = newKey;
        recomputeMeasure(nodeIdx);
        if (path != null) {
            for (int i = path.size() - 1; i >= 0; i--) {
                recomputeMeasure(path.get(i)[0]);
            }
        }
    }
}
