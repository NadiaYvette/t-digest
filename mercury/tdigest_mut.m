%-----------------------------------------------------------------------------%
% tdigest_mut.m
%
% Truly mutable t-digest implementation using Mercury's array module
% with di/uo destructive update modes and a Fenwick tree for prefix sums.
%
% Merging digest variant with K_1 (arcsine) scale function.
%
% Since Mercury's uniqueness tracking does not automatically propagate
% through discriminated union fields, we use unsafe_promise_unique when
% reconstructing mut_tdigest values.  This is safe because the di mode
% on the input guarantees we hold the sole reference.
%-----------------------------------------------------------------------------%

:- module tdigest_mut.
:- interface.

:- import_module array.
:- import_module float.
:- import_module int.

%-----------------------------------------------------------------------------%
% Types
%-----------------------------------------------------------------------------%

:- import_module tdigest.   % For the centroid type.

:- type mut_tdigest
    --->    mut_tdigest(
                mt_delta        :: float,
                mt_centroids    :: array(centroid),  % sorted by mean
                mt_count        :: int,              % number of active centroids
                mt_buffer       :: array(centroid),   % unsorted buffer
                mt_buf_len      :: int,              % current buffer length
                mt_buf_cap      :: int,              % buffer capacity
                mt_total_weight :: float,
                mt_min          :: float,
                mt_max          :: float,
                mt_fenwick      :: array(float)      % Fenwick tree of weights
            ).

%-----------------------------------------------------------------------------%
% Public interface (di/uo threaded)
%-----------------------------------------------------------------------------%

    % Create a new empty mutable t-digest with the given compression parameter.
    %
:- pred mut_new(float::in, mut_tdigest::uo) is det.

    % Add a value with a given weight.
    %
:- pred mut_add(float::in, float::in, mut_tdigest::di, mut_tdigest::uo) is det.

    % Add a single value (weight 1.0).
    %
:- pred mut_add_value(float::in, mut_tdigest::di, mut_tdigest::uo) is det.

    % Force compression of buffered values into the centroid array.
    %
:- pred mut_compress(mut_tdigest::di, mut_tdigest::uo) is det.

    % Estimate the value at quantile Q (0..1).
    % May compress as a side-effect.
    %
:- pred mut_quantile(mut_tdigest::di, float::in, mut_tdigest::uo,
    float::out) is det.

    % Estimate the CDF value at X.
    % May compress as a side-effect.
    %
:- pred mut_cdf(mut_tdigest::di, float::in, mut_tdigest::uo,
    float::out) is det.

    % Return the number of active centroids (compresses first if needed).
    %
:- pred mut_centroid_count(mut_tdigest::di, mut_tdigest::uo,
    int::out) is det.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module list.
:- import_module math.

%-----------------------------------------------------------------------------%
% Promise-unique helper
%
% When we deconstruct a mut_tdigest (di) and reconstruct it, the fields
% lose their unique inst.  Since di guarantees sole ownership, it is
% safe to promise uniqueness on the rebuilt record.
%-----------------------------------------------------------------------------%

:- func promise_unique_td(mut_tdigest) = mut_tdigest.
:- mode promise_unique_td(in) = uo is det.

promise_unique_td(TD) = unsafe_promise_unique(TD).

%-----------------------------------------------------------------------------%
% Scale function K_1 (arcsine)
%-----------------------------------------------------------------------------%

:- func k_scale(float, float) = float.

k_scale(Delta, Q) = (Delta / (2.0 * math.pi)) * math.asin(2.0 * Q - 1.0).

%-----------------------------------------------------------------------------%
% Fenwick tree operations
%-----------------------------------------------------------------------------%

    % Build a Fenwick tree from the weights of the first Count centroids.
    % Returns a unique array sized Count+1 (1-indexed internally).
    %
:- pred fenwick_build(array(centroid)::in, int::in,
    array(float)::array_uo) is det.

fenwick_build(Centroids, Count, Fenwick) :-
    array.init(Count + 1, 0.0, Fenwick0),
    fenwick_build_loop(Centroids, Count, 0, Fenwick0, Fenwick).

