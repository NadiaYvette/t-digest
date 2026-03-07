// Generic array-backed 2-3-4 tree with monoidal measures.
//
// Type parameters:
//   K - key/element type (stored in sorted order)
//   M - measure type (monoidal annotation on subtrees)
//
// Traits protocol provides:
//   measure(K) -> M         - measure a single element
//   combine(M, M) -> M     - monoidal combine
//   identity() -> M        - monoidal identity
//   compare(K, K) -> Int   - <0, 0, >0

protocol Tree234Traits {
    associatedtype K
    associatedtype M

    static func measure(_ key: K) -> M
    static func combine(_ a: M, _ b: M) -> M
    static func identity() -> M
    static func compare(_ a: K, _ b: K) -> Int
}

struct WeightResult<K> {
    var key: K
    var cumBefore: Double
    var index: Int
    var found: Bool
}

struct Tree234<Traits: Tree234Traits> {
    typealias K = Traits.K
    typealias M = Traits.M

    struct Node {
        var n: Int = 0             // number of keys: 1, 2, or 3
        var keys: (K?, K?, K?) = (nil, nil, nil)
        var children: (Int, Int, Int, Int) = (-1, -1, -1, -1)
        var measure: M = Traits.identity()

        // Key accessors using tuples (Swift doesn't allow fixed-size arrays easily)
        func key(_ i: Int) -> K {
            switch i {
            case 0: return keys.0!
            case 1: return keys.1!
            case 2: return keys.2!
            default: fatalError("key index out of range")
            }
        }

        mutating func setKey(_ i: Int, _ v: K) {
            switch i {
            case 0: keys.0 = v
            case 1: keys.1 = v
            case 2: keys.2 = v
            default: fatalError("key index out of range")
            }
        }

        func child(_ i: Int) -> Int {
            switch i {
            case 0: return children.0
            case 1: return children.1
            case 2: return children.2
            case 3: return children.3
            default: fatalError("child index out of range")
            }
        }

        mutating func setChild(_ i: Int, _ v: Int) {
            switch i {
            case 0: children.0 = v
            case 1: children.1 = v
            case 2: children.2 = v
            case 3: children.3 = v
            default: fatalError("child index out of range")
            }
        }
    }

    private var nodes: [Node] = []
    private var freeList: [Int] = []
    private var root: Int = -1
    private(set) var count: Int = 0

    init() {}

    // MARK: - Node allocation

    private mutating func allocNode() -> Int {
        if let idx = freeList.popLast() {
            nodes[idx] = Node()
            return idx
        }
        let idx = nodes.count
        nodes.append(Node())
        return idx
    }

    private mutating func freeNode(_ idx: Int) {
        freeList.append(idx)
    }

    private func isLeaf(_ idx: Int) -> Bool {
        return nodes[idx].children.0 == -1
    }

    private func is4Node(_ idx: Int) -> Bool {
        return nodes[idx].n == 3
    }

    // MARK: - Measure recomputation

    private mutating func recomputeMeasure(_ idx: Int) {
        let nd = nodes[idx]
        var m = Traits.identity()
        for i in 0...nd.n {
            let c = nd.child(i)
            if c != -1 {
                m = Traits.combine(m, nodes[c].measure)
            }
            if i < nd.n {
                m = Traits.combine(m, Traits.measure(nd.key(i)))
            }
        }
        nodes[idx].measure = m
    }

    // MARK: - Split 4-node child

    private mutating func splitChild(_ parentIdx: Int, _ childPos: Int) {
        let childIdx = nodes[parentIdx].child(childPos)

        // Save child data before allocNode may grow the array
        let k0 = nodes[childIdx].key(0)
        let k1 = nodes[childIdx].key(1)
        let k2 = nodes[childIdx].key(2)
        let c0 = nodes[childIdx].child(0)
        let c1 = nodes[childIdx].child(1)
        let c2 = nodes[childIdx].child(2)
        let c3 = nodes[childIdx].child(3)

        // Create right node with k2, c2, c3
        let rightIdx = allocNode()
        nodes[rightIdx].n = 1
        nodes[rightIdx].setKey(0, k2)
        nodes[rightIdx].setChild(0, c2)
        nodes[rightIdx].setChild(1, c3)

        // Shrink child (left) to k0, c0, c1
        nodes[childIdx].n = 1
        nodes[childIdx].setKey(0, k0)
        nodes[childIdx].setChild(0, c0)
        nodes[childIdx].setChild(1, c1)
        nodes[childIdx].setChild(2, -1)
        nodes[childIdx].setChild(3, -1)

        recomputeMeasure(childIdx)
        recomputeMeasure(rightIdx)

        // Insert mid key (k1) into parent at childPos
        let parentN = nodes[parentIdx].n
        // Shift keys and children right
        var i = parentN
        while i > childPos {
            nodes[parentIdx].setKey(i, nodes[parentIdx].key(i - 1))
            nodes[parentIdx].setChild(i + 1, nodes[parentIdx].child(i))
            i -= 1
        }
        nodes[parentIdx].setKey(childPos, k1)
        nodes[parentIdx].setChild(childPos + 1, rightIdx)
        nodes[parentIdx].n += 1

        recomputeMeasure(parentIdx)
    }

    // MARK: - Insert

