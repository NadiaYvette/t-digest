%% Demo for t-digest Erlang implementation.
-module(demo).
-export([main/0]).

main() ->
    N = 10000,
    TD = lists:foldl(
        fun(I, Acc) -> tdigest:add(Acc, I / N) end,
        tdigest:new(100),
        lists:seq(0, N - 1)
    ),

    io:format("T-Digest demo: ~B uniform values in [0, 1)~n", [N]),
    io:format("Centroids: ~B~n", [tdigest:centroid_count(TD)]),
    io:format("~n"),
    io:format("Quantile estimates (expected ~~ q for uniform):~n"),

    Qs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999],
    lists:foreach(
        fun(Q) ->
            Est = tdigest:quantile(TD, Q),
            Error = abs(Est - Q),
            io:format("  q=~7.3f  estimated=~.6f  error=~.6f~n", [Q, Est, Error])
        end,
        Qs
    ),

    io:format("~n"),
    io:format("CDF estimates (expected ~~ x for uniform):~n"),

    lists:foreach(
        fun(X) ->
            Est = tdigest:cdf(TD, X),
            Error = abs(Est - X),
            io:format("  x=~7.3f  estimated=~.6f  error=~.6f~n", [X, Est, Error])
        end,
        Qs
    ),

    %% Test merge
    TD1 = lists:foldl(
        fun(I, Acc) -> tdigest:add(Acc, I / 10000) end,
        tdigest:new(100),
        lists:seq(0, 4999)
    ),
    TD2 = lists:foldl(
        fun(I, Acc) -> tdigest:add(Acc, I / 10000) end,
        tdigest:new(100),
        lists:seq(5000, 9999)
    ),
    Merged = tdigest:merge(TD1, TD2),

    io:format("~n"),
    io:format("After merge:~n"),
    io:format("  median=~.6f (expected ~~0.5)~n", [tdigest:quantile(Merged, 0.5)]),
    io:format("  p99   =~.6f (expected ~~0.99)~n", [tdigest:quantile(Merged, 0.99)]).