:- pred fenwick_build_loop(array(centroid)::in, int::in, int::in,
    array(float)::array_di, array(float)::array_uo) is det.

fenwick_build_loop(Centroids, Count, I, !Fenwick) :-
    ( if I < Count then
        array.lookup(Centroids, I, C),
        W = C ^ weight,
        fenwick_update(I, W, Count, !Fenwick),
        fenwick_build_loop(Centroids, Count, I + 1, !Fenwick)
    else
        true
    ).

    % Add Val to the Fenwick tree at position I (0-indexed externally,
    % converted to 1-indexed internally).
    %
:- pred fenwick_update(int::in, float::in, int::in,
    array(float)::array_di, array(float)::array_uo) is det.

fenwick_update(I, Val, Count, !Fenwick) :-
    J = I + 1,  % Convert to 1-indexed.
    fenwick_update_loop(J, Val, Count, !Fenwick).

:- pred fenwick_update_loop(int::in, float::in, int::in,
    array(float)::array_di, array(float)::array_uo) is det.

fenwick_update_loop(J, Val, Count, !Fenwick) :-
    ( if J =< Count then
        array.lookup(!.Fenwick, J, Old),
        array.set(J, Old + Val, !Fenwick),
        NextJ = J + (J /\ (-J)),   % J + lowest set bit
        fenwick_update_loop(NextJ, Val, Count, !Fenwick)
    else
        true
    ).

    % Compute prefix sum for indices 0..I (inclusive, 0-indexed externally).
    % Returns sum of weights for centroids 0 through I.
    %
:- func fenwick_prefix_sum(array(float), int) = float.

fenwick_prefix_sum(Fenwick, I) = Sum :-
    J = I + 1,  % Convert to 1-indexed.
    fenwick_prefix_sum_loop(Fenwick, J, 0.0, Sum).

:- pred fenwick_prefix_sum_loop(array(float)::in, int::in,
    float::in, float::out) is det.

fenwick_prefix_sum_loop(Fenwick, J, Acc, Sum) :-
    ( if J > 0 then
        array.lookup(Fenwick, J, Val),
        NextJ = J - (J /\ (-J)),   % J - lowest set bit
        fenwick_prefix_sum_loop(Fenwick, NextJ, Acc + Val, Sum)
    else
        Sum = Acc
    ).

    % Find the smallest index I (0-indexed) where prefix sum >= Target.
    % Uses O(log n) binary descent on the Fenwick tree.
    % Also returns the prefix sum up to (but not including) index I.
    %
:- pred fenwick_find(array(float)::in, int::in, float::in,
    int::out, float::out) is det.

fenwick_find(Fenwick, Count, Target, Idx, CumBefore) :-
    largest_power_of_2(Count, BitMask),
    fenwick_find_loop(Fenwick, Count, Target, BitMask, 0, 0.0,
        Idx1, _),
    % Idx1 is 0-indexed result from the descent.
    ( if Idx1 >= Count then
        Idx = Count - 1
    else
        Idx = Idx1
    ),
    ( if Idx > 0 then
        CumBefore = fenwick_prefix_sum(Fenwick, Idx - 1)
    else
        CumBefore = 0.0
    ).

:- pred largest_power_of_2(int::in, int::out) is det.

largest_power_of_2(N, P) :-
    ( if N =< 0 then
        P = 0
    else
        largest_power_of_2_loop(1, N, P)
    ).

:- pred largest_power_of_2_loop(int::in, int::in, int::out) is det.

largest_power_of_2_loop(Cur, N, P) :-
    Next = Cur << 1,
    ( if Next =< N then
        largest_power_of_2_loop(Next, N, P)
    else
        P = Cur
    ).

:- pred fenwick_find_loop(array(float)::in, int::in, float::in,
    int::in, int::in, float::in, int::out, float::out) is det.

