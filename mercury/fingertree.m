%-----------------------------------------------------------------------------%
% fingertree.m
%
% A finger tree specialized for t-digest centroids, measured by
% (total_weight, count). Based on Hinze & Paterson's design.
%
% Provides O(1) amortized cons/snoc, O(log n) split by accumulated
% measure, and O(1) cached measure access.
%
% This implementation uses two levels of nesting (sufficient for
% thousands of elements), with the inner tree stored as a flat list
% to avoid infinite type recursion in Mercury.
%-----------------------------------------------------------------------------%

:- module fingertree.
:- interface.

:- import_module float.
:- import_module int.
:- import_module list.

%-----------------------------------------------------------------------------%
% Measure type
%-----------------------------------------------------------------------------%

:- type td_measure
    --->    td_measure(
                tm_weight :: float,
                tm_count  :: int
            ).

:- func measure_empty = td_measure.
:- func measure_append(td_measure, td_measure) = td_measure.

%-----------------------------------------------------------------------------%
% Centroid type (re-exported for use by tdigest)
%-----------------------------------------------------------------------------%

:- type centroid
    --->    centroid(mean :: float, weight :: float).

:- func centroid_measure(centroid) = td_measure.

%-----------------------------------------------------------------------------%
% Finger tree types
%-----------------------------------------------------------------------------%

:- type fingertree
    --->    ft_empty
    ;       ft_single(centroid)
    ;       ft_deep(td_measure, digit, fingertree2, digit).

    % Level-2 finger tree (stores node values).
:- type fingertree2
    --->    ft2_empty
    ;       ft2_single(node)
    ;       ft2_deep(td_measure, digit2, list(node2), digit2).

:- type digit
    --->    one(centroid)
    ;       two(centroid, centroid)
    ;       three(centroid, centroid, centroid)
    ;       four(centroid, centroid, centroid, centroid).

:- type node
    --->    node2(td_measure, centroid, centroid)
    ;       node3(td_measure, centroid, centroid, centroid).

    % Level-2 digit (of nodes).
:- type digit2
    --->    one2(node)
    ;       two2(node, node)
    ;       three2(node, node, node)
    ;       four2(node, node, node, node).

    % Level-2 node (of nodes).
:- type node2
    --->    node2_2(td_measure, node, node)
    ;       node2_3(td_measure, node, node, node).

%-----------------------------------------------------------------------------%
% Operations
%-----------------------------------------------------------------------------%

    % Get the cached measure of a tree in O(1).
:- func ft_measure(fingertree) = td_measure.

    % Prepend an element (O(1) amortized).
:- func ft_cons(centroid, fingertree) = fingertree.

    % Append an element (O(1) amortized).
:- func ft_snoc(fingertree, centroid) = fingertree.

    % Build a finger tree from a list.
:- func ft_from_list(list(centroid)) = fingertree.

    % Convert a finger tree to a sorted list (in-order traversal).
:- func ft_to_list(fingertree) = list(centroid).

    % Test if the tree is empty.
:- pred ft_null(fingertree::in) is semidet.

    % Get the count of elements from the measure in O(1).
:- func ft_size(fingertree) = int.

    % Split tree where Pred(accumulated_measure) first becomes true.
    % ft_split(Pred, Tree, Left, X, Right).
    % Fails if tree is empty or Pred never becomes true.
:- pred ft_split(pred(td_measure)::in(pred(in) is semidet),
    fingertree::in, fingertree::out, centroid::out, fingertree::out)
    is semidet.

    % View leftmost element. Fails if empty.
:- pred ft_viewl(fingertree::in, centroid::out, fingertree::out) is semidet.

    % View rightmost element. Fails if empty.
:- pred ft_viewr(fingertree::in, fingertree::out, centroid::out) is semidet.

    % Concatenate two trees.
:- func ft_concat(fingertree, fingertree) = fingertree.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module require.

%-----------------------------------------------------------------------------%
% Measure operations
%-----------------------------------------------------------------------------%

measure_empty = td_measure(0.0, 0).

measure_append(td_measure(W1, C1), td_measure(W2, C2)) =
    td_measure(W1 + W2, C1 + C2).

centroid_measure(centroid(_, W)) = td_measure(W, 1).

%-----------------------------------------------------------------------------%
% Measure helpers for digits and nodes
%-----------------------------------------------------------------------------%

