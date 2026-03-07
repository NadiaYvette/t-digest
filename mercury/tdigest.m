%-----------------------------------------------------------------------------%
% tdigest.m
%
% Dunning t-digest for online quantile estimation.
% Merging digest variant with K_1 (arcsine) scale function.
%
% Uses a finger tree (from fingertree.m) with four-component monoidal
% measure (weight, count, maxMean, meanWeightSum) for O(log n) operations.
%
% * O(log n) insertion via split-by-mean (no buffering needed)
% * O(log n) quantile queries via split-by-cumulative-weight
% * O(log n) CDF queries via split-by-mean
% * O(delta * log n) compression via split-based greedy merge
% * O(1) total weight, centroid count, and chunk mean computation
%-----------------------------------------------------------------------------%

:- module tdigest.
:- interface.

:- import_module float.
:- import_module int.
:- import_module fingertree.

%-----------------------------------------------------------------------------%
% Measure type
%-----------------------------------------------------------------------------%

:- type td_measure
    --->    td_measure(
                tm_weight          :: float,   % sum of weights
                tm_count           :: int,     % number of centroids
                tm_max_mean        :: float,   % max centroid mean
                tm_mean_weight_sum :: float    % sum of mean*weight
            ).

%-----------------------------------------------------------------------------%
% Centroid type
%-----------------------------------------------------------------------------%

:- type centroid
    --->    centroid(mean :: float, weight :: float).

%-----------------------------------------------------------------------------%
% Type class instances
%-----------------------------------------------------------------------------%

:- instance monoid(td_measure).
:- instance measured(td_measure, centroid).

%-----------------------------------------------------------------------------%
% Types
%-----------------------------------------------------------------------------%

:- type tdigest
    --->    tdigest(
                delta           :: float,
                centroids       :: fingertree(td_measure, centroid),
                total_weight    :: float,
                td_min          :: float,
                td_max          :: float,
                max_centroids   :: int
            ).

%-----------------------------------------------------------------------------%
% Public operations
%-----------------------------------------------------------------------------%

:- func new(float) = tdigest.
:- func add(tdigest, float, float) = tdigest.
:- func add_value(float, tdigest) = tdigest.
:- func compress(tdigest) = tdigest.
:- func quantile(tdigest, float) = float.
:- func cdf(tdigest, float) = float.
:- func merge_digests(tdigest, tdigest) = tdigest.
:- func centroid_count(tdigest) = int.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module list.
:- import_module math.
:- import_module maybe.

%-----------------------------------------------------------------------------%
% Type class instances
%-----------------------------------------------------------------------------%

:- instance monoid(td_measure) where [
    func(mempty/0) is td_measure_mempty,
    func(mappend/2) is td_measure_mappend
].

:- instance measured(td_measure, centroid) where [
    func(measure/1) is centroid_measure
].

:- func td_measure_mempty = td_measure.

td_measure_mempty = td_measure(0.0, 0, -float.max, 0.0).

:- func td_measure_mappend(td_measure, td_measure) = td_measure.

td_measure_mappend(td_measure(W1, C1, MM1, MWS1),
        td_measure(W2, C2, MM2, MWS2)) =
    td_measure(W1 + W2, C1 + C2, float.max(MM1, MM2), MWS1 + MWS2).

:- func centroid_measure(centroid) = td_measure.

centroid_measure(centroid(M, W)) = td_measure(W, 1, M, M * W).

%-----------------------------------------------------------------------------%
% Measure helpers specific to td_measure
%-----------------------------------------------------------------------------%

    % Get the count of elements from the measure in O(1).
:- func ft_size(fingertree(td_measure, centroid)) = int.

ft_size(T) = ft_measure(T) ^ tm_count.

    % Split by mean value: elements with mean < X go left, >= X go right.
    % Returns {Left, Right}.
:- func ft_split_by_mean(float,
    fingertree(td_measure, centroid))
    = {fingertree(td_measure, centroid),
       fingertree(td_measure, centroid)}.

