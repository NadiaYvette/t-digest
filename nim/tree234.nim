# Generic array-backed 2-3-4 tree with monoidal measures.
#
# Type parameters:
#   K      - key/element type (stored in sorted order)
#   M      - measure type (monoidal annotation on subtrees)
#
# Trait procs (passed at construction):
#   measureFn(K) -> M            - measure a single element
#   combineFn(M, M) -> M         - monoidal combine
#   identityFn() -> M            - monoidal identity
#   compareFn(K, K) -> int       - <0, 0, >0

type
  Node[K, M] = object
    n: int                        # number of keys: 1, 2, or 3
    keys: array[3, K]
    children: array[4, int]       # -1 means no child (leaf edge)
    measure: M                    # cached subtree measure

  WeightResult*[K] = object
    key*: K
    cumBefore*: float
    index*: int
    found*: bool

  Tree234*[K, M] = object
    nodes: seq[Node[K, M]]
    freeList: seq[int]
    root: int
    count: int
    measureFn*: proc(k: K): M {.noSideEffect.}
    combineFn*: proc(a, b: M): M {.noSideEffect.}
    identityFn*: proc(): M {.noSideEffect.}
    compareFn*: proc(a, b: K): int {.noSideEffect.}

proc initNode[K, M](identity: M): Node[K, M] =
  result.n = 0
  result.children = [-1, -1, -1, -1]
  result.measure = identity

proc newTree234*[K, M](
    measureFn: proc(k: K): M {.noSideEffect.},
    combineFn: proc(a, b: M): M {.noSideEffect.},
    identityFn: proc(): M {.noSideEffect.},
    compareFn: proc(a, b: K): int {.noSideEffect.}
): Tree234[K, M] =
  result.nodes = @[]
  result.freeList = @[]
  result.root = -1
  result.count = 0
  result.measureFn = measureFn
  result.combineFn = combineFn
  result.identityFn = identityFn
  result.compareFn = compareFn

proc allocNode[K, M](t: var Tree234[K, M]): int =
  if t.freeList.len > 0:
    result = t.freeList[^1]
    t.freeList.setLen(t.freeList.len - 1)
    t.nodes[result] = initNode[K, M](t.identityFn())
  else:
    result = t.nodes.len
    t.nodes.add(initNode[K, M](t.identityFn()))

proc isLeaf[K, M](t: Tree234[K, M], idx: int): bool {.inline.} =
  t.nodes[idx].children[0] == -1

proc is4Node[K, M](t: Tree234[K, M], idx: int): bool {.inline.} =
  t.nodes[idx].n == 3

proc recomputeMeasure[K, M](t: var Tree234[K, M], idx: int) =
  var m = t.identityFn()
  let nd = t.nodes[idx]
  for i in 0 .. nd.n:
    if nd.children[i] != -1:
      m = t.combineFn(m, t.nodes[nd.children[i]].measure)
    if i < nd.n:
      m = t.combineFn(m, t.measureFn(nd.keys[i]))
  t.nodes[idx].measure = m

proc splitChild[K, M](t: var Tree234[K, M], parentIdx, childPos: int) =
  let childIdx = t.nodes[parentIdx].children[childPos]
  assert t.nodes[childIdx].n == 3

  # Save child data before allocNode may invalidate references
  let k0 = t.nodes[childIdx].keys[0]
  let k1 = t.nodes[childIdx].keys[1]
  let k2 = t.nodes[childIdx].keys[2]
  let c0 = t.nodes[childIdx].children[0]
  let c1 = t.nodes[childIdx].children[1]
  let c2 = t.nodes[childIdx].children[2]
  let c3 = t.nodes[childIdx].children[3]

  # Create right node with k2, c2, c3
  let rightIdx = t.allocNode()
  t.nodes[rightIdx].n = 1
  t.nodes[rightIdx].keys[0] = k2
  t.nodes[rightIdx].children[0] = c2
  t.nodes[rightIdx].children[1] = c3

  # Shrink child (left) to k0, c0, c1
  t.nodes[childIdx].n = 1
  t.nodes[childIdx].keys[0] = k0
  t.nodes[childIdx].children[0] = c0
  t.nodes[childIdx].children[1] = c1
  t.nodes[childIdx].children[2] = -1
  t.nodes[childIdx].children[3] = -1

  # Recompute measures for left and right
  t.recomputeMeasure(childIdx)
  t.recomputeMeasure(rightIdx)

  # Insert mid_key (k1) into parent at childPos
  # Shift keys and children to make room
  var i = t.nodes[parentIdx].n
  while i > childPos:
    t.nodes[parentIdx].keys[i] = t.nodes[parentIdx].keys[i - 1]
    t.nodes[parentIdx].children[i + 1] = t.nodes[parentIdx].children[i]
    dec i
  t.nodes[parentIdx].keys[childPos] = k1
  t.nodes[parentIdx].children[childPos + 1] = rightIdx
  inc t.nodes[parentIdx].n

  t.recomputeMeasure(parentIdx)

proc insertNonFull[K, M](t: var Tree234[K, M], idx: int, key: K) =
  if t.isLeaf(idx):
    # Insert key in sorted position
    var pos = t.nodes[idx].n
    while pos > 0 and t.compareFn(key, t.nodes[idx].keys[pos - 1]) < 0:
      t.nodes[idx].keys[pos] = t.nodes[idx].keys[pos - 1]
      dec pos
    t.nodes[idx].keys[pos] = key
    inc t.nodes[idx].n
    t.recomputeMeasure(idx)
    return

  # Find child to descend into
  var pos = 0
  while pos < t.nodes[idx].n and t.compareFn(key, t.nodes[idx].keys[pos]) >= 0:
    inc pos

  # If that child is a 4-node, split it first
  if t.is4Node(t.nodes[idx].children[pos]):
    t.splitChild(idx, pos)
    # After split, mid_key is at keys[pos]. Decide which side to go.
    if t.compareFn(key, t.nodes[idx].keys[pos]) >= 0:
      inc pos

  t.insertNonFull(t.nodes[idx].children[pos], key)
  t.recomputeMeasure(idx)