:- func digit_measure(digit) = td_measure.

digit_measure(one(A)) = centroid_measure(A).
digit_measure(two(A, B)) =
    measure_append(centroid_measure(A), centroid_measure(B)).
digit_measure(three(A, B, C)) =
    measure_append(centroid_measure(A),
        measure_append(centroid_measure(B), centroid_measure(C))).
digit_measure(four(A, B, C, D)) =
    measure_append(
        measure_append(centroid_measure(A), centroid_measure(B)),
        measure_append(centroid_measure(C), centroid_measure(D))).

:- func node_measure(node) = td_measure.

node_measure(node2(M, _, _)) = M.
node_measure(node3(M, _, _, _)) = M.

:- func make_node2(centroid, centroid) = node.

make_node2(A, B) = node2(measure_append(centroid_measure(A),
    centroid_measure(B)), A, B).

:- func make_node3(centroid, centroid, centroid) = node.

make_node3(A, B, C) = node3(
    measure_append(centroid_measure(A),
        measure_append(centroid_measure(B), centroid_measure(C))),
    A, B, C).

%-----------------------------------------------------------------------------%
% Level-2 measure helpers
%-----------------------------------------------------------------------------%

:- func digit2_measure(digit2) = td_measure.

digit2_measure(one2(A)) = node_measure(A).
digit2_measure(two2(A, B)) =
    measure_append(node_measure(A), node_measure(B)).
digit2_measure(three2(A, B, C)) =
    measure_append(node_measure(A),
        measure_append(node_measure(B), node_measure(C))).
digit2_measure(four2(A, B, C, D)) =
    measure_append(
        measure_append(node_measure(A), node_measure(B)),
        measure_append(node_measure(C), node_measure(D))).

:- func node2_measure(node2) = td_measure.

node2_measure(node2_2(M, _, _)) = M.
node2_measure(node2_3(M, _, _, _)) = M.

:- func make_node2_2(node, node) = node2.

make_node2_2(A, B) = node2_2(measure_append(node_measure(A),
    node_measure(B)), A, B).

:- func make_node2_3(node, node, node) = node2.

make_node2_3(A, B, C) = node2_3(
    measure_append(node_measure(A),
        measure_append(node_measure(B), node_measure(C))),
    A, B, C).

:- func node2_list_measure(list(node2)) = td_measure.

node2_list_measure([]) = measure_empty.
node2_list_measure([N | Ns]) =
    measure_append(node2_measure(N), node2_list_measure(Ns)).

%-----------------------------------------------------------------------------%
% ft_measure
%-----------------------------------------------------------------------------%

ft_measure(ft_empty) = measure_empty.
ft_measure(ft_single(A)) = centroid_measure(A).
ft_measure(ft_deep(M, _, _, _)) = M.

:- func ft2_measure(fingertree2) = td_measure.

ft2_measure(ft2_empty) = measure_empty.
ft2_measure(ft2_single(A)) = node_measure(A).
ft2_measure(ft2_deep(M, _, _, _)) = M.

%-----------------------------------------------------------------------------%
% Smart constructor for deep
%-----------------------------------------------------------------------------%

:- func deep(digit, fingertree2, digit) = fingertree.

deep(L, M, R) = ft_deep(
    measure_append(digit_measure(L),
        measure_append(ft2_measure(M), digit_measure(R))),
    L, M, R).

:- func deep2(digit2, list(node2), digit2) = fingertree2.

deep2(L, M, R) = ft2_deep(
    measure_append(digit2_measure(L),
        measure_append(node2_list_measure(M), digit2_measure(R))),
    L, M, R).

%-----------------------------------------------------------------------------%
% ft_cons
%-----------------------------------------------------------------------------%

ft_cons(A, ft_empty) = ft_single(A).
ft_cons(A, ft_single(B)) = deep(one(A), ft2_empty, one(B)).
ft_cons(A, ft_deep(_, one(B), M, R)) = deep(two(A, B), M, R).
ft_cons(A, ft_deep(_, two(B, C), M, R)) = deep(three(A, B, C), M, R).
ft_cons(A, ft_deep(_, three(B, C, D), M, R)) = deep(four(A, B, C, D), M, R).
ft_cons(A, ft_deep(_, four(B, C, D, E), M, R)) =
    deep(two(A, B), ft2_cons(make_node3(C, D, E), M), R).

