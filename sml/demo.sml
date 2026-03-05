(* demo.sml -- Demo / self-test for the t-digest library.
 * Compile and run: mlton demo.mlb && ./demo
 * Or with SML/NJ: sml demo.sml
 *)

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
