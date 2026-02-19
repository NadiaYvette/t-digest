%%% tdigest.pl -- Dunning t-digest (merging digest variant) in SWI-Prolog
%%%
%%% Data structure:
%%%   tdigest(Delta, Centroids, Buffer, TotalWeight, Min, Max)
%%%
%%% where Centroids and Buffer are lists of centroid(Mean, Weight) terms,
%%% Centroids are kept sorted by Mean, and Delta is the compression parameter.
%%%
%%% Scale function K1: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)

:- module(tdigest, [
    tdigest_new/2,
    tdigest_add/4,
    tdigest_compress/2,
    tdigest_quantile/3,
    tdigest_cdf/3,
    tdigest_merge/3,
    tdigest_centroid_count/2
]).

%% ---------------------------------------------------------------------------
%% Scale function K1
%% ---------------------------------------------------------------------------

k_scale(Q, Delta, K) :-
    QC is max(0.0, min(1.0, Q)),
    K is (Delta / (2.0 * pi)) * asin(2.0 * QC - 1.0).

%% ---------------------------------------------------------------------------
%% Constructor
%% ---------------------------------------------------------------------------

%% tdigest_new(+Delta, -TD)
%% Create an empty t-digest with the given compression parameter.
tdigest_new(Delta, tdigest(Delta, [], [], 0.0, PosInf, NegInf)) :-
    PosInf is inf,
    NegInf is -inf.

%% ---------------------------------------------------------------------------
%% Add a value
%% ---------------------------------------------------------------------------

%% tdigest_add(+TD0, +Value, +Weight, -TD1)
%% Add a weighted value to the t-digest. If the buffer reaches capacity,
%% a compression is triggered automatically.
tdigest_add(tdigest(Delta, Centroids, Buffer0, TW0, Min0, Max0),
            Value, Weight,
            TD1) :-
    VF is float(Value),
    WF is float(Weight),
    TW1 is TW0 + WF,
    Min1 is min(Min0, VF),
    Max1 is max(Max0, VF),
    Buffer1 = [centroid(VF, WF) | Buffer0],
    length(Buffer1, BufLen),
    BufferCap is ceiling(Delta * 5),
    (   BufLen >= BufferCap
    ->  tdigest_compress(tdigest(Delta, Centroids, Buffer1, TW1, Min1, Max1), TD1)
    ;   TD1 = tdigest(Delta, Centroids, Buffer1, TW1, Min1, Max1)
    ).

%% ---------------------------------------------------------------------------
%% Compress
%% ---------------------------------------------------------------------------

%% tdigest_compress(+TD0, -TD1)
%% Merge the buffer into centroids, sort by mean, and greedily merge
%% adjacent centroids using the K1 scale function constraint.
tdigest_compress(tdigest(Delta, Centroids, Buffer, TW, Min, Max),
                 tdigest(Delta, NewCentroids, [], TW, Min, Max)) :-
    append(Centroids, Buffer, All),
    (   All = []
    ->  NewCentroids = []
    ;   All = [_]
    ->  NewCentroids = All
    ;   sort_centroids(All, Sorted),
        Sorted = [First | Rest],
        greedy_merge(Rest, First, 0.0, TW, Delta, NewCentroids)
    ).

%% sort_centroids(+List, -Sorted)
%% Sort centroids by their mean using msort and a keyed-sort approach.
sort_centroids(Centroids, Sorted) :-
    maplist(key_centroid, Centroids, Keyed),
    msort(Keyed, KeyedSorted),
    maplist(unkey_centroid, KeyedSorted, Sorted).

key_centroid(centroid(M, W), M-centroid(M, W)).
unkey_centroid(_-C, C).

%% greedy_merge(+Items, +CurrentCentroid, +WeightSoFar, +TotalWeight, +Delta, -Result)
%% Walk through sorted items, merging into the current centroid when the
%% K1 scale function allows it, otherwise starting a new centroid.
%% The result list is built in forward order.
greedy_merge([], Current, _WSF, _TW, _Delta, [Current]).
greedy_merge([centroid(IM, IW) | Rest], centroid(CM, CW), WSF, TW, Delta, Result) :-
    ProposedWeight is CW + IW,
    (   TW > 0.0
    ->  Q0 is WSF / TW,
        Q1 is (WSF + ProposedWeight) / TW
    ;   Q0 = 0.0,
        Q1 = 1.0
    ),
    (   % Always allow merging if proposed weight <= 1 (single-observation clusters)
        (ProposedWeight =< 1.0)
    ->  merge_centroid(centroid(CM, CW), centroid(IM, IW), Merged),
        greedy_merge(Rest, Merged, WSF, TW, Delta, Result)
    ;   k_scale(Q0, Delta, K0),
        k_scale(Q1, Delta, K1),
        KDiff is K1 - K0,
        (   KDiff =< 1.0
        ->  merge_centroid(centroid(CM, CW), centroid(IM, IW), Merged),
            greedy_merge(Rest, Merged, WSF, TW, Delta, Result)
        ;   % Start a new centroid; push current onto the accumulator
            WSF1 is WSF + CW,
            greedy_merge(Rest, centroid(IM, IW), WSF1, TW, Delta, RestResult),
            Result = [centroid(CM, CW) | RestResult]
        )
    ).