:- func ft2_cons(node, fingertree2) = fingertree2.

ft2_cons(A, ft2_empty) = ft2_single(A).
ft2_cons(A, ft2_single(B)) = deep2(one2(A), [], one2(B)).
ft2_cons(A, ft2_deep(_, one2(B), M, R)) = deep2(two2(A, B), M, R).
ft2_cons(A, ft2_deep(_, two2(B, C), M, R)) = deep2(three2(A, B, C), M, R).
ft2_cons(A, ft2_deep(_, three2(B, C, D), M, R)) =
    deep2(four2(A, B, C, D), M, R).
ft2_cons(A, ft2_deep(_, four2(B, C, D, E), M, R)) =
    deep2(two2(A, B), [make_node2_3(C, D, E) | M], R).

%-----------------------------------------------------------------------------%
% ft_snoc
%-----------------------------------------------------------------------------%

ft_snoc(ft_empty, A) = ft_single(A).
ft_snoc(ft_single(B), A) = deep(one(B), ft2_empty, one(A)).
ft_snoc(ft_deep(_, L, M, one(B)), A) = deep(L, M, two(B, A)).
ft_snoc(ft_deep(_, L, M, two(B, C)), A) = deep(L, M, three(B, C, A)).
ft_snoc(ft_deep(_, L, M, three(B, C, D)), A) = deep(L, M, four(B, C, D, A)).
ft_snoc(ft_deep(_, L, M, four(B, C, D, E)), A) =
    deep(L, ft2_snoc(M, make_node3(B, C, D)), two(E, A)).

:- func ft2_snoc(fingertree2, node) = fingertree2.

ft2_snoc(ft2_empty, A) = ft2_single(A).
ft2_snoc(ft2_single(B), A) = deep2(one2(B), [], one2(A)).
ft2_snoc(ft2_deep(_, L, M, one2(B)), A) = deep2(L, M, two2(B, A)).
ft2_snoc(ft2_deep(_, L, M, two2(B, C)), A) = deep2(L, M, three2(B, C, A)).
ft2_snoc(ft2_deep(_, L, M, three2(B, C, D)), A) =
    deep2(L, M, four2(B, C, D, A)).
ft2_snoc(ft2_deep(_, L, M, four2(B, C, D, E)), A) =
    deep2(L, M ++ [make_node2_3(B, C, D)], two2(E, A)).

%-----------------------------------------------------------------------------%
% ft_from_list / ft_to_list
%-----------------------------------------------------------------------------%

ft_from_list(Xs) = list.foldl(func(X, T) = ft_snoc(T, X), Xs, ft_empty).

ft_to_list(T) = ft_to_list_acc(T, []).

:- func ft_to_list_acc(fingertree, list(centroid)) = list(centroid).

ft_to_list_acc(ft_empty, Acc) = Acc.
ft_to_list_acc(ft_single(A), Acc) = [A | Acc].
ft_to_list_acc(ft_deep(_, L, M, R), Acc) =
    digit_to_list(L, node_tree_to_list(M, digit_to_list(R, Acc))).

:- func digit_to_list(digit, list(centroid)) = list(centroid).

digit_to_list(one(A), Acc) = [A | Acc].
digit_to_list(two(A, B), Acc) = [A, B | Acc].
digit_to_list(three(A, B, C), Acc) = [A, B, C | Acc].
digit_to_list(four(A, B, C, D), Acc) = [A, B, C, D | Acc].

:- func node_tree_to_list(fingertree2, list(centroid)) = list(centroid).

node_tree_to_list(ft2_empty, Acc) = Acc.
node_tree_to_list(ft2_single(N), Acc) = node_to_list(N, Acc).
node_tree_to_list(ft2_deep(_, L, M, R), Acc) =
    digit2_to_list(L, node2_list_to_list(M, digit2_to_list(R, Acc))).

:- func node_to_list(node, list(centroid)) = list(centroid).

node_to_list(node2(_, A, B), Acc) = [A, B | Acc].
node_to_list(node3(_, A, B, C), Acc) = [A, B, C | Acc].

:- func digit2_to_list(digit2, list(centroid)) = list(centroid).

digit2_to_list(one2(A), Acc) = node_to_list(A, Acc).
digit2_to_list(two2(A, B), Acc) = node_to_list(A, node_to_list(B, Acc)).
digit2_to_list(three2(A, B, C), Acc) =
    node_to_list(A, node_to_list(B, node_to_list(C, Acc))).