fenwick_find_loop(Fenwick, Count, Target, BitMask, Pos, CumAcc,
        Idx, CumOut) :-
    ( if BitMask = 0 then
        Idx = Pos,
        CumOut = CumAcc
    else
        NextPos = Pos + BitMask,
        NextBit = BitMask >> 1,
        ( if NextPos =< Count then
            array.lookup(Fenwick, NextPos, TreeVal),
            NewCum = CumAcc + TreeVal,
            ( if NewCum < Target then
                fenwick_find_loop(Fenwick, Count, Target, NextBit,
                    NextPos, NewCum, Idx, CumOut)
            else
                fenwick_find_loop(Fenwick, Count, Target, NextBit,
                    Pos, CumAcc, Idx, CumOut)
            )
        else
            fenwick_find_loop(Fenwick, Count, Target, NextBit,
                Pos, CumAcc, Idx, CumOut)
        )
    ).

%-----------------------------------------------------------------------------%
% Construction
%-----------------------------------------------------------------------------%

mut_new(Delta, TD) :-
    BufCap = float.ceiling_to_int(Delta * 5.0),
    array.init(BufCap, centroid(0.0, 0.0), Centroids),
    array.init(BufCap, centroid(0.0, 0.0), Buffer),
    array.init(1, 0.0, Fenwick),
    TD = promise_unique_td(
        mut_tdigest(Delta, Centroids, 0, Buffer, 0, BufCap,
            0.0, float.max, -float.max, Fenwick)).

%-----------------------------------------------------------------------------%
% Adding values
%-----------------------------------------------------------------------------%

mut_add_value(Value, !TD) :-
    mut_add(Value, 1.0, !TD).

mut_add(Value, Weight, TD0, TD) :-
    TD0 = mut_tdigest(Delta, Centroids0, Count, Buffer0, BufLen0, BufCap,
        TotalWeight0, Min0, Max0, Fenwick0),
    NewTotalWeight = TotalWeight0 + Weight,
    NewMin = float.min(Value, Min0),
    NewMax = float.max(Value, Max0),
    NewBufLen = BufLen0 + 1,
    % Grow buffer if needed.
    BufSize = array.size(Buffer0),
    ( if BufLen0 < BufSize then
        array.set(BufLen0, centroid(Value, Weight),
            unsafe_promise_unique(Buffer0), Buffer1)
    else
        NewBufSize = BufSize * 2 + 1,
        array.resize(NewBufSize, centroid(0.0, 0.0),
            unsafe_promise_unique(Buffer0), Buffer1a),
        array.set(BufLen0, centroid(Value, Weight), Buffer1a, Buffer1)
    ),
    TD1 = promise_unique_td(
        mut_tdigest(Delta, Centroids0, Count, Buffer1, NewBufLen, BufCap,
            NewTotalWeight, NewMin, NewMax, Fenwick0)),
    ( if NewBufLen >= BufCap then
        mut_compress(TD1, TD)
    else
        TD = TD1
    ).

%-----------------------------------------------------------------------------%
% Compression (greedy merge)
%-----------------------------------------------------------------------------%

mut_compress(TD0, TD) :-
    TD0 = mut_tdigest(Delta, Centroids0, Count0, Buffer0, BufLen0, BufCap,
        TotalWeight, Min, Max, _Fenwick0),
    ( if BufLen0 = 0, Count0 =< 1 then
        TD = promise_unique_td(TD0)
    else
        % Collect all centroids into a list, sort, then greedy merge.
        array_to_list_n(Centroids0, Count0, 0, CentroidList),
        array_to_list_n(Buffer0, BufLen0, 0, BufferList),
        AllList = CentroidList ++ BufferList,
        list.sort(compare_centroids, AllList, Sorted),
        (
            Sorted = [],
            array.init(1, 0.0, EmptyFenwick),
            array.init(BufCap, centroid(0.0, 0.0), EmptyBuffer),
            TD = promise_unique_td(
                mut_tdigest(Delta, Centroids0, 0, EmptyBuffer, 0, BufCap,
                    TotalWeight, Min, Max, EmptyFenwick))
        ;
            Sorted = [First | Rest],
            MaxCentroids = list.length(Sorted),
            array.init(MaxCentroids, centroid(0.0, 0.0), MergedArr0),
            array.set(0, First, MergedArr0, MergedArr1),
            greedy_merge_array(Delta, TotalWeight, 0.0, 0, First,
                Rest, MergedArr1, MergedArr2, MergedCount),
            % Build Fenwick tree from merged centroids.
            fenwick_build(MergedArr2, MergedCount, FenwickNew),
            % Create new empty buffer.
            array.init(BufCap, centroid(0.0, 0.0), NewBuffer),
            TD = promise_unique_td(
                mut_tdigest(Delta, MergedArr2, MergedCount, NewBuffer,
                    0, BufCap, TotalWeight, Min, Max, FenwickNew))
        )
    ).

