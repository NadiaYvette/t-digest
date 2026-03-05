(* bench.sml -- Benchmark / asymptotic-behavior tests for SML t-digest
 * Compile: mlton bench.mlb
 *)

(* Simple LCG random number generator *)
val rngState = ref 12345
fun simpleRandom () =
  let
    val s = !rngState
    val s' = IntInf.toInt (IntInf.mod (IntInf.fromInt s * 1103515245 + 12345, 2147483648))
    val _ = rngState := s'
  in
    Real.fromInt s' / 2147483648.0
  end

(* Timer using Timer structure *)
fun getTimeMs () : real =
  let
    val t = Time.toReal (Time.now ())
  in
    t * 1000.0
  end

fun timeBlock (f : unit -> 'a) : real * 'a =
  let
    val t0 = getTimeMs ()
    val result = f ()
    val t1 = getTimeMs ()
  in
    (t1 - t0, result)
  end

(* Test state *)
val passCount = ref 0
val failCount = ref 0

fun check (label : string) (ok : bool) : unit =
  if ok
  then (passCount := !passCount + 1;
        print ("  " ^ label ^ "  PASS\n"))
  else (failCount := !failCount + 1;
        print ("  " ^ label ^ "  FAIL\n"))

fun ratioOk (ratio : real) (expected : real) : bool =
  ratio >= expected * 0.5 andalso ratio <= expected * 3.0

fun ratioOkWide (ratio : real) (expected : real) : bool =
  ratio >= expected * 0.2 andalso ratio <= expected * 5.0

fun realToStr (r : real) (decimals : int) : string =
  let
    val factor = Real.fromInt (IntInf.toInt (IntInf.pow (10, decimals)))
    val rounded = Real.realRound (r * factor) / factor
  in
    Real.fmt (StringCvt.FIX (SOME decimals)) rounded
  end

fun padLeft (s : string) (w : int) : string =
  if String.size s >= w then s
  else padLeft (" " ^ s) w

(* Build a t-digest from n uniform values *)
fun buildDigest (delta : real) (n : int) : TDigest.t =
  let
    fun loop 0 td = td
      | loop i td =
          loop (i - 1) (TDigest.add td (Real.fromInt (n - i) / Real.fromInt n) 1.0)
  in
    loop n (TDigest.create delta)
  end

val _ =
let
  val _ = print "=== T-Digest Asymptotic Behavior Tests (SML) ===\n\n"

  (* --------------------------------------------------------------------- *)
  (* Test 1: add() is amortized O(1)                                       *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 1: add() is amortized O(1) ---\n"

  val sizes = [1000, 10000, 100000, 1000000]
  val times1 = List.map (fn n =>
    let
      val (ms, _) = timeBlock (fn () => buildDigest 100.0 n)
    in
      print ("  N=" ^ padLeft (Int.toString n) 9 ^
             "  time=" ^ realToStr ms 1 ^ "ms\n");
      ms
    end) sizes

  val _ = let
    fun loop (i, prev :: cur :: rest) =
          let
            val n = List.nth (sizes, i)
            val expected = Real.fromInt n / Real.fromInt (List.nth (sizes, i - 1))
            val ratio = cur / prev
          in
            check ("N=" ^ Int.toString n ^
                   "  ratio=" ^ realToStr ratio 2 ^
                   " (expected ~" ^ realToStr expected 1 ^ ")")
                  (ratioOk ratio expected);
            loop (i + 1, cur :: rest)
          end
      | loop _ = ()
  in
    loop (1, times1)
  end

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Test 2: Centroid count bounded by O(delta)                             *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 2: Centroid count bounded by O(delta) ---\n"

  val delta = 100.0
  val _ = List.app (fn n =>
    let
      val td = buildDigest delta n
      val cc = TDigest.centroidCount td
    in
      check ("N=" ^ padLeft (Int.toString n) 9 ^
             "  centroids=" ^ padLeft (Int.toString cc) 4 ^
             "  (delta=100, limit=500)")
            (cc <= 500)
    end) sizes

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Test 3: Query time independent of N                                    *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 3: Query time independent of N ---\n"

  val querySizes = [1000, 10000, 100000]
  val queryTimes = List.map (fn n =>
    let
      val td = TDigest.compress (buildDigest 100.0 n)
      val iterations = 10000
      val (ms, _) = timeBlock (fn () =>
        let fun loop 0 acc = acc
              | loop i acc =
                  let
                    val q = case TDigest.quantile td 0.5 of SOME v => v | NONE => 0.0
                    val c = case TDigest.cdf td 0.5 of SOME v => v | NONE => 0.0
                  in
                    loop (i - 1) (acc + q + c)
                  end
        in loop iterations 0.0 end)
      val usPerQuery = (ms * 1000.0) / Real.fromInt iterations
    in
      print ("  N=" ^ padLeft (Int.toString n) 9 ^
             "  query_time=" ^ realToStr usPerQuery 2 ^ "us\n");
      usPerQuery
    end) querySizes

  val _ = let
    fun loop (i, prev :: cur :: rest) =
          let
            val ratio = cur / prev
          in
            check ("N=" ^ Int.toString (List.nth (querySizes, i)) ^
                   "  ratio=" ^ realToStr ratio 2 ^ " (expected ~1.0)")
                  (ratioOkWide ratio 1.0);
            loop (i + 1, cur :: rest)
          end
      | loop _ = ()
  in
    loop (1, queryTimes)
  end

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Test 4: Tail accuracy improves with delta                              *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 4: Tail accuracy improves with delta ---\n"

  val deltas = [50.0, 100.0, 200.0]
  val tailQs = [0.01, 0.001, 0.99, 0.999]
  val nAcc = 100000

  val _ = List.app (fn q =>
    let
      val errors = List.map (fn d =>
        let
          val td = buildDigest d nAcc
          val est = case TDigest.quantile td q of SOME v => v | NONE => 0.0
          val err = Real.abs (est - q)
        in
          print ("  delta=" ^ padLeft (Int.toString (Real.round d)) 5 ^
                 "  q=" ^ realToStr q 3 ^
                 "  error=" ^ realToStr err 6 ^ "\n");
          err
        end) deltas
    in
      let
        fun loop (i, prev :: cur :: rest) =
              let
                val ok = cur <= prev * 1.5 + 0.001
              in
                check ("delta=" ^ Int.toString (Real.round (List.nth (deltas, i))) ^
                       " q=" ^ realToStr q 3 ^ " error decreases")
                      ok;
                loop (i + 1, cur :: rest)
              end
          | loop _ = ()
      in
        loop (1, errors)
      end
    end) tailQs

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Test 5: Merge preserves weight and accuracy                            *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 5: Merge preserves weight and accuracy ---\n"

  val nMerge = 10000
  val td1 = let
    fun loop i td = if i >= nMerge div 2 then td
                    else loop (i + 1) (TDigest.add td (Real.fromInt i / Real.fromInt nMerge) 1.0)
  in loop 0 (TDigest.create 100.0) end

  val td2 = let
    fun loop i td = if i >= nMerge then td
                    else loop (i + 1) (TDigest.add td (Real.fromInt i / Real.fromInt nMerge) 1.0)
  in loop (nMerge div 2) (TDigest.create 100.0) end

  val wBefore = TDigest.totalWeight td1 + TDigest.totalWeight td2
  val merged = TDigest.merge td1 td2
  val wAfter = TDigest.totalWeight merged

  val _ = check ("weight_before=" ^ realToStr wBefore 0 ^
                 "  weight_after=" ^ realToStr wAfter 0 ^ "  (equal)")
                (Real.abs (wBefore - wAfter) < 1e~9)

  val medianEst = case TDigest.quantile merged 0.5 of SOME v => v | NONE => 0.0
  val medianErr = Real.abs (medianEst - 0.5)
  val _ = check ("median_error=" ^ realToStr medianErr 6 ^ "  (< 0.05)")
                (medianErr < 0.05)

  val p99Est = case TDigest.quantile merged 0.99 of SOME v => v | NONE => 0.0
  val p99Err = Real.abs (p99Est - 0.99)
  val _ = check ("p99_error=" ^ realToStr p99Err 6 ^ "  (< 0.05)")
                (p99Err < 0.05)

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Test 6: compress is O(n log n)                                         *)
  (* --------------------------------------------------------------------- *)
  val _ = print "--- Test 6: compress is O(n log n) ---\n"

  val compressSizes = [500, 5000, 50000]
  val compressTimes = List.map (fn bufN =>
    let
      (* Build a digest with bufN items in one shot using a huge delta *)
      fun buildBuf 0 td = td
        | buildBuf i td =
            let val v = simpleRandom ()
            in buildBuf (i - 1) (TDigest.add td v 1.0) end
      val td = buildBuf bufN (TDigest.create 100000.0)
      val (ms, _) = timeBlock (fn () => TDigest.centroidCount (TDigest.compress td))
    in
      print ("  buf_n=" ^ padLeft (Int.toString bufN) 8 ^
             "  compress_time=" ^ realToStr ms 2 ^ "ms\n");
      ms
    end) compressSizes

  val _ = let
    fun loop (i, prev :: cur :: rest) =
          let
            val n0 = Real.fromInt (List.nth (compressSizes, i - 1))
            val n1 = Real.fromInt (List.nth (compressSizes, i))
            val expected = (n1 * Math.ln n1 / Math.ln 2.0) /
                           (n0 * Math.ln n0 / Math.ln 2.0)
            val ratio = cur / prev
            val ok = ratio >= expected * 0.3 andalso ratio <= expected * 4.0
          in
            check ("buf_n=" ^ Int.toString (List.nth (compressSizes, i)) ^
                   "  ratio=" ^ realToStr ratio 2 ^
                   " (expected ~" ^ realToStr expected 1 ^ ")")
                  ok;
            loop (i + 1, cur :: rest)
          end
      | loop _ = ()
  in
    loop (1, compressTimes)
  end

  val _ = print "\n"

  (* --------------------------------------------------------------------- *)
  (* Summary                                                                *)
  (* --------------------------------------------------------------------- *)
  val total = !passCount + !failCount
in
  print ("Summary: " ^ Int.toString (!passCount) ^ "/" ^
         Int.toString total ^ " tests passed\n")
end