ft_split_by_mean(X, Tree) = {Left, Right} :-
    ( if ft_split(
            (pred(M::in) is semidet :- M ^ tm_max_mean >= X),
            Tree, L, SplitC, R)
    then
        % SplitC's mean >= X; it goes in Right.
        Left = L,
        Right = ft_cons(SplitC, R)
    else
        % X is greater than all means; everything is in Left.
        Left = Tree,
        Right = ft_empty
    ).

%-----------------------------------------------------------------------------%
% Construction
%-----------------------------------------------------------------------------%

new(Delta) = tdigest(Delta, ft_empty, 0.0, float.max, -float.max,
                     ceiling_to_int(Delta * 3.0)).

%-----------------------------------------------------------------------------%
% Scale function K_1
%-----------------------------------------------------------------------------%

    % k(q, delta) = (delta / (2 * pi)) * asin(2 * q - 1)
    %
:- func k_scale(float, float) = float.

k_scale(Delta, Q) = (Delta / (2.0 * math.pi)) * math.asin(2.0 * Q - 1.0).

    % k_inv(k, delta) = (1 + sin(2 * pi * k / delta)) / 2
    %
:- func k_scale_inv(float, float) = float.

k_scale_inv(Delta, K) = (1.0 + math.sin(2.0 * math.pi * K / Delta)) / 2.0.

%-----------------------------------------------------------------------------%
% Merging centroids
%-----------------------------------------------------------------------------%

:- func merge_centroid(centroid, centroid) = centroid.

merge_centroid(A, B) = centroid(NewMean, NewWeight) :-
    NewWeight = A ^ weight + B ^ weight,
    NewMean = (A ^ mean * A ^ weight + B ^ mean * B ^ weight) / NewWeight.

%-----------------------------------------------------------------------------%
% Adding values - O(log n) via split-by-mean
%-----------------------------------------------------------------------------%

add(TD0, Value, Weight) = TD :-
    N = TD0 ^ total_weight + Weight,
    NewMin = float.min(Value, TD0 ^ td_min),
    NewMax = float.max(Value, TD0 ^ td_max),
    Delta = TD0 ^ delta,
    Cs = TD0 ^ centroids,
    NewC = centroid(Value, Weight),
    ( if ft_null(Cs) then
        NewCs = ft_single(NewC)
    else
        ft_split_by_mean(Value, Cs) = {Left, Right},
        LeftWeight = (ft_measure(Left)) ^ tm_weight,
        NewCs = try_merge_neighbor(Delta, N, LeftWeight, Left, Right, NewC)
    ),
    TD1 = tdigest(Delta, NewCs, N, NewMin, NewMax, TD0 ^ max_centroids),
    ( if ft_size(NewCs) > TD0 ^ max_centroids then
        TD = compress(TD1)
    else
        TD = TD1
    ).

add_value(Value, TD) = add(TD, Value, 1.0).

:- type merge_candidate
    --->    merge_candidate(
                mc_rest     :: fingertree(td_measure, centroid),
                mc_neighbor :: centroid,
                mc_dist     :: float
            ).

:- func try_merge_neighbor(float, float, float,
    fingertree(td_measure, centroid),
    fingertree(td_measure, centroid),
    centroid) = fingertree(td_measure, centroid).

try_merge_neighbor(Delta, N, LeftWeight, Left, Right, NewC) = Result :-
    LeftCandidate = check_left_neighbor(Delta, N, Left, NewC),
    RightCandidate = check_right_neighbor(Delta, N, LeftWeight, Right, NewC),
    ( if
        LeftCandidate = yes(LCand),
        RightCandidate = yes(RCand)
    then
        ( if LCand ^ mc_dist =< RCand ^ mc_dist then
            Result = ft_concat(
                ft_snoc(LCand ^ mc_rest,
                        merge_centroid(LCand ^ mc_neighbor, NewC)),
                Right)
        else
            Result = ft_concat(Left,
                ft_cons(merge_centroid(RCand ^ mc_neighbor, NewC),
                        RCand ^ mc_rest))
        )
    else if LeftCandidate = yes(LCand2) then
        Result = ft_concat(
            ft_snoc(LCand2 ^ mc_rest,
                    merge_centroid(LCand2 ^ mc_neighbor, NewC)),
            Right)
    else if RightCandidate = yes(RCand2) then
        Result = ft_concat(Left,
            ft_cons(merge_centroid(RCand2 ^ mc_neighbor, NewC),
                    RCand2 ^ mc_rest))
    else
        % Insert as new centroid.
        Result = ft_concat(Left, ft_cons(NewC, Right))
    ).

