(* tdigest_ref.sml -- Imperative (ref-based) interface for the t-digest.
 * Wraps the pure TDigest structure with mutable references so that
 * operations mutate in place rather than returning new values.
 *)

(* ------------------------------------------------------------------ *)
(* Signature                                                          *)
(* ------------------------------------------------------------------ *)
signature T_DIGEST_REF =
sig
  type tdigest_ref

  val create        : real -> tdigest_ref           (* delta *)
  val add           : tdigest_ref -> real -> unit    (* ref, value *)
  val addWeighted   : tdigest_ref -> real -> real -> unit  (* ref, value, weight *)
  val compress      : tdigest_ref -> unit
  val quantile      : tdigest_ref -> real -> real option
  val cdf           : tdigest_ref -> real -> real option
  val merge         : tdigest_ref -> tdigest_ref -> unit  (* dst, src *)
  val totalWeight   : tdigest_ref -> real
  val centroidCount : tdigest_ref -> int
  val freeze        : tdigest_ref -> TDigest.t       (* snapshot to pure *)
  val thaw          : TDigest.t -> tdigest_ref        (* create ref from pure *)
end

(* ------------------------------------------------------------------ *)
(* Structure                                                          *)
(* ------------------------------------------------------------------ *)
structure TDigestRef :> T_DIGEST_REF =
struct

  type tdigest_ref = TDigest.t ref

  fun create (delta : real) : tdigest_ref =
    ref (TDigest.create delta)

  fun add (r : tdigest_ref) (value : real) : unit =
    r := TDigest.add (!r) value 1.0

  fun addWeighted (r : tdigest_ref) (value : real) (weight : real) : unit =
    r := TDigest.add (!r) value weight

  fun compress (r : tdigest_ref) : unit =
    r := TDigest.compress (!r)

  fun quantile (r : tdigest_ref) (q : real) : real option =
    TDigest.quantile (!r) q

  fun cdf (r : tdigest_ref) (x : real) : real option =
    TDigest.cdf (!r) x

  fun merge (dst : tdigest_ref) (src : tdigest_ref) : unit =
    dst := TDigest.merge (!dst) (!src)

  fun totalWeight (r : tdigest_ref) : real =
    TDigest.totalWeight (!r)

  fun centroidCount (r : tdigest_ref) : int =
    TDigest.centroidCount (!r)

  fun freeze (r : tdigest_ref) : TDigest.t = !r

  fun thaw (td : TDigest.t) : tdigest_ref = ref td

end (* structure TDigestRef *)
