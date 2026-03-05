(** Dunning t-digest for online quantile estimation.
    Merging digest variant with K_1 (arcsine) scale function. *)

type t

val create : ?delta:float -> unit -> t
val add : t -> float -> ?weight:float -> unit -> unit
val compress : t -> unit
val quantile : t -> float -> float option
val cdf : t -> float -> float option
val merge : t -> t -> unit
val total_weight : t -> float
val centroid_count : t -> int
val min_val : t -> float
val max_val : t -> float