%% merge_centroid(+C1, +C2, -Merged)
%% Merge two centroids using weighted mean.
merge_centroid(centroid(M1, W1), centroid(M2, W2), centroid(MN, WN)) :-
    WN is W1 + W2,
    MN is (M1 * W1 + M2 * W2) / WN.

%% ---------------------------------------------------------------------------
%% Quantile estimation
%% ---------------------------------------------------------------------------

%% tdigest_quantile(+TD, +Q, -Value)
%% Estimate the value at quantile Q (0.0 to 1.0).
tdigest_quantile(TD0, Q, Value) :-
    ensure_compressed(TD0, tdigest(_Delta, Centroids, [], TW, Min, Max)),
    QC is max(0.0, min(1.0, float(Q))),
    Target is QC * TW,
    (   Centroids = []
    ->  Value = 0.0
    ;   Centroids = [centroid(M, _)]
    ->  Value = M
    ;   quantile_walk(Centroids, Target, TW, Min, Max, 0.0, Value)
    ).

%% quantile_walk(+Centroids, +Target, +TotalWeight, +Min, +Max, +Cumulative, -Value)
quantile_walk([centroid(CM, CW)], Target, TW, _Min, Max, Cum, Value) :-
    % Last centroid: right boundary
    !,
    RightStart is TW - CW / 2.0,
    (   Target > RightStart
    ->  (   CW =:= 1.0
        ->  Value = CM
        ;   HalfW is CW / 2.0,
            Frac is (Target - RightStart) / HalfW,
            Value is CM + (Max - CM) * Frac
        )
    ;   Value = CM
    ).
quantile_walk([centroid(CM, CW) | Rest], Target, TW, Min, Max, Cum, Value) :-
    HalfW is CW / 2.0,
    Mid is Cum + HalfW,
    % First centroid check (Cum == 0.0 means we are at the first centroid)
    (   Cum =:= 0.0, Target < HalfW
    ->  (   CW =:= 1.0
        ->  Value = Min
        ;   Frac is Target / HalfW,
            Value is Min + (CM - Min) * Frac
        )
    ;   % Check if target falls between this centroid and the next
        Rest = [centroid(NM, NW) | _],
        NextMid is Cum + CW + NW / 2.0,
        (   Target =< NextMid
        ->  (   NextMid =:= Mid
            ->  Frac = 0.5
            ;   Frac is (Target - Mid) / (NextMid - Mid)
            ),
            Value is CM + Frac * (NM - CM)
        ;   NewCum is Cum + CW,
            quantile_walk(Rest, Target, TW, Min, Max, NewCum, Value)
        )
    ).

%% ---------------------------------------------------------------------------
%% CDF estimation
%% ---------------------------------------------------------------------------

%% tdigest_cdf(+TD, +X, -Q)
%% Estimate the cumulative distribution function value at X.
tdigest_cdf(TD0, X, Q) :-
    ensure_compressed(TD0, tdigest(_Delta, Centroids, [], TW, Min, Max)),
    XF is float(X),
    (   Centroids = []
    ->  Q = 0.0
    ;   XF =< Min
    ->  Q = 0.0
    ;   XF >= Max
    ->  Q = 1.0
    ;   cdf_walk(Centroids, XF, TW, Min, Max, 0.0, Q)
    ).

%% cdf_walk(+Centroids, +X, +TotalWeight, +Min, +Max, +Cumulative, -Q)
cdf_walk([centroid(CM, CW)], X, TW, _Min, Max, Cum, Q) :-
    % Last centroid
    !,
    HalfW is CW / 2.0,
    (   X > CM
    ->  RightW is TW - Cum - HalfW,
        (   Max =:= CM
        ->  Frac = 0.0
        ;   Frac is (X - CM) / (Max - CM)
        ),
        Q is (Cum + HalfW + RightW * Frac) / TW
    ;   Q is (Cum + HalfW) / TW
    ).
cdf_walk([centroid(CM, CW) | Rest], X, TW, Min, Max, Cum, Q) :-
    HalfW is CW / 2.0,
    Mid is Cum + HalfW,
    (   Cum =:= 0.0, X < CM
    ->  % Left boundary: between min and first centroid
        (   CM =:= Min
        ->  Frac = 1.0
        ;   Frac is (X - Min) / (CM - Min)
        ),
        Q is (HalfW * Frac) / TW
    ;   Cum =:= 0.0, X =:= CM
    ->  Q is HalfW / TW
    ;   % Middle: look at next centroid
        Rest = [centroid(NM, NW) | _],
        NextCum is Cum + CW,
        NextMid is NextCum + NW / 2.0,
        (   X < NM
        ->  (   CM =:= NM
            ->  Frac = 0.5
            ;   Frac is (X - CM) / (NM - CM)
            ),
            Q is (Mid + Frac * (NextMid - Mid)) / TW
        ;   cdf_walk(Rest, X, TW, Min, Max, NextCum, Q)
        )
    ).