:- pred compare_centroids(centroid::in, centroid::in,
    comparison_result::uo) is det.

compare_centroids(centroid(MeanA, _), centroid(MeanB, _), Result) :-
    compare(Result, MeanA, MeanB).

:- pred array_to_list_n(array(T)::in, int::in, int::in,
    list(T)::out) is det.

array_to_list_n(Arr, N, I, List) :-
    ( if I >= N then
        List = []
    else
        array.lookup(Arr, I, Elem),
        array_to_list_n(Arr, N, I + 1, Tail),
        List = [Elem | Tail]
    ).

    % Greedy merge loop: walks the sorted list and merges into the output
    % array.  Current centroid is at index OutIdx in the array.
    %
:- pred greedy_merge_array(float::in, float::in, float::in, int::in,
    centroid::in, list(centroid)::in,
    array(centroid)::array_di, array(centroid)::array_uo,
    int::out) is det.

greedy_merge_array(_, _, _, OutIdx, Current, [], !Arr, OutCount) :-
    array.set(OutIdx, Current, !Arr),
    OutCount = OutIdx + 1.
greedy_merge_array(Delta, N, WeightSoFar, OutIdx, Current, [Item | Rest],
        !Arr, OutCount) :-
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
        % Merge the two centroids.
        MergedWeight = Current ^ weight + Item ^ weight,
        MergedMean = (Current ^ mean * Current ^ weight +
            Item ^ mean * Item ^ weight) / MergedWeight,
        MergedC = centroid(MergedMean, MergedWeight),
        array.set(OutIdx, MergedC, !Arr),
        greedy_merge_array(Delta, N, WeightSoFar, OutIdx, MergedC, Rest,
            !Arr, OutCount)
    else
        % Emit Current, start a new centroid with Item.
        array.set(OutIdx, Current, !Arr),
        NewWeightSoFar = WeightSoFar + Current ^ weight,
        NewOutIdx = OutIdx + 1,
        array.set(NewOutIdx, Item, !Arr),
        greedy_merge_array(Delta, N, NewWeightSoFar, NewOutIdx, Item, Rest,
            !Arr, OutCount)
    ).

%-----------------------------------------------------------------------------%
% Ensure compressed
%-----------------------------------------------------------------------------%

:- pred ensure_compressed(mut_tdigest::di, mut_tdigest::uo) is det.

ensure_compressed(!TD) :-
    !.TD = mut_tdigest(_, _, _, _, BufLen, _, _, _, _, _),
    ( if BufLen > 0 then
        mut_compress(promise_unique_td(!.TD), !:TD)
    else
        !:TD = promise_unique_td(!.TD)
    ).

%-----------------------------------------------------------------------------%
% Quantile estimation
%-----------------------------------------------------------------------------%

mut_quantile(TD0, Q, TD, Value) :-
    ensure_compressed(TD0, TD1),
    TD1 = mut_tdigest(_, Centroids, Count, _, _, _, TotalWeight,
        Min, Max, Fenwick),
    ( if Count = 0 then
        Value = 0.0
    else if Count = 1 then
        array.lookup(Centroids, 0, Only),
        Value = Only ^ mean
    else
        QClamped = float.max(0.0, float.min(1.0, Q)),
        Target = QClamped * TotalWeight,
        quantile_with_fenwick(Centroids, Count, Fenwick, Target,
            TotalWeight, Min, Max, Value)
    ),
    TD = promise_unique_td(TD1).

:- pred quantile_with_fenwick(array(centroid)::in, int::in,
    array(float)::in, float::in, float::in, float::in, float::in,
    float::out) is det.