:- func check_left_neighbor(float, float,
    fingertree(td_measure, centroid), centroid) = maybe(merge_candidate).

check_left_neighbor(Delta, N, Left, NewC) = Result :-
    ( if ft_viewr(Left, LeftRest, LC) then
        CumBefore = (ft_measure(LeftRest)) ^ tm_weight,
        ProposedL = LC ^ weight + NewC ^ weight,
        Q0L = CumBefore / N,
        Q1L = (CumBefore + ProposedL) / N,
        ( if k_scale(Delta, Q1L) - k_scale(Delta, Q0L) =< 1.0 then
            DistL = float.abs(LC ^ mean - NewC ^ mean),
            Result = yes(merge_candidate(LeftRest, LC, DistL))
        else
            Result = no
        )
    else
        Result = no
    ).

:- func check_right_neighbor(float, float, float,
    fingertree(td_measure, centroid), centroid) = maybe(merge_candidate).

check_right_neighbor(Delta, N, LeftWeight, Right, NewC) = Result :-
    ( if ft_viewl(Right, RC, RightRest) then
        ProposedR = RC ^ weight + NewC ^ weight,
        Q0R = LeftWeight / N,
        Q1R = (LeftWeight + ProposedR) / N,
        ( if k_scale(Delta, Q1R) - k_scale(Delta, Q0R) =< 1.0 then
            DistR = float.abs(RC ^ mean - NewC ^ mean),
            Result = yes(merge_candidate(RightRest, RC, DistR))
        else
            Result = no
        )
    else
        Result = no
    ).

%-----------------------------------------------------------------------------%
% Compression - O(delta * log n) split-based
%-----------------------------------------------------------------------------%

compress(TD0) = TD :-
    Cs = TD0 ^ centroids,
    Cnt = ft_size(Cs),
    ( if Cnt =< 1 then
        TD = TD0
    else
        N = TD0 ^ total_weight,
        Delta = TD0 ^ delta,
        KMin = k_scale(Delta, 0.0),
        KMax = k_scale(Delta, 1.0),
        JMin = ceiling_to_int(KMin),
        JMax = floor_to_int(KMax),
        boundaries(Delta, N, JMin + 1, JMax, [], Bounds),
        split_merge(Bounds, Cs, ft_empty, Merged),
        TD = tdigest(Delta, Merged, N, TD0 ^ td_min, TD0 ^ td_max,
                     TD0 ^ max_centroids)
    ).

:- pred boundaries(float::in, float::in, int::in, int::in,
    list(float)::in, list(float)::out) is det.

boundaries(Delta, N, J, JMax, !Acc) :-
    ( if J > JMax then
        list.reverse(!Acc)
    else
        B = k_scale_inv(Delta, float(J)) * N,
        boundaries(Delta, N, J + 1, JMax, [B | !.Acc], !:Acc)
    ).

:- pred split_merge(list(float)::in,
    fingertree(td_measure, centroid)::in,
    fingertree(td_measure, centroid)::in,
    fingertree(td_measure, centroid)::out) is det.

split_merge([], Remaining, Acc, Result) :-
    merge_chunk(Remaining, MaybeC),
    (
        MaybeC = yes(C),
        Result = ft_snoc(Acc, C)
    ;
        MaybeC = no,
        Result = Acc
    ).
