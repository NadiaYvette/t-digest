%-----------------------------------------------------------------------------%
% tdigest_mut.m
%
% Mutable t-digest implementation using an array-backed 2-3-4 tree
% (measured_tree234) with four-component monoidal measures.
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
:- import_module measured_tree234.

    % Four-component monoidal measure for t-digest centroids.
    %
:- type td_mut_measure
    --->    td_mut_measure(
                tdm_weight          :: float,
                tdm_count           :: int,
                tdm_max_mean        :: float,
                tdm_mean_weight_sum :: float
            ).

:- type mut_tdigest
    --->    mut_tdigest(
                mt_delta        :: float,
                mt_tree         :: measured_tree(centroid, td_mut_measure),
                mt_buffer       :: array(centroid),
                mt_buf_len      :: int,
                mt_buf_cap      :: int,
                mt_total_weight :: float,
                mt_min          :: float,
                mt_max          :: float
            ).

%-----------------------------------------------------------------------------%
% Type class instances
%-----------------------------------------------------------------------------%

:- instance mt_monoid(td_mut_measure).
:- instance mt_measured(td_mut_measure, centroid).

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

    % Force compression of buffered values into the tree.
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

:- import_module bool.
:- import_module list.
:- import_module math.

%-----------------------------------------------------------------------------%
% Type class instances
%-----------------------------------------------------------------------------%

:- instance mt_monoid(td_mut_measure) where [
    ( mt_mempty = td_mut_measure(0.0, 0, -float.max, 0.0) ),
    ( mt_mappend(A, B) = td_mut_measure(
        A ^ tdm_weight + B ^ tdm_weight,
        A ^ tdm_count + B ^ tdm_count,
        float.max(A ^ tdm_max_mean, B ^ tdm_max_mean),
        A ^ tdm_mean_weight_sum + B ^ tdm_mean_weight_sum
    ) )
].

:- instance mt_measured(td_mut_measure, centroid) where [
    ( mt_measure(centroid(Mean, Weight)) =
        td_mut_measure(Weight, 1, Mean, Mean * Weight)
    )
].

%-----------------------------------------------------------------------------%
% Promise-unique helper
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
% Centroid comparison
%-----------------------------------------------------------------------------%

:- pred compare_centroids(centroid::in, centroid::in,
    comparison_result::uo) is det.

compare_centroids(centroid(MeanA, _), centroid(MeanB, _), Result) :-
    compare(Result, MeanA, MeanB).

%-----------------------------------------------------------------------------%
% Dummy centroid for array initialization
%-----------------------------------------------------------------------------%

:- func dummy_centroid = centroid.

dummy_centroid = centroid(0.0, 0.0).

%-----------------------------------------------------------------------------%
% Weight extraction from measure
%-----------------------------------------------------------------------------%

:- func weight_of_measure(td_mut_measure) = float.

weight_of_measure(M) = M ^ tdm_weight.

%-----------------------------------------------------------------------------%
% Construction
%-----------------------------------------------------------------------------%

mut_new(Delta, TD) :-
    BufCap = float.ceiling_to_int(Delta * 5.0),
    mt_new(dummy_centroid, Tree),
    array.init(BufCap, dummy_centroid, Buffer),
    TD = promise_unique_td(
        mut_tdigest(Delta, Tree, Buffer, 0, BufCap,
            0.0, float.max, -float.max)).

%-----------------------------------------------------------------------------%
% Adding values
%-----------------------------------------------------------------------------%

mut_add_value(Value, !TD) :-
    mut_add(Value, 1.0, !TD).

mut_add(Value, Weight, TD0, TD) :-
    TD0 = mut_tdigest(Delta, Tree, Buffer0, BufLen0, BufCap,
        TotalWeight0, Min0, Max0),
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
        array.resize(NewBufSize, dummy_centroid,
            unsafe_promise_unique(Buffer0), Buffer1a),
        array.set(BufLen0, centroid(Value, Weight), Buffer1a, Buffer1)
    ),
    TD1 = promise_unique_td(
        mut_tdigest(Delta, Tree, Buffer1, NewBufLen, BufCap,
            NewTotalWeight, NewMin, NewMax)),
    ( if NewBufLen >= BufCap then
        mut_compress(TD1, TD)
    else
        TD = TD1
    ).

%-----------------------------------------------------------------------------%
% Compression (greedy merge)
%-----------------------------------------------------------------------------%

mut_compress(TD0, TD) :-
    TD0 = mut_tdigest(Delta, Tree0, Buffer0, BufLen0, BufCap,
        TotalWeight, Min, Max),
    TreeSize = mt_size(Tree0),
    ( if BufLen0 = 0, TreeSize =< 1 then
        TD = promise_unique_td(TD0)
    else
        % Collect all centroids from tree and buffer, sort, then greedy merge.
        mt_collect(Tree0, TreeCentroids),
        array_to_list_n(Buffer0, BufLen0, 0, BufferList),
        AllList = TreeCentroids ++ BufferList,
        list.sort(compare_centroids_for_sort, AllList, Sorted),
        (
            Sorted = [],
            mt_new(dummy_centroid, NewTree),
            array.init(BufCap, dummy_centroid, NewBuffer),
            TD = promise_unique_td(
                mut_tdigest(Delta, NewTree, NewBuffer, 0, BufCap,
                    TotalWeight, Min, Max))
        ;
            Sorted = [First | Rest],
            greedy_merge(Delta, TotalWeight, 0.0, First, Rest, [], Merged0),
            list.reverse(Merged0, Merged),
            % Build tree from sorted merged centroids.
            mt_build_from_sorted(dummy_centroid, Merged, NewTree),
            array.init(BufCap, dummy_centroid, NewBuffer),
            TD = promise_unique_td(
                mut_tdigest(Delta, NewTree, NewBuffer, 0, BufCap,
                    TotalWeight, Min, Max))
        )
    ).

