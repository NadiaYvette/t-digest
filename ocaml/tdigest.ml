(* Dunning t-digest for online quantile estimation.
   Merging digest variant with K_1 (arcsine) scale function. *)

type centroid = {
  mutable mean : float;
  mutable weight : float;
}

type t = {
  delta : float;
  mutable centroids : centroid array;
  mutable centroid_len : int;
  mutable buffer : centroid array;
  mutable buffer_len : int;
  buffer_cap : int;
  mutable total_weight : float;
  mutable min_val : float;
  mutable max_val : float;
}

let default_delta = 100.0
let buffer_factor = 5

let create ?(delta = default_delta) () =
  let cap = int_of_float (ceil (delta *. float_of_int buffer_factor)) in
  {
    delta;
    centroids = Array.make (cap * 2) { mean = 0.0; weight = 0.0 };
    centroid_len = 0;
    buffer = Array.make cap { mean = 0.0; weight = 0.0 };
    buffer_len = 0;
    buffer_cap = cap;
    total_weight = 0.0;
    min_val = infinity;
    max_val = neg_infinity;
  }

let k td q =
  (td.delta /. (2.0 *. Float.pi)) *. Float.asin (2.0 *. q -. 1.0)

let compress td =
  if td.buffer_len = 0 && td.centroid_len <= 1 then ()
  else begin
    let total = td.centroid_len + td.buffer_len in
    let all = Array.make total { mean = 0.0; weight = 0.0 } in
    for i = 0 to td.centroid_len - 1 do
      all.(i) <- { mean = td.centroids.(i).mean; weight = td.centroids.(i).weight }
    done;
    for i = 0 to td.buffer_len - 1 do
      all.(td.centroid_len + i) <- { mean = td.buffer.(i).mean; weight = td.buffer.(i).weight }
    done;
    td.buffer_len <- 0;
    Array.sort (fun a b -> Float.compare a.mean b.mean) all;

    (* Rebuild centroids in-place *)
    let needed = total + td.buffer_cap in
    if Array.length td.centroids < needed then
      td.centroids <- Array.make (needed * 2) { mean = 0.0; weight = 0.0 };
    td.centroids.(0) <- { mean = all.(0).mean; weight = all.(0).weight };
    let new_len = ref 1 in
    let weight_so_far = ref 0.0 in
    let n = td.total_weight in
    for i = 1 to total - 1 do
      let last = td.centroids.(!new_len - 1) in
      let proposed = last.weight +. all.(i).weight in
      let q0 = !weight_so_far /. n in
      let q1 = (!weight_so_far +. proposed) /. n in
      if (proposed <= 1.0 && total > 1) || (k td q1 -. k td q0 <= 1.0) then begin
        let new_weight = last.weight +. all.(i).weight in
        last.mean <- (last.mean *. last.weight +. all.(i).mean *. all.(i).weight) /. new_weight;
        last.weight <- new_weight
      end else begin
        weight_so_far := !weight_so_far +. last.weight;
        td.centroids.(!new_len) <- { mean = all.(i).mean; weight = all.(i).weight };
        incr new_len
      end
    done;
    td.centroid_len <- !new_len
  end

let add td value ?(weight = 1.0) () =
  if td.buffer_len >= Array.length td.buffer then begin
    let new_buf = Array.make (td.buffer_len * 2 + 1) { mean = 0.0; weight = 0.0 } in
    Array.blit td.buffer 0 new_buf 0 td.buffer_len;
    td.buffer <- new_buf
  end;
  td.buffer.(td.buffer_len) <- { mean = value; weight };
  td.buffer_len <- td.buffer_len + 1;
  td.total_weight <- td.total_weight +. weight;
  if value < td.min_val then td.min_val <- value;
  if value > td.max_val then td.max_val <- value;
  if td.buffer_len >= td.buffer_cap then compress td

