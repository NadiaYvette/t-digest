(* Dunning t-digest for online quantile estimation.
   Merging digest variant with K_1 (arcsine) scale function.
   Uses an array-backed 2-3-4 tree with four-component monoidal measures. *)

(* ---- Centroid type ---- *)
type centroid = {
  mutable mean : float;
  mutable weight : float;
}

(* ---- Monoidal measure ---- *)
type measure = {
  m_weight : float;
  m_count : int;
  m_max_mean : float;
  m_mean_weight_sum : float;
}

let measure_identity =
  { m_weight = 0.0; m_count = 0; m_max_mean = neg_infinity; m_mean_weight_sum = 0.0 }

let measure_of_centroid c =
  { m_weight = c.weight; m_count = 1; m_max_mean = c.mean;
    m_mean_weight_sum = c.mean *. c.weight }

let measure_combine a b =
  { m_weight = a.m_weight +. b.m_weight;
    m_count = a.m_count + b.m_count;
    m_max_mean = Float.max a.m_max_mean b.m_max_mean;
    m_mean_weight_sum = a.m_mean_weight_sum +. b.m_mean_weight_sum }

(* ---- Array-backed 2-3-4 tree node ---- *)
type node = {
  mutable n : int;              (* number of keys: 0..3 *)
  keys : centroid array;        (* length 3 *)
  children : int array;         (* length 4, -1 = no child *)
  mutable meas : measure;
}

let make_node () =
  { n = 0;
    keys = Array.init 3 (fun _ -> { mean = 0.0; weight = 0.0 });
    children = Array.make 4 (-1);
    meas = measure_identity }

(* ---- 2-3-4 tree ---- *)
type tree234 = {
  mutable nodes : node array;
  mutable nodes_len : int;
  mutable free_list : int array;
  mutable free_len : int;
  mutable root : int;          (* -1 = empty *)
  mutable count : int;
}

let tree234_create cap =
  { nodes = Array.init cap (fun _ -> make_node ());
    nodes_len = 0;
    free_list = Array.make cap 0;
    free_len = 0;
    root = -1;
    count = 0 }

let tree234_alloc t =
  if t.free_len > 0 then begin
    t.free_len <- t.free_len - 1;
    let idx = t.free_list.(t.free_len) in
    let nd = t.nodes.(idx) in
    nd.n <- 0;
    nd.children.(0) <- -1; nd.children.(1) <- -1;
    nd.children.(2) <- -1; nd.children.(3) <- -1;
    nd.meas <- measure_identity;
    idx
  end else begin
    let idx = t.nodes_len in
    if idx >= Array.length t.nodes then begin
      let new_cap = max (idx + 1) (Array.length t.nodes * 2) in
      let new_arr = Array.init new_cap (fun i ->
        if i < idx then t.nodes.(i) else make_node ()
      ) in
      t.nodes <- new_arr
    end;
    t.nodes_len <- idx + 1;
    let nd = t.nodes.(idx) in
    nd.n <- 0;
    nd.children.(0) <- -1; nd.children.(1) <- -1;
    nd.children.(2) <- -1; nd.children.(3) <- -1;
    nd.meas <- measure_identity;
    idx
  end

let tree234_is_leaf t idx =
  t.nodes.(idx).children.(0) = -1

let tree234_is_4node t idx =
  t.nodes.(idx).n = 3

let tree234_recompute t idx =
  let nd = t.nodes.(idx) in
  let m = ref measure_identity in
  for i = 0 to nd.n do
    if nd.children.(i) >= 0 then
      m := measure_combine !m t.nodes.(nd.children.(i)).meas;
    if i < nd.n then
      m := measure_combine !m (measure_of_centroid nd.keys.(i))
  done;
  nd.meas <- !m