%% ---------------------------------------------------------------------------
%% Merge two t-digests
%% ---------------------------------------------------------------------------

%% tdigest_merge(+TD1, +TD2, -TD3)
%% Merge two t-digests into one. Uses the maximum delta of the two.
tdigest_merge(TD1_0, TD2_0, TD3) :-
    ensure_compressed(TD1_0, tdigest(D1, C1, [], TW1, Min1, Max1)),
    ensure_compressed(TD2_0, tdigest(D2, C2, [], TW2, Min2, Max2)),
    Delta is max(D1, D2),
    TW is TW1 + TW2,
    MinV is min(Min1, Min2),
    MaxV is max(Max1, Max2),
    append(C1, C2, AllCentroids),
    % Build the merged digest and compress it
    tdigest_compress(tdigest(Delta, AllCentroids, [], TW, MinV, MaxV), TD3).

%% ---------------------------------------------------------------------------
%% Centroid count (after compression)
%% ---------------------------------------------------------------------------

tdigest_centroid_count(TD0, Count) :-
    ensure_compressed(TD0, tdigest(_, Centroids, [], _, _, _)),
    length(Centroids, Count).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

%% ensure_compressed(+TD0, -TD1)
%% If the buffer is non-empty, compress first.
ensure_compressed(tdigest(D, C, [], TW, Min, Max),
                  tdigest(D, C, [], TW, Min, Max)) :- !.
ensure_compressed(TD0, TD1) :-
    tdigest_compress(TD0, TD1).

%% ---------------------------------------------------------------------------
%% Simple pseudo-random number generator (LCG) for the demo
%% ---------------------------------------------------------------------------

%% lcg_next(+State, -NextState, -Value01)
%% Linear congruential generator producing values in [0, 1).
%% Uses the Numerical Recipes constants: a=1664525, c=1013904223, m=2^32
lcg_next(State, NextState, Value) :-
    M is 1 << 32,
    NextState is (1664525 * State + 1013904223) mod M,
    Value is float(NextState) / float(M).

%% generate_values(+N, +State, -Values)
%% Generate N pseudo-random values in [0, 1) using the LCG.
generate_values(0, _State, []) :- !.
generate_values(N, State, [V | Rest]) :-
    N > 0,
    lcg_next(State, State1, V),
    N1 is N - 1,
    generate_values(N1, State1, Rest).

%% ---------------------------------------------------------------------------
%% Bulk add values into a t-digest
%% ---------------------------------------------------------------------------

add_values(TD, [], TD).
add_values(TD0, [V | Vs], TD) :-
    tdigest_add(TD0, V, 1.0, TD1),
    add_values(TD1, Vs, TD).

%% ---------------------------------------------------------------------------
%% Demo / Self-test
%% ---------------------------------------------------------------------------

main :-
    N = 10000,

    % Generate N uniform values in [0, 1) using the LCG
    generate_values(N, 42, Values),

    % Build the t-digest
    tdigest_new(100, TD0),
    add_values(TD0, Values, TD1),

    % Report centroid count
    tdigest_centroid_count(TD1, CC),
    format("T-Digest demo: ~d uniform values in [0, 1)~n", [N]),
    format("Centroids: ~d~n~n", [CC]),

    % Quantile estimates
    format("Quantile estimates (expected ~~ q for uniform):~n"),
    Qs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999],
    forall(
        member(Q, Qs),
        (   tdigest_quantile(TD1, Q, Est),
            Err is abs(Est - Q),
            format("  q=~6f  estimated=~6f  error=~6f~n", [Q, Est, Err])
        )
    ),
    nl,

    % CDF estimates
    format("CDF estimates (expected ~~ x for uniform):~n"),
    Xs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999],
    forall(
        member(X, Xs),
        (   tdigest_cdf(TD1, X, CdfEst),
            CdfErr is abs(CdfEst - X),
            format("  x=~6f  estimated=~6f  error=~6f~n", [X, CdfEst, CdfErr])
        )
    ),
    nl,

    % Test merge: split data in half, merge, check
    generate_values(5000, 42, Values1),
    generate_values(5000, 99999, Values2),
    tdigest_new(100, TDA0),
    tdigest_new(100, TDB0),
    add_values(TDA0, Values1, TDA),
    add_values(TDB0, Values2, TDB),
    tdigest_merge(TDA, TDB, TDMerged),

    format("After merge:~n"),
    tdigest_quantile(TDMerged, 0.5, Med),
    tdigest_quantile(TDMerged, 0.99, P99),
    format("  median=~6f (expected ~~0.5)~n", [Med]),
    format("  p99   =~6f (expected ~~0.99)~n", [P99]),

    halt(0).

:- initialization(main, main).
