//! Generic array-backed 2-3-4 tree with monoidal measures.
//!
//! A balanced search tree where each internal node has 2, 3, or 4 children
//! (equivalently 1, 2, or 3 keys). Nodes are stored in a flat `Vec` with
//! index-based pointers, and a free list recycles deleted slots.
//!
//! The tree maintains a monoidal measure at each node that summarizes the
//! subtree rooted there, enabling efficient aggregate queries (e.g., prefix
//! sums, counts) via top-down traversal.

use std::cmp::Ordering;

/// Trait for computing a measure from a single element (leaf contribution).
pub trait Measured<M> {
    fn measure(&self) -> M;
}

/// Trait for a monoidal type: associative `combine` with `Default` as identity.
pub trait Monoid: Clone + Default {
    fn combine(&self, other: &Self) -> Self;
}

/// Result of a neighbor search: predecessor and successor information.
#[derive(Debug, Clone)]
pub struct NeighborResult<K> {
    /// The predecessor key and its cumulative weight (sum of weights before it).
    pub pred: Option<(K, f64)>,
    /// The successor key and its cumulative weight (sum of weights before it).
    pub succ: Option<(K, f64)>,
}

const NO_CHILD: i32 = -1;

/// A node in the 2-3-4 tree.
#[derive(Clone, Debug)]
struct Node<K, M> {
    /// Number of keys stored (1, 2, or 3).
    n: u8,
    /// Keys stored in this node. Only indices 0..n are valid.
    keys: [Option<K>; 3],
    /// Children indices. children[0..=n] are valid for internal nodes.
    /// NO_CHILD (-1) means leaf / no child.
    children: [i32; 4],
    /// Cached monoidal measure for the entire subtree rooted at this node.
    measure: M,
}

impl<K: Clone, M: Clone + Default> Node<K, M> {
    fn new() -> Self {
        Node {
            n: 0,
            keys: [None, None, None],
            children: [NO_CHILD; 4],
            measure: M::default(),
        }
    }

    fn is_leaf(&self) -> bool {
        self.children[0] == NO_CHILD
    }

    fn is_four_node(&self) -> bool {
        self.n == 3
    }
}

/// An array-backed 2-3-4 tree with monoidal measures.
#[derive(Clone)]
pub struct Tree234<K, M> {
    nodes: Vec<Node<K, M>>,
    free_list: Vec<usize>,
    root: i32,
    count: usize,
}