digit2_to_list(four2(A, B, C, D), Acc) =
    node_to_list(A, node_to_list(B, node_to_list(C, node_to_list(D, Acc)))).

:- func node2_to_list(node2, list(centroid)) = list(centroid).

node2_to_list(node2_2(_, A, B), Acc) = node_to_list(A, node_to_list(B, Acc)).
node2_to_list(node2_3(_, A, B, C), Acc) =
    node_to_list(A, node_to_list(B, node_to_list(C, Acc))).

:- func node2_list_to_list(list(node2), list(centroid)) = list(centroid).

node2_list_to_list([], Acc) = Acc.
node2_list_to_list([N | Ns], Acc) =
    node2_to_list(N, node2_list_to_list(Ns, Acc)).

%-----------------------------------------------------------------------------%
% ft_null / ft_size
%-----------------------------------------------------------------------------%

ft_null(ft_empty).

ft_size(T) = ft_measure(T) ^ tm_count.

%-----------------------------------------------------------------------------%
% ft_viewl / ft_viewr
%-----------------------------------------------------------------------------%

ft_viewl(ft_single(A), A, ft_empty).
ft_viewl(ft_deep(_, L, M, R), Head, Rest) :-
    (
        L = one(A),
        Head = A,
        ( if ft2_viewl(M, N, M2) then
            Rest = deep(node_to_digit(N), M2, R)
        else
            Rest = digit_to_tree(R)
        )
    ;
        L = two(A, B),
        Head = A,
        Rest = deep(one(B), M, R)
    ;
        L = three(A, B, C),
        Head = A,
        Rest = deep(two(B, C), M, R)
    ;
        L = four(A, B, C, D),
        Head = A,
        Rest = deep(three(B, C, D), M, R)
    ).

:- pred ft2_viewl(fingertree2::in, node::out, fingertree2::out) is semidet.

ft2_viewl(ft2_single(A), A, ft2_empty).
ft2_viewl(ft2_deep(_, L, M, R), Head, Rest) :-
    (
        L = one2(A),
        Head = A,
        ( if M = [N | Ms] then
            Rest = deep2(node2_to_digit2(N), Ms, R)
        else
            Rest = digit2_to_tree2(R)
        )
    ;
        L = two2(A, B),
        Head = A,
        Rest = deep2(one2(B), M, R)
    ;
        L = three2(A, B, C),
        Head = A,
        Rest = deep2(two2(B, C), M, R)
    ;
        L = four2(A, B, C, D),
        Head = A,
        Rest = deep2(three2(B, C, D), M, R)
    ).

ft_viewr(ft_single(A), ft_empty, A).
ft_viewr(ft_deep(_, L, M, R), Rest, Last) :-
    (
        R = one(A),
        Last = A,
        ( if ft2_viewr(M, M2, N) then
            Rest = deep(L, M2, node_to_digit(N))
        else
            Rest = digit_to_tree(L)
        )
    ;
        R = two(A, B),
        Last = B,
        Rest = deep(L, M, one(A))
    ;
        R = three(A, B, C),
        Last = C,
        Rest = deep(L, M, two(A, B))
    ;
        R = four(A, B, C, D),
        Last = D,
        Rest = deep(L, M, three(A, B, C))
    ).

:- pred ft2_viewr(fingertree2::in, fingertree2::out, node::out) is semidet.

ft2_viewr(ft2_single(A), ft2_empty, A).
ft2_viewr(ft2_deep(_, L, M, R), Rest, Last) :-
    (
        R = one2(A),
        Last = A,
        ( if list.split_last(M, Ms, N) then
            Rest = deep2(L, Ms, node2_to_digit2(N))
        else
            Rest = digit2_to_tree2(L)
        )
    ;
        R = two2(A, B),
        Last = B,
        Rest = deep2(L, M, one2(A))
    ;
        R = three2(A, B, C),
        Last = C,
        Rest = deep2(L, M, two2(A, B))
    ;
        R = four2(A, B, C, D),
        Last = D,
        Rest = deep2(L, M, three2(A, B, C))
    ).

%-----------------------------------------------------------------------------%
% Conversion helpers
%-----------------------------------------------------------------------------%

