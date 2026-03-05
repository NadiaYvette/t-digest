%-----------------------------------------------------------------------------%
% bench.m -- Benchmark / asymptotic-behavior tests for Mercury t-digest
% Compile: mmc --make bench
%-----------------------------------------------------------------------------%

:- module bench.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module tdigest.
:- import_module float.
:- import_module int.
:- import_module list.
:- import_module math.
:- import_module string.
:- import_module bool.

%-----------------------------------------------------------------------------%
% C FFI for wall-clock timing
%-----------------------------------------------------------------------------%

:- pred get_wall_time(float::out, io::di, io::uo) is det.

:- pragma foreign_proc("C",
    get_wall_time(Time::out, _IO0::di, _IO::uo),
    [will_not_call_mercury, promise_pure, thread_safe],
"
#include <time.h>
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    Time = (double)ts.tv_sec + (double)ts.tv_nsec / 1.0e9;
").

%-----------------------------------------------------------------------------%
% Helpers
%-----------------------------------------------------------------------------%

:- pred check(string::in, bool::in, int::in, int::out, int::in, int::out,
    io::di, io::uo) is det.

check(Label, OK, !PassCount, !FailCount, !IO) :-
    (
        OK = yes,
        !:PassCount = !.PassCount + 1,
        io.format("  %s  PASS\n", [s(Label)], !IO)
    ;
        OK = no,
        !:FailCount = !.FailCount + 1,
        io.format("  %s  FAIL\n", [s(Label)], !IO)
    ).

:- func to_bool(bool) = bool.
to_bool(X) = X.

:- func build_digest(float, int) = tdigest.
build_digest(Delta, N) = TD :-
    build_digest_loop(0, N, tdigest.new(Delta), TD).

:- pred build_digest_loop(int::in, int::in, tdigest::in, tdigest::out) is det.
build_digest_loop(I, N, !TD) :-
    ( if I >= N then
        true
    else
        V = float(I) / float(N),
        !:TD = tdigest.add(!.TD, V, 1.0),
        build_digest_loop(I + 1, N, !TD)
    ).

:- pred build_digest_range(float::in, int::in, int::in, int::in,
    tdigest::out) is det.
build_digest_range(Delta, From, To, N, TD) :-
    build_range_loop(From, To, N, tdigest.new(Delta), TD).

:- pred build_range_loop(int::in, int::in, int::in, tdigest::in,
    tdigest::out) is det.
build_range_loop(I, To, N, !TD) :-
    ( if I >= To then
        true
    else
        V = float(I) / float(N),
        !:TD = tdigest.add(!.TD, V, 1.0),
        build_range_loop(I + 1, To, N, !TD)
    ).

:- func simple_random(int) = {float, int}.
simple_random(State0) = {V, State1} :-
    State1 = (State0 * 1103515245 + 12345) mod (1 << 31),
    V = float(State1) / float(1 << 31).

:- pred query_loop(int::in, tdigest::in, float::in, float::out) is det.
query_loop(I, TD, !Acc) :-
    ( if I =< 0 then
        true
    else
        Q = tdigest.quantile(TD, 0.5),
        C = tdigest.cdf(TD, 0.5),
        !:Acc = !.Acc + Q + C,
        query_loop(I - 1, TD, !Acc)
    ).

%-----------------------------------------------------------------------------%
% Main
%-----------------------------------------------------------------------------%

main(!IO) :-
    io.write_string("=== T-Digest Asymptotic Behavior Tests (Mercury) ===\n\n", !IO),
    PC0 = 0, FC0 = 0,
    test1(PC0, PC1, FC0, FC1, !IO),
    test2(PC1, PC2, FC1, FC2, !IO),
    test3(PC2, PC3, FC2, FC3, !IO),
    test4(PC3, PC4, FC3, FC4, !IO),
    test5(PC4, PC5, FC4, FC5, !IO),
    test6(PC5, PC6, FC5, FC6, !IO),
    Total = PC6 + FC6,
    io.format("Summary: %d/%d tests passed\n", [i(PC6), i(Total)], !IO).

%-----------------------------------------------------------------------------%
% Test 1: add() is amortized O(1)
%-----------------------------------------------------------------------------%

:- pred test1(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test1(!PC, !FC, !IO) :-
    io.write_string("--- Test 1: add() is amortized O(1) ---\n", !IO),
    Sizes = [1000, 10000, 100000, 1000000],
    test1_times(Sizes, [], RevTimes, !IO),
    list.reverse(RevTimes, Times),
    test1_check(Sizes, Times, 1, !PC, !FC, !IO),
    io.nl(!IO).

:- pred test1_times(list(int)::in, list(float)::in, list(float)::out,
    io::di, io::uo) is det.
test1_times([], Acc, Acc, !IO).
test1_times([N | Rest], Acc, Times, !IO) :-
    get_wall_time(T0, !IO),
    TD = build_digest(100.0, N),
    _ = tdigest.centroid_count(TD),
    get_wall_time(T1, !IO),
    Ms = (T1 - T0) * 1000.0,
    io.format("  N=%-9d  time=%.1fms\n", [i(N), f(Ms)], !IO),
    test1_times(Rest, [Ms | Acc], Times, !IO).

:- pred test1_check(list(int)::in, list(float)::in, int::in,
    int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test1_check(Sizes, Times, I, !PC, !FC, !IO) :-
    ( if I >= list.length(Sizes) then
        true
    else
        list.det_index0(Sizes, I, N),
        list.det_index0(Sizes, I - 1, NPrev),
        list.det_index0(Times, I, T),
        list.det_index0(Times, I - 1, TPrev),
        Expected = float(N) / float(NPrev),
        ( if TPrev > 0.0 then Ratio = T / TPrev else Ratio = 1.0 ),
        Label = string.format("N=%d  ratio=%.2f (expected ~%.1f)",
            [i(N), f(Ratio), f(Expected)]),
        ( if Ratio >= Expected * 0.5, Ratio =< Expected * 3.0 then
            OK = yes
        else
            OK = no
        ),
        check(Label, OK, !PC, !FC, !IO),
        test1_check(Sizes, Times, I + 1, !PC, !FC, !IO)
    ).

%-----------------------------------------------------------------------------%
% Test 2: Centroid count bounded by O(delta)
%-----------------------------------------------------------------------------%

:- pred test2(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test2(!PC, !FC, !IO) :-
    io.write_string("--- Test 2: Centroid count bounded by O(delta) ---\n", !IO),
    Sizes = [1000, 10000, 100000, 1000000],
    list.foldl3(test2_one, Sizes, !PC, !FC, !IO),
    io.nl(!IO).

:- pred test2_one(int::in, int::in, int::out, int::in, int::out,
    io::di, io::uo) is det.
test2_one(N, !PC, !FC, !IO) :-
    TD = build_digest(100.0, N),
    CC = tdigest.centroid_count(TD),
    Label = string.format("N=%-9d  centroids=%-4d  (delta=100, limit=500)",
        [i(N), i(CC)]),
    ( if CC =< 500 then OK = yes else OK = no ),
    check(Label, OK, !PC, !FC, !IO).

%-----------------------------------------------------------------------------%
% Test 3: Query time independent of N
%-----------------------------------------------------------------------------%

:- pred test3(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test3(!PC, !FC, !IO) :-
    io.write_string("--- Test 3: Query time independent of N ---\n", !IO),
    QSizes = [1000, 10000, 100000],
    test3_times(QSizes, [], RevQT, !IO),
    list.reverse(RevQT, QTimes),
    test3_check(QSizes, QTimes, 1, !PC, !FC, !IO),
    io.nl(!IO).

:- pred test3_times(list(int)::in, list(float)::in, list(float)::out,
    io::di, io::uo) is det.
test3_times([], Acc, Acc, !IO).
test3_times([N | Rest], Acc, Times, !IO) :-
    TD = tdigest.compress(build_digest(100.0, N)),
    Iterations = 10000,
    get_wall_time(T0, !IO),
    query_loop(Iterations, TD, 0.0, _),
    get_wall_time(T1, !IO),
    Ms = (T1 - T0) * 1000.0,
    UsPer = (Ms * 1000.0) / float(Iterations),
    io.format("  N=%-9d  query_time=%.2fus\n", [i(N), f(UsPer)], !IO),
    test3_times(Rest, [UsPer | Acc], Times, !IO).

:- pred test3_check(list(int)::in, list(float)::in, int::in,
    int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test3_check(Sizes, Times, I, !PC, !FC, !IO) :-
    ( if I >= list.length(Sizes) then
        true
    else
        list.det_index0(Sizes, I, N),
        list.det_index0(Times, I, T),
        list.det_index0(Times, I - 1, TPrev),
        ( if TPrev > 0.0 then Ratio = T / TPrev else Ratio = 1.0 ),
        Label = string.format("N=%d  ratio=%.2f (expected ~1.0)",
            [i(N), f(Ratio)]),
        ( if Ratio >= 0.2, Ratio =< 5.0 then OK = yes else OK = no ),
        check(Label, OK, !PC, !FC, !IO),
        test3_check(Sizes, Times, I + 1, !PC, !FC, !IO)
    ).

%-----------------------------------------------------------------------------%
% Test 4: Tail accuracy improves with delta
%-----------------------------------------------------------------------------%

:- pred test4(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test4(!PC, !FC, !IO) :-
    io.write_string("--- Test 4: Tail accuracy improves with delta ---\n", !IO),
    Deltas = [50.0, 100.0, 200.0],
    TailQs = [0.01, 0.001, 0.99, 0.999],
    list.foldl3(test4_q(Deltas), TailQs, !PC, !FC, !IO),
    io.nl(!IO).

:- pred test4_q(list(float)::in, float::in,
    int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test4_q(Deltas, Q, !PC, !FC, !IO) :-
    NAcc = 100000,
    Errors = list.map(test4_compute_error(Q, NAcc), Deltas),
    test4_print_errors(Deltas, Q, Errors, !IO),
    test4_check_errors(Deltas, Q, Errors, 1, !PC, !FC, !IO).

:- func test4_compute_error(float, int, float) = float.
test4_compute_error(Q, NAcc, Delta) = Err :-
    TD = build_digest(Delta, NAcc),
    Est = tdigest.quantile(TD, Q),
    Err = float.abs(Est - Q).

:- pred test4_print_errors(list(float)::in, float::in, list(float)::in,
    io::di, io::uo) is det.
test4_print_errors([], _, _, !IO).
test4_print_errors([_ | _], _, [], !IO).
test4_print_errors([D | Ds], Q, [E | Es], !IO) :-
    DI = float.truncate_to_int(D),
    io.format("  delta=%-5d  q=%-6.3f  error=%.6f\n",
        [i(DI), f(Q), f(E)], !IO),
    test4_print_errors(Ds, Q, Es, !IO).

:- pred test4_check_errors(list(float)::in, float::in, list(float)::in,
    int::in, int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test4_check_errors(Deltas, Q, Errors, I, !PC, !FC, !IO) :-
    ( if I >= list.length(Deltas) then
        true
    else
        list.det_index0(Deltas, I, D),
        list.det_index0(Errors, I, E),
        list.det_index0(Errors, I - 1, EPrev),
        Limit = EPrev * 1.5 + 0.001,
        ( if E =< Limit then OK = yes else OK = no ),
        DI = float.truncate_to_int(D),
        Label = string.format("delta=%d q=%.3f error decreases (%.6f <= %.6f)",
            [i(DI), f(Q), f(E), f(EPrev)]),
        check(Label, OK, !PC, !FC, !IO),
        test4_check_errors(Deltas, Q, Errors, I + 1, !PC, !FC, !IO)
    ).

%-----------------------------------------------------------------------------%
% Test 5: Merge preserves weight and accuracy
%-----------------------------------------------------------------------------%

:- pred test5(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test5(!PC, !FC, !IO) :-
    io.write_string("--- Test 5: Merge preserves weight and accuracy ---\n", !IO),
    NMerge = 10000,
    Half = NMerge / 2,
    build_digest_range(100.0, 0, Half, NMerge, TD1),
    build_digest_range(100.0, Half, NMerge, NMerge, TD2),
    WBefore = TD1 ^ total_weight + TD2 ^ total_weight,
    Merged = tdigest.merge_digests(TD1, TD2),
    WAfter = Merged ^ total_weight,
    Diff = float.abs(WBefore - WAfter),
    L1 = string.format("weight_before=%.0f  weight_after=%.0f  (equal)",
        [f(WBefore), f(WAfter)]),
    ( if Diff < 0.001 then OK1 = yes else OK1 = no ),
    check(L1, OK1, !PC, !FC, !IO),

    MedianEst = tdigest.quantile(Merged, 0.5),
    MedianErr = float.abs(MedianEst - 0.5),
    L2 = string.format("median_error=%.6f  (< 0.05)", [f(MedianErr)]),
    ( if MedianErr < 0.05 then OK2 = yes else OK2 = no ),
    check(L2, OK2, !PC, !FC, !IO),

    P99Est = tdigest.quantile(Merged, 0.99),
    P99Err = float.abs(P99Est - 0.99),
    L3 = string.format("p99_error=%.6f  (< 0.05)", [f(P99Err)]),
    ( if P99Err < 0.05 then OK3 = yes else OK3 = no ),
    check(L3, OK3, !PC, !FC, !IO),
    io.nl(!IO).

%-----------------------------------------------------------------------------%
% Test 6: compress is O(n log n)
%-----------------------------------------------------------------------------%

:- pred test6(int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test6(!PC, !FC, !IO) :-
    io.write_string("--- Test 6: compress is O(n log n) ---\n", !IO),
    CSizes = [500, 5000, 50000],
    test6_times(CSizes, 12345, [], RevCT, !IO),
    list.reverse(RevCT, CTimes),
    test6_check(CSizes, CTimes, 1, !PC, !FC, !IO),
    io.nl(!IO).

:- pred test6_times(list(int)::in, int::in, list(float)::in,
    list(float)::out, io::di, io::uo) is det.
test6_times([], _, Acc, Acc, !IO).
test6_times([BufN | Rest], Seed, Acc, Times, !IO) :-
    build_random_digest(BufN, Seed, TD, NewSeed),
    get_wall_time(T0, !IO),
    _ = tdigest.centroid_count(tdigest.compress(TD)),
    get_wall_time(T1, !IO),
    Ms = (T1 - T0) * 1000.0,
    io.format("  buf_n=%-8d  compress_time=%.2fms\n", [i(BufN), f(Ms)], !IO),
    test6_times(Rest, NewSeed, [Ms | Acc], Times, !IO).

:- pred build_random_digest(int::in, int::in, tdigest::out, int::out) is det.
build_random_digest(N, Seed, TD, SeedOut) :-
    build_random_loop(N, Seed, tdigest.new(100000.0), TD, SeedOut).

:- pred build_random_loop(int::in, int::in, tdigest::in, tdigest::out,
    int::out) is det.
build_random_loop(I, Seed, !TD, SeedOut) :-
    ( if I =< 0 then
        SeedOut = Seed
    else
        {V, Seed1} = simple_random(Seed),
        !:TD = tdigest.add(!.TD, V, 1.0),
        build_random_loop(I - 1, Seed1, !TD, SeedOut)
    ).

:- pred test6_check(list(int)::in, list(float)::in, int::in,
    int::in, int::out, int::in, int::out, io::di, io::uo) is det.
test6_check(Sizes, Times, I, !PC, !FC, !IO) :-
    ( if I >= list.length(Sizes) then
        true
    else
        list.det_index0(Sizes, I, N),
        list.det_index0(Sizes, I - 1, NPrev),
        list.det_index0(Times, I, T),
        list.det_index0(Times, I - 1, TPrev),
        Scale = float(N) / float(NPrev),
        ( if TPrev > 0.0 then Ratio = T / TPrev else Ratio = 1.0 ),
        Label = string.format("buf_n=%d  ratio=%.2f (expected ~%.1f to %.1f)",
            [i(N), f(Ratio), f(Scale), f(Scale * 2.0)]),
        ( if Ratio >= Scale * 0.3, Ratio =< Scale * 4.0 then
            OK = yes
        else
            OK = no
        ),
        check(Label, OK, !PC, !FC, !IO),
        test6_check(Sizes, Times, I + 1, !PC, !FC, !IO)
    ).

%-----------------------------------------------------------------------------%
:- end_module bench.
%-----------------------------------------------------------------------------%
