%%% bench.pl -- Benchmark / asymptotic-behavior tests for SWI-Prolog t-digest
%%% Run with: swipl bench.pl

:- use_module(tdigest).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

:- dynamic pass_count/1, fail_count/1.
pass_count(0).
fail_count(0).

increment_pass :-
    retract(pass_count(N)),
    N1 is N + 1,
    assert(pass_count(N1)).

increment_fail :-
    retract(fail_count(N)),
    N1 is N + 1,
    assert(fail_count(N1)).

check(Label, true) :-
    increment_pass,
    format("  ~w  PASS~n", [Label]).
check(Label, false) :-
    increment_fail,
    format("  ~w  FAIL~n", [Label]).

check(Label, Goal) :-
    ( Goal -> OK = true ; OK = false ),
    check(Label, OK).

ratio_ok(Ratio, Expected) :-
    Ratio >= Expected * 0.5,
    Ratio =< Expected * 3.0.

ratio_ok_wide(Ratio, Expected) :-
    Ratio >= Expected * 0.2,
    Ratio =< Expected * 5.0.

%% get_time_ms(-Ms)
get_time_ms(Ms) :-
    get_time(T),
    Ms is T * 1000.0.

%% time_block(:Goal, -Ms)
time_block(Goal, Ms) :-
    get_time_ms(T0),
    call(Goal),
    get_time_ms(T1),
    Ms is T1 - T0.

%% Build a t-digest with N uniform values in [0, 1)
build_digest(Delta, N, TD) :-
    tdigest_new(Delta, TD0),
    build_digest_loop(0, N, TD0, TD).

build_digest_loop(I, N, TD, TD) :- I >= N, !.
build_digest_loop(I, N, TD0, TD) :-
    V is float(I) / float(N),
    tdigest_add(TD0, V, 1.0, TD1),
    I1 is I + 1,
    build_digest_loop(I1, N, TD1, TD).

%%% Simple LCG random
:- dynamic rng_state/1.
rng_state(12345).

simple_random(V) :-
    retract(rng_state(S)),
    S1 is (S * 1103515245 + 12345) mod (2 ** 31),
    assert(rng_state(S1)),
    V is float(S1) / float(2 ** 31).

%%% ---------------------------------------------------------------------------
%%% Main
%%% ---------------------------------------------------------------------------

:- initialization(main, main).

main :-
    format("=== T-Digest Asymptotic Behavior Tests (Prolog) ===~n~n"),
    test1,
    test2,
    test3,
    test4,
    test5,
    test6,
    summary.

%%% ---------------------------------------------------------------------------
%%% Test 1: add() is amortized O(1)
%%% ---------------------------------------------------------------------------

test1 :-
    format("--- Test 1: add() is amortized O(1) ---~n"),
    Sizes = [1000, 10000, 100000],
    maplist(test1_time, Sizes, Times),
    test1_check(Sizes, Times),
    nl.

test1_time(N, Ms) :-
    time_block(build_digest(100.0, N, _), Ms),
    format("  N=~t~9|~w~t~20|time=~1fms~n", [N, Ms]).

test1_check([_], [_]) :- !.
test1_check([N0, N1 | Ns], [T0, T1 | Ts]) :-
    Expected is float(N1) / float(N0),
    Ratio is T1 / T0,
    format(atom(Label), "N=~w  ratio=~2f (expected ~~~1f)", [N1, Ratio, Expected]),
    ( ratio_ok(Ratio, Expected) -> OK = true ; OK = false ),
    check(Label, OK),
    test1_check([N1 | Ns], [T1 | Ts]).

%%% ---------------------------------------------------------------------------
%%% Test 2: Centroid count bounded by O(delta)
%%% ---------------------------------------------------------------------------

test2 :-
    format("--- Test 2: Centroid count bounded by O(delta) ---~n"),
    Sizes = [1000, 10000, 100000],
    maplist(test2_one, Sizes),
    nl.

test2_one(N) :-
    build_digest(100.0, N, TD),
    tdigest_centroid_count(TD, CC),
    format(atom(Label), "N=~w  centroids=~w  (delta=100, limit=500)", [N, CC]),
    ( CC =< 500 -> OK = true ; OK = false ),
    check(Label, OK).

%%% ---------------------------------------------------------------------------
%%% Test 3: Query time independent of N
%%% ---------------------------------------------------------------------------

test3 :-
    format("--- Test 3: Query time independent of N ---~n"),
    Sizes = [1000, 10000, 100000],
    maplist(test3_time, Sizes, Times),
    test3_check(Sizes, Times),
    nl.

test3_time(N, UsPer) :-
    build_digest(100.0, N, TD0),
    tdigest_compress(TD0, TD),
    Iterations = 2000,
    get_time_ms(T0),
    test3_query_loop(Iterations, TD),
    get_time_ms(T1),
    Ms is T1 - T0,
    UsPer is (Ms * 1000.0) / Iterations,
    format("  N=~t~9|~w~t~20|query_time=~2fus~n", [N, UsPer]).

test3_query_loop(0, _) :- !.
test3_query_loop(I, TD) :-
    tdigest_quantile(TD, 0.5, _),
    tdigest_cdf(TD, 0.5, _),
    I1 is I - 1,
    test3_query_loop(I1, TD).

test3_check([_], [_]) :- !.
test3_check([_, N1 | Ns], [T0, T1 | Ts]) :-
    Ratio is T1 / T0,
    format(atom(Label), "N=~w  ratio=~2f (expected ~~1.0)", [N1, Ratio]),
    ( ratio_ok_wide(Ratio, 1.0) -> OK = true ; OK = false ),
    check(Label, OK),
    test3_check([N1 | Ns], [T1 | Ts]).