:- func node_to_digit(node) = digit.

node_to_digit(node2(_, A, B)) = two(A, B).
node_to_digit(node3(_, A, B, C)) = three(A, B, C).

:- func digit_to_tree(digit) = fingertree.

digit_to_tree(one(A)) = ft_single(A).
digit_to_tree(two(A, B)) = deep(one(A), ft2_empty, one(B)).
digit_to_tree(three(A, B, C)) = deep(two(A, B), ft2_empty, one(C)).
digit_to_tree(four(A, B, C, D)) = deep(two(A, B), ft2_empty, two(C, D)).

:- func node2_to_digit2(node2) = digit2.

node2_to_digit2(node2_2(_, A, B)) = two2(A, B).
node2_to_digit2(node2_3(_, A, B, C)) = three2(A, B, C).

:- func digit2_to_tree2(digit2) = fingertree2.

digit2_to_tree2(one2(A)) = ft2_single(A).
digit2_to_tree2(two2(A, B)) = deep2(one2(A), [], one2(B)).
digit2_to_tree2(three2(A, B, C)) = deep2(two2(A, B), [], one2(C)).
digit2_to_tree2(four2(A, B, C, D)) = deep2(two2(A, B), [], two2(C, D)).

%-----------------------------------------------------------------------------%
% ft_split
%
% Split the tree where predicate on accumulated measure first becomes true.
% Returns (Left, Element, Right) where Left contains all elements before
% the split point.
%-----------------------------------------------------------------------------%

ft_split(Pred, Tree, Left, X, Right) :-
    Tree \= ft_empty,
    Pred(ft_measure(Tree)),
    split_tree(Pred, measure_empty, Tree, Left, X, Right).

:- pred split_tree(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, fingertree::in,
    fingertree::out, centroid::out, fingertree::out) is det.

split_tree(_, _, ft_empty, _, _, _) :-
    error("split_tree: empty").
split_tree(_, _, ft_single(A), ft_empty, A, ft_empty).
split_tree(Pred, Acc, ft_deep(_, L, M, R), Left, X, Right) :-
    AccL = measure_append(Acc, digit_measure(L)),
    ( if Pred(AccL) then
        % Split is in the left digit.
        split_digit(Pred, Acc, L, Before, X, After),
        Left = list_to_tree(Before),
        Right = deepl(After, M, R)
    else
        AccLM = measure_append(AccL, ft2_measure(M)),
        ( if Pred(AccLM) then
            % Split is in the middle tree.
            split_tree2(Pred, AccL, M, ML, Node, MR),
            % Now split within the node.
            split_node(Pred,
                measure_append(AccL, ft2_measure(ML)),
                Node, Before, X, After),
            Left = deepr(L, ML, Before),
            Right = deepl(After, MR, R)
        else
            % Split is in the right digit.
            split_digit(Pred, AccLM, R, Before, X, After),
            Left = deepr(L, M, Before),
            Right = list_to_tree(After)
        )
    ).

:- pred split_tree2(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, fingertree2::in,
    fingertree2::out, node::out, fingertree2::out) is det.

split_tree2(_, _, ft2_empty, _, _, _) :-
    error("split_tree2: empty").
split_tree2(_, _, ft2_single(A), ft2_empty, A, ft2_empty).
split_tree2(Pred, Acc, ft2_deep(_, L, M, R), Left, X, Right) :-
    AccL = measure_append(Acc, digit2_measure(L)),
    ( if Pred(AccL) then
        split_digit2(Pred, Acc, L, Before, X, After),
        Left = list2_to_tree2(Before),
        Right = deepl2(After, M, R)
    else
        AccLM = measure_append(AccL, node2_list_measure(M)),
        ( if Pred(AccLM) then
            split_node2_list(Pred, AccL, M, MBefore, Node2, MAfter),
            split_node2(Pred,
                measure_append(AccL,
                    node2_list_measure(MBefore)),
                Node2, Before, X, After),
            Left = deepr2(L, MBefore, Before),
            Right = deepl2(After, MAfter, R)
        else
            split_digit2(Pred, AccLM, R, Before, X, After),
            Left = deepr2(L, M, Before),
            Right = list2_to_tree2(After)
        )
    ).

:- pred split_node2_list(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, list(node2)::in,
    list(node2)::out, node2::out, list(node2)::out) is det.

