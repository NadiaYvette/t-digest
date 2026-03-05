%%% demo.pl -- Demo / self-test for the t-digest library
%%% Run with: swipl demo.pl

:- use_module(tdigest).

%% Simple LCG pseudo-random number generator
lcg_next(State, NextState, Value) :-
    M is 1 << 32,
    NextState is (1664525 * State + 1013904223) mod M,
    Value is float(NextState) / float(M).

generate_values(0, _State, []) :- !.
generate_values(N, State, [V | Rest]) :-
    N > 0,
    lcg_next(State, State1, V),
    N1 is N - 1,
    generate_values(N1, State1, Rest).

%% Bulk add values into a t-digest
add_values(TD, [], TD).
add_values(TD0, [V | Vs], TD) :-
    tdigest_add(TD0, V, 1.0, TD1),
    add_values(TD1, Vs, TD).

%% Demo / Self-test
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

    % Test merge
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
