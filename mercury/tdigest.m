%-----------------------------------------------------------------------------%
% tdigest.m
%
% Dunning t-digest for online quantile estimation.
% Merging digest variant with K_1 (arcsine) scale function.
%
% Compile with: mmc --make tdigest
%-----------------------------------------------------------------------------%

:- module tdigest.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module float.
:- import_module int.
:- import_module list.
:- import_module math.
:- import_module string.

%-----------------------------------------------------------------------------%
% Types
%-----------------------------------------------------------------------------%

:- type centroid
    --->    centroid(mean :: float, weight :: float).

:- type tdigest
    --->    tdigest(
                delta       :: float,
                centroids   :: list(centroid),
                buffer      :: list(centroid),
                total_weight :: float,
                td_min      :: float,
                td_max      :: float
            ).

%-----------------------------------------------------------------------------%
% Construction
%-----------------------------------------------------------------------------%

:- func new(float) = tdigest.

new(Delta) = tdigest(Delta, [], [], 0.0, float.max, -float.max).

:- func buffer_cap(tdigest) = int.

buffer_cap(TD) = ceiling_to_int(TD ^ delta * 5.0).

%-----------------------------------------------------------------------------%
% Scale function K_1
%-----------------------------------------------------------------------------%

    % k(q, delta) = (delta / (2 * pi)) * asin(2 * q - 1)
    %
:- func k_scale(float, float) = float.

k_scale(Delta, Q) = (Delta / (2.0 * math.pi)) * math.asin(2.0 * Q - 1.0).

%-----------------------------------------------------------------------------%
% Adding values
%-----------------------------------------------------------------------------%

:- func add(tdigest, float, float) = tdigest.

add(TD0, Value, Weight) = TD :-
    NewBuffer = [centroid(Value, Weight) | TD0 ^ buffer],
    NewTotalWeight = TD0 ^ total_weight + Weight,
    NewMin = float.min(Value, TD0 ^ td_min),
    NewMax = float.max(Value, TD0 ^ td_max),
    TD1 = tdigest(TD0 ^ delta, TD0 ^ centroids, NewBuffer,
                  NewTotalWeight, NewMin, NewMax),
    ( if list.length(NewBuffer) >= buffer_cap(TD1) then
        TD = compress(TD1)
    else
        TD = TD1
    ).

    % add_value is suitable for use with list.foldl:
    % list.foldl(add_value, Values, TD0) = TD.
    % The element comes first, the accumulator second.
    %
:- func add_value(float, tdigest) = tdigest.

add_value(Value, TD) = add(TD, Value, 1.0).

%-----------------------------------------------------------------------------%
% Compression (greedy merge)
%-----------------------------------------------------------------------------%

:- func compress(tdigest) = tdigest.

compress(TD0) = TD :-
    ( if TD0 ^ buffer = [], list.length(TD0 ^ centroids) =< 1 then
        TD = TD0
    else
        All0 = TD0 ^ centroids ++ TD0 ^ buffer,
        list.sort(compare_centroids, All0, Sorted),
        N = TD0 ^ total_weight,
        Delta = TD0 ^ delta,
        Merged = greedy_merge(Delta, N, Sorted),
        TD = tdigest(Delta, Merged, [], N, TD0 ^ td_min, TD0 ^ td_max)
    ).

:- pred compare_centroids(centroid::in, centroid::in,
    comparison_result::uo) is det.

compare_centroids(centroid(MeanA, _), centroid(MeanB, _), Result) :-
    compare(Result, MeanA, MeanB).

    % Greedy merge: walk sorted centroids, merging adjacent ones when the
    % scale function constraint allows it.
    %
:- func greedy_merge(float, float, list(centroid)) = list(centroid).

greedy_merge(_, _, []) = [].
greedy_merge(Delta, N, [C | Rest]) = Merged :-
    greedy_merge_loop(Delta, N, 0.0, C, Rest, Merged).

:- pred greedy_merge_loop(float::in, float::in, float::in,
    centroid::in, list(centroid)::in, list(centroid)::out) is det.