(* Split a 4-node child at position child_pos of parent *)
let tree234_split_child t parent_idx child_pos =
  let child_idx = t.nodes.(parent_idx).children.(child_pos) in
  (* Save child data before alloc may grow array *)
  let k0 = { mean = t.nodes.(child_idx).keys.(0).mean;
              weight = t.nodes.(child_idx).keys.(0).weight } in
  let k1 = { mean = t.nodes.(child_idx).keys.(1).mean;
              weight = t.nodes.(child_idx).keys.(1).weight } in
  let k2 = { mean = t.nodes.(child_idx).keys.(2).mean;
              weight = t.nodes.(child_idx).keys.(2).weight } in
  let c0 = t.nodes.(child_idx).children.(0) in
  let c1 = t.nodes.(child_idx).children.(1) in
  let c2 = t.nodes.(child_idx).children.(2) in
  let c3 = t.nodes.(child_idx).children.(3) in

  let right_idx = tree234_alloc t in
  (* After alloc, set up right node: k2, c2, c3 *)
  t.nodes.(right_idx).n <- 1;
  t.nodes.(right_idx).keys.(0).mean <- k2.mean;
  t.nodes.(right_idx).keys.(0).weight <- k2.weight;
  t.nodes.(right_idx).children.(0) <- c2;
  t.nodes.(right_idx).children.(1) <- c3;

  (* Shrink child (left) to k0, c0, c1 *)
  t.nodes.(child_idx).n <- 1;
  t.nodes.(child_idx).keys.(0).mean <- k0.mean;
  t.nodes.(child_idx).keys.(0).weight <- k0.weight;
  t.nodes.(child_idx).children.(0) <- c0;
  t.nodes.(child_idx).children.(1) <- c1;
  t.nodes.(child_idx).children.(2) <- -1;
  t.nodes.(child_idx).children.(3) <- -1;

  tree234_recompute t child_idx;
  tree234_recompute t right_idx;

  (* Insert k1 into parent at child_pos, shift keys/children *)
  let pn = t.nodes.(parent_idx).n in
  for i = pn downto child_pos + 1 do
    t.nodes.(parent_idx).keys.(i).mean <- t.nodes.(parent_idx).keys.(i - 1).mean;
    t.nodes.(parent_idx).keys.(i).weight <- t.nodes.(parent_idx).keys.(i - 1).weight;
    t.nodes.(parent_idx).children.(i + 1) <- t.nodes.(parent_idx).children.(i)
  done;
  t.nodes.(parent_idx).keys.(child_pos).mean <- k1.mean;
  t.nodes.(parent_idx).keys.(child_pos).weight <- k1.weight;
  t.nodes.(parent_idx).children.(child_pos + 1) <- right_idx;
  t.nodes.(parent_idx).n <- pn + 1;
  tree234_recompute t parent_idx

let centroid_compare a b =
  Float.compare a.mean b.mean