split_merge([B | Bs], Remaining, Acc, Result) :-
    ( if ft_split(
            (pred(M::in) is semidet :- M ^ tm_weight > B),
            Remaining, ChunkPart, SplitC, RestPart)
    then
        % ChunkPart has cumulative weight <= B.
        % SplitC and RestPart form the rest.
        Chunk = ChunkPart,
        Rest = ft_cons(SplitC, RestPart)
    else
        % All remaining weight <= B; everything goes in this chunk.
        Chunk = Remaining,
        Rest = ft_empty
    ),
    merge_chunk(Chunk, MaybeC),
    (
        MaybeC = yes(C),
        split_merge(Bs, Rest, ft_snoc(Acc, C), Result)
    ;
        MaybeC = no,
        split_merge(Bs, Rest, Acc, Result)
    ).

:- pred merge_chunk(fingertree(td_measure, centroid)::in,
    maybe(centroid)::out) is det.

merge_chunk(FT, Result) :-
    M = ft_measure(FT),
    W = M ^ tm_weight,
    ( if W > 0.0 then
        MWS = M ^ tm_mean_weight_sum,
        Result = yes(centroid(MWS / W, W))
    else
        Result = no
    ).

%-----------------------------------------------------------------------------%
% Quantile estimation using ft_split for O(log n) lookup
%-----------------------------------------------------------------------------%

quantile(TD, Q) = Value :-
    Cs = TD ^ centroids,
    ( if ft_null(Cs) then
        Value = 0.0
    else if Cs = ft_single(Only) then
        Value = Only ^ mean
    else
        QClamped = float.max(0.0, float.min(1.0, Q)),
        N = TD ^ total_weight,
        Target = QClamped * N,
        Min = TD ^ td_min,
        Max = TD ^ td_max,
        NumCentroids = ft_size(Cs),
        ( if ft_split(
                (pred(M::in) is semidet :- M ^ tm_weight > Target),
                Cs, LeftTree, SplitC, RightTree)
        then
            LeftCount = ft_size(LeftTree),
            Cumulative = (ft_measure(LeftTree)) ^ tm_weight,
            quantile_at(SplitC, LeftCount, NumCentroids,
                Cumulative, Target, N, Min, Max,
                LeftTree, RightTree, Value)
        else
            % Target exceeds total weight - return max.
            ( if ft_viewr(Cs, _, LastC) then
                Value = LastC ^ mean
            else
                Value = Max
            )
        )
    ).

:- pred quantile_at(centroid::in, int::in, int::in,
    float::in, float::in, float::in, float::in, float::in,
    fingertree(td_measure, centroid)::in,
    fingertree(td_measure, centroid)::in, float::out) is det.

quantile_at(C, I, NumCentroids, Cumulative, Target, N, Min, Max,
        _LeftTree, RightTree, Value) :-
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
        ( if ft_viewl(RightTree, NextC, _) then
            Mid = Cumulative + HalfW,
            NextMid = Cumulative + C ^ weight + NextC ^ weight / 2.0,
            ( if NextMid = Mid then
                Frac = 0.5
            else
                Frac = (Target - Mid) / (NextMid - Mid)
            ),
            Value = C ^ mean + Frac * (NextC ^ mean - C ^ mean)
        else
            Value = C ^ mean
        )
    ).

%-----------------------------------------------------------------------------%
% CDF estimation using ft_split_by_mean for O(log n) lookup
%-----------------------------------------------------------------------------%

