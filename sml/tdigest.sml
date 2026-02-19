(* tdigest.sml -- Dunning's t-digest (merging digest variant) in Standard ML.
 * Purely functional: every operation returns a new digest value.
 *
 * Compile and run:
 *   mlton tdigest.sml && ./tdigest
 *   sml tdigest.sml
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

  type t =
    { centroids   : centroid list
    , buffer      : centroid list
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
    { centroids   = []
    , buffer      = []
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

  (* Length of a list. *)
  fun listLen xs = List.length xs

  (* ---- compress -------------------------------------------------- *)

  fun compressImpl (td : t) : t =
    let
      val { centroids, buffer, totalWeight = n, minVal, maxVal,
            delta = d, bufferCap } = td
    in
      if null buffer andalso listLen centroids <= 1
      then td
      else
        let
          val all = sortCentroids (centroids @ buffer)

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
                    (proposed <= 1.0 andalso listLen all > 1)
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
              { centroids = [], buffer = [], totalWeight = n,
                minVal = minVal, maxVal = maxVal,
                delta = d, bufferCap = bufferCap }
          | first :: rest =>
              { centroids   = walk first 0.0 rest []
              , buffer      = []
              , totalWeight = n
              , minVal      = minVal
              , maxVal      = maxVal
              , delta       = d
              , bufferCap   = bufferCap
              }
        end
    end

  val compress = compressImpl

  (* ---- add ------------------------------------------------------- *)

  fun add (td : t) (value : real) (weight : real) : t =
    let
      val { centroids, buffer, totalWeight = n, minVal, maxVal,
            delta = d, bufferCap } = td
      val newBuf = { mean = value, weight = weight } :: buffer
      val newN   = n + weight
      val newMin = Real.min (minVal, value)
      val newMax = Real.max (maxVal, value)
      val td' =
        { centroids   = centroids
        , buffer      = newBuf
        , totalWeight = newN
        , minVal      = newMin
        , maxVal      = newMax
        , delta       = d
        , bufferCap   = bufferCap
        }
    in
      if listLen newBuf >= bufferCap
      then compressImpl td'
      else td'
    end

  (* ---- quantile -------------------------------------------------- *)

  fun quantile (td : t) (q : real) : real option =
    let
      val td' = if null (#buffer td) then td else compressImpl td
      val cs  = #centroids td'
      val n   = #totalWeight td'
      val mn  = #minVal td'
      val mx  = #maxVal td'
    in
      case cs of
        [] => NONE
      | [c] => SOME (#mean c)
      | _ =>
          let
            val q' = Real.max (0.0, Real.min (1.0, q))
            val target = q' * n

            (* Convert list to vector for indexed access. *)
            val v   = Vector.fromList cs
            val len = Vector.length v

            fun centAt i = Vector.sub (v, i)

            (* Walk centroids by index. cumulative = weight before centroid i. *)
            fun walk (i : int) (cumulative : real) : real =
              if i >= len then mx
              else
                let
                  val c   = centAt i
                  val cw  = #weight c
                  val mid = cumulative + cw / 2.0
                in
                  (* Left boundary *)
                  if i = 0 andalso target < cw / 2.0
                  then
                    if Real.== (cw, 1.0) then mn
                    else mn + (#mean c - mn) * (target / (cw / 2.0))
                  (* Right boundary *)
                  else if i = len - 1
                  then
                    let val rightStart = n - cw / 2.0
                    in
                      if target > rightStart
                      then
                        if Real.== (cw, 1.0) then mx
                        else #mean c + (mx - #mean c)
                               * ((target - rightStart) / (cw / 2.0))
                      else #mean c
                    end
                  (* Interior: interpolate between this midpoint and next *)
                  else
                    let
                      val nc      = centAt (i + 1)
                      val nextMid = cumulative + cw + #weight nc / 2.0
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
                      else walk (i + 1) (cumulative + cw)
                    end
                end
          in
            SOME (walk 0 0.0)
          end
    end

  (* ---- cdf ------------------------------------------------------- *)

  fun cdf (td : t) (x : real) : real option =
    let
      val td' = if null (#buffer td) then td else compressImpl td
      val cs  = #centroids td'
      val n   = #totalWeight td'
      val mn  = #minVal td'
      val mx  = #maxVal td'
    in
      case cs of
        [] => NONE
      | _ =>
          if x <= mn then SOME 0.0
          else if x >= mx then SOME 1.0
          else
            let
              val v   = Vector.fromList cs
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
      val otherCentroids = #centroids td2'
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
    in listLen (#centroids td')
    end

end (* structure TDigest *)


(* ================================================================== *)
(* Demo / Self-test                                                   *)
(* ================================================================== *)

local
  fun padRight (s, width) =
    if String.size s >= width then s
    else s ^ CharVector.tabulate (width - String.size s, fn _ => #" ")

  fun fmtReal6 x = Real.fmt (StringCvt.FIX (SOME 6)) x

  fun printQuantileLine (q, est) =
    let
      val err = Real.abs (est - q)
    in
      print ("  q=" ^ padRight (Real.fmt (StringCvt.FIX (SOME 3)) q, 6)
             ^ "  estimated=" ^ fmtReal6 est
             ^ "  error=" ^ fmtReal6 err ^ "\n")
    end

  fun printCdfLine (x, est) =
    let
      val err = Real.abs (est - x)
    in
      print ("  x=" ^ padRight (Real.fmt (StringCvt.FIX (SOME 3)) x, 6)
             ^ "  estimated=" ^ fmtReal6 est
             ^ "  error=" ^ fmtReal6 err ^ "\n")
    end

  val nValues = 10000
  val nReal   = Real.fromInt nValues

  (* Build digest with uniform values 0/n, 1/n, ..., (n-1)/n *)
  fun buildUniform () =
    let
      fun loop (i, td) =
        if i >= nValues then td
        else loop (i + 1, TDigest.add td (Real.fromInt i / nReal) 1.0)
    in
      loop (0, TDigest.create 100.0)
    end

  val quantiles = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]

in

val () =
  let
    val td = buildUniform ()
    val cc = TDigest.centroidCount td
  in
    print ("T-Digest demo: " ^ Int.toString nValues
           ^ " uniform values in [0, 1)\n");
    print ("Centroids: " ^ Int.toString cc ^ "\n\n");

    print "Quantile estimates (expected ~ q for uniform):\n";
    List.app (fn q =>
      (case TDigest.quantile td q of
         SOME est => printQuantileLine (q, est)
       | NONE     => print ("  q=" ^ Real.toString q ^ "  N/A\n"))
    ) quantiles;

    print "\nCDF estimates (expected ~ x for uniform):\n";
    List.app (fn x =>
      (case TDigest.cdf td x of
         SOME est => printCdfLine (x, est)
       | NONE     => print ("  x=" ^ Real.toString x ^ "  N/A\n"))
    ) quantiles;

    (* Test merge *)
    let
      fun buildHalf (startI, endI) =
        let
          fun loop (i, td) =
            if i >= endI then td
            else loop (i + 1, TDigest.add td (Real.fromInt i / nReal) 1.0)
        in
          loop (startI, TDigest.create 100.0)
        end

      val td1 = buildHalf (0, 5000)
      val td2 = buildHalf (5000, 10000)
      val merged = TDigest.merge td1 td2
    in
      print "\nAfter merge:\n";
      (case TDigest.quantile merged 0.5 of
         SOME v => print ("  median=" ^ fmtReal6 v ^ " (expected ~0.5)\n")
       | NONE   => print "  median=N/A\n");
      (case TDigest.quantile merged 0.99 of
         SOME v => print ("  p99   =" ^ fmtReal6 v ^ " (expected ~0.99)\n")
       | NONE   => print "  p99=N/A\n")
    end
  end

end