let quantile td q =
  if td.buffer_len > 0 then compress td;
  if td.centroid_len = 0 then None
  else if td.centroid_len = 1 then Some td.centroids.(0).mean
  else begin
    let q = Float.max 0.0 (Float.min 1.0 q) in
    let n = td.total_weight in
    let target = q *. n in
    let cumulative = ref 0.0 in
    let result = ref None in
    let i = ref 0 in
    while !result = None && !i < td.centroid_len do
      let c = td.centroids.(!i) in
      let mid = !cumulative +. c.weight /. 2.0 in
      (* Left boundary *)
      if !i = 0 && target < c.weight /. 2.0 then begin
        if c.weight = 1.0 then
          result := Some td.min_val
        else
          result := Some (td.min_val +. (c.mean -. td.min_val) *. (target /. (c.weight /. 2.0)))
      end;
      (* Right boundary *)
      if !result = None && !i = td.centroid_len - 1 then begin
        if target > n -. c.weight /. 2.0 then begin
          if c.weight = 1.0 then
            result := Some td.max_val
          else begin
            let remaining = n -. c.weight /. 2.0 in
            result := Some (c.mean +. (td.max_val -. c.mean) *. ((target -. remaining) /. (c.weight /. 2.0)))
          end
        end else
          result := Some c.mean
      end;
      (* Interpolation between centroids *)
      if !result = None && !i < td.centroid_len - 1 then begin
        let next_c = td.centroids.(!i + 1) in
        let next_mid = !cumulative +. c.weight +. next_c.weight /. 2.0 in
        if target <= next_mid then begin
          let frac =
            if next_mid = mid then 0.5
            else (target -. mid) /. (next_mid -. mid)
          in
          result := Some (c.mean +. frac *. (next_c.mean -. c.mean))
        end
      end;
      cumulative := !cumulative +. c.weight;
      incr i
    done;
    match !result with
    | Some _ -> !result
    | None -> Some td.max_val
  end

let cdf td x =
  if td.buffer_len > 0 then compress td;
  if td.centroid_len = 0 then None
  else if x <= td.min_val then Some 0.0
  else if x >= td.max_val then Some 1.0
  else begin
    let n = td.total_weight in
    let cumulative = ref 0.0 in
    let result = ref None in
    let i = ref 0 in
    while !result = None && !i < td.centroid_len do
      let c = td.centroids.(!i) in
      if !i = 0 then begin
        if x < c.mean then begin
          let inner_w = c.weight /. 2.0 in
          let frac = if c.mean = td.min_val then 1.0 else (x -. td.min_val) /. (c.mean -. td.min_val) in
          result := Some ((inner_w *. frac) /. n)
        end else if x = c.mean then
          result := Some ((c.weight /. 2.0) /. n)
      end;
      if !result = None && !i = td.centroid_len - 1 then begin
        if x > c.mean then begin
          let right_w = n -. !cumulative -. c.weight /. 2.0 in
          let frac = if td.max_val = c.mean then 0.0 else (x -. c.mean) /. (td.max_val -. c.mean) in
          result := Some ((!cumulative +. c.weight /. 2.0 +. right_w *. frac) /. n)
        end else
          result := Some ((!cumulative +. c.weight /. 2.0) /. n)
      end;
      if !result = None && !i < td.centroid_len - 1 then begin
        let _mid = !cumulative +. c.weight /. 2.0 in
        let next_c = td.centroids.(!i + 1) in
        let next_cumulative = !cumulative +. c.weight in
        let next_mid = next_cumulative +. next_c.weight /. 2.0 in
        if x < next_c.mean then begin
          if c.mean = next_c.mean then
            result := Some ((_mid +. (next_mid -. _mid) /. 2.0) /. n)
          else begin
            let frac = (x -. c.mean) /. (next_c.mean -. c.mean) in
            result := Some ((_mid +. frac *. (next_mid -. _mid)) /. n)
          end
        end
      end;
      cumulative := !cumulative +. c.weight;
      incr i
    done;
    match !result with
    | Some _ -> !result
    | None -> Some 1.0
  end

let merge td other =
  if other.buffer_len > 0 then compress other;
  for i = 0 to other.centroid_len - 1 do
    let c = other.centroids.(i) in
    add td c.mean ~weight:c.weight ()
  done

let total_weight td = td.total_weight
let centroid_count td =
  if td.buffer_len > 0 then compress td;
  td.centroid_len
let min_val td = td.min_val
let max_val td = td.max_val