quantile_with_fenwick(Centroids, Count, Fenwick, Target, N, Min, Max,
        Value) :-
    fenwick_find(Fenwick, Count, Target, Idx, CumBefore),
    array.lookup(Centroids, Idx, C),
    LastIdx = Count - 1,
    HalfW = C ^ weight / 2.0,
    ( if Idx = 0, Target < HalfW then
        % Left boundary: interpolate between min and first centroid.
        ( if C ^ weight = 1.0 then
            Value = Min
        else
            Value = Min + (C ^ mean - Min) * (Target / HalfW)
        )
    else if Idx = LastIdx then
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
        array.lookup(Centroids, Idx + 1, NextC),
        Cumulative = CumBefore,
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
            % Target beyond this pair; walk forward.
            quantile_walk_forward(Centroids, Count, Idx + 1,
                Cumulative + C ^ weight, Target, N, Max, Value)
        )
    ).

:- pred quantile_walk_forward(array(centroid)::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::out) is det.

quantile_walk_forward(Centroids, Count, I, Cumulative, Target, N, Max,
        Value) :-
    LastIdx = Count - 1,
    ( if I > LastIdx then
        Value = Max
    else
        array.lookup(Centroids, I, C),
        HalfW = C ^ weight / 2.0,
        ( if I = LastIdx then
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
            array.lookup(Centroids, I + 1, NextC),
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
                quantile_walk_forward(Centroids, Count, I + 1,
                    Cumulative + C ^ weight, Target, N, Max, Value)
            )
        )
    ).

%-----------------------------------------------------------------------------%
% CDF estimation
%-----------------------------------------------------------------------------%

mut_cdf(TD0, X, TD, Q) :-
    ensure_compressed(TD0, TD1),
    TD1 = mut_tdigest(_, Centroids, Count, _, _, _, TotalWeight,
        Min, Max, Fenwick),
    ( if Count = 0 then
        Q = 0.0
    else if X =< Min then
        Q = 0.0
    else if X >= Max then
        Q = 1.0
    else
        cdf_with_arrays(Centroids, Count, Fenwick, X, TotalWeight,
            Min, Max, Q)
    ),
    TD = promise_unique_td(TD1).

:- pred cdf_with_arrays(array(centroid)::in, int::in,
    array(float)::in, float::in, float::in, float::in, float::in,
    float::out) is det.

cdf_with_arrays(Centroids, Count, Fenwick, X, N, Min, Max, Q) :-
    % Linear walk through centroids (mirrors the pure implementation).
    cdf_walk(Centroids, Count, Fenwick, 0, X, N, Min, Max, Q).

:- pred cdf_walk(array(centroid)::in, int::in, array(float)::in,
    int::in, float::in, float::in, float::in, float::in,
    float::out) is det.

cdf_walk(Centroids, Count, Fenwick, I, X, N, Min, Max, Q) :-
    LastIdx = Count - 1,
    ( if I > LastIdx then
        Q = 1.0
    else
        array.lookup(Centroids, I, C),
        ( if I > 0 then
            Cumulative = fenwick_prefix_sum(Fenwick, I - 1)
        else
            Cumulative = 0.0
        ),
        ( if I = 0, X < C ^ mean then
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
            array.lookup(Centroids, I + 1, NextC),
            Mid0 = Cumulative + C ^ weight / 2.0,
            NextCumulative = Cumulative + C ^ weight,
            NextMid = NextCumulative + NextC ^ weight / 2.0,
            ( if X < NextC ^ mean then
                ( if C ^ mean = NextC ^ mean then
                    Frac = 0.5
                else
                    Frac = (X - C ^ mean) / (NextC ^ mean - C ^ mean)
                ),
                Q = (Mid0 + Frac * (NextMid - Mid0)) / N
            else
                cdf_walk(Centroids, Count, Fenwick, I + 1,
                    X, N, Min, Max, Q)
            )
        )
    ).

%-----------------------------------------------------------------------------%
% Centroid count
%-----------------------------------------------------------------------------%

mut_centroid_count(TD0, TD, Count) :-
    ensure_compressed(TD0, TD1),
    TD1 = mut_tdigest(_, _, Count, _, _, _, _, _, _, _),
    TD = promise_unique_td(TD1).

%-----------------------------------------------------------------------------%
:- end_module tdigest_mut.
%-----------------------------------------------------------------------------%