greedy_merge_loop(_, _, _, Current, [], [Current]).
greedy_merge_loop(Delta, N, WeightSoFar, Current, [Item | Rest], Result) :-
    Proposed = Current ^ weight + Item ^ weight,
    Q0 = WeightSoFar / N,
    Q1 = (WeightSoFar + Proposed) / N,
    K0 = k_scale(Delta, Q0),
    K1 = k_scale(Delta, Q1),
    ( if
        ( Proposed =< 1.0, Rest = [_ | _]
        ; K1 - K0 =< 1.0
        )
    then
        MergedCentroid = merge_centroid(Current, Item),
        greedy_merge_loop(Delta, N, WeightSoFar, MergedCentroid, Rest, Result)
    else
        NewWeightSoFar = WeightSoFar + Current ^ weight,
        greedy_merge_loop(Delta, N, NewWeightSoFar, Item, Rest, Tail),
        Result = [Current | Tail]
    ).

    % Merge two centroids using weighted mean.
    %
:- func merge_centroid(centroid, centroid) = centroid.

merge_centroid(A, B) = centroid(NewMean, NewWeight) :-
    NewWeight = A ^ weight + B ^ weight,
    NewMean = (A ^ mean * A ^ weight + B ^ mean * B ^ weight) / NewWeight.

%-----------------------------------------------------------------------------%
% Quantile estimation
%-----------------------------------------------------------------------------%

:- func quantile(tdigest, float) = float.

quantile(TD0, Q) = Value :-
    TD = ensure_compressed(TD0),
    Cs = TD ^ centroids,
    ( if Cs = [] then
        Value = 0.0
    else if Cs = [Only] then
        Value = Only ^ mean
    else
        QClamped = float.max(0.0, float.min(1.0, Q)),
        N = TD ^ total_weight,
        Target = QClamped * N,
        Min = TD ^ td_min,
        Max = TD ^ td_max,
        NumCentroids = list.length(Cs),
        walk_quantile(Cs, 0, NumCentroids, 0.0, Target, N, Min, Max, Value)
    ).

:- pred walk_quantile(list(centroid)::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::in,
    float::out) is det.

walk_quantile([], _, _, _, _, _, _, Max, Max).
walk_quantile([C | Rest], I, NumCentroids, Cumulative, Target, N, Min, Max,
        Value) :-
    LastIdx = NumCentroids - 1,
    HalfW = C ^ weight / 2.0,
    ( if I = 0, Target < HalfW then
        % Left boundary: interpolate between min and first centroid.
        ( if C ^ weight = 1.0 then
            Value = Min
        else
            Value = Min + (C ^ mean - Min) * (Target / HalfW)
        )
    else if I = LastIdx then
        % Right boundary: interpolate between last centroid and max.
        ( if Target > N - HalfW then
            ( if C ^ weight = 1.0 then
                Value = Max
            else
                Remaining = N - HalfW,
                Value = C ^ mean +
                    (Max - C ^ mean) * ((Target - Remaining) / HalfW)
            )
        else
            Value = C ^ mean
        )
    else
        % Middle: interpolate between adjacent centroid midpoints.
        (
            Rest = [NextC | _],
            Mid = Cumulative + HalfW,
            NextMid = Cumulative + C ^ weight + NextC ^ weight / 2.0,
            ( if Target =< NextMid then
                ( if NextMid = Mid then
                    Frac = 0.5
                else
                    Frac = (Target - Mid) / (NextMid - Mid)
                ),
                Value = C ^ mean + Frac * (NextC ^ mean - C ^ mean)
            else
                NewCumulative = Cumulative + C ^ weight,
                walk_quantile(Rest, I + 1, NumCentroids, NewCumulative,
                    Target, N, Min, Max, Value)
            )
        ;
            Rest = [],
            Value = Max
        )
    ).

%-----------------------------------------------------------------------------%
% CDF estimation
%-----------------------------------------------------------------------------%

:- func cdf(tdigest, float) = float.

cdf(TD0, X) = Q :-
    TD = ensure_compressed(TD0),
    Cs = TD ^ centroids,
    N = TD ^ total_weight,
    Min = TD ^ td_min,
    Max = TD ^ td_max,
    ( if Cs = [] then
        Q = 0.0
    else if X =< Min then
        Q = 0.0
    else if X >= Max then
        Q = 1.0
    else
        NumCentroids = list.length(Cs),
        walk_cdf(Cs, 0, NumCentroids, 0.0, X, N, Min, Max, Q)
    ).

:- pred walk_cdf(list(centroid)::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::in,
    float::out) is det.