:- pred compare_centroids_for_sort(centroid::in, centroid::in,
    comparison_result::uo) is det.

compare_centroids_for_sort(centroid(MeanA, _), centroid(MeanB, _), Result) :-
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

    % Greedy merge: accumulates merged centroids in reverse order.
    %
:- pred greedy_merge(float::in, float::in, float::in,
    centroid::in, list(centroid)::in,
    list(centroid)::in, list(centroid)::out) is det.

greedy_merge(_, _, _, Current, [], !Acc) :-
    !:Acc = [Current | !.Acc].
greedy_merge(Delta, N, WeightSoFar, Current, [Item | Rest], !Acc) :-
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
        greedy_merge(Delta, N, WeightSoFar, MergedC, Rest, !Acc)
    else
        % Emit Current, start a new centroid with Item.
        !:Acc = [Current | !.Acc],
        NewWeightSoFar = WeightSoFar + Current ^ weight,
        greedy_merge(Delta, N, NewWeightSoFar, Item, Rest, !Acc)
    ).

%-----------------------------------------------------------------------------%
% Ensure compressed
%-----------------------------------------------------------------------------%

:- pred ensure_compressed(mut_tdigest::di, mut_tdigest::uo) is det.

ensure_compressed(!TD) :-
    !.TD = mut_tdigest(_, _, _, BufLen, _, _, _, _),
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
    TD1 = mut_tdigest(_, Tree, _, _, _, TotalWeight, Min, Max),
    TreeSize = mt_size(Tree),
    ( if TreeSize = 0 then
        Value = 0.0
    else if TreeSize = 1 then
        mt_collect(Tree, Centroids1),
        ( Centroids1 = [Only | _],
            Value = Only ^ mean
        ; Centroids1 = [],
            Value = 0.0
        )
    else
        QClamped = float.max(0.0, float.min(1.0, Q)),
        Target = QClamped * TotalWeight,
        quantile_with_tree(Tree, TreeSize, Target,
            TotalWeight, Min, Max, Value)
    ),
    TD = promise_unique_td(TD1).

:- pred quantile_with_tree(measured_tree(centroid, td_mut_measure)::in,
    int::in, float::in, float::in, float::in, float::in,
    float::out) is det.

quantile_with_tree(Tree, Count, Target, N, Min, Max, Value) :-
    mt_find_by_weight(Tree, Target, weight_of_measure, WR),
    ( if WR ^ wr_found = yes then
        % Collect all centroids for interpolation
        mt_collect(Tree, Centroids),
        Idx = WR ^ wr_index,
        CumBefore = WR ^ wr_cum_before,
        quantile_interpolate(Centroids, Count, Idx, CumBefore,
            Target, N, Min, Max, Value)
    else
        Value = 0.0
    ).

:- pred quantile_interpolate(list(centroid)::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::in,
    float::out) is det.

quantile_interpolate(Centroids, Count, Idx, CumBefore, Target, N,
        Min, Max, Value) :-
    list.det_index0(Centroids, Idx, C),
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
        list.det_index0(Centroids, Idx + 1, NextC),
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

:- pred quantile_walk_forward(list(centroid)::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::out) is det.

quantile_walk_forward(Centroids, Count, I, Cumulative, Target, N, Max,
        Value) :-
    LastIdx = Count - 1,
    ( if I > LastIdx then
        Value = Max
    else
        list.det_index0(Centroids, I, C),
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
            list.det_index0(Centroids, I + 1, NextC),
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
    TD1 = mut_tdigest(_, Tree, _, _, _, TotalWeight, Min, Max),
    TreeSize = mt_size(Tree),
    ( if TreeSize = 0 then
        Q = 0.0
    else if X =< Min then
        Q = 0.0
    else if X >= Max then
        Q = 1.0
    else
        mt_collect(Tree, Centroids),
        cdf_walk(Centroids, TreeSize, 0, 0.0, X, TotalWeight,
            Min, Max, Q)
    ),
    TD = promise_unique_td(TD1).

:- pred cdf_walk(list(centroid)::in, int::in, int::in, float::in,
    float::in, float::in, float::in, float::in,
    float::out) is det.

cdf_walk(Centroids, Count, I, Cumulative, X, N, Min, Max, Q) :-
    LastIdx = Count - 1,
    ( if I > LastIdx then
        Q = 1.0
    else
        list.det_index0(Centroids, I, C),
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
            list.det_index0(Centroids, I + 1, NextC),
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
                cdf_walk(Centroids, Count, I + 1,
                    Cumulative + C ^ weight, X, N, Min, Max, Q)
            )
        )
    ).

%-----------------------------------------------------------------------------%
% Centroid count
%-----------------------------------------------------------------------------%

mut_centroid_count(TD0, TD, Count) :-
    ensure_compressed(TD0, TD1),
    TD1 = mut_tdigest(_, Tree, _, _, _, _, _, _),
    Count = mt_size(Tree),
    TD = promise_unique_td(TD1).

%-----------------------------------------------------------------------------%
:- end_module tdigest_mut.
%-----------------------------------------------------------------------------%
