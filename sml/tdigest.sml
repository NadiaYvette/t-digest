(* tdigest.sml -- Dunning's t-digest (merging digest variant) in Standard ML.
 * Purely functional: every operation returns a new digest value.
 *
 * This implementation uses an augmented balanced BST (weight-balanced tree)
 * for O(log n) quantile queries by cumulative weight and O(1) total
 * count/weight via cached subtree measures, similar to the Haskell
 * finger-tree implementation.
 *)

(* ------------------------------------------------------------------ *)
(* Signature                                                          *)
(* ------------------------------------------------------------------ *)
signature T_DIGEST =
sig
  type centroid = { mean : real, weight : real }
  type t

  val create     : real -> t                     (* delta *)
  val add        : t -> real -> real -> t         (* digest, value, weight *)
  val compress   : t -> t
  val quantile   : t -> real -> real option
  val cdf        : t -> real -> real option
  val merge      : t -> t -> t
  val totalWeight : t -> real
  val centroidCount : t -> int
end

(* ------------------------------------------------------------------ *)
(* Structure                                                          *)
(* ------------------------------------------------------------------ *)
structure TDigest :> T_DIGEST =
struct

  type centroid = { mean : real, weight : real }

  (* ---------------------------------------------------------------- *)
  (* Augmented weight-balanced BST (size-balanced tree)               *)
  (*                                                                  *)
  (* Each node caches:                                                *)
  (*   - subtree total weight (sum of all centroid weights)            *)
  (*   - subtree count (number of centroids)                          *)
  (* This gives O(1) measure at the root and O(log n) split by       *)
  (* cumulative weight.                                               *)
  (* ---------------------------------------------------------------- *)

  datatype tree
    = Leaf
    | Node of { left   : tree
              , cent   : centroid
              , right  : tree
              , tWeight : real    (* subtree total weight *)
              , tCount  : int     (* subtree centroid count *)
              }

  fun treeWeight Leaf = 0.0
    | treeWeight (Node {tWeight, ...}) = tWeight

  fun treeCount Leaf = 0
    | treeCount (Node {tCount, ...}) = tCount

  fun mkNode (l, c : centroid, r) =
    Node { left = l, cent = c, right = r
         , tWeight = treeWeight l + #weight c + treeWeight r
         , tCount  = treeCount l + 1 + treeCount r
         }

  (* Build a balanced BST from a sorted list in O(n). *)
  fun fromSortedList (xs : centroid list) : tree =
    let
      val arr = Vector.fromList xs
      val len = Vector.length arr
      fun build lo hi =
        if lo > hi then Leaf
        else
          let val mid = lo + (hi - lo) div 2
          in mkNode (build lo (mid - 1),
                     Vector.sub (arr, mid),
                     build (mid + 1) hi)
          end
    in
      build 0 (len - 1)
    end

  (* Convert tree to sorted list (in-order traversal). *)
  fun toList Leaf = []
    | toList (Node {left, cent, right, ...}) =
        toList left @ [cent] @ toList right

  (* Split by cumulative weight predicate: find the centroid where
   * cumulative weight (from left) exceeds target.
   * Returns (leftTree, matchOpt, rightTree, leftCumWeight, leftCumCount).
   * leftCumWeight = total weight of centroids strictly to the left of match.
   * This runs in O(log n) for balanced trees. *)
  fun splitByWeight (Leaf, _) = (Leaf, NONE, Leaf, 0.0, 0)
    | splitByWeight (Node {left, cent, right, ...}, target) =
        let
          val leftW = treeWeight left
          val leftPlusCent = leftW + #weight cent
        in
          if target <= leftW
          then
            (* Target is in the left subtree *)
            let
              val (ll, m, lr, cumW, cumC) = splitByWeight (left, target)
            in
              (ll, m, case m of
                        NONE => mkNode (lr, cent, right)
                      | SOME _ => mkNode (lr, cent, right),
               cumW, cumC)
            end
          else if target <= leftPlusCent
          then
            (* This centroid is the split point *)
            (left, SOME cent, right, leftW, treeCount left)
          else
            (* Target is in the right subtree *)
            let
              val (rl, m, rr, cumW, cumC) =
                splitByWeight (right, target - leftPlusCent)
            in
              (case m of
                 NONE => mkNode (left, cent, rl)
               | SOME _ => mkNode (left, cent, rl),
               m, rr,
               leftPlusCent + cumW,
               treeCount left + 1 + cumC)
            end
        end

  (* Get the rightmost centroid and its cumulative weight (weight before it). *)
  fun rightmost Leaf = NONE
    | rightmost (Node {left, cent, right = Leaf, ...}) =
        SOME (cent, treeWeight left)
    | rightmost (Node {left, cent, right, ...}) =
        (case rightmost right of
           SOME (c, cumInRight) =>
             SOME (c, treeWeight left + #weight cent + cumInRight)
         | NONE => NONE)

  (* Get the leftmost centroid. *)
  fun leftmost Leaf = NONE
    | leftmost (Node {left = Leaf, cent, ...}) = SOME cent
    | leftmost (Node {left, ...}) = leftmost left

  (* Get the centroid at a given 0-based index, plus cumulative weight before it. *)
  fun nthWithCum (Leaf, _) = NONE
    | nthWithCum (Node {left, cent, right, ...}, idx) =
        let val lc = treeCount left
        in
          if idx < lc then nthWithCum (left, idx)
          else if idx = lc then SOME (cent, treeWeight left)
          else
            case nthWithCum (right, idx - lc - 1) of
              SOME (c, cumInRight) =>
                SOME (c, treeWeight left + #weight cent + cumInRight)
            | NONE => NONE
        end

  (* ---------------------------------------------------------------- *)
  (* t-digest type using the tree                                     *)
  (* ---------------------------------------------------------------- *)

  type t =
    { centroids   : tree
    , buffer      : centroid list
    , bufferLen   : int
    , totalWeight : real
    , minVal      : real
    , maxVal      : real
    , delta       : real
    , bufferCap   : int
    }

  val pi = Math.pi

  (* K_1 scale function: k(q, delta) = (delta / (2 pi)) * asin(2q - 1) *)
  fun k (delta : real) (q : real) : real =
    (delta / (2.0 * pi)) * Math.asin (2.0 * q - 1.0)

  (* Create a fresh empty digest with the given compression parameter. *)
  fun create (delta : real) : t =
    { centroids   = Leaf
    , buffer      = []
    , bufferLen   = 0
    , totalWeight = 0.0
    , minVal      = Real.posInf
    , maxVal      = Real.negInf
    , delta       = delta
    , bufferCap   = Real.ceil (delta * 5.0)
    }

  (* ---- helpers --------------------------------------------------- *)

  (* Sort a centroid list by mean, ascending. Simple merge-sort. *)
  fun sortCentroids ([] : centroid list) : centroid list = []
    | sortCentroids [x] = [x]
    | sortCentroids xs =
        let
          fun split ([], left, right) = (left, right)
            | split ([x], left, right) = (x :: left, right)
            | split (a :: b :: rest, left, right) =
                split (rest, a :: left, b :: right)
          val (l, r) = split (xs, [], [])
          fun mergeL ([], ys) = ys
            | mergeL (xs, []) = xs
            | mergeL (x :: xs', y :: ys') =
                if #mean x <= #mean y
                then x :: mergeL (xs', y :: ys')
                else y :: mergeL (x :: xs', ys')
        in
          mergeL (sortCentroids l, sortCentroids r)
        end

  (* Weighted-mean merge of two centroids. *)
  fun mergeCentroid (a : centroid) (b : centroid) : centroid =
    let
      val w = #weight a + #weight b
    in
      { mean   = (#mean a * #weight a + #mean b * #weight b) / w
      , weight = w
      }
    end

  (* ---- compress (greedy merge on lists, rebuild tree) ------------ *)

  fun compressImpl (td : t) : t =
    let
      val { centroids, buffer, bufferLen = _, totalWeight = n, minVal, maxVal,
            delta = d, bufferCap } = td
    in
      if null buffer andalso treeCount centroids <= 1
      then td
      else
        let
          val all = sortCentroids (toList centroids @ buffer)

          (* Greedy merge walk.
             current   : centroid being built
             wsf       : weight before `current` (weight_so_far)
             rest      : remaining sorted centroids
             acc       : finished centroids in reverse order *)
          fun walk (current : centroid)
                   (wsf : real)
                   ([] : centroid list)
                   (acc : centroid list) : centroid list =
                rev (current :: acc)
            | walk current wsf (item :: rest) acc =
                let
                  val proposed = #weight current + #weight item
                  val q0 = wsf / n
                  val q1 = (wsf + proposed) / n
                  val canMerge =
                    (proposed <= 1.0 andalso not (null rest))
                    orelse (k d q1 - k d q0 <= 1.0)
                in
                  if canMerge
                  then walk (mergeCentroid current item) wsf rest acc
                  else walk item
                            (wsf + #weight current)
                            rest
                            (current :: acc)
                end
        in
          case all of
            [] =>
              { centroids = Leaf, buffer = [], bufferLen = 0,
                totalWeight = n,
                minVal = minVal, maxVal = maxVal,
                delta = d, bufferCap = bufferCap }
          | first :: rest =>
              let val merged = walk first 0.0 rest []
              in
                { centroids   = fromSortedList merged
                , buffer      = []
                , bufferLen   = 0
                , totalWeight = n
                , minVal      = minVal
                , maxVal      = maxVal
                , delta       = d
                , bufferCap   = bufferCap
                }
              end
        end
    end

  val compress = compressImpl

  (* ---- add ------------------------------------------------------- *)

  fun add (td : t) (value : real) (weight : real) : t =
    let
      val { centroids, buffer, bufferLen, totalWeight = n, minVal, maxVal,
            delta = d, bufferCap } = td
      val newBuf = { mean = value, weight = weight } :: buffer
      val newBufLen = bufferLen + 1
      val newN   = n + weight
      val newMin = Real.min (minVal, value)
      val newMax = Real.max (maxVal, value)
      val td' =
        { centroids   = centroids
        , buffer      = newBuf
        , bufferLen   = newBufLen
        , totalWeight = newN
        , minVal      = newMin
        , maxVal      = newMax
        , delta       = d
        , bufferCap   = bufferCap
        }
    in
      if newBufLen >= bufferCap
      then compressImpl td'
      else td'
    end

  (* ---- quantile (O(log n) via tree split) ------------------------ *)

  fun quantile (td : t) (q : real) : real option =
    let
      val td' = if null (#buffer td) then td else compressImpl td
      val cs  = #centroids td'
      val n   = #totalWeight td'
      val mn  = #minVal td'
      val mx  = #maxVal td'
      val numCentroids = treeCount cs
    in
      if numCentroids = 0 then NONE
      else if numCentroids = 1 then
        (case leftmost cs of
           SOME c => SOME (#mean c)
         | NONE => NONE)
      else
        let
          val q' = Real.max (0.0, Real.min (1.0, q))
          val target = q' * n

          (* Split the tree: find the centroid where cumulative weight
           * from the left exceeds target. This is O(log n). *)
          val (_, splitResult, _, leftCumW, leftCumC) =
            splitByWeight (cs, target)

          (* interpolateAt: given centroid index i, cumulative weight before it,
           * the centroid itself, and the target weight, interpolate the quantile value. *)
          fun interpolateAt (i : int) (cumulative : real) (c : centroid) : real =
            (* Left boundary *)
            if i = 0 andalso target < #weight c / 2.0
            then
              if Real.== (#weight c, 1.0) then mn
              else mn + (#mean c - mn) * (target / (#weight c / 2.0))
            (* Right boundary *)
            else if i = numCentroids - 1
            then
              let val rightStart = n - #weight c / 2.0
              in
                if target > rightStart
                then
                  if Real.== (#weight c, 1.0) then mx
                  else #mean c + (mx - #mean c)
                         * ((target - rightStart) / (#weight c / 2.0))
                else #mean c
              end
            (* Interior: interpolate between this midpoint and next *)
            else
              let
                val mid = cumulative + #weight c / 2.0
              in
                case nthWithCum (cs, i + 1) of
                  SOME (nc, _) =>
                    let
                      val nextMid = cumulative + #weight c + #weight nc / 2.0
                    in
                      if target <= nextMid
                      then
                        let
                          val frac =
                            if Real.== (nextMid, mid) then 0.5
                            else (target - mid) / (nextMid - mid)
                        in
                          #mean c + frac * (#mean nc - #mean c)
                        end
                      else
                        (* Advance to next centroid *)
                        interpolateAt (i + 1) (cumulative + #weight c) nc
                    end
                | NONE => #mean c
              end
        in
          case splitResult of
            SOME c =>
              SOME (interpolateAt leftCumC leftCumW c)
          | NONE =>
              (* target beyond all centroids; use rightmost *)
              (case rightmost cs of
                 SOME (c, cumBefore) =>
                   SOME (interpolateAt (numCentroids - 1) cumBefore c)
               | NONE => SOME mx)
        end
    end

  (* ---- cdf (O(log n) initial locate, then local walk) ------------ *)

  fun cdf (td : t) (x : real) : real option =
    let
      val td' = if null (#buffer td) then td else compressImpl td
      val cs  = #centroids td'
      val n   = #totalWeight td'
      val mn  = #minVal td'
      val mx  = #maxVal td'
      val numCentroids = treeCount cs
    in
      if numCentroids = 0 then NONE
      else if x <= mn then SOME 0.0
      else if x >= mx then SOME 1.0
      else
        let
          (* For CDF we walk the sorted list. We could do a BST search by mean
           * for a partial O(log n) optimization, but the list walk matches
           * the original algorithm's interpolation logic exactly. The primary
           * O(log n) benefit is in quantile queries via splitByWeight. *)
          val v   = Vector.fromList (toList cs)
          val len = Vector.length v
          fun centAt i = Vector.sub (v, i)

          fun walk (i : int) (cumulative : real) : real =
            if i >= len then 1.0
            else
              let
                val c  = centAt i
                val cw = #weight c
                val cm = #mean c
                val mid = cumulative + cw / 2.0
              in
                (* First centroid: left boundary region *)
                if i = 0 andalso x < cm
                then
                  let
                    val innerW = cw / 2.0
                    val frac = if Real.== (cm, mn) then 1.0
                               else (x - mn) / (cm - mn)
                  in
                    (innerW * frac) / n
                  end
                else if i = 0 andalso Real.== (x, cm)
                then (cw / 2.0) / n

                (* Last centroid: right boundary region *)
                else if i = len - 1
                then
                  if x > cm
                  then
                    let
                      val rightW = n - cumulative - cw / 2.0
                      val frac = if Real.== (mx, cm) then 0.0
                                 else (x - cm) / (mx - cm)
                    in
                      (cumulative + cw / 2.0 + rightW * frac) / n
                    end
                  else (cumulative + cw / 2.0) / n

                (* Interior *)
                else
                  let
                    val nc = centAt (i + 1)
                    val ncm = #mean nc
                    val nextCum = cumulative + cw
                    val nextMid = nextCum + #weight nc / 2.0
                  in
                    if x < ncm
                    then
                      if Real.== (cm, ncm)
                      then (mid + (nextMid - mid) / 2.0) / n
                      else
                        let val frac = (x - cm) / (ncm - cm)
                        in (mid + frac * (nextMid - mid)) / n
                        end
                    else walk (i + 1) (cumulative + cw)
                  end
              end
        in
          SOME (walk 0 0.0)
        end
    end

  (* ---- merge ----------------------------------------------------- *)

  fun merge (td1 : t) (td2 : t) : t =
    let
      val td2' = if null (#buffer td2) then td2 else compressImpl td2
      val otherCentroids = toList (#centroids td2')
      fun addAll td [] = td
        | addAll td ((c : centroid) :: rest) =
            addAll (add td (#mean c) (#weight c)) rest
    in
      addAll td1 otherCentroids
    end

  (* ---- accessors ------------------------------------------------- *)

  fun totalWeight (td : t) = #totalWeight td

  fun centroidCount (td : t) =
    let val td' = if null (#buffer td) then td else compressImpl td
    in treeCount (#centroids td')
    end

end (* structure TDigest *)