walk_cdf([], _, _, _, _, _, _, _, 1.0).
walk_cdf([C | Rest], I, NumCentroids, Cumulative, X, N, Min, Max, Q) :-
    LastIdx = NumCentroids - 1,
    ( if I = 0, X < C ^ mean then
        % First centroid, left boundary.
        InnerW = C ^ weight / 2.0,
        ( if C ^ mean = Min then
            Frac = 1.0
        else
            Frac = (X - Min) / (C ^ mean - Min)
        ),
        Q = (InnerW * Frac) / N
    else if I = 0, X = C ^ mean then
        Q = (C ^ weight / 2.0) / N
    else if I = LastIdx, X > C ^ mean then
        % Last centroid, right boundary.
        RightW = N - Cumulative - C ^ weight / 2.0,
        ( if Max = C ^ mean then
            Frac = 0.0
        else
            Frac = (X - C ^ mean) / (Max - C ^ mean)
        ),
        Q = (Cumulative + C ^ weight / 2.0 + RightW * Frac) / N
    else if I = LastIdx then
        Q = (Cumulative + C ^ weight / 2.0) / N
    else
        % Middle: interpolate between centroid midpoints.
        (
            Rest = [NextC | _],
            Mid = Cumulative + C ^ weight / 2.0,
            NextCumulative = Cumulative + C ^ weight,
            NextMid = NextCumulative + NextC ^ weight / 2.0,
            ( if X < NextC ^ mean then
                ( if C ^ mean = NextC ^ mean then
                    Frac = 0.5
                else
                    Frac = (X - C ^ mean) / (NextC ^ mean - C ^ mean)
                ),
                Q = (Mid + Frac * (NextMid - Mid)) / N
            else
                walk_cdf(Rest, I + 1, NumCentroids, NextCumulative,
                    X, N, Min, Max, Q)
            )
        ;
            Rest = [],
            Q = 1.0
        )
    ).

%-----------------------------------------------------------------------------%
% Merge two digests
%-----------------------------------------------------------------------------%

:- func merge_digests(tdigest, tdigest) = tdigest.

merge_digests(TD1, TD2) = TDOut :-
    Compressed2 = ensure_compressed(TD2),
    OtherCs = Compressed2 ^ centroids,
    Combined = list.foldl(
        (func(C::in, Acc::in) = (Out::out) is det :-
            Out = add(Acc, C ^ mean, C ^ weight)),
        OtherCs, TD1),
    TDOut = compress(Combined).

%-----------------------------------------------------------------------------%
% Helper: ensure buffer is compressed
%-----------------------------------------------------------------------------%

:- func ensure_compressed(tdigest) = tdigest.

ensure_compressed(TD) =
    ( if TD ^ buffer = [] then
        TD
    else
        compress(TD)
    ).

%-----------------------------------------------------------------------------%
% Centroid count after compression
%-----------------------------------------------------------------------------%

:- func centroid_count(tdigest) = int.

centroid_count(TD0) = list.length(TD ^ centroids) :-
    TD = ensure_compressed(TD0).

%-----------------------------------------------------------------------------%
% Simple LCG PRNG (no external dependency)
%
% Parameters from Numerical Recipes.
%-----------------------------------------------------------------------------%

:- func lcg_next(int) = int.

lcg_next(S) = (1664525 * S + 1013904223) mod (1 << 32).

:- func lcg_double(int) = float.

lcg_double(S) = float.float(int.abs(S) mod (1 << 30)) /
                float.float(1 << 30).

    % Generate N doubles in [0,1) from a seed.
    %
:- pred lcg_doubles(int::in, int::in, list(float)::out, int::out) is det.

lcg_doubles(N, Seed, Values, SeedOut) :-
    lcg_doubles_loop(N, Seed, [], RevValues, SeedOut),
    list.reverse(RevValues, Values).

:- pred lcg_doubles_loop(int::in, int::in, list(float)::in,
    list(float)::out, int::out) is det.

lcg_doubles_loop(N, Seed, Acc, Values, SeedOut) :-
    ( if N =< 0 then
        Values = Acc,
        SeedOut = Seed
    else
        S1 = lcg_next(Seed),
        V = lcg_double(S1),
        lcg_doubles_loop(N - 1, S1, [V | Acc], Values, SeedOut)
    ).

%-----------------------------------------------------------------------------%
% Formatting helpers
%-----------------------------------------------------------------------------%

:- func format_float(int, float) = string.

