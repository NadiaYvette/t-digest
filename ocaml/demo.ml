(* Demo / self-test for t-digest OCaml implementation *)

let () =
  let td = Tdigest.create ~delta:100.0 () in
  let n = 10000 in
  for i = 0 to n - 1 do
    Tdigest.add td (float_of_int i /. float_of_int n) ()
  done;

  Printf.printf "T-Digest demo: %d uniform values in [0, 1)\n" n;
  Printf.printf "Centroids: %d\n\n" (Tdigest.centroid_count td);

  Printf.printf "Quantile estimates (expected ~ q for uniform):\n";
  List.iter (fun q ->
    match Tdigest.quantile td q with
    | Some est ->
      Printf.printf "  q=%-6.3f  estimated=%.6f  error=%.6f\n" q est (Float.abs (est -. q))
    | None ->
      Printf.printf "  q=%-6.3f  no data\n" q
  ) [0.001; 0.01; 0.1; 0.25; 0.5; 0.75; 0.9; 0.99; 0.999];

  Printf.printf "\nCDF estimates (expected ~ x for uniform):\n";
  List.iter (fun x ->
    match Tdigest.cdf td x with
    | Some est ->
      Printf.printf "  x=%-6.3f  estimated=%.6f  error=%.6f\n" x est (Float.abs (est -. x))
    | None ->
      Printf.printf "  x=%-6.3f  no data\n" x
  ) [0.001; 0.01; 0.1; 0.25; 0.5; 0.75; 0.9; 0.99; 0.999];

  (* Test merge *)
  let td1 = Tdigest.create ~delta:100.0 () in
  let td2 = Tdigest.create ~delta:100.0 () in
  for i = 0 to 4999 do
    Tdigest.add td1 (float_of_int i /. 10000.0) ()
  done;
  for i = 5000 to 9999 do
    Tdigest.add td2 (float_of_int i /. 10000.0) ()
  done;
  Tdigest.merge td1 td2;

  Printf.printf "\nAfter merge:\n";
  (match Tdigest.quantile td1 0.5 with
   | Some v -> Printf.printf "  median=%.6f (expected ~0.5)\n" v
   | None -> Printf.printf "  median: no data\n");
  (match Tdigest.quantile td1 0.99 with
   | Some v -> Printf.printf "  p99   =%.6f (expected ~0.99)\n" v
   | None -> Printf.printf "  p99: no data\n")