split_node2_list(_, _, [], _, _, _) :-
    error("split_node2_list: empty").
split_node2_list(Pred, Acc, [N | Ns], Before, X, After) :-
    AccN = measure_append(Acc, node2_measure(N)),
    ( if Pred(AccN) then
        Before = [], X = N, After = Ns
    else
        split_node2_list(Pred, AccN, Ns, Before0, X, After),
        Before = [N | Before0]
    ).

%-----------------------------------------------------------------------------%
% Split within digits
%-----------------------------------------------------------------------------%

:- pred split_digit(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, digit::in,
    list(centroid)::out, centroid::out, list(centroid)::out) is det.

split_digit(_, _, one(A), [], A, []).
split_digit(Pred, Acc, two(A, B), Before, X, After) :-
    AccA = measure_append(Acc, centroid_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B]
    else
        Before = [A], X = B, After = []
    ).
split_digit(Pred, Acc, three(A, B, C), Before, X, After) :-
    AccA = measure_append(Acc, centroid_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C]
    else
        AccB = measure_append(AccA, centroid_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C]
        else
            Before = [A, B], X = C, After = []
        )
    ).
split_digit(Pred, Acc, four(A, B, C, D), Before, X, After) :-
    AccA = measure_append(Acc, centroid_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C, D]
    else
        AccB = measure_append(AccA, centroid_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C, D]
        else
            AccC = measure_append(AccB, centroid_measure(C)),
            ( if Pred(AccC) then
                Before = [A, B], X = C, After = [D]
            else
                Before = [A, B, C], X = D, After = []
            )
        )
    ).

:- pred split_digit2(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, digit2::in,
    list(node)::out, node::out, list(node)::out) is det.

split_digit2(_, _, one2(A), [], A, []).
split_digit2(Pred, Acc, two2(A, B), Before, X, After) :-
    AccA = measure_append(Acc, node_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B]
    else
        Before = [A], X = B, After = []
    ).
split_digit2(Pred, Acc, three2(A, B, C), Before, X, After) :-
    AccA = measure_append(Acc, node_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C]
    else
        AccB = measure_append(AccA, node_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C]
        else
            Before = [A, B], X = C, After = []
        )
    ).
split_digit2(Pred, Acc, four2(A, B, C, D), Before, X, After) :-
    AccA = measure_append(Acc, node_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C, D]
    else
        AccB = measure_append(AccA, node_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C, D]
        else
            AccC = measure_append(AccB, node_measure(C)),
            ( if Pred(AccC) then
                Before = [A, B], X = C, After = [D]
            else
                Before = [A, B, C], X = D, After = []
            )
        )
    ).

%-----------------------------------------------------------------------------%
% Split within nodes
%-----------------------------------------------------------------------------%

:- pred split_node(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, node::in,
    list(centroid)::out, centroid::out, list(centroid)::out) is det.

split_node(Pred, Acc, node2(_, A, B), Before, X, After) :-
    AccA = measure_append(Acc, centroid_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B]
    else
        Before = [A], X = B, After = []
    ).
split_node(Pred, Acc, node3(_, A, B, C), Before, X, After) :-
    AccA = measure_append(Acc, centroid_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C]
    else
        AccB = measure_append(AccA, centroid_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C]
        else
            Before = [A, B], X = C, After = []
        )
    ).

:- pred split_node2(pred(td_measure)::in(pred(in) is semidet),
    td_measure::in, node2::in,
    list(node)::out, node::out, list(node)::out) is det.

split_node2(Pred, Acc, node2_2(_, A, B), Before, X, After) :-
    AccA = measure_append(Acc, node_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B]
    else
        Before = [A], X = B, After = []
    ).
split_node2(Pred, Acc, node2_3(_, A, B, C), Before, X, After) :-
    AccA = measure_append(Acc, node_measure(A)),
    ( if Pred(AccA) then
        Before = [], X = A, After = [B, C]
    else
        AccB = measure_append(AccA, node_measure(B)),
        ( if Pred(AccB) then
            Before = [A], X = B, After = [C]
        else
            Before = [A, B], X = C, After = []
        )
    ).

%-----------------------------------------------------------------------------%
% Deep constructors with possibly-empty digit lists
%-----------------------------------------------------------------------------%

:- func deepl(list(centroid), fingertree2, digit) = fingertree.