proc insert*[K, M](t: var Tree234[K, M], key: K) =
  if t.root == -1:
    t.root = t.allocNode()
    t.nodes[t.root].n = 1
    t.nodes[t.root].keys[0] = key
    t.recomputeMeasure(t.root)
    inc t.count
    return

  # If root is a 4-node, split it
  if t.is4Node(t.root):
    let oldRoot = t.root
    t.root = t.allocNode()
    t.nodes[t.root].children[0] = oldRoot
    t.splitChild(t.root, 0)

  t.insertNonFull(t.root, key)
  inc t.count

proc clear*[K, M](t: var Tree234[K, M]) =
  t.nodes.setLen(0)
  t.freeList.setLen(0)
  t.root = -1
  t.count = 0

proc size*[K, M](t: Tree234[K, M]): int = t.count

proc rootMeasure*[K, M](t: Tree234[K, M]): M =
  if t.root == -1:
    return t.identityFn()
  t.nodes[t.root].measure

proc forEachImpl[K, M](t: Tree234[K, M], idx: int, f: proc(k: K)) =
  if idx == -1:
    return
  let nd = t.nodes[idx]
  for i in 0 .. nd.n:
    if nd.children[i] != -1:
      t.forEachImpl(nd.children[i], f)
    if i < nd.n:
      f(nd.keys[i])

proc forEach*[K, M](t: Tree234[K, M], f: proc(k: K)) =
  t.forEachImpl(t.root, f)

proc collectImpl[K, M](t: Tree234[K, M], idx: int, output: var seq[K]) =
  if idx == -1:
    return
  let nd = t.nodes[idx]
  for i in 0 .. nd.n:
    if nd.children[i] != -1:
      t.collectImpl(nd.children[i], output)
    if i < nd.n:
      output.add(nd.keys[i])

proc collect*[K, M](t: Tree234[K, M], output: var seq[K]) =
  output.setLen(0)
  t.collectImpl(t.root, output)

proc subtreeCount[K, M](t: Tree234[K, M], idx: int): int =
  if idx == -1:
    return 0
  let nd = t.nodes[idx]
  result = nd.n
  for i in 0 .. nd.n:
    if nd.children[i] != -1:
      result += t.subtreeCount(nd.children[i])

proc findByWeightImpl[K, M](t: Tree234[K, M], idx: int, target, cum: float,
    globalIdx: int, weightOf: proc(m: M): float): WeightResult[K] =
  if idx == -1:
    result.found = false
    return

  let nd = t.nodes[idx]
  var runningCum = cum
  var runningIdx = globalIdx

  for i in 0 .. nd.n:
    # Process child
    if nd.children[i] != -1:
      let childWeight = weightOf(t.nodes[nd.children[i]].measure)
      if runningCum + childWeight >= target:
        return t.findByWeightImpl(nd.children[i], target, runningCum,
            runningIdx, weightOf)
      runningCum += childWeight
      runningIdx += t.subtreeCount(nd.children[i])

    if i < nd.n:
      let keyWeight = weightOf(t.measureFn(nd.keys[i]))
      if runningCum + keyWeight >= target:
        return WeightResult[K](key: nd.keys[i], cumBefore: runningCum,
            index: runningIdx, found: true)
      runningCum += keyWeight
      inc runningIdx

  result.found = false

proc findByWeight*[K, M](t: Tree234[K, M], target: float,
    weightOf: proc(m: M): float): WeightResult[K] =
  if t.root == -1:
    result.found = false
    return
  t.findByWeightImpl(t.root, target, 0.0, 0, weightOf)

proc buildRecursive[K, M](t: var Tree234[K, M], sorted: openArray[K],
    lo, hi: int): int =
  let n = hi - lo
  if n <= 0:
    return -1

  if n <= 3:
    result = t.allocNode()
    t.nodes[result].n = n
    for i in 0 ..< n:
      t.nodes[result].keys[i] = sorted[lo + i]
    t.recomputeMeasure(result)
    return

  # For moderate ranges, create a 2-node and recurse
  if n <= 7:
    let mid = lo + n div 2
    let left = t.buildRecursive(sorted, lo, mid)
    let right = t.buildRecursive(sorted, mid + 1, hi)
    result = t.allocNode()
    t.nodes[result].n = 1
    t.nodes[result].keys[0] = sorted[mid]
    t.nodes[result].children[0] = left
    t.nodes[result].children[1] = right
    t.recomputeMeasure(result)
    return

  # For larger, use 3-node to keep tree balanced
  let third = n div 3
  let m1 = lo + third
  let m2 = lo + 2 * third + 1
  let c0 = t.buildRecursive(sorted, lo, m1)
  let c1 = t.buildRecursive(sorted, m1 + 1, m2)
  let c2 = t.buildRecursive(sorted, m2 + 1, hi)
  result = t.allocNode()
  t.nodes[result].n = 2
  t.nodes[result].keys[0] = sorted[m1]
  t.nodes[result].keys[1] = sorted[m2]
  t.nodes[result].children[0] = c0
  t.nodes[result].children[1] = c1
  t.nodes[result].children[2] = c2
  t.recomputeMeasure(result)

proc buildFromSorted*[K, M](t: var Tree234[K, M], sorted: openArray[K]) =
  t.clear()
  if sorted.len == 0:
    return
  t.count = sorted.len
  t.root = t.buildRecursive(sorted, 0, sorted.len)
