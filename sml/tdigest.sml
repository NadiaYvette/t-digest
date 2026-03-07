(* tdigest.sml -- Dunning's t-digest (merging digest variant) in Standard ML.
 * Purely functional: every operation returns a new digest value.
 *
 * This implementation uses an augmented balanced BST (weight-balanced tree)
 * with a four-component measure per node, following the pattern of the
 * Haskell finger-tree reference implementation:
 *
 *   tWeight       -- subtree total weight (for split-by-cumulative-weight)
 *   tCount        -- subtree centroid count (O(1) size)
 *   tMaxMean      -- maximum centroid mean in subtree (for split-by-mean)
 *   tMeanWeightSum -- sum of (mean * weight) for all centroids (O(1) chunk merge)
 *
 * This enables:
 *   - O(log n) insertion via split-by-mean (no buffering needed)
 *   - O(log n) quantile queries via split-by-cumulative-weight
 *   - O(log n) CDF queries via split-by-mean
 *   - O(delta * log n) compression via split-based greedy merge
 *   - O(1) total weight, centroid count, and chunk mean computation
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
  (* Augmented weight-balanced BST with four-component measure        *)
  (*                                                                  *)
  (* Each node caches:                                                *)
  (*   - subtree total weight (sum of all centroid weights)            *)
  (*   - subtree count (number of centroids)                          *)
  (*   - maximum centroid mean in subtree                              *)
  (*   - sum of mean*weight for all centroids in subtree              *)
  (* ---------------------------------------------------------------- *)

  datatype tree
    = Leaf
    | Node of { left          : tree
              , cent          : centroid
              , right         : tree
              , tWeight       : real    (* subtree total weight *)
              , tCount        : int     (* subtree centroid count *)
              , tMaxMean      : real    (* max centroid mean in subtree *)
              , tMeanWeightSum : real   (* sum of mean*weight in subtree *)
              }

  fun treeWeight Leaf = 0.0
    | treeWeight (Node {tWeight, ...}) = tWeight

  fun treeCount Leaf = 0
    | treeCount (Node {tCount, ...}) = tCount

  fun treeMaxMean Leaf = Real.negInf
    | treeMaxMean (Node {tMaxMean, ...}) = tMaxMean

  fun treeMeanWeightSum Leaf = 0.0
    | treeMeanWeightSum (Node {tMeanWeightSum, ...}) = tMeanWeightSum

  fun mkNode (l, c : centroid, r) =
    Node { left = l, cent = c, right = r
         , tWeight = treeWeight l + #weight c + treeWeight r
         , tCount  = treeCount l + 1 + treeCount r
         , tMaxMean = Real.max (treeMaxMean l, Real.max (#mean c, treeMaxMean r))
         , tMeanWeightSum = treeMeanWeightSum l + #mean c * #weight c + treeMeanWeightSum r
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

  (* ---------------------------------------------------------------- *)
  (* Tree operations                                                  *)
  (* ---------------------------------------------------------------- *)

  (* Split tree into (left, right) where all centroids in left have
   * mean < x and right starts with the first centroid with mean >= x.
   * O(log n). *)
  fun splitByMean (Leaf, _) = (Leaf, Leaf)
    | splitByMean (Node {left, cent, right, ...}, x) =
        if #mean cent >= x
        then
          let val (ll, lr) = splitByMean (left, x)
          in (ll, mkNode (lr, cent, right))
          end
        else
          let val (rl, rr) = splitByMean (right, x)
          in (mkNode (left, cent, rl), rr)
          end

  (* Split tree into (left, right) where left has cumulative weight <= target
   * and right has the rest. O(log n). *)
  fun splitAtWeight (Leaf, _) = (Leaf, Leaf)
    | splitAtWeight (Node {left, cent, right, ...}, target) =
        let val leftW = treeWeight left
        in
          if target <= leftW
          then
            let val (ll, lr) = splitAtWeight (left, target)
            in (ll, mkNode (lr, cent, right))
            end
          else if target < leftW + #weight cent
          then
            (left, mkNode (Leaf, cent, right))
          else
            let val (rl, rr) = splitAtWeight (right, target - leftW - #weight cent)
            in (mkNode (left, cent, rl), rr)
            end
        end

  (* Split by cumulative weight predicate: find the centroid where
   * cumulative weight (from left) exceeds target.
   * Returns (leftTree, matchOpt, rightTree, leftCumWeight, leftCumCount).
   * This runs in O(log n) for balanced trees. *)
  fun splitByWeight (Leaf, _) = (Leaf, NONE, Leaf, 0.0, 0)
    | splitByWeight (Node {left, cent, right, ...}, target) =
        let
          val leftW = treeWeight left
          val leftPlusCent = leftW + #weight cent
        in
          if target <= leftW
          then
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
            (left, SOME cent, right, leftW, treeCount left)
          else
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

  (* Get the rightmost centroid and the tree without it. *)
  fun viewRight Leaf = NONE
    | viewRight (Node {left, cent, right = Leaf, ...}) = SOME (left, cent)
    | viewRight (Node {left, cent, right, ...}) =
        (case viewRight right of
           SOME (rest, rc) => SOME (mkNode (left, cent, rest), rc)
         | NONE => NONE)

  (* Get the leftmost centroid and the tree without it. *)
  fun viewLeft Leaf = NONE
    | viewLeft (Node {left = Leaf, cent, right, ...}) = SOME (cent, right)
    | viewLeft (Node {left, cent, right, ...}) =
        (case viewLeft left of
           SOME (lc, rest) => SOME (lc, mkNode (rest, cent, right))
         | NONE => NONE)

  (* Get the rightmost centroid (without removing). *)
  fun rightmost Leaf = NONE
    | rightmost (Node {cent, right = Leaf, ...}) = SOME cent
    | rightmost (Node {right, ...}) = rightmost right

  (* Get the leftmost centroid (without removing). *)
  fun leftmost Leaf = NONE
    | leftmost (Node {left = Leaf, cent, ...}) = SOME cent
    | leftmost (Node {left, ...}) = leftmost left

  (* Join two trees where all keys in l < c < all keys in r.
   * Produces a reasonably balanced tree. O(log n). *)
  fun joinWith (Leaf, c, r) = insertMin (c, r)
    | joinWith (l, c, Leaf) = insertMax (c, l)
    | joinWith (l as Node {left=ll, cent=lc, right=lr, tCount=ln, ...},
                c,
                r as Node {left=rl, cent=rc, right=rr, tCount=rn, ...}) =
        if ln > 3 * rn
        then mkNode (ll, lc, joinWith (lr, c, r))
        else if rn > 3 * ln
        then mkNode (joinWith (l, c, rl), rc, rr)
        else mkNode (l, c, r)

  (* Insert at the minimum (leftmost) position. *)
  and insertMin (c, Leaf) = mkNode (Leaf, c, Leaf)
    | insertMin (c, Node {left, cent, right, ...}) =
        mkNode (insertMin (c, left), cent, right)

  (* Insert at the maximum (rightmost) position. *)
  and insertMax (c, Leaf) = mkNode (Leaf, c, Leaf)
    | insertMax (c, Node {left, cent, right, ...}) =
        mkNode (left, cent, insertMax (c, right))

  (* Join two trees where all keys in l < all keys in r. O(log n). *)
  fun treeJoin (Leaf, r) = r
    | treeJoin (l, Leaf) = l
    | treeJoin (l, r) =
        case viewLeft r of
          SOME (c, r') => joinWith (l, c, r')
        | NONE => l

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
  (* t-digest type                                                    *)
  (* ---------------------------------------------------------------- *)

  type t =
    { centroids    : tree
    , totalWeight  : real
    , minVal       : real
    , maxVal       : real
    , delta        : real
    , maxCentroids : int
    }

  val pi = Math.pi

  (* K_1 scale function: k(q, delta) = (delta / (2 pi)) * asin(2q - 1) *)
  fun k (delta : real) (q : real) : real =
    (delta / (2.0 * pi)) * Math.asin (2.0 * q - 1.0)

  (* K_1 inverse: q(k, delta) = (1 + sin(2 pi k / delta)) / 2 *)
  fun kInv (delta : real) (kVal : real) : real =
    (1.0 + Math.sin (2.0 * pi * kVal / delta)) / 2.0

  (* Create a fresh empty digest with the given compression parameter. *)
  fun create (delta : real) : t =
    { centroids    = Leaf
    , totalWeight  = 0.0
    , minVal       = Real.posInf
    , maxVal       = Real.negInf
    , delta        = delta
    , maxCentroids = Real.ceil (delta * 3.0)
    }

  (* ---- helpers --------------------------------------------------- *)

  (* Weighted-mean merge of two centroids. *)
  fun mergeCentroid (a : centroid) (b : centroid) : centroid =
    let
      val w = #weight a + #weight b
    in
      { mean   = (#mean a * #weight a + #mean b * #weight b) / w
      , weight = w
      }
    end

  (* ---- add (O(log n) direct insertion) ----------------------------- *)

  fun add (td : t) (value : real) (weight : real) : t =
    let
      val { centroids = cs, totalWeight = oldN, minVal, maxVal,
            delta = d, maxCentroids } = td
      val n = oldN + weight
      val newMin = Real.min (minVal, value)
      val newMax = Real.max (maxVal, value)
      val newC : centroid = { mean = value, weight = weight }
    in
      if treeCount cs = 0
      then
        { centroids    = mkNode (Leaf, newC, Leaf)
        , totalWeight  = n
        , minVal       = newMin
        , maxVal       = newMax
        , delta        = d
        , maxCentroids = maxCentroids
        }
      else
        let
          val (left, right) = splitByMean (cs, value)
          val leftWeight = treeWeight left
          val kf = k d

          (* Check left neighbor *)
          val leftNeighbor =
            case viewRight left of
              NONE => NONE
            | SOME (leftRest, lc) =>
                let
                  val cumBefore = treeWeight leftRest
                  val proposed = #weight lc + weight
                  val q0 = cumBefore / n
                  val q1 = (cumBefore + proposed) / n
                  val canMerge = kf q1 - kf q0 <= 1.0
                  val dist = Real.abs (#mean lc - value)
                in
                  if canMerge
                  then SOME (leftRest, lc, dist)
                  else NONE
                end

          (* Check right neighbor *)
          val rightNeighbor =
            case viewLeft right of
              NONE => NONE
            | SOME (rc, rightRest) =>
                let
                  val proposed = #weight rc + weight
                  val q0 = leftWeight / n
                  val q1 = (leftWeight + proposed) / n
                  val canMerge = kf q1 - kf q0 <= 1.0
                  val dist = Real.abs (#mean rc - value)
                in
                  if canMerge
                  then SOME (rightRest, rc, dist)
                  else NONE
                end

          val newCentroids =
            case (leftNeighbor, rightNeighbor) of
              (SOME (leftRest, lc, ldist), SOME (rightRest, rc, rdist)) =>
                if ldist <= rdist
                then joinWith (leftRest, mergeCentroid lc newC, right)
                else joinWith (left, mergeCentroid rc newC, rightRest)
            | (SOME (leftRest, lc, _), NONE) =>
                joinWith (leftRest, mergeCentroid lc newC, right)
            | (NONE, SOME (rightRest, rc, _)) =>
                joinWith (left, mergeCentroid rc newC, rightRest)
            | (NONE, NONE) =>
                joinWith (left, newC, right)

          val td' =
            { centroids    = newCentroids
            , totalWeight  = n
            , minVal       = newMin
            , maxVal       = newMax
            , delta        = d
            , maxCentroids = maxCentroids
            }
        in
          if treeCount newCentroids > maxCentroids
          then compressImpl td'
          else td'
        end
    end

  (* ---- compress (split-based O(delta * log n)) -------------------- *)

  and compressImpl (td : t) : t =
    let
      val { centroids = cs, totalWeight = n, minVal, maxVal,
            delta = d, maxCentroids } = td
      val cnt = treeCount cs
    in
      if cnt <= 1
      then td
      else
        let
          (* K1 range: k(0) = -delta/2, k(1) = +delta/2 *)
          val kMin = k d 0.0   (* = -delta/2 *)
          val kMax = k d 1.0   (* = +delta/2 *)
          val jMin = Real.ceil kMin
          val jMax = Real.floor kMax

          (* Build boundaries: cumulative weight at each integer k-value *)
          fun buildBoundaries (j, acc) =
            if j > jMax then rev acc
            else buildBoundaries (j + 1, (kInv d (Real.fromInt j) * n) :: acc)

          val boundaries = buildBoundaries (jMin + 1, [])

          (* Merge all centroids in a chunk into one using the measure. O(1). *)
          fun mergeChunk (chunk : tree) : centroid option =
            let val w = treeWeight chunk
            in
              if w <= 0.0 then NONE
              else SOME { mean = treeMeanWeightSum chunk / w, weight = w }
            end

          (* Split-and-merge at each boundary *)
          fun splitMerge ([], remaining, acc) =
                (case mergeChunk remaining of
                   NONE => rev acc
                 | SOME c => rev (c :: acc))
            | splitMerge (b :: bs, remaining, acc) =
                let
                  val (chunk, rest) = splitAtWeight (remaining, b)
                in
                  case mergeChunk chunk of
                    NONE => splitMerge (bs, rest, acc)
                  | SOME c => splitMerge (bs, rest, c :: acc)
                end

          val mergedList = splitMerge (boundaries, cs, [])
        in
          { centroids    = fromSortedList mergedList
          , totalWeight  = n
          , minVal       = minVal
          , maxVal       = maxVal
          , delta        = d
          , maxCentroids = maxCentroids
          }
        end
    end

  val compress = compressImpl

  (* ---- quantile (O(log n) via tree split) ------------------------ *)

  fun quantile (td : t) (q : real) : real option =
    let
      val cs  = #centroids td
      val n   = #totalWeight td
      val mn  = #minVal td
      val mx  = #maxVal td
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
                 SOME c =>
                   let val cumBefore = n - #weight c
                   in SOME (interpolateAt (numCentroids - 1) cumBefore c)
                   end
               | NONE => SOME mx)
        end
    end

  (* ---- cdf (O(log n) via split-by-mean) -------------------------- *)

  fun cdf (td : t) (x : real) : real option =
    let
      val cs  = #centroids td
      val n   = #totalWeight td
      val mn  = #minVal td
      val mx  = #maxVal td
      val numCentroids = treeCount cs
    in
      if numCentroids = 0 then NONE
      else if x <= mn then SOME 0.0
      else if x >= mx then SOME 1.0
      else
        let
          val (left, right) = splitByMean (cs, x)

          fun cdfAtFirst (c : centroid) : real =
            if x < #mean c
            then
              let
                val innerW = #weight c / 2.0
                val frac = if Real.== (#mean c, mn) then 1.0
                           else (x - mn) / (#mean c - mn)
              in
                (innerW * frac) / n
              end
            else (#weight c / 2.0) / n

          fun cdfAtLast (c : centroid) (cumBefore : real) : real =
            if x > #mean c
            then
              let
                val halfW = #weight c / 2.0
                val rightW = n - cumBefore - halfW
                val frac = if Real.== (mx, #mean c) then 0.0
                           else (x - #mean c) / (mx - #mean c)
              in
                (cumBefore + halfW + rightW * frac) / n
              end
            else (cumBefore + #weight c / 2.0) / n

          fun cdfBetween (lc : centroid) (lcCum : real)
                         (rc : centroid) (rcCum : real) : real =
            if x <= #mean lc then (lcCum + #weight lc / 2.0) / n
            else if x >= #mean rc then (rcCum + #weight rc / 2.0) / n
            else
              let
                val lMid = lcCum + #weight lc / 2.0
                val rMid = rcCum + #weight rc / 2.0
                val frac = if Real.== (#mean lc, #mean rc) then 0.5
                           else (x - #mean lc) / (#mean rc - #mean lc)
              in
                (lMid + frac * (rMid - lMid)) / n
              end
        in
          case (viewRight left, viewLeft right) of
            (NONE, SOME (rc, _)) =>
              (* x is before all centroids *)
              SOME (cdfAtFirst rc)
          | (_, NONE) =>
              (* x is after all centroids *)
              (case viewRight left of
                 SOME (lRest, lc) =>
                   SOME (cdfAtLast lc (treeWeight lRest))
               | NONE => SOME 1.0)
          | (SOME (lRest, lc), SOME (rc, _)) =>
              let
                val lcCum = treeWeight lRest
                val lcIdx = treeCount lRest
                val rcIdx = treeCount left
              in
                if x <= #mean lc
                then
                  if lcIdx = 0
                  then SOME (cdfAtFirst lc)
                  else
                    (case viewRight lRest of
                       SOME (llRest, llc) =>
                         SOME (cdfBetween llc (treeWeight llRest) lc lcCum)
                     | NONE => SOME (cdfAtFirst lc))
                else
                  if rcIdx = numCentroids - 1 andalso x > #mean rc
                  then SOME (cdfAtLast rc (treeWeight left))
                  else SOME (cdfBetween lc lcCum rc (treeWeight left))
              end
        end
    end

  (* ---- merge ----------------------------------------------------- *)

  fun merge (td1 : t) (td2 : t) : t =
    let
      val otherCentroids = toList (#centroids td2)
      fun addAll td [] = td
        | addAll td ((c : centroid) :: rest) =
            addAll (add td (#mean c) (#weight c)) rest
    in
      compress (addAll td1 otherCentroids)
    end

  (* ---- accessors ------------------------------------------------- *)

  fun totalWeight (td : t) = #totalWeight td

  fun centroidCount (td : t) = treeCount (#centroids td)

end (* structure TDigest *)
