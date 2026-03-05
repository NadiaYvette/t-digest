%% Dunning t-digest for online quantile estimation.
%% Merging digest variant with K1 (arcsine) scale function.
-module(tdigest).

-compile({no_auto_import,[ceil/1]}).

-export([new/0, new/1, add/2, add/3, compress/1, quantile/2, cdf/2,
         merge/2, centroid_count/1]).

-record(tdigest, {
    delta = 100.0,
    centroids = [],   % [{Mean, Weight}] sorted by mean
    buffer = [],      % [{Mean, Weight}] unsorted
    total_weight = 0.0,
    min = infinity,
    max = neg_infinity,
    buffer_cap = 500
}).

-define(DEFAULT_DELTA, 100).
-define(BUFFER_FACTOR, 5).

new() -> new(?DEFAULT_DELTA).

new(Delta) ->
    #tdigest{
        delta = Delta * 1.0,
        buffer_cap = ceil(Delta * ?BUFFER_FACTOR)
    }.

add(TD, Value) -> add(TD, Value, 1.0).

add(TD, Value, Weight) ->
    V = Value * 1.0,
    W = Weight * 1.0,
    NewMin = min_val(TD#tdigest.min, V),
    NewMax = max_val(TD#tdigest.max, V),
    NewBuf = [{V, W} | TD#tdigest.buffer],
    TD1 = TD#tdigest{
        buffer = NewBuf,
        total_weight = TD#tdigest.total_weight + W,
        min = NewMin,
        max = NewMax
    },
    case length(NewBuf) >= TD1#tdigest.buffer_cap of
        true -> compress(TD1);
        false -> TD1
    end.

compress(#tdigest{buffer = [], centroids = C} = TD) when length(C) =< 1 -> TD;
compress(#tdigest{} = TD) ->
    All = lists:sort(fun({M1, _}, {M2, _}) -> M1 =< M2 end,
                     TD#tdigest.centroids ++ TD#tdigest.buffer),
    [{M0, W0} | Rest] = All,
    N = TD#tdigest.total_weight,
    Delta = TD#tdigest.delta,
    AllLen = length(All),
    {RevCentroids, _} = lists:foldl(
        fun({Mean, Weight}, {[{LM, LW} | Tail], WSF}) ->
            Proposed = LW + Weight,
            Q0 = WSF / N,
            Q1 = (WSF + Proposed) / N,
            case (Proposed =< 1 andalso AllLen > 1) orelse
                 (k(Q1, Delta) - k(Q0, Delta) =< 1.0) of
                true ->
                    NewW = LW + Weight,
                    NewM = (LM * LW + Mean * Weight) / NewW,
                    {[{NewM, NewW} | Tail], WSF};
                false ->
                    {[{Mean, Weight}, {LM, LW} | Tail], WSF + LW}
            end
        end,
        {[{M0, W0}], 0.0},
        Rest
    ),
    TD#tdigest{centroids = lists:reverse(RevCentroids), buffer = []}.

quantile(TD0, Q) ->
    TD = ensure_compressed(TD0),
    quantile_internal(TD, Q).

quantile_internal(#tdigest{centroids = []}, _Q) -> undefined;
quantile_internal(#tdigest{centroids = [{Mean, _}]}, _Q) -> Mean;
quantile_internal(#tdigest{} = TD, Q0) ->
    Q = max(0.0, min(1.0, Q0)),
    N = TD#tdigest.total_weight,
    Target = Q * N,
    Centroids = TD#tdigest.centroids,
    Count = length(Centroids),
    walk_quantile(Centroids, 0, Count, 0.0, Target, N, TD#tdigest.min, TD#tdigest.max).

walk_quantile([], _I, _Count, _Cum, _Target, _N, _Min, Max) -> Max;
walk_quantile([{Mean, Weight} | Rest], I, Count, Cum, Target, N, Min, Max) ->
    if
        I =:= 0 andalso Target < Weight / 2.0 ->
            case Weight =:= 1.0 of
                true -> Min;
                false -> Min + (Mean - Min) * (Target / (Weight / 2.0))
            end;
        I =:= Count - 1 ->
            if
                Target > N - Weight / 2.0 ->
                    case Weight =:= 1.0 of
                        true -> Max;
                        false ->
                            Remaining = N - Weight / 2.0,
                            Mean + (Max - Mean) * ((Target - Remaining) / (Weight / 2.0))
                    end;
                true -> Mean
            end;
        true ->
            Mid = Cum + Weight / 2.0,
            [{NextMean, NextWeight} | _] = Rest,
            NextMid = Cum + Weight + NextWeight / 2.0,
            if
                Target =< NextMid ->
                    Frac = case NextMid =:= Mid of
                               true -> 0.5;
                               false -> (Target - Mid) / (NextMid - Mid)
                           end,
                    Mean + Frac * (NextMean - Mean);
                true ->
                    walk_quantile(Rest, I + 1, Count, Cum + Weight, Target, N, Min, Max)
            end
    end.

cdf(TD0, X) ->
    TD = ensure_compressed(TD0),
    cdf_internal(TD, X).

cdf_internal(#tdigest{centroids = []}, _X) -> undefined;
cdf_internal(#tdigest{min = Min}, X) when X =< Min -> 0.0;
cdf_internal(#tdigest{max = Max}, X) when X >= Max -> 1.0;
cdf_internal(#tdigest{} = TD, X) ->
    N = TD#tdigest.total_weight,
    Centroids = TD#tdigest.centroids,
    Count = length(Centroids),
    walk_cdf(Centroids, 0, Count, 0.0, X, N, TD#tdigest.min, TD#tdigest.max).

walk_cdf([], _I, _Count, _Cum, _X, _N, _Min, _Max) -> 1.0;
walk_cdf([{Mean, Weight} | Rest], I, Count, Cum, X, N, Min, Max) ->
    if
        I =:= 0 andalso X < Mean ->
            InnerW = Weight / 2.0,
            Frac = case Mean =:= Min of
                       true -> 1.0;
                       false -> (X - Min) / (Mean - Min)
                   end,
            (InnerW * Frac) / N;
        I =:= 0 andalso X =:= Mean ->
            (Weight / 2.0) / N;
        I =:= Count - 1 ->
            if
                X > Mean ->
                    InnerW = Weight / 2.0,
                    RightW = N - Cum - InnerW,
                    Frac = case Max =:= Mean of
                               true -> 0.0;
                               false -> (X - Mean) / (Max - Mean)
                           end,
                    (Cum + InnerW + RightW * Frac) / N;
                true ->
                    (Cum + Weight / 2.0) / N
            end;
        true ->
            Mid = Cum + Weight / 2.0,
            [{NextMean, NextWeight} | _] = Rest,
            NextCum = Cum + Weight,
            NextMid = NextCum + NextWeight / 2.0,
            if
                X < NextMean ->
                    case Mean =:= NextMean of
                        true ->
                            (Mid + (NextMid - Mid) / 2.0) / N;
                        false ->
                            Frac = (X - Mean) / (NextMean - Mean),
                            (Mid + Frac * (NextMid - Mid)) / N
                    end;
                true ->
                    walk_cdf(Rest, I + 1, Count, Cum + Weight, X, N, Min, Max)
            end
    end.

merge(TD, Other0) ->
    Other = ensure_compressed(Other0),
    lists:foldl(
        fun({Mean, Weight}, Acc) -> add(Acc, Mean, Weight) end,
        TD,
        Other#tdigest.centroids
    ).

centroid_count(TD0) ->
    TD = ensure_compressed(TD0),
    length(TD#tdigest.centroids).

%% Internal helpers

ensure_compressed(#tdigest{buffer = []} = TD) -> TD;
ensure_compressed(TD) -> compress(TD).

k(Q, Delta) ->
    (Delta / (2.0 * math:pi())) * math:asin(2.0 * Q - 1.0).

ceil(X) ->
    T = trunc(X),
    case X > T of
        true -> T + 1;
        false -> T
    end.

min_val(infinity, V) -> V;
min_val(A, B) when A =< B -> A;
min_val(_, B) -> B.

max_val(neg_infinity, V) -> V;
max_val(A, B) when A >= B -> A;
max_val(_, B) -> B.