deepl([], M, R) = T :-
    ( if ft2_viewl(M, N, M2) then
        T = deep(node_to_digit(N), M2, R)
    else
        T = digit_to_tree(R)
    ).
deepl([A], M, R) = deep(one(A), M, R).
deepl([A, B], M, R) = deep(two(A, B), M, R).
deepl([A, B, C], M, R) = deep(three(A, B, C), M, R).
deepl([A, B, C, D], M, R) = deep(four(A, B, C, D), M, R).
deepl([_, _, _, _, _ | _], _, _) = _ :-
    error("deepl: too many elements").

:- func deepr(digit, fingertree2, list(centroid)) = fingertree.

deepr(L, M, []) = T :-
    ( if ft2_viewr(M, M2, N) then
        T = deep(L, M2, node_to_digit(N))
    else
        T = digit_to_tree(L)
    ).
deepr(L, M, [A]) = deep(L, M, one(A)).
deepr(L, M, [A, B]) = deep(L, M, two(A, B)).
deepr(L, M, [A, B, C]) = deep(L, M, three(A, B, C)).
deepr(L, M, [A, B, C, D]) = deep(L, M, four(A, B, C, D)).
deepr(_, _, [_, _, _, _, _ | _]) = _ :-
    error("deepr: too many elements").

:- func deepl2(list(node), list(node2), digit2) = fingertree2.

deepl2([], M, R) = T :-
    ( if M = [N | Ms] then
        T = deep2(node2_to_digit2(N), Ms, R)
    else
        T = digit2_to_tree2(R)
    ).
deepl2([A], M, R) = deep2(one2(A), M, R).
deepl2([A, B], M, R) = deep2(two2(A, B), M, R).
deepl2([A, B, C], M, R) = deep2(three2(A, B, C), M, R).
deepl2([A, B, C, D], M, R) = deep2(four2(A, B, C, D), M, R).
deepl2([_, _, _, _, _ | _], _, _) = _ :-
    error("deepl2: too many elements").

:- func deepr2(digit2, list(node2), list(node)) = fingertree2.

deepr2(L, M, []) = T :-
    ( if list.split_last(M, Ms, N) then
        T = deep2(L, Ms, node2_to_digit2(N))
    else
        T = digit2_to_tree2(L)
    ).
deepr2(L, M, [A]) = deep2(L, M, one2(A)).
deepr2(L, M, [A, B]) = deep2(L, M, two2(A, B)).
deepr2(L, M, [A, B, C]) = deep2(L, M, three2(A, B, C)).
deepr2(L, M, [A, B, C, D]) = deep2(L, M, four2(A, B, C, D)).
deepr2(_, _, [_, _, _, _, _ | _]) = _ :-
    error("deepr2: too many elements").

%-----------------------------------------------------------------------------%
% List-to-tree helpers
%-----------------------------------------------------------------------------%

:- func list_to_tree(list(centroid)) = fingertree.

list_to_tree([]) = ft_empty.
list_to_tree([A]) = ft_single(A).
list_to_tree([A, B]) = deep(one(A), ft2_empty, one(B)).
list_to_tree([A, B, C]) = deep(two(A, B), ft2_empty, one(C)).
list_to_tree([A, B, C, D]) = deep(two(A, B), ft2_empty, two(C, D)).
list_to_tree([_, _, _, _, _ | _]) = _ :-
    error("list_to_tree: too many elements").

:- func list2_to_tree2(list(node)) = fingertree2.

list2_to_tree2([]) = ft2_empty.
list2_to_tree2([A]) = ft2_single(A).
list2_to_tree2([A, B]) = deep2(one2(A), [], one2(B)).
list2_to_tree2([A, B, C]) = deep2(two2(A, B), [], one2(C)).
list2_to_tree2([A, B, C, D]) = deep2(two2(A, B), [], two2(C, D)).
list2_to_tree2([_, _, _, _, _ | _]) = _ :-
    error("list2_to_tree2: too many elements").

%-----------------------------------------------------------------------------%
% ft_concat
%-----------------------------------------------------------------------------%

ft_concat(T1, T2) = app3(T1, [], T2).

:- func app3(fingertree, list(centroid), fingertree) = fingertree.