impl<K, M> Tree234<K, M>
where
    K: Clone,
    M: Monoid,
    K: Measured<M>,
{
    /// Creates a new empty tree.
    pub fn new() -> Self {
        Tree234 {
            nodes: Vec::new(),
            free_list: Vec::new(),
            root: NO_CHILD,
            count: 0,
        }
    }

    /// Returns the number of keys in the tree.
    pub fn size(&self) -> usize {
        self.count
    }

    /// Returns the measure of the entire tree (root's cached measure).
    pub fn root_measure(&self) -> M {
        if self.root == NO_CHILD {
            M::default()
        } else {
            self.nodes[self.root as usize].measure.clone()
        }
    }

    /// Clears the tree, removing all elements.
    pub fn clear(&mut self) {
        self.nodes.clear();
        self.free_list.clear();
        self.root = NO_CHILD;
        self.count = 0;
    }

    /// Allocates a new node, reusing from free list if possible.
    fn alloc_node(&mut self) -> usize {
        if let Some(idx) = self.free_list.pop() {
            self.nodes[idx] = Node::new();
            idx
        } else {
            let idx = self.nodes.len();
            self.nodes.push(Node::new());
            idx
        }
    }

    /// Recomputes the cached measure for a node from its keys and children.
    fn recompute_measure(&mut self, idx: usize) {
        let node = &self.nodes[idx];
        let n = node.n as usize;
        let is_leaf = node.is_leaf();

        let mut m = M::default();

        for i in 0..n {
            if !is_leaf {
                let child = node.children[i];
                if child != NO_CHILD {
                    m = m.combine(&self.nodes[child as usize].measure);
                }
            }
            m = m.combine(&node.keys[i].as_ref().unwrap().measure());
        }
        // Rightmost child.
        if !is_leaf {
            let child = node.children[n];
            if child != NO_CHILD {
                m = m.combine(&self.nodes[child as usize].measure);
            }
        }

        self.nodes[idx].measure = m;
    }

    /// Inserts a key into the tree using top-down insertion with pre-emptive
    /// splitting of 4-nodes.
    pub fn insert(&mut self, key: K, cmp: &impl Fn(&K, &K) -> Ordering) {
        self.count += 1;

        if self.root == NO_CHILD {
            let idx = self.alloc_node();
            self.nodes[idx].n = 1;
            self.nodes[idx].keys[0] = Some(key);
            self.recompute_measure(idx);
            self.root = idx as i32;
            return;
        }

        // If root is a 4-node, split it first.
        if self.nodes[self.root as usize].is_four_node() {
            self.split_root();
        }

        // Walk down with a path stack so we can recompute measures upward.
        let mut path: Vec<usize> = Vec::with_capacity(32);
        let mut cur = self.root as usize;

        loop {
            path.push(cur);
            let n = self.nodes[cur].n as usize;

            if self.nodes[cur].is_leaf() {
                // Insert into this leaf (guaranteed room since we split 4-nodes on the way down).
                self.insert_key_at_leaf(cur, &key, cmp);
                break;
            }

            // Find which child to descend into.
            let mut pos = n;
            for i in 0..n {
                if cmp(&key, self.nodes[cur].keys[i].as_ref().unwrap()) == Ordering::Less {
                    pos = i;
                    break;
                }
            }

            let child_idx = self.nodes[cur].children[pos] as usize;

            // If child is a 4-node, split it before descending.
            if self.nodes[child_idx].is_four_node() {
                self.split_child(cur, pos);
                // After split, parent `cur` gained a key at position `pos`.
                // Decide which of the two resulting children to descend into.
                let n_after = self.nodes[cur].n as usize;
                // Re-find position after split.
                let mut new_pos = n_after;
                for i in 0..n_after {
                    if cmp(&key, self.nodes[cur].keys[i].as_ref().unwrap()) == Ordering::Less {
                        new_pos = i;
                        break;
                    }
                }
                cur = self.nodes[cur].children[new_pos] as usize;
            } else {
                cur = child_idx;
            }
        }

        // Recompute measures along the path (bottom-up).
        for &idx in path.iter().rev() {
            self.recompute_measure(idx);
        }
    }

    /// Inserts a key into a leaf node in the correct sorted position.
    fn insert_key_at_leaf(&mut self, node_idx: usize, key: &K, cmp: &impl Fn(&K, &K) -> Ordering) {
        let n = self.nodes[node_idx].n as usize;
        debug_assert!(n < 3);

        // Find insertion position.
        let mut pos = n;
        for i in 0..n {
            if cmp(key, self.nodes[node_idx].keys[i].as_ref().unwrap()) == Ordering::Less {
                pos = i;
                break;
            }
        }

        // Shift keys right to make room.
        for i in (pos..n).rev() {
            self.nodes[node_idx].keys[i + 1] = self.nodes[node_idx].keys[i].take();
        }
        self.nodes[node_idx].keys[pos] = Some(key.clone());
        self.nodes[node_idx].n = (n + 1) as u8;
    }

    /// Splits the root node (which must be a 4-node).
    fn split_root(&mut self) {
        let old_root = self.root as usize;
        let new_root = self.alloc_node();
        self.nodes[new_root].n = 0;
        self.nodes[new_root].children[0] = old_root as i32;
        self.split_child(new_root, 0);
        self.root = new_root as i32;
    }

    /// Splits the child at `child_pos` of `parent_idx`. The child must be a 4-node.
    fn split_child(&mut self, parent_idx: usize, child_pos: usize) {
        let child_idx = self.nodes[parent_idx].children[child_pos] as usize;
        let right_idx = self.alloc_node();

        // Child has keys [k0, k1, k2] and children [c0, c1, c2, c3].
        let k1 = self.nodes[child_idx].keys[1].take().unwrap();
        let k2 = self.nodes[child_idx].keys[2].take().unwrap();
        let c2 = self.nodes[child_idx].children[2];
        let c3 = self.nodes[child_idx].children[3];

        // Right node gets k2, c2, c3.
        self.nodes[right_idx].n = 1;
        self.nodes[right_idx].keys[0] = Some(k2);
        self.nodes[right_idx].children[0] = c2;
        self.nodes[right_idx].children[1] = c3;

        // Left (child) node shrinks to just k0, c0, c1.
        self.nodes[child_idx].n = 1;
        self.nodes[child_idx].children[2] = NO_CHILD;
        self.nodes[child_idx].children[3] = NO_CHILD;

        // Recompute measures for left and right.
        self.recompute_measure(child_idx);
        self.recompute_measure(right_idx);

        // Insert k1 into parent at position child_pos, with right_idx as the new right child.
        let pn = self.nodes[parent_idx].n as usize;

        // Shift parent keys and children right to make room at child_pos.
        for i in (child_pos..pn).rev() {
            self.nodes[parent_idx].keys[i + 1] = self.nodes[parent_idx].keys[i].take();
            self.nodes[parent_idx].children[i + 2] = self.nodes[parent_idx].children[i + 1];
        }
        self.nodes[parent_idx].keys[child_pos] = Some(k1);
        self.nodes[parent_idx].children[child_pos + 1] = right_idx as i32;
        self.nodes[parent_idx].n = (pn + 1) as u8;

        self.recompute_measure(parent_idx);
    }

    /// Collects all keys in sorted order via in-order traversal.
    pub fn to_vec(&self) -> Vec<K> {
        let mut result = Vec::with_capacity(self.count);
        if self.root != NO_CHILD {
            self.collect_inorder(self.root as usize, &mut result);
        }
        result
    }

    fn collect_inorder(&self, idx: usize, out: &mut Vec<K>) {
        let node = &self.nodes[idx];
        let n = node.n as usize;
        for i in 0..n {
            if !node.is_leaf() {
                let c = node.children[i];
                if c != NO_CHILD {
                    self.collect_inorder(c as usize, out);
                }
            }
            out.push(node.keys[i].as_ref().unwrap().clone());
        }
        if !node.is_leaf() {
            let c = node.children[n];
            if c != NO_CHILD {
                self.collect_inorder(c as usize, out);
            }
        }
    }

    /// Applies a function to each key in sorted order.
    pub fn for_each(&self, mut f: impl FnMut(&K)) {
        if self.root != NO_CHILD {
            self.for_each_inorder(self.root as usize, &mut f);
        }
    }

    fn for_each_inorder(&self, idx: usize, f: &mut impl FnMut(&K)) {
        let node = &self.nodes[idx];
        let n = node.n as usize;
        for i in 0..n {
            if !node.is_leaf() {
                let c = node.children[i];
                if c != NO_CHILD {
                    self.for_each_inorder(c as usize, f);
                }
            }
            f(node.keys[i].as_ref().unwrap());
        }
        if !node.is_leaf() {
            let c = node.children[n];
            if c != NO_CHILD {
                self.for_each_inorder(c as usize, f);
            }
        }
    }

    /// Finds a key by cumulative weight, walking down the tree.
    ///
    /// Returns `(key, cumulative_weight_before_key, index_in_sorted_order)`.
    ///
    /// `weight_fn` extracts the weight from a measure (subtree aggregate).
    /// `key_weight_fn` extracts the weight from a single key.
    ///
    /// Finds the first key where cumulative weight (including that key) >= target.
    pub fn find_by_weight(
        &self,
        target: f64,
        weight_fn: &impl Fn(&M) -> f64,
        key_weight_fn: &impl Fn(&K) -> f64,
    ) -> Option<(K, f64, usize)> {
        if self.root == NO_CHILD {
            return None;
        }
        let mut remaining = target;
        let mut cum = 0.0;
        let mut index: usize = 0;
        let mut cur = self.root as usize;

        loop {
            let node = &self.nodes[cur];
            let n = node.n as usize;
            let is_leaf = node.is_leaf();

            let mut descended = false;
            for i in 0..n {
                // Check left child.
                if !is_leaf {
                    let c = node.children[i];
                    if c != NO_CHILD {
                        let child_w = weight_fn(&self.nodes[c as usize].measure);
                        if remaining > child_w {
                            remaining -= child_w;
                            cum += child_w;
                            index += self.subtree_count(c as usize);
                        } else {
                            // Descend into this child.
                            cur = c as usize;
                            descended = true;
                            break;
                        }
                    }
                }

                // Check this key.
                let kw = key_weight_fn(node.keys[i].as_ref().unwrap());
                if remaining <= kw {
                    return Some((node.keys[i].as_ref().unwrap().clone(), cum, index));
                }
                remaining -= kw;
                cum += kw;
                index += 1;
            }

            if descended {
                continue;
            }

            // Check rightmost child.
            if !is_leaf {
                let c = node.children[n];
                if c != NO_CHILD {
                    cur = c as usize;
                    continue;
                }
            }

            // Target exceeds total weight; return last key.
            return None;
        }
    }

    /// Count of keys in a subtree.
    fn subtree_count(&self, idx: usize) -> usize {
        let node = &self.nodes[idx];
        let n = node.n as usize;
        let mut count = n;
        if !node.is_leaf() {
            for i in 0..=n {
                let c = node.children[i];
                if c != NO_CHILD {
                    count += self.subtree_count(c as usize);
                }
            }
        }
        count
    }

    /// Finds the predecessor and successor of a key by comparison, plus
    /// cumulative weight information.
    ///
    /// `weight_fn` extracts weight from a single key.
    pub fn find_neighbors(
        &self,
        key: &K,
        cmp: &impl Fn(&K, &K) -> Ordering,
        weight_fn: &impl Fn(&K) -> f64,
    ) -> NeighborResult<K> {
        let mut pred: Option<(K, f64)> = None;
        let mut succ: Option<(K, f64)> = None;
        let mut cum_weight = 0.0;
        let mut found_insert_point = false;

        self.for_each(|k| {
            let kw = weight_fn(k);
            if !found_insert_point {
                match cmp(k, key) {
                    Ordering::Less => {
                        pred = Some((k.clone(), cum_weight));
                        cum_weight += kw;
                    }
                    Ordering::Equal | Ordering::Greater => {
                        if cmp(k, key) == Ordering::Equal {
                            // Exact match: this key is a neighbor.
                            pred = Some((k.clone(), cum_weight));
                            cum_weight += kw;
                        } else {
                            // k > key: this is the successor.
                            succ = Some((k.clone(), cum_weight));
                            found_insert_point = true;
                            cum_weight += kw;
                        }
                    }
                }
            } else {
                cum_weight += kw;
            }
        });

        NeighborResult { pred, succ }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone, Debug, PartialEq)]
    struct TestKey(i32);

    #[derive(Clone, Debug, Default)]
    struct TestMeasure {
        count: usize,
        sum: i64,
    }

    impl Monoid for TestMeasure {
        fn combine(&self, other: &Self) -> Self {
            TestMeasure {
                count: self.count + other.count,
                sum: self.sum + other.sum,
            }
        }
    }

    impl Measured<TestMeasure> for TestKey {
        fn measure(&self) -> TestMeasure {
            TestMeasure {
                count: 1,
                sum: self.0 as i64,
            }
        }
    }

    fn cmp_keys(a: &TestKey, b: &TestKey) -> Ordering {
        a.0.cmp(&b.0)
    }

    #[test]
    fn test_insert_and_to_vec() {
        let mut tree = Tree234::<TestKey, TestMeasure>::new();
        let values = [5, 3, 7, 1, 4, 6, 8, 2, 9, 0];
        for v in values {
            tree.insert(TestKey(v), &cmp_keys);
        }
        let result: Vec<i32> = tree.to_vec().iter().map(|k| k.0).collect();
        assert_eq!(result, vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
        assert_eq!(tree.size(), 10);
    }

    #[test]
    fn test_measures() {
        let mut tree = Tree234::<TestKey, TestMeasure>::new();
        for i in 0..10 {
            tree.insert(TestKey(i), &cmp_keys);
        }
        let m = tree.root_measure();
        assert_eq!(m.count, 10);
        assert_eq!(m.sum, 45); // 0+1+...+9
    }

    #[test]
    fn test_clear() {
        let mut tree = Tree234::<TestKey, TestMeasure>::new();
        for i in 0..10 {
            tree.insert(TestKey(i), &cmp_keys);
        }
        tree.clear();
        assert_eq!(tree.size(), 0);
        assert_eq!(tree.root_measure().count, 0);
    }

    #[test]
    fn test_large_insert() {
        let mut tree = Tree234::<TestKey, TestMeasure>::new();
        for i in 0..1000 {
            tree.insert(TestKey(i), &cmp_keys);
        }
        let v = tree.to_vec();
        assert_eq!(v.len(), 1000);
        for (i, k) in v.iter().enumerate() {
            assert_eq!(k.0, i as i32);
        }
    }

    #[test]
    fn test_reverse_insert() {
        let mut tree = Tree234::<TestKey, TestMeasure>::new();
        for i in (0..100).rev() {
            tree.insert(TestKey(i), &cmp_keys);
        }
        let v = tree.to_vec();
        for (i, k) in v.iter().enumerate() {
            assert_eq!(k.0, i as i32);
        }
    }
}