format_float(Decimals, X) = Str :-
    ( if X < 0.0 then
        Str = "-" ++ format_float(Decimals, -X)
    else
        Factor = math.pow(10.0, float.float(Decimals)),
        Scaled = float.truncate_to_int(X * Factor + 0.5),
        WholePart = Scaled // Factor_int,
        FracPart = Scaled mod Factor_int,
        Factor_int = float.truncate_to_int(Factor),
        FracStr0 = string.int_to_string(FracPart),
        PadLen = Decimals - string.length(FracStr0),
        ( if PadLen > 0 then
            Padding = string.duplicate_char('0', PadLen),
            FracStr = Padding ++ FracStr0
        else
            FracStr = FracStr0
        ),
        Str = string.int_to_string(WholePart) ++ "." ++ FracStr
    ).

:- func pad_right(int, string) = string.

pad_right(N, S) = PaddedS :-
    Len = string.length(S),
    ( if Len >= N then
        PaddedS = S
    else
        Padding = string.duplicate_char(' ', N - Len),
        PaddedS = S ++ Padding
    ).

%-----------------------------------------------------------------------------%
% Main: demo and self-test
%-----------------------------------------------------------------------------%

main(!IO) :-
    NumValues = 10000,
    Delta = 100.0,

    % Generate uniform values in [0, 1) using simple LCG.
    lcg_doubles(NumValues, 42, Values, Seed1),

    % Build t-digest.
    TD0 = new(Delta),
    TD = list.foldl(add_value, Values, TD0),

    io.write_string("T-Digest demo: ", !IO),
    io.write_int(NumValues, !IO),
    io.write_string(" uniform values in [0, 1)\n", !IO),
    io.write_string("Centroids: ", !IO),
    io.write_int(centroid_count(TD), !IO),
    io.nl(!IO),
    io.nl(!IO),

    % Quantile estimates.
    io.write_string("Quantile estimates (expected ~ q for uniform):\n", !IO),
    Qs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999],
    list.foldl(print_quantile_line(TD), Qs, !IO),
    io.nl(!IO),

    % CDF estimates.
    io.write_string("CDF estimates (expected ~ x for uniform):\n", !IO),
    Xs = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999],
    list.foldl(print_cdf_line(TD), Xs, !IO),
    io.nl(!IO),

    % Test merge: split values into two halves, merge, check.
    lcg_doubles(5000, Seed1, Vals1, Seed2),
    lcg_doubles(5000, Seed2, Vals2, _Seed3),
    TDm1 = list.foldl(add_value, Vals1, new(Delta)),
    TDm2 = list.foldl(add_value, Vals2, new(Delta)),
    TDm = merge_digests(TDm1, TDm2),

    io.write_string("After merge of two 5000-element digests:\n", !IO),
    Median = quantile(TDm, 0.5),
    io.write_string("  median=" ++ format_float(6, Median) ++
        " (expected ~0.5)\n", !IO),
    P99 = quantile(TDm, 0.99),
    io.write_string("  p99   =" ++ format_float(6, P99) ++
        " (expected ~0.99)\n", !IO),
    io.write_string("  centroids=", !IO),
    io.write_int(centroid_count(TDm), !IO),
    io.nl(!IO),
    io.nl(!IO),

    % Verify merge preserves total weight.
    MergeTotalWeight = TDm ^ total_weight,
    ExpectedWeight = TDm1 ^ total_weight + TDm2 ^ total_weight,
    io.write_string("Merge total weight: " ++
        format_float(1, MergeTotalWeight) ++
        " (expected " ++ format_float(1, ExpectedWeight) ++ ")\n", !IO),
    io.nl(!IO),
    io.write_string("Done.\n", !IO).

:- pred print_quantile_line(tdigest::in, float::in,
    io::di, io::uo) is det.

print_quantile_line(TD, Q, !IO) :-
    Est = quantile(TD, Q),
    Err = float.abs(Est - Q),
    io.write_string("  q=" ++ pad_right(6, format_float(3, Q)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

:- pred print_cdf_line(tdigest::in, float::in,
    io::di, io::uo) is det.

print_cdf_line(TD, X, !IO) :-
    Est = cdf(TD, X),
    Err = float.abs(Est - X),
    io.write_string("  x=" ++ pad_right(6, format_float(3, X)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

%-----------------------------------------------------------------------------%
:- end_module tdigest.
%-----------------------------------------------------------------------------%