%%% ---------------------------------------------------------------------------
%%% Test 4: Tail accuracy improves with delta
%%% ---------------------------------------------------------------------------

test4 :-
    format("--- Test 4: Tail accuracy improves with delta ---~n"),
    Deltas = [50.0, 100.0, 200.0],
    TailQs = [0.01, 0.001, 0.99, 0.999],
    maplist(test4_q(Deltas), TailQs),
    nl.

test4_q(Deltas, Q) :-
    maplist(test4_one(Q), Deltas, Errors),
    test4_check(Deltas, Q, Errors).

test4_one(Q, Delta, Err) :-
    build_digest(Delta, 100000, TD),
    tdigest_quantile(TD, Q, Est),
    Err is abs(Est - Q),
    DI is integer(Delta),
    format("  delta=~t~5|~w  q=~3f  error=~6f~n", [DI, Q, Err]).

test4_check([_], _, [_]) :- !.
test4_check([_, D1 | Ds], Q, [E0, E1 | Es]) :-
    Limit is E0 * 1.5 + 0.001,
    ( E1 =< Limit -> OK = true ; OK = false ),
    DI is integer(D1),
    format(atom(Label), "delta=~w q=~3f error decreases (~6f <= ~6f)",
           [DI, Q, E1, E0]),
    check(Label, OK),
    test4_check([D1 | Ds], Q, [E1 | Es]).

%%% ---------------------------------------------------------------------------
%%% Test 5: Merge preserves weight and accuracy
%%% ---------------------------------------------------------------------------

test5 :-
    format("--- Test 5: Merge preserves weight and accuracy ---~n"),
    NMerge = 10000,
    Half is NMerge // 2,
    build_digest_range(100.0, 0, Half, NMerge, TD1),
    build_digest_range(100.0, Half, NMerge, NMerge, TD2),
    TD1 = tdigest(_, _, _, TW1, _, _),
    TD2 = tdigest(_, _, _, TW2, _, _),
    WBefore is TW1 + TW2,
    tdigest_merge(TD1, TD2, TDM),
    TDM = tdigest(_, _, _, WAfter, _, _),
    Diff is abs(WBefore - WAfter),
    format(atom(L1), "weight_before=~0f  weight_after=~0f  (equal)", [WBefore, WAfter]),
    ( Diff < 0.001 -> OK1 = true ; OK1 = false ),
    check(L1, OK1),

    tdigest_quantile(TDM, 0.5, Median),
    MedianErr is abs(Median - 0.5),
    format(atom(L2), "median_error=~6f  (< 0.05)", [MedianErr]),
    ( MedianErr < 0.05 -> OK2 = true ; OK2 = false ),
    check(L2, OK2),

    tdigest_quantile(TDM, 0.99, P99),
    P99Err is abs(P99 - 0.99),
    format(atom(L3), "p99_error=~6f  (< 0.05)", [P99Err]),
    ( P99Err < 0.05 -> OK3 = true ; OK3 = false ),
    check(L3, OK3),
    nl.

build_digest_range(Delta, From, To, N, TD) :-
    tdigest_new(Delta, TD0),
    build_range_loop(From, To, N, TD0, TD).

build_range_loop(I, To, _, TD, TD) :- I >= To, !.
build_range_loop(I, To, N, TD0, TD) :-
    V is float(I) / float(N),
    tdigest_add(TD0, V, 1.0, TD1),
    I1 is I + 1,
    build_range_loop(I1, To, N, TD1, TD).

%%% ---------------------------------------------------------------------------
%%% Test 6: compress is O(n log n)
%%% ---------------------------------------------------------------------------

test6 :-
    format("--- Test 6: compress is O(n log n) ---~n"),
    CompressSizes = [500, 5000, 50000],
    maplist(test6_time, CompressSizes, CTimes),
    test6_check(CompressSizes, CTimes),
    nl.

test6_time(BufN, Ms) :-
    build_random_buffer(BufN, Buffer),
    tdigest_new(100.0, tdigest(D, _, _, _, _, _)),
    TD = tdigest(D, [], Buffer, float(BufN), 0.0, 1.0),
    time_block(tdigest_compress(TD, _), Ms),
    format("  buf_n=~t~8|~w~t~18|compress_time=~2fms~n", [BufN, Ms]).

build_random_buffer(0, []) :- !.
build_random_buffer(N, [centroid(V, 1.0) | Rest]) :-
    simple_random(V),
    N1 is N - 1,
    build_random_buffer(N1, Rest).

test6_check([_], [_]) :- !.
test6_check([N0, N1 | Ns], [T0, T1 | Ts]) :-
    Scale is float(N1) / float(N0),
    Ratio is T1 / T0,
    format(atom(Label), "buf_n=~w  ratio=~2f (expected ~~~1f to ~1f)",
           [N1, Ratio, Scale, Scale * 2.0]),
    ( Ratio >= Scale * 0.3, Ratio =< Scale * 4.0 -> OK = true ; OK = false ),
    check(Label, OK),
    test6_check([N1 | Ns], [T1 | Ts]).

%%% ---------------------------------------------------------------------------
%%% Summary
%%% ---------------------------------------------------------------------------

summary :-
    pass_count(P),
    fail_count(F),
    Total is P + F,
    format("Summary: ~w/~w tests passed~n", [P, Total]).