(* Insert key into a non-full node's subtree *)
let rec tree234_insert_non_full t idx key =
  if tree234_is_leaf t idx then begin
    let nd = t.nodes.(idx) in
    let pos = ref nd.n in
    while !pos > 0 && centroid_compare key nd.keys.(!pos - 1) < 0 do
      nd.keys.(!pos).mean <- nd.keys.(!pos - 1).mean;
      nd.keys.(!pos).weight <- nd.keys.(!pos - 1).weight;
      decr pos
    done;
    nd.keys.(!pos).mean <- key.mean;
    nd.keys.(!pos).weight <- key.weight;
    nd.n <- nd.n + 1;
    tree234_recompute t idx
  end else begin
    let nd = t.nodes.(idx) in
    let pos = ref 0 in
    while !pos < nd.n && centroid_compare key nd.keys.(!pos) >= 0 do
      incr pos
    done;
    if tree234_is_4node t nd.children.(!pos) then begin
      tree234_split_child t idx !pos;
      if centroid_compare key t.nodes.(idx).keys.(!pos) >= 0 then
        incr pos
    end;
    tree234_insert_non_full t t.nodes.(idx).children.(!pos) key;
    tree234_recompute t idx
  end

let tree234_insert t key =
  if t.root = -1 then begin
    let idx = tree234_alloc t in
    t.nodes.(idx).n <- 1;
    t.nodes.(idx).keys.(0).mean <- key.mean;
    t.nodes.(idx).keys.(0).weight <- key.weight;
    tree234_recompute t idx;
    t.root <- idx;
    t.count <- 1
  end else begin
    if tree234_is_4node t t.root then begin
      let old_root = t.root in
      let new_root = tree234_alloc t in
      t.nodes.(new_root).children.(0) <- old_root;
      t.root <- new_root;
      tree234_split_child t new_root 0
    end;
    tree234_insert_non_full t t.root key;
    t.count <- t.count + 1
  end

let tree234_clear t =
  t.nodes_len <- 0;
  t.free_len <- 0;
  t.root <- -1;
  t.count <- 0

let tree234_size t = t.count

let tree234_root_measure t =
  if t.root = -1 then measure_identity
  else t.nodes.(t.root).meas

(* In-order traversal: collect all keys *)
let tree234_collect t =
  let result = Array.make t.count { mean = 0.0; weight = 0.0 } in
  let pos = ref 0 in
  let rec walk idx =
    if idx >= 0 then begin
      let nd = t.nodes.(idx) in
      for i = 0 to nd.n do
        if nd.children.(i) >= 0 then walk nd.children.(i);
        if i < nd.n then begin
          result.(!pos) <- { mean = nd.keys.(i).mean; weight = nd.keys.(i).weight };
          incr pos
        end
      done
    end
  in
  walk t.root;
  result

(* Build a balanced 2-3-4 tree from a sorted array *)
let tree234_build_from_sorted t (sorted : centroid array) len =
  tree234_clear t;
  if len <= 0 then ()
  else begin
    let rec build lo hi =
      let n = hi - lo in
      if n <= 0 then -1
      else if n <= 3 then begin
        let idx = tree234_alloc t in
        t.nodes.(idx).n <- n;
        for i = 0 to n - 1 do
          t.nodes.(idx).keys.(i).mean <- sorted.(lo + i).mean;
          t.nodes.(idx).keys.(i).weight <- sorted.(lo + i).weight
        done;
        tree234_recompute t idx;
        idx
      end else if n <= 7 then begin
        let mid = lo + n / 2 in
        let left = build lo mid in
        let right = build (mid + 1) hi in
        let idx = tree234_alloc t in
        t.nodes.(idx).n <- 1;
        t.nodes.(idx).keys.(0).mean <- sorted.(mid).mean;
        t.nodes.(idx).keys.(0).weight <- sorted.(mid).weight;
        t.nodes.(idx).children.(0) <- left;
        t.nodes.(idx).children.(1) <- right;
        tree234_recompute t idx;
        idx
      end else begin
        let third = n / 3 in
        let m1 = lo + third in
        let m2 = lo + 2 * third + 1 in
        let c0 = build lo m1 in
        let c1 = build (m1 + 1) m2 in
        let c2 = build (m2 + 1) hi in
        let idx = tree234_alloc t in
        t.nodes.(idx).n <- 2;
        t.nodes.(idx).keys.(0).mean <- sorted.(m1).mean;
        t.nodes.(idx).keys.(0).weight <- sorted.(m1).weight;
        t.nodes.(idx).keys.(1).mean <- sorted.(m2).mean;
        t.nodes.(idx).keys.(1).weight <- sorted.(m2).weight;
        t.nodes.(idx).children.(0) <- c0;
        t.nodes.(idx).children.(1) <- c1;
        t.nodes.(idx).children.(2) <- c2;
        tree234_recompute t idx;
        idx
      end
    in
    t.root <- build 0 len;
    t.count <- len
  end

(* Find by cumulative weight: find centroid where cumulative weight reaches target.
   Returns (centroid, cumulative_weight_before, index, found). *)
let tree234_find_by_weight t target =
  let dummy = { mean = 0.0; weight = 0.0 } in
  if t.root = -1 then (dummy, 0.0, 0, false)
  else begin
    let rec subtree_count idx =
      if idx = -1 then 0
      else
        let nd = t.nodes.(idx) in
        let c = ref nd.n in
        for i = 0 to nd.n do
          if nd.children.(i) >= 0 then
            c := !c + subtree_count nd.children.(i)
        done;
        !c
    in
    let rec walk idx tgt cum gi =
      let nd = t.nodes.(idx) in
      let rc = ref cum in
      let ri = ref gi in
      let found = ref false in
      let result = ref (dummy, 0.0, 0, false) in
      let i = ref 0 in
      while !i <= nd.n && not !found do
        (* Process child *)
        if nd.children.(!i) >= 0 then begin
          let child_w = t.nodes.(nd.children.(!i)).meas.m_weight in
          if !rc +. child_w >= tgt then begin
            result := walk nd.children.(!i) tgt !rc !ri;
            found := true
          end else begin
            rc := !rc +. child_w;
            ri := !ri + subtree_count nd.children.(!i)
          end
        end;
        if not !found && !i < nd.n then begin
          let kw = nd.keys.(!i).weight in
          if !rc +. kw >= tgt then begin
            result := ({ mean = nd.keys.(!i).mean; weight = nd.keys.(!i).weight },
                       !rc, !ri, true);
            found := true
          end else begin
            rc := !rc +. kw;
            ri := !ri + 1
          end
        end;
        incr i
      done;
      if !found then !result
      else (dummy, 0.0, 0, false)
    in
    walk t.root target 0.0 0
  end

(* ---- T-Digest ---- *)
type t = {
  delta : float;
  mutable tree : tree234;
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
    tree = tree234_create (cap * 2);
    buffer = Array.init cap (fun _ -> { mean = 0.0; weight = 0.0 });
    buffer_len = 0;
    buffer_cap = cap;
    total_weight = 0.0;
    min_val = infinity;
    max_val = neg_infinity;
  }

let k td q =
  (td.delta /. (2.0 *. Float.pi)) *. Float.asin (2.0 *. q -. 1.0)

let compress td =
  if td.buffer_len = 0 && tree234_size td.tree <= 1 then ()
  else begin
    (* Collect all centroids from tree and buffer *)
    let tree_centroids = tree234_collect td.tree in
    let tree_len = Array.length tree_centroids in
    let total = tree_len + td.buffer_len in
    let all = Array.init total (fun i ->
      if i < tree_len then
        { mean = tree_centroids.(i).mean; weight = tree_centroids.(i).weight }
      else
        let bi = i - tree_len in
        { mean = td.buffer.(bi).mean; weight = td.buffer.(bi).weight }
    ) in
    td.buffer_len <- 0;
    Array.sort (fun a b -> Float.compare a.mean b.mean) all;

    (* Merge centroids according to K1 scale function *)
    let merged = Array.make total { mean = 0.0; weight = 0.0 } in
    merged.(0) <- { mean = all.(0).mean; weight = all.(0).weight };
    let new_len = ref 1 in
    let weight_so_far = ref 0.0 in
    let n = td.total_weight in
    for i = 1 to total - 1 do
      let last = merged.(!new_len - 1) in
      let proposed = last.weight +. all.(i).weight in
      let q0 = !weight_so_far /. n in
      let q1 = (!weight_so_far +. proposed) /. n in
      if (proposed <= 1.0 && total > 1) || (k td q1 -. k td q0 <= 1.0) then begin
        let new_weight = last.weight +. all.(i).weight in
        last.mean <- (last.mean *. last.weight +. all.(i).mean *. all.(i).weight) /. new_weight;
        last.weight <- new_weight
      end else begin
        weight_so_far := !weight_so_far +. last.weight;
        merged.(!new_len) <- { mean = all.(i).mean; weight = all.(i).weight };
        incr new_len
      end
    done;

    (* Rebuild tree from sorted merged centroids *)
    tree234_build_from_sorted td.tree merged !new_len
  end

let add td value ?(weight = 1.0) () =
  if td.buffer_len >= Array.length td.buffer then begin
    let new_buf = Array.init (td.buffer_len * 2 + 1) (fun i ->
      if i < td.buffer_len then
        { mean = td.buffer.(i).mean; weight = td.buffer.(i).weight }
      else
        { mean = 0.0; weight = 0.0 }
    ) in
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
  let sz = tree234_size td.tree in
  if sz = 0 then None
  else if sz = 1 then begin
    let centroids = tree234_collect td.tree in
    Some centroids.(0).mean
  end
  else begin
    let q = Float.max 0.0 (Float.min 1.0 q) in
    let n = td.total_weight in
    let target = q *. n in

    (* Collect centroids for interpolation *)
    let centroids = tree234_collect td.tree in

    (* Build prefix sums *)
    let cum = Array.make sz 0.0 in
    cum.(0) <- centroids.(0).weight;
    for i = 1 to sz - 1 do
      cum.(i) <- cum.(i - 1) +. centroids.(i).weight
    done;

    let first = centroids.(0) in
    if target < first.weight /. 2.0 then begin
      if first.weight = 1.0 then Some td.min_val
      else Some (td.min_val +. (first.mean -. td.min_val) *. (target /. (first.weight /. 2.0)))
    end
    else begin
      let last = centroids.(sz - 1) in
      if target > n -. last.weight /. 2.0 then begin
        if last.weight = 1.0 then Some td.max_val
        else begin
          let remaining = n -. last.weight /. 2.0 in
          Some (last.mean +. (td.max_val -. last.mean) *. ((target -. remaining) /. (last.weight /. 2.0)))
        end
      end
      else begin
        (* Binary search for centroid *)
        let lo = ref 0 in
        let hi = ref (sz - 1) in
        while !lo < !hi do
          let mid = !lo + (!hi - !lo) / 2 in
          if cum.(mid) < target then lo := mid + 1
          else hi := mid
        done;
        let idx = ref !lo in
        if !idx >= sz - 1 then idx := sz - 2;
        if !idx < 0 then idx := 0;

        let i = !idx in
        let cum_before = if i > 0 then cum.(i - 1) else 0.0 in
        let c = centroids.(i) in
        let mid_val = cum_before +. c.weight /. 2.0 in

        if i > 0 && target < mid_val then begin
          let i2 = i - 1 in
          let cum_before2 = if i2 > 0 then cum.(i2 - 1) else 0.0 in
          let c2 = centroids.(i2) in
          let mid2 = cum_before2 +. c2.weight /. 2.0 in
          let next_c = centroids.(i2 + 1) in
          let next_mid = cum_before2 +. c2.weight +. next_c.weight /. 2.0 in
          let frac =
            if next_mid = mid2 then 0.5
            else (target -. mid2) /. (next_mid -. mid2)
          in
          Some (c2.mean +. frac *. (next_c.mean -. c2.mean))
        end
        else if i = sz - 1 then
          Some c.mean
        else begin
          let next_c = centroids.(i + 1) in
          let next_mid = cum_before +. c.weight +. next_c.weight /. 2.0 in
          if target <= next_mid then begin
            let frac =
              if next_mid = mid_val then 0.5
              else (target -. mid_val) /. (next_mid -. mid_val)
            in
            Some (c.mean +. frac *. (next_c.mean -. c.mean))
          end else
            Some next_c.mean
        end
      end
    end
  end

let cdf td x =
  if td.buffer_len > 0 then compress td;
  let sz = tree234_size td.tree in
  if sz = 0 then None
  else if x <= td.min_val then Some 0.0
  else if x >= td.max_val then Some 1.0
  else begin
    let n = td.total_weight in
    let centroids = tree234_collect td.tree in

    (* Build prefix sums *)
    let cum = Array.make sz 0.0 in
    cum.(0) <- centroids.(0).weight;
    for i = 1 to sz - 1 do
      cum.(i) <- cum.(i - 1) +. centroids.(i).weight
    done;

    (* Binary search for rightmost centroid with mean <= x *)
    let lo = ref 0 in
    let hi = ref (sz - 1) in
    let idx = ref (-1) in
    while !lo <= !hi do
      let mid_i = !lo + (!hi - !lo) / 2 in
      if centroids.(mid_i).mean <= x then begin
        idx := mid_i;
        lo := mid_i + 1
      end else
        hi := mid_i - 1
    done;

    if !idx = -1 then begin
      let c = centroids.(0) in
      let inner_w = c.weight /. 2.0 in
      let frac = if c.mean = td.min_val then 1.0
                 else (x -. td.min_val) /. (c.mean -. td.min_val) in
      Some ((inner_w *. frac) /. n)
    end else begin
      let i = !idx in
      let c = centroids.(i) in
      let cum_before = if i = 0 then 0.0 else cum.(i - 1) in
      let cum_mid = cum_before +. c.weight /. 2.0 in

      if i = sz - 1 then begin
        if x > c.mean then begin
          let right_w = n -. cum_before -. c.weight /. 2.0 in
          let frac = if td.max_val = c.mean then 0.0
                     else (x -. c.mean) /. (td.max_val -. c.mean) in
          Some ((cum_mid +. right_w *. frac) /. n)
        end else
          Some (cum_mid /. n)
      end else begin
        let next_c = centroids.(i + 1) in
        let next_cum_before = cum_before +. c.weight in
        let next_mid = next_cum_before +. next_c.weight /. 2.0 in
        if x = c.mean then
          Some (cum_mid /. n)
        else if c.mean = next_c.mean then
          Some ((cum_mid +. (next_mid -. cum_mid) /. 2.0) /. n)
        else begin
          let frac = (x -. c.mean) /. (next_c.mean -. c.mean) in
          Some ((cum_mid +. frac *. (next_mid -. cum_mid)) /. n)
        end
      end
    end
  end

let merge td other =
  if other.buffer_len > 0 then compress other;
  let centroids = tree234_collect other.tree in
  Array.iter (fun c -> add td c.mean ~weight:c.weight ()) centroids

let total_weight td = td.total_weight

let centroid_count td =
  if td.buffer_len > 0 then compress td;
  tree234_size td.tree

let min_val td = td.min_val
let max_val td = td.max_val