app3(T1, Xs, T2) = Result :-
    ( if T1 = ft_empty then
        Result = prepend_list(Xs, T2)
    else if T2 = ft_empty then
        Result = append_list(T1, Xs)
    else if T1 = ft_single(A) then
        Result = ft_cons(A, prepend_list(Xs, T2))
    else if T2 = ft_single(Z) then
        Result = ft_snoc(append_list(T1, Xs), Z)
    else if T1 = ft_deep(_, L1, M1, R1), T2 = ft_deep(_, L2, M2, R2) then
        Result = deep(L1,
            app3_2(M1,
                nodes(digit_to_centroid_list(R1) ++ Xs ++
                    digit_to_centroid_list(L2)),
                M2),
            R2)
    else
        error("app3: impossible")
    ).

:- func prepend_list(list(centroid), fingertree) = fingertree.

prepend_list([], T) = T.
prepend_list([X | Xs], T) = ft_cons(X, prepend_list(Xs, T)).

:- func append_list(fingertree, list(centroid)) = fingertree.

append_list(T, []) = T.
append_list(T, [X | Xs]) = append_list(ft_snoc(T, X), Xs).

:- func digit_to_centroid_list(digit) = list(centroid).

digit_to_centroid_list(one(A)) = [A].
digit_to_centroid_list(two(A, B)) = [A, B].
digit_to_centroid_list(three(A, B, C)) = [A, B, C].
digit_to_centroid_list(four(A, B, C, D)) = [A, B, C, D].

:- func nodes(list(centroid)) = list(node).

nodes(Xs) = Result :-
    (
        Xs = [],
        Result = []
    ;
        Xs = [_],
        error("nodes: odd element count")
    ;
        Xs = [A, B],
        Result = [make_node2(A, B)]
    ;
        Xs = [A, B, C],
        Result = [make_node3(A, B, C)]
    ;
        Xs = [A, B, C, D],
        Result = [make_node2(A, B), make_node2(C, D)]
    ;
        Xs = [A, B, C, D, E | Rest],
        Result = [make_node3(A, B, C) | nodes([D, E | Rest])]
    ).

:- func app3_2(fingertree2, list(node), fingertree2) = fingertree2.

app3_2(T1, Xs, T2) = Result :-
    ( if T1 = ft2_empty then
        Result = prepend_list2(Xs, T2)
    else if T2 = ft2_empty then
        Result = append_list2(T1, Xs)
    else if T1 = ft2_single(A) then
        Result = ft2_cons(A, prepend_list2(Xs, T2))
    else if T2 = ft2_single(Z) then
        Result = ft2_snoc(append_list2(T1, Xs), Z)
    else if T1 = ft2_deep(_, L1, M1, R1), T2 = ft2_deep(_, L2, M2, R2) then
        Result = deep2(L1,
            M1 ++ nodes2(digit2_to_node_list(R1) ++ Xs ++
                digit2_to_node_list(L2)) ++ M2,
            R2)
    else
        error("app3_2: impossible")
    ).

:- func prepend_list2(list(node), fingertree2) = fingertree2.

prepend_list2([], T) = T.
prepend_list2([X | Xs], T) = ft2_cons(X, prepend_list2(Xs, T)).

:- func append_list2(fingertree2, list(node)) = fingertree2.

append_list2(T, []) = T.
append_list2(T, [X | Xs]) = append_list2(ft2_snoc(T, X), Xs).

:- func digit2_to_node_list(digit2) = list(node).

digit2_to_node_list(one2(A)) = [A].
digit2_to_node_list(two2(A, B)) = [A, B].
digit2_to_node_list(three2(A, B, C)) = [A, B, C].
digit2_to_node_list(four2(A, B, C, D)) = [A, B, C, D].

:- func nodes2(list(node)) = list(node2).

nodes2(Xs) = Result :-
    (
        Xs = [],
        Result = []
    ;
        Xs = [_],
        error("nodes2: odd element count")
    ;
        Xs = [A, B],
        Result = [make_node2_2(A, B)]
    ;
        Xs = [A, B, C],
        Result = [make_node2_3(A, B, C)]
    ;
        Xs = [A, B, C, D],
        Result = [make_node2_2(A, B), make_node2_2(C, D)]
    ;
        Xs = [A, B, C, D, E | Rest],
        Result = [make_node2_3(A, B, C) | nodes2([D, E | Rest])]
    ).

%-----------------------------------------------------------------------------%
:- end_module fingertree.
%-----------------------------------------------------------------------------%