cdf(TD, X) = Q :-
    Cs = TD ^ centroids,
    N = TD ^ total_weight,
    Min = TD ^ td_min,
    Max = TD ^ td_max,
    ( if ft_null(Cs) then
        Q = 0.0
    else if X =< Min then
        Q = 0.0
    else if X >= Max then
        Q = 1.0
    else
        NumCentroids = ft_size(Cs),
        ft_split_by_mean(X, Cs) = {LeftPart, RightPart},
        ( if ft_viewr(LeftPart, LRest, LC),
             ft_viewl(RightPart, RC, _)
        then
            LcCum = (ft_measure(LRest)) ^ tm_weight,
            LcIdx = ft_size(LRest),
            RcIdx = ft_size(LeftPart),
            ( if X =< LC ^ mean then
                ( if LcIdx = 0 then
                    Q = cdf_at_first(LC, X, Min, N)
                else
                    ( if ft_viewr(LRest, LLRest, LLC) then
                        LLCum = (ft_measure(LLRest)) ^ tm_weight,
                        Q = cdf_between(LLC, LLCum, LC, LcCum, X, N)
                    else
                        Q = cdf_at_first(LC, X, Min, N)
                    )
                )
            else
                ( if RcIdx = NumCentroids - 1, X > RC ^ mean then
                    RcCum = (ft_measure(LeftPart)) ^ tm_weight,
                    Q = cdf_at_last(RC, RcCum, X, Max, N)
                else
                    RcCum = (ft_measure(LeftPart)) ^ tm_weight,
                    Q = cdf_between(LC, LcCum, RC, RcCum, X, N)
                )
            )
        else if ft_null(LeftPart), ft_viewl(RightPart, RC2, _) then
            Q = cdf_at_first(RC2, X, Min, N)
        else if ft_viewr(LeftPart, LRest2, LC2), ft_null(RightPart) then
            LC2Cum = (ft_measure(LRest2)) ^ tm_weight,
            Q = cdf_at_last(LC2, LC2Cum, X, Max, N)
        else
            Q = 1.0
        )
    ).

:- func cdf_at_first(centroid, float, float, float) = float.

cdf_at_first(C, X, Min, N) = Q :-
    ( if X < C ^ mean then
        InnerW = C ^ weight / 2.0,
        ( if C ^ mean = Min then
            Frac = 1.0
        else
            Frac = (X - Min) / (C ^ mean - Min)
        ),
        Q = (InnerW * Frac) / N
    else
        Q = (C ^ weight / 2.0) / N
    ).

:- func cdf_at_last(centroid, float, float, float, float) = float.

cdf_at_last(C, CumBefore, X, Max, N) = Q :-
    ( if X > C ^ mean then
        HalfW = C ^ weight / 2.0,
        RightW = N - CumBefore - HalfW,
        ( if Max = C ^ mean then
            Frac = 0.0
        else
            Frac = (X - C ^ mean) / (Max - C ^ mean)
        ),
        Q = (CumBefore + HalfW + RightW * Frac) / N
    else
        Q = (CumBefore + C ^ weight / 2.0) / N
    ).

:- func cdf_between(centroid, float, centroid, float, float, float) = float.

cdf_between(LC, LcCum, RC, RcCum, X, N) = Q :-
    ( if X =< LC ^ mean then
        Q = (LcCum + LC ^ weight / 2.0) / N
    else if X >= RC ^ mean then
        Q = (RcCum + RC ^ weight / 2.0) / N
    else
        LMid = LcCum + LC ^ weight / 2.0,
        RMid = RcCum + RC ^ weight / 2.0,
        ( if LC ^ mean = RC ^ mean then
            Frac = 0.5
        else
            Frac = (X - LC ^ mean) / (RC ^ mean - LC ^ mean)
        ),
        Q = (LMid + Frac * (RMid - LMid)) / N
    ).

%-----------------------------------------------------------------------------%
% Merge two digests
%-----------------------------------------------------------------------------%

merge_digests(TD1, TD2) = TDOut :-
    OtherCs = ft_to_list(TD2 ^ centroids),
    Combined = list.foldl(
        (func(C::in, Acc::in) = (Out::out) is det :-
            Out = add(Acc, C ^ mean, C ^ weight)),
        OtherCs, TD1),
    TDOut = compress(Combined).

%-----------------------------------------------------------------------------%
% Centroid count
%-----------------------------------------------------------------------------%

centroid_count(TD) = ft_size(TD ^ centroids).

%-----------------------------------------------------------------------------%
:- end_module tdigest.
%-----------------------------------------------------------------------------%
