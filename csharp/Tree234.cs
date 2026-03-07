// Generic array-backed 2-3-4 tree with monoidal measures.
//
// Type parameters:
//   K      - key/element type (stored in sorted order)
//   M      - measure type (monoidal annotation on subtrees)
//
// ITree234Traits<K, M> provides:
//   M Measure(K)          - measure a single element
//   M Combine(M, M)       - monoidal combine
//   M Identity()           - monoidal identity
//   int Compare(K, K)      - <0, 0, >0

using System;
using System.Collections.Generic;

namespace TDigestLib
{
    public interface ITree234Traits<K, M>
    {
        M Measure(K key);
        M Combine(M a, M b);
        M Identity();
        int Compare(K a, K b);
    }

    public struct WeightResult<K>
    {
        public K Key;
        public double CumBefore;
        public int Index;
        public bool Found;
    }

    public class Tree234<K, M, TTraits> where TTraits : struct, ITree234Traits<K, M>
    {
        private struct Node
        {
            public int N;               // number of keys: 1, 2, or 3
            public K Key0, Key1, Key2;
            public int Child0, Child1, Child2, Child3;
            public M Measure;

            public K GetKey(int i)
            {
                switch (i) { case 0: return Key0; case 1: return Key1; default: return Key2; }
            }

            public void SetKey(int i, K val)
            {
                switch (i) { case 0: Key0 = val; break; case 1: Key1 = val; break; default: Key2 = val; break; }
            }

            public int GetChild(int i)
            {
                switch (i) { case 0: return Child0; case 1: return Child1; case 2: return Child2; default: return Child3; }
            }

            public void SetChild(int i, int val)
            {
                switch (i) { case 0: Child0 = val; break; case 1: Child1 = val; break; case 2: Child2 = val; break; default: Child3 = val; break; }
            }
        }

        private TTraits _traits;
        private List<Node> _nodes;
        private List<int> _freeList;
        private int _root;
        private int _count;

        public Tree234()
        {
            _traits = default;
            _nodes = new List<Node>();
            _freeList = new List<int>();
            _root = -1;
            _count = 0;
        }

        private Node NewNode()
        {
            var nd = new Node();
            nd.N = 0;
            nd.Child0 = -1; nd.Child1 = -1; nd.Child2 = -1; nd.Child3 = -1;
            nd.Measure = _traits.Identity();
            return nd;
        }

        private int AllocNode()
        {
            int idx;
            if (_freeList.Count > 0)
            {
                idx = _freeList[_freeList.Count - 1];
                _freeList.RemoveAt(_freeList.Count - 1);
                _nodes[idx] = NewNode();
            }
            else
            {
                idx = _nodes.Count;
                _nodes.Add(NewNode());
            }
            return idx;
        }

        private bool IsLeaf(int idx) => _nodes[idx].Child0 == -1;
        private bool Is4Node(int idx) => _nodes[idx].N == 3;

        private void RecomputeMeasure(int idx)
        {
            var nd = _nodes[idx];
            M m = _traits.Identity();
            for (int i = 0; i <= nd.N; i++)
            {
                int child = nd.GetChild(i);
                if (child != -1)
                    m = _traits.Combine(m, _nodes[child].Measure);
                if (i < nd.N)
                    m = _traits.Combine(m, _traits.Measure(nd.GetKey(i)));
            }
            nd.Measure = m;
            _nodes[idx] = nd;
        }

        private void SplitChild(int parentIdx, int childPos)
        {
            var parent = _nodes[parentIdx];
            int childIdx = parent.GetChild(childPos);
            var child = _nodes[childIdx];

            K k0 = child.Key0, k1 = child.Key1, k2 = child.Key2;
            int c0 = child.Child0, c1 = child.Child1, c2 = child.Child2, c3 = child.Child3;

            int rightIdx = AllocNode();
            // After AllocNode, re-read parent/child by index
            var right = _nodes[rightIdx];
            right.N = 1;
            right.Key0 = k2;
            right.Child0 = c2;
            right.Child1 = c3;
            _nodes[rightIdx] = right;

            // Shrink child (left) to k0, c0, c1
            child = _nodes[childIdx];
            child.N = 1;
            child.Key0 = k0;
            child.Child0 = c0;
            child.Child1 = c1;
            child.Child2 = -1;
            child.Child3 = -1;
            _nodes[childIdx] = child;

            RecomputeMeasure(childIdx);
            RecomputeMeasure(rightIdx);

            // Insert k1 into parent at childPos
            parent = _nodes[parentIdx];
            for (int i = parent.N; i > childPos; i--)
            {
                parent.SetKey(i, parent.GetKey(i - 1));
                parent.SetChild(i + 1, parent.GetChild(i));
            }
            parent.SetKey(childPos, k1);
            parent.SetChild(childPos + 1, rightIdx);
            parent.N++;
            _nodes[parentIdx] = parent;

            RecomputeMeasure(parentIdx);
        }

        private void InsertNonFull(int idx, K key)
        {
            var nd = _nodes[idx];
            if (IsLeaf(idx))
            {
                int pos = nd.N;
                while (pos > 0 && _traits.Compare(key, nd.GetKey(pos - 1)) < 0)
                {
                    nd.SetKey(pos, nd.GetKey(pos - 1));
                    pos--;
                }
                nd.SetKey(pos, key);
                nd.N++;
                _nodes[idx] = nd;
                RecomputeMeasure(idx);
                return;
            }

            int p = 0;
            while (p < nd.N && _traits.Compare(key, nd.GetKey(p)) >= 0)
                p++;

            if (Is4Node(nd.GetChild(p)))
            {
                SplitChild(idx, p);
                nd = _nodes[idx]; // re-read after split
                if (_traits.Compare(key, nd.GetKey(p)) >= 0)
                    p++;
            }

            InsertNonFull(nd.GetChild(p), key);
            RecomputeMeasure(idx);
        }