    private mutating func insertNonFull(_ idx: Int, _ key: K) {
        if isLeaf(idx) {
            var pos = nodes[idx].n
            while pos > 0 && Traits.compare(key, nodes[idx].key(pos - 1)) < 0 {
                nodes[idx].setKey(pos, nodes[idx].key(pos - 1))
                pos -= 1
            }
            nodes[idx].setKey(pos, key)
            nodes[idx].n += 1
            recomputeMeasure(idx)
            return
        }

        var pos = 0
        while pos < nodes[idx].n && Traits.compare(key, nodes[idx].key(pos)) >= 0 {
            pos += 1
        }

        if is4Node(nodes[idx].child(pos)) {
            splitChild(idx, pos)
            if Traits.compare(key, nodes[idx].key(pos)) >= 0 {
                pos += 1
            }
        }

        insertNonFull(nodes[idx].child(pos), key)
        recomputeMeasure(idx)
    }

    mutating func insert(_ key: K) {
        if root == -1 {
            root = allocNode()
            nodes[root].n = 1
            nodes[root].setKey(0, key)
            recomputeMeasure(root)
            count += 1
            return
        }

        if is4Node(root) {
            let oldRoot = root
            root = allocNode()
            nodes[root].setChild(0, oldRoot)
            splitChild(root, 0)
        }

        insertNonFull(root, key)
        count += 1
    }

    // MARK: - Clear

    mutating func clear() {
        nodes.removeAll()
        freeList.removeAll()
        root = -1
        count = 0
    }

    // MARK: - Root measure

    func rootMeasure() -> M {
        if root == -1 { return Traits.identity() }
        return nodes[root].measure
    }

    // MARK: - In-order traversal

    private func forEachImpl(_ idx: Int, _ body: (K) -> Void) {
        if idx == -1 { return }
        let nd = nodes[idx]
        for i in 0...nd.n {
            let c = nd.child(i)
            if c != -1 {
                forEachImpl(c, body)
            }
            if i < nd.n {
                body(nd.key(i))
            }
        }
    }

    func forEach(_ body: (K) -> Void) {
        forEachImpl(root, body)
    }

    // MARK: - Collect

    func collect() -> [K] {
        var result: [K] = []
        result.reserveCapacity(count)
        forEach { result.append($0) }
        return result
    }

    // MARK: - Subtree count

    private func subtreeCount(_ idx: Int) -> Int {
        if idx == -1 { return 0 }
        let nd = nodes[idx]
        var c = nd.n
        for i in 0...nd.n {
            let ch = nd.child(i)
            if ch != -1 {
                c += subtreeCount(ch)
            }
        }
        return c
    }

    // MARK: - Find by weight

    private func findByWeightImpl(_ idx: Int, _ target: Double, _ cum: Double,
                                   _ globalIdx: Int,
                                   _ weightOf: (M) -> Double) -> WeightResult<K>? {
        if idx == -1 { return nil }

        let nd = nodes[idx]
        var runningCum = cum
        var runningIdx = globalIdx

        for i in 0...nd.n {
            let c = nd.child(i)
            if c != -1 {
                let childWeight = weightOf(nodes[c].measure)
                if runningCum + childWeight >= target {
                    return findByWeightImpl(c, target, runningCum, runningIdx, weightOf)
                }
                runningCum += childWeight
                runningIdx += subtreeCount(c)
            }

            if i < nd.n {
                let keyWeight = weightOf(Traits.measure(nd.key(i)))
                if runningCum + keyWeight >= target {
                    return WeightResult(key: nd.key(i), cumBefore: runningCum,
                                        index: runningIdx, found: true)
                }
                runningCum += keyWeight
                runningIdx += 1
            }
        }

        return nil
    }

    func findByWeight(_ target: Double, _ weightOf: (M) -> Double) -> WeightResult<K>? {
        if root == -1 { return nil }
        return findByWeightImpl(root, target, 0.0, 0, weightOf)
    }

    // MARK: - Build from sorted

    private mutating func buildRecursive(_ sorted: [K], _ lo: Int, _ hi: Int) -> Int {
        let n = hi - lo
        if n <= 0 { return -1 }

        if n <= 3 {
            let idx = allocNode()
            nodes[idx].n = n
            for i in 0..<n {
                nodes[idx].setKey(i, sorted[lo + i])
            }
            recomputeMeasure(idx)
            return idx
        }

        if n <= 7 {
            let mid = lo + n / 2
            let left = buildRecursive(sorted, lo, mid)
            let right = buildRecursive(sorted, mid + 1, hi)
            let idx = allocNode()
            nodes[idx].n = 1
            nodes[idx].setKey(0, sorted[mid])
            nodes[idx].setChild(0, left)
            nodes[idx].setChild(1, right)
            recomputeMeasure(idx)
            return idx
        }

        // Use 3-node for larger ranges
        let third = n / 3
        let m1 = lo + third
        let m2 = lo + 2 * third + 1
        let c0 = buildRecursive(sorted, lo, m1)
        let c1 = buildRecursive(sorted, m1 + 1, m2)
        let c2 = buildRecursive(sorted, m2 + 1, hi)
        let idx = allocNode()
        nodes[idx].n = 2
        nodes[idx].setKey(0, sorted[m1])
        nodes[idx].setKey(1, sorted[m2])
        nodes[idx].setChild(0, c0)
        nodes[idx].setChild(1, c1)
        nodes[idx].setChild(2, c2)
        recomputeMeasure(idx)
        return idx
    }

    mutating func buildFromSorted(_ sorted: [K]) {
        clear()
        if sorted.isEmpty { return }
        count = sorted.count
        root = buildRecursive(sorted, 0, sorted.count)
    }

    // MARK: - Size

    var size: Int { return count }
}