        public void Insert(K key)
        {
            if (_root == -1)
            {
                _root = AllocNode();
                var nd = _nodes[_root];
                nd.N = 1;
                nd.Key0 = key;
                _nodes[_root] = nd;
                RecomputeMeasure(_root);
                _count++;
                return;
            }

            if (Is4Node(_root))
            {
                int oldRoot = _root;
                _root = AllocNode();
                var nd = _nodes[_root];
                nd.Child0 = oldRoot;
                _nodes[_root] = nd;
                SplitChild(_root, 0);
            }

            InsertNonFull(_root, key);
            _count++;
        }

        public void Clear()
        {
            _nodes.Clear();
            _freeList.Clear();
            _root = -1;
            _count = 0;
        }

        public int Size => _count;

        public M RootMeasure
        {
            get
            {
                if (_root == -1) return _traits.Identity();
                return _nodes[_root].Measure;
            }
        }

        private void ForEachImpl(int idx, Action<K> action)
        {
            if (idx == -1) return;
            var nd = _nodes[idx];
            for (int i = 0; i <= nd.N; i++)
            {
                int child = nd.GetChild(i);
                if (child != -1)
                    ForEachImpl(child, action);
                if (i < nd.N)
                    action(nd.GetKey(i));
            }
        }

        public void ForEach(Action<K> action)
        {
            ForEachImpl(_root, action);
        }

        public void Collect(List<K> output)
        {
            output.Clear();
            ForEach(k => output.Add(k));
        }

        private int SubtreeCount(int idx)
        {
            if (idx == -1) return 0;
            var nd = _nodes[idx];
            int c = nd.N;
            for (int i = 0; i <= nd.N; i++)
            {
                int child = nd.GetChild(i);
                if (child != -1)
                    c += SubtreeCount(child);
            }
            return c;
        }

        public WeightResult<K> FindByWeight(double target, Func<M, double> weightOf)
        {
            if (_root == -1)
                return new WeightResult<K> { Found = false };
            return FindByWeightImpl(_root, target, 0.0, 0, weightOf);
        }

        private WeightResult<K> FindByWeightImpl(int idx, double target, double cum, int globalIdx, Func<M, double> weightOf)
        {
            if (idx == -1)
                return new WeightResult<K> { Found = false };

            var nd = _nodes[idx];
            double runningCum = cum;
            int runningIdx = globalIdx;

            for (int i = 0; i <= nd.N; i++)
            {
                int child = nd.GetChild(i);
                if (child != -1)
                {
                    double childWeight = weightOf(_nodes[child].Measure);
                    if (runningCum + childWeight >= target)
                        return FindByWeightImpl(child, target, runningCum, runningIdx, weightOf);
                    runningCum += childWeight;
                    runningIdx += SubtreeCount(child);
                }

                if (i < nd.N)
                {
                    double keyWeight = weightOf(_traits.Measure(nd.GetKey(i)));
                    if (runningCum + keyWeight >= target)
                        return new WeightResult<K> { Key = nd.GetKey(i), CumBefore = runningCum, Index = runningIdx, Found = true };
                    runningCum += keyWeight;
                    runningIdx++;
                }
            }

            return new WeightResult<K> { Found = false };
        }

        public void BuildFromSorted(List<K> sorted)
        {
            Clear();
            if (sorted.Count == 0) return;
            _count = sorted.Count;
            _root = BuildRecursive(sorted, 0, sorted.Count);
        }

        private int BuildRecursive(List<K> sorted, int lo, int hi)
        {
            int n = hi - lo;
            if (n <= 0) return -1;

            if (n <= 3)
            {
                int idx = AllocNode();
                var nd = _nodes[idx];
                nd.N = n;
                for (int i = 0; i < n; i++)
                    nd.SetKey(i, sorted[lo + i]);
                _nodes[idx] = nd;
                RecomputeMeasure(idx);
                return idx;
            }

            if (n <= 7)
            {
                int mid = lo + n / 2;
                int left = BuildRecursive(sorted, lo, mid);
                int right = BuildRecursive(sorted, mid + 1, hi);
                int idx = AllocNode();
                var nd = _nodes[idx];
                nd.N = 1;
                nd.Key0 = sorted[mid];
                nd.Child0 = left;
                nd.Child1 = right;
                _nodes[idx] = nd;
                RecomputeMeasure(idx);
                return idx;
            }

            // 3-node for larger ranges
            int third = n / 3;
            int m1 = lo + third;
            int m2 = lo + 2 * third + 1;
            int c0 = BuildRecursive(sorted, lo, m1);
            int c1 = BuildRecursive(sorted, m1 + 1, m2);
            int c2 = BuildRecursive(sorted, m2 + 1, hi);
            {
                int idx = AllocNode();
                var nd = _nodes[idx];
                nd.N = 2;
                nd.Key0 = sorted[m1];
                nd.Key1 = sorted[m2];
                nd.Child0 = c0;
                nd.Child1 = c1;
                nd.Child2 = c2;
                _nodes[idx] = nd;
                RecomputeMeasure(idx);
                return idx;
            }
        }
    }
}
