%-----------------------------------------------------------------------------%
% measured_tree234.m
%
% A generic array-backed 2-3-4 tree with monoidal measures.
%
% Named "measured_tree234" to avoid clashing with Mercury's standard
% library "tree234" module.
%
% Type class parameters:
%   M - measure type (must be an instance of monoid/1)
%   K - key/element type (must be an instance of measured/2 and
%       has a comparison predicate passed to operations)
%
% Design:
%   - Array-backed node pool using Mercury's array module with free list
%   - Node: n (1-3 keys), keys (array of 3), children (array of 4), measure
%   - Four-component cached measure per node
%   - Top-down insertion (split 4-nodes on way down)
%   - Operations: insert, collect, find_by_weight, build_from_sorted, clear, size
%
% Uses the same type class pattern as fingertree.m:
%   typeclass monoid(M)
%   typeclass measured(M, A) <= monoid(M)
%
% Since the tree is mutable (array-backed), predicates use di/uo modes.
%-----------------------------------------------------------------------------%

:- module measured_tree234.
:- interface.

:- import_module array.
:- import_module float.
:- import_module int.
:- import_module list.

%-----------------------------------------------------------------------------%
% Type classes (re-export from fingertree for convenience, or define here)
%-----------------------------------------------------------------------------%

:- typeclass mt_monoid(M) where [
    func mt_mempty = M,
    func mt_mappend(M, M) = M
].

:- typeclass mt_measured(M, K) <= mt_monoid(M) where [
    func mt_measure(K) = M
].

%-----------------------------------------------------------------------------%
% Tree type
%-----------------------------------------------------------------------------%

    % An array-backed 2-3-4 tree with cached monoidal measures.
    %
:- type measured_tree(K, M)
    --->    measured_tree(
                mt_nodes     :: array(mt_node(K, M)),
                mt_free_list :: list(int),
                mt_root      :: int,          % -1 means empty
                mt_count     :: int           % number of elements
            ).

    % A node in the 2-3-4 tree.
    % n = number of keys (1, 2, or 3)
    % keys are stored in a 3-element array, children in a 4-element array.
    % children(i) = -1 means no child (leaf edge).
    %
:- type mt_node(K, M)
    --->    mt_node(
                mt_n          :: int,
                mt_keys       :: array(K),
                mt_children   :: array(int),
                mt_node_meas  :: M
            ).

    % Result from find_by_weight.
    %
:- type weight_result(K)
    --->    weight_result(
                wr_key        :: K,
                wr_cum_before :: float,
                wr_index      :: int,
                wr_found      :: bool
            ).

:- import_module bool.

%-----------------------------------------------------------------------------%
% Operations
%-----------------------------------------------------------------------------%

    % Create a new empty tree. Needs a dummy key for array initialization.
    %
:- pred mt_new(K::in, measured_tree(K, M)::uo) is det <= mt_measured(M, K).

    % Insert a key into the tree. The comparison predicate defines ordering.
    %
:- pred mt_insert(pred(K, K, comparison_result),
    K, measured_tree(K, M), measured_tree(K, M)) <= mt_measured(M, K).
:- mode mt_insert(in(pred(in, in, out) is det),
    in, di, uo) is det.

    % Get the number of elements.
    %
:- func mt_size(measured_tree(K, M)) = int.

    % Get the root measure (monoidal summary of all elements).
    %
:- func mt_root_measure(measured_tree(K, M)) = M <= mt_measured(M, K).

    % Collect all keys in-order into a list.
    %
:- pred mt_collect(measured_tree(K, M)::in, list(K)::out) is det.

    % Clear the tree (reset to empty).
    %
:- pred mt_clear(K::in, measured_tree(K, M)::di, measured_tree(K, M)::uo)
    is det <= mt_measured(M, K).

    % Build a balanced tree from a sorted list of keys.
    %
:- pred mt_build_from_sorted(K::in, list(K)::in,
    measured_tree(K, M)::uo) is det <= mt_measured(M, K).

    % Find element by cumulative weight. weight_of extracts the weight
    % component from a measure value.
    %
:- pred mt_find_by_weight(measured_tree(K, M)::in,
    float::in, (func(M) = float)::in,
    weight_result(K)::out) is det <= mt_measured(M, K).

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

:- import_module require.

%-----------------------------------------------------------------------------%
% Promise-unique helper
%-----------------------------------------------------------------------------%

:- func promise_unique_tree(measured_tree(K, M)) = measured_tree(K, M).
:- mode promise_unique_tree(in) = uo is det.

promise_unique_tree(T) = unsafe_promise_unique(T).

%-----------------------------------------------------------------------------%
% Node helpers
%-----------------------------------------------------------------------------%

:- func make_empty_node(K, M) = mt_node(K, M).

make_empty_node(DummyKey, Identity) = Node :-
    array.init(3, DummyKey, Keys),
    array.init(4, -1, Children),
    Node = mt_node(0, Keys, Children, Identity).

:- pred node_is_leaf(array(mt_node(K, M))::in, int::in) is semidet.

node_is_leaf(Nodes, Idx) :-
    array.lookup(Nodes, Idx, Node),
    array.lookup(Node ^ mt_children, 0, C0),
    C0 = -1.

:- pred node_is_4node(array(mt_node(K, M))::in, int::in) is semidet.

node_is_4node(Nodes, Idx) :-
    array.lookup(Nodes, Idx, Node),
    Node ^ mt_n = 3.

%-----------------------------------------------------------------------------%
% Alloc / free
%-----------------------------------------------------------------------------%

:- pred alloc_node(K::in, int::out,
    measured_tree(K, M)::di, measured_tree(K, M)::uo) is det
    <= mt_measured(M, K).

alloc_node(DummyKey, Idx, !Tree) :-
    !.Tree = measured_tree(Nodes0, FreeList0, Root, Count),
    Identity = mt_mempty : M,
    EmptyNode = make_empty_node(DummyKey, Identity),
    (
        FreeList0 = [FreeIdx | RestFree],
        Idx = FreeIdx,
        array.set(FreeIdx, EmptyNode,
            unsafe_promise_unique(Nodes0), Nodes1),
        !:Tree = promise_unique_tree(
            measured_tree(Nodes1, RestFree, Root, Count))
    ;
        FreeList0 = [],
        Idx = array.size(Nodes0),
        % Grow the array by one.
        NewSize = Idx + 1,
        array.resize(NewSize, EmptyNode,
            unsafe_promise_unique(Nodes0), Nodes1),
        !:Tree = promise_unique_tree(
            measured_tree(Nodes1, [], Root, Count))
    ).

%-----------------------------------------------------------------------------%
% Recompute measure
%-----------------------------------------------------------------------------%

:- pred recompute_measure(int::in,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo) is det
    <= mt_measured(M, K).

recompute_measure(Idx, !Nodes) :-
    array.lookup(!.Nodes, Idx, Node),
    N = Node ^ mt_n,
    Children = Node ^ mt_children,
    Keys = Node ^ mt_keys,
    recompute_measure_loop(0, N, Children, Keys, !.Nodes,
        mt_mempty : M, NewMeas),
    NewNode = Node ^ mt_node_meas := NewMeas,
    array.set(Idx, NewNode, !Nodes).

:- pred recompute_measure_loop(int::in, int::in, array(int)::in,
    array(K)::in, array(mt_node(K, M))::in, M::in, M::out) is det
    <= mt_measured(M, K).

recompute_measure_loop(I, N, Children, Keys, Nodes, !Acc) :-
    ( if I > N then
        true
    else
        array.lookup(Children, I, ChildIdx),
        ( if ChildIdx \= -1 then
            array.lookup(Nodes, ChildIdx, ChildNode),
            !:Acc = mt_mappend(!.Acc, ChildNode ^ mt_node_meas)
        else
            true
        ),
        ( if I < N then
            array.lookup(Keys, I, Key),
            !:Acc = mt_mappend(!.Acc, mt_measure(Key))
        else
            true
        ),
        recompute_measure_loop(I + 1, N, Children, Keys, Nodes, !Acc)
    ).

%-----------------------------------------------------------------------------%
% Split child (split a 4-node child at child_pos of parent)
%-----------------------------------------------------------------------------%

:- pred split_child(K::in, int::in, int::in,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo,
    list(int)::in, list(int)::out) is det
    <= mt_measured(M, K).

split_child(DummyKey, ParentIdx, ChildPos, !Nodes, !FreeList) :-
    array.lookup(!.Nodes, ParentIdx, ParentNode),
    array.lookup(ParentNode ^ mt_children, ChildPos, ChildIdx),

    % Save child data
    array.lookup(!.Nodes, ChildIdx, ChildNode),
    array.lookup(ChildNode ^ mt_keys, 0, K0),
    array.lookup(ChildNode ^ mt_keys, 1, K1),
    array.lookup(ChildNode ^ mt_keys, 2, K2),
    array.lookup(ChildNode ^ mt_children, 0, C0),
    array.lookup(ChildNode ^ mt_children, 1, C1),
    array.lookup(ChildNode ^ mt_children, 2, C2),
    array.lookup(ChildNode ^ mt_children, 3, C3),

    % Allocate right node
    Identity = mt_mempty : M,
    RightNode0 = make_empty_node(DummyKey, Identity),
    % We need to allocate from array or free list
    (
        !.FreeList = [FreeIdx | RestFree],
        RightIdx = FreeIdx,
        !:FreeList = RestFree,
        array.set(RightIdx, RightNode0, !Nodes)
    ;
        !.FreeList = [],
        RightIdx = array.size(!.Nodes),
        array.resize(RightIdx + 1, RightNode0, !Nodes)
    ),

    % Set right node: n=1, key=K2, children=C2,C3
    array.lookup(!.Nodes, RightIdx, RightNode1),
    array.set(0, K2, unsafe_promise_unique(RightNode1 ^ mt_keys), RKeys),
    array.set(0, C2, unsafe_promise_unique(RightNode1 ^ mt_children), RCh0),
    array.set(1, C3, RCh0, RCh1),
    RightNode2 = ((RightNode1 ^ mt_n := 1) ^ mt_keys := RKeys)
        ^ mt_children := RCh1,
    array.set(RightIdx, RightNode2, !Nodes),

    % Shrink child (left) to n=1, key=K0, children=C0,C1
    array.lookup(!.Nodes, ChildIdx, ChildNode2),
    array.set(0, K0, unsafe_promise_unique(ChildNode2 ^ mt_keys), LKeys),
    array.set(0, C0, unsafe_promise_unique(ChildNode2 ^ mt_children), LCh0),
    array.set(1, C1, LCh0, LCh1),
    array.set(2, -1, LCh1, LCh2),
    array.set(3, -1, LCh2, LCh3),
    LeftNode = ((ChildNode2 ^ mt_n := 1) ^ mt_keys := LKeys)
        ^ mt_children := LCh3,
    array.set(ChildIdx, LeftNode, !Nodes),

    % Recompute measures for left and right
    recompute_measure(ChildIdx, !Nodes),
    recompute_measure(RightIdx, !Nodes),

    % Insert K1 into parent at ChildPos
    array.lookup(!.Nodes, ParentIdx, PNode0),
    ParentN = PNode0 ^ mt_n,
    shift_parent_keys_children(ParentN, ChildPos, PNode0 ^ mt_keys,
        PNode0 ^ mt_children, PKeys, PCh),
    array.set(ChildPos, K1, PKeys, PKeys2),
    array.set(ChildPos + 1, RightIdx, PCh, PCh2),
    PNode1 = (((PNode0 ^ mt_n := ParentN + 1) ^ mt_keys := PKeys2)
        ^ mt_children := PCh2),
    array.set(ParentIdx, PNode1, !Nodes),

    recompute_measure(ParentIdx, !Nodes).

:- pred shift_parent_keys_children(int::in, int::in,
    array(K)::in, array(int)::in,
    array(K)::out, array(int)::out) is det.

shift_parent_keys_children(N, ChildPos, KeysIn, ChildrenIn, KeysOut, ChildrenOut) :-
    shift_keys_loop(N - 1, ChildPos, unsafe_promise_unique(KeysIn), KeysOut),
    shift_children_loop(N, ChildPos, unsafe_promise_unique(ChildrenIn), ChildrenOut).

:- pred shift_keys_loop(int::in, int::in,
    array(K)::array_di, array(K)::array_uo) is det.

shift_keys_loop(I, Stop, !Keys) :-
    ( if I >= Stop then
        array.lookup(!.Keys, I, K),
        array.set(I + 1, K, !Keys),
        ( if I > Stop then
            shift_keys_loop(I - 1, Stop, !Keys)
        else
            true
        )
    else
        true
    ).

:- pred shift_children_loop(int::in, int::in,
    array(int)::array_di, array(int)::array_uo) is det.

shift_children_loop(I, Stop, !Children) :-
    NewStop = Stop + 1,
    ( if I >= NewStop then
        array.lookup(!.Children, I, C),
        array.set(I + 1, C, !Children),
        ( if I > NewStop then
            shift_children_loop(I - 1, NewStop, !Children)
        else
            true
        )
    else
        true
    ).

%-----------------------------------------------------------------------------%
% Insert into non-full node
%-----------------------------------------------------------------------------%

:- pred insert_non_full(K, pred(K, K, comparison_result),
    int, K,
    array(mt_node(K, M)), array(mt_node(K, M)),
    list(int), list(int)) <= mt_measured(M, K).
:- mode insert_non_full(in,
    in(pred(in, in, out) is det),
    in, in, array_di, array_uo, in, out) is det.

insert_non_full(DummyKey, Compare, Idx, Key, !Nodes, !FreeList) :-
    ( if node_is_leaf(!.Nodes, Idx) then
        % Insert key in sorted position
        array.lookup(!.Nodes, Idx, Node0),
        N = Node0 ^ mt_n,
        find_insert_pos(Compare, Key, Node0 ^ mt_keys, N, Pos),
        shift_keys_for_insert(N - 1, Pos, unsafe_promise_unique(Node0 ^ mt_keys), Keys1),
        array.set(Pos, Key, Keys1, Keys2),
        Node1 = (Node0 ^ mt_n := N + 1) ^ mt_keys := Keys2,
        array.set(Idx, Node1, !Nodes),
        recompute_measure(Idx, !Nodes)
    else
        % Find child to descend into
        array.lookup(!.Nodes, Idx, Node0),
        N = Node0 ^ mt_n,
        find_child_pos(Compare, Key, Node0 ^ mt_keys, N, 0, ChildPos),

        % Get child index
        array.lookup(Node0 ^ mt_children, ChildPos, ChildIdx),

        % If child is a 4-node, split it first
        ( if node_is_4node(!.Nodes, ChildIdx) then
            split_child(DummyKey, Idx, ChildPos, !Nodes, !FreeList),
            % After split, decide which side to go
            array.lookup(!.Nodes, Idx, Node1),
            array.lookup(Node1 ^ mt_keys, ChildPos, MidKey),
            Compare(Key, MidKey, Cmp),
            ( if ( Cmp = (>) ; Cmp = (=) ) then
                NewChildPos = ChildPos + 1
            else
                NewChildPos = ChildPos
            ),
            array.lookup(Node1 ^ mt_children, NewChildPos, NewChildIdx),
            insert_non_full(DummyKey, Compare, NewChildIdx, Key,
                !Nodes, !FreeList)
        else
            insert_non_full(DummyKey, Compare, ChildIdx, Key,
                !Nodes, !FreeList)
        ),
        recompute_measure(Idx, !Nodes)
    ).

:- pred find_insert_pos(pred(K, K, comparison_result),
    K, array(K), int, int).
:- mode find_insert_pos(in(pred(in, in, out) is det),
    in, in, in, out) is det.

find_insert_pos(Compare, Key, Keys, N, Pos) :-
    find_insert_pos_loop(Compare, Key, Keys, N, Pos).

:- pred find_insert_pos_loop(pred(K, K, comparison_result),
    K, array(K), int, int).
:- mode find_insert_pos_loop(in(pred(in, in, out) is det),
    in, in, in, out) is det.

find_insert_pos_loop(Compare, Key, Keys, Pos0, Pos) :-
    ( if Pos0 > 0 then
        array.lookup(Keys, Pos0 - 1, ExistingKey),
        Compare(Key, ExistingKey, Cmp),
        ( if Cmp = (<) then
            find_insert_pos_loop(Compare, Key, Keys, Pos0 - 1, Pos)
        else
            Pos = Pos0
        )
    else
        Pos = 0
    ).

:- pred shift_keys_for_insert(int::in, int::in,
    array(K)::array_di, array(K)::array_uo) is det.

shift_keys_for_insert(I, Stop, !Keys) :-
    ( if I >= Stop then
        array.lookup(!.Keys, I, K),
        array.set(I + 1, K, !Keys),
        ( if I > Stop then
            shift_keys_for_insert(I - 1, Stop, !Keys)
        else
            true
        )
    else
        true
    ).

:- pred find_child_pos(pred(K, K, comparison_result),
    K, array(K), int, int, int).
:- mode find_child_pos(in(pred(in, in, out) is det),
    in, in, in, in, out) is det.

find_child_pos(Compare, Key, Keys, N, Pos0, Pos) :-
    ( if Pos0 < N then
        array.lookup(Keys, Pos0, ExistingKey),
        Compare(Key, ExistingKey, Cmp),
        ( if ( Cmp = (>) ; Cmp = (=) ) then
            find_child_pos(Compare, Key, Keys, N, Pos0 + 1, Pos)
        else
            Pos = Pos0
        )
    else
        Pos = Pos0
    ).

%-----------------------------------------------------------------------------%
% In-order traversal (collect)
%-----------------------------------------------------------------------------%

:- pred collect_impl(array(mt_node(K, M))::in, int::in,
    list(K)::in, list(K)::out) is det.

collect_impl(Nodes, Idx, !Acc) :-
    ( if Idx = -1 then
        true
    else
        array.lookup(Nodes, Idx, Node),
        N = Node ^ mt_n,
        collect_node(Nodes, Node, N, 0, !Acc)
    ).

:- pred collect_node(array(mt_node(K, M))::in, mt_node(K, M)::in,
    int::in, int::in, list(K)::in, list(K)::out) is det.

collect_node(Nodes, Node, N, I, !Acc) :-
    ( if I > N then
        true
    else
        % First recurse into right siblings, then add key, then left child.
        % We build the list in reverse order for efficiency, then reverse.
        % Actually, let's collect from right to left to build the list properly.
        true,
        ( if I < N then
            % Process everything from I+1 onwards first (for correct order)
            collect_node(Nodes, Node, N, I + 1, !Acc)
        else
            true
        ),
        % Now process: if I < N, prepend key[I]
        ( if I < N then
            array.lookup(Node ^ mt_keys, I, Key),
            !:Acc = [Key | !.Acc]
        else
            true
        ),
        % Process child[I]
        array.lookup(Node ^ mt_children, I, ChildIdx),
        collect_impl(Nodes, ChildIdx, !Acc)
    ).

%-----------------------------------------------------------------------------%
% Subtree count (for find_by_weight)
%-----------------------------------------------------------------------------%

:- func subtree_count(array(mt_node(K, M)), int) = int.

subtree_count(Nodes, Idx) = Count :-
    ( if Idx = -1 then
        Count = 0
    else
        array.lookup(Nodes, Idx, Node),
        N = Node ^ mt_n,
        subtree_count_children(Nodes, Node ^ mt_children, N, 0, 0, ChildCount),
        Count = N + ChildCount
    ).

:- pred subtree_count_children(array(mt_node(K, M))::in, array(int)::in,
    int::in, int::in, int::in, int::out) is det.

subtree_count_children(Nodes, Children, N, I, !Acc) :-
    ( if I > N then
        true
    else
        array.lookup(Children, I, ChildIdx),
        ( if ChildIdx \= -1 then
            !:Acc = !.Acc + subtree_count(Nodes, ChildIdx)
        else
            true
        ),
        subtree_count_children(Nodes, Children, N, I + 1, !Acc)
    ).

%-----------------------------------------------------------------------------%
% Find by weight
%-----------------------------------------------------------------------------%

:- pred find_by_weight_impl(array(mt_node(K, M))::in, int::in,
    float::in, float::in, int::in, (func(M) = float)::in,
    weight_result(K)::out) is det <= mt_measured(M, K).

find_by_weight_impl(Nodes, Idx, Target, Cum, GlobalIdx, WeightOf, Result) :-
    ( if Idx = -1 then
        % Should not normally reach here; return not-found
        % We need a dummy key; use error
        error("find_by_weight_impl: reached -1 index")
    else
        array.lookup(Nodes, Idx, Node),
        N = Node ^ mt_n,
        find_weight_loop(Nodes, Node, N, 0, Target, Cum, GlobalIdx,
            WeightOf, Result)
    ).

:- pred find_weight_loop(array(mt_node(K, M))::in, mt_node(K, M)::in,
    int::in, int::in, float::in, float::in, int::in,
    (func(M) = float)::in,
    weight_result(K)::out) is det <= mt_measured(M, K).

find_weight_loop(Nodes, Node, N, I, Target, RunCum, RunIdx,
        WeightOf, Result) :-
    ( if I > N then
        % Should not reach here
        error("find_weight_loop: past end of node")
    else
        % Process child[I]
        array.lookup(Node ^ mt_children, I, ChildIdx),
        ( if ChildIdx \= -1 then
            array.lookup(Nodes, ChildIdx, ChildNode),
            ChildWeight = WeightOf(ChildNode ^ mt_node_meas),
            ( if RunCum + ChildWeight >= Target then
                find_by_weight_impl(Nodes, ChildIdx, Target, RunCum,
                    RunIdx, WeightOf, Result)
            else
                NewRunCum = RunCum + ChildWeight,
                NewRunIdx = RunIdx + subtree_count(Nodes, ChildIdx),
                process_key_in_weight(Nodes, Node, N, I, Target,
                    NewRunCum, NewRunIdx, WeightOf, Result)
            )
        else
            process_key_in_weight(Nodes, Node, N, I, Target,
                RunCum, RunIdx, WeightOf, Result)
        )
    ).

:- pred process_key_in_weight(array(mt_node(K, M))::in, mt_node(K, M)::in,
    int::in, int::in, float::in, float::in, int::in,
    (func(M) = float)::in,
    weight_result(K)::out) is det <= mt_measured(M, K).

process_key_in_weight(Nodes, Node, N, I, Target, RunCum, RunIdx,
        WeightOf, Result) :-
    ( if I < N then
        array.lookup(Node ^ mt_keys, I, Key),
        KeyWeight = WeightOf(mt_measure(Key)),
        ( if RunCum + KeyWeight >= Target then
            Result = weight_result(Key, RunCum, RunIdx, yes)
        else
            find_weight_loop(Nodes, Node, N, I + 1, Target,
                RunCum + KeyWeight, RunIdx + 1, WeightOf, Result)
        )
    else
        % Past the last key; shouldn't normally happen
        error("process_key_in_weight: past last key")
    ).

%-----------------------------------------------------------------------------%
% Build from sorted
%-----------------------------------------------------------------------------%

:- pred build_recursive(K::in, array(K)::in, int::in, int::in, int::out,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo,
    list(int)::in, list(int)::out) is det <= mt_measured(M, K).

build_recursive(DummyKey, Sorted, Lo, Hi, Result, !Nodes, !FreeList) :-
    NumElems = Hi - Lo,
    ( if NumElems =< 0 then
        Result = -1
    else if NumElems =< 3 then
        % Leaf node with 1-3 keys
        alloc_in_array(DummyKey, Idx, !Nodes, !FreeList),
        set_leaf_keys(Sorted, Lo, NumElems, Idx, !Nodes),
        recompute_measure(Idx, !Nodes),
        Result = Idx
    else if NumElems =< 7 then
        % 2-node: one key, two children
        Mid = Lo + NumElems / 2,
        build_recursive(DummyKey, Sorted, Lo, Mid, LeftIdx, !Nodes, !FreeList),
        build_recursive(DummyKey, Sorted, Mid + 1, Hi, RightIdx, !Nodes, !FreeList),
        alloc_in_array(DummyKey, Idx, !Nodes, !FreeList),
        array.lookup(Sorted, Mid, MidKey),
        set_2node(Idx, MidKey, LeftIdx, RightIdx, !Nodes),
        recompute_measure(Idx, !Nodes),
        Result = Idx
    else
        % 3-node: two keys, three children
        Third = NumElems / 3,
        M1 = Lo + Third,
        M2 = Lo + 2 * Third + 1,
        build_recursive(DummyKey, Sorted, Lo, M1, C0, !Nodes, !FreeList),
        build_recursive(DummyKey, Sorted, M1 + 1, M2, C1, !Nodes, !FreeList),
        build_recursive(DummyKey, Sorted, M2 + 1, Hi, C2, !Nodes, !FreeList),
        alloc_in_array(DummyKey, Idx, !Nodes, !FreeList),
        array.lookup(Sorted, M1, Key1),
        array.lookup(Sorted, M2, Key2),
        set_3node(Idx, Key1, Key2, C0, C1, C2, !Nodes),
        recompute_measure(Idx, !Nodes),
        Result = Idx
    ).

:- pred alloc_in_array(K::in, int::out,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo,
    list(int)::in, list(int)::out) is det <= mt_measured(M, K).

alloc_in_array(DummyKey, Idx, !Nodes, !FreeList) :-
    Identity = mt_mempty : M,
    EmptyNode = make_empty_node(DummyKey, Identity),
    (
        !.FreeList = [FreeIdx | RestFree],
        Idx = FreeIdx,
        !:FreeList = RestFree,
        array.set(FreeIdx, EmptyNode, !Nodes)
    ;
        !.FreeList = [],
        Idx = array.size(!.Nodes),
        array.resize(Idx + 1, EmptyNode, !Nodes)
    ).

:- pred set_leaf_keys(array(K)::in, int::in, int::in, int::in,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo) is det.

set_leaf_keys(Sorted, Lo, NumElems, Idx, !Nodes) :-
    array.lookup(!.Nodes, Idx, Node0),
    set_leaf_keys_loop(Sorted, Lo, NumElems, 0,
        unsafe_promise_unique(Node0 ^ mt_keys), Keys),
    Node1 = (Node0 ^ mt_n := NumElems) ^ mt_keys := Keys,
    array.set(Idx, Node1, !Nodes).

:- pred set_leaf_keys_loop(array(K)::in, int::in, int::in, int::in,
    array(K)::array_di, array(K)::array_uo) is det.

set_leaf_keys_loop(Sorted, Lo, NumElems, I, !Keys) :-
    ( if I < NumElems then
        array.lookup(Sorted, Lo + I, Key),
        array.set(I, Key, !Keys),
        set_leaf_keys_loop(Sorted, Lo, NumElems, I + 1, !Keys)
    else
        true
    ).

:- pred set_2node(int::in, K::in, int::in, int::in,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo) is det.

set_2node(Idx, Key, LeftIdx, RightIdx, !Nodes) :-
    array.lookup(!.Nodes, Idx, Node0),
    array.set(0, Key, unsafe_promise_unique(Node0 ^ mt_keys), Keys),
    array.set(0, LeftIdx, unsafe_promise_unique(Node0 ^ mt_children), Ch0),
    array.set(1, RightIdx, Ch0, Ch1),
    Node1 = ((Node0 ^ mt_n := 1) ^ mt_keys := Keys) ^ mt_children := Ch1,
    array.set(Idx, Node1, !Nodes).

:- pred set_3node(int::in, K::in, K::in, int::in, int::in, int::in,
    array(mt_node(K, M))::array_di, array(mt_node(K, M))::array_uo) is det.

set_3node(Idx, Key1, Key2, C0, C1, C2, !Nodes) :-
    array.lookup(!.Nodes, Idx, Node0),
    array.set(0, Key1, unsafe_promise_unique(Node0 ^ mt_keys), Keys0),
    array.set(1, Key2, Keys0, Keys1),
    array.set(0, C0, unsafe_promise_unique(Node0 ^ mt_children), Ch0),
    array.set(1, C1, Ch0, Ch1),
    array.set(2, C2, Ch1, Ch2),
    Node1 = ((Node0 ^ mt_n := 2) ^ mt_keys := Keys1) ^ mt_children := Ch2,
    array.set(Idx, Node1, !Nodes).

%-----------------------------------------------------------------------------%
% Public operations
%-----------------------------------------------------------------------------%

mt_new(DummyKey, Tree) :-
    Identity = mt_mempty : M,
    EmptyNode = make_empty_node(DummyKey, Identity),
    array.init(4, EmptyNode, Nodes),
    Tree = promise_unique_tree(measured_tree(Nodes, [], -1, 0)).

mt_insert(Compare, Key, !Tree) :-
    !.Tree = measured_tree(Nodes0, FreeList0, Root0, Count0),
    DummyKey = Key,  % Use the key being inserted as dummy
    ( if Root0 = -1 then
        % Empty tree: create root with one key
        Identity = mt_mempty : M,
        EmptyNode = make_empty_node(DummyKey, Identity),
        ( if array.size(Nodes0) > 0 then
            Idx = 0,
            array.set(0, EmptyNode,
                unsafe_promise_unique(Nodes0), Nodes1)
        else
            Idx = 0,
            array.init(4, EmptyNode, Nodes1)
        ),
        array.lookup(Nodes1, Idx, Node0),
        array.set(0, Key, unsafe_promise_unique(Node0 ^ mt_keys), Keys),
        Node1 = (Node0 ^ mt_n := 1) ^ mt_keys := Keys,
        array.set(Idx, Node1, Nodes1, Nodes2),
        recompute_measure(Idx, Nodes2, Nodes3),
        !:Tree = promise_unique_tree(
            measured_tree(Nodes3, FreeList0, Idx, Count0 + 1))
    else
        % If root is a 4-node, split it
        ( if node_is_4node(Nodes0, Root0) then
            % Create new root with old root as child[0]
            TempTree0 = promise_unique_tree(
                measured_tree(Nodes0, FreeList0, Root0, Count0)),
            alloc_node(DummyKey, NewRootIdx, TempTree0, TempTree1),
            TempTree1 = measured_tree(Nodes1a, FreeList1a, _, _),
            array.lookup(Nodes1a, NewRootIdx, NewRootNode0),
            array.set(0, Root0,
                unsafe_promise_unique(NewRootNode0 ^ mt_children),
                NRCh),
            NewRootNode1 = NewRootNode0 ^ mt_children := NRCh,
            array.set(NewRootIdx, NewRootNode1,
                unsafe_promise_unique(Nodes1a), Nodes1b),
            split_child(DummyKey, NewRootIdx, 0, Nodes1b, Nodes1c,
                FreeList1a, FreeList1b),
            insert_non_full(DummyKey, Compare, NewRootIdx, Key,
                Nodes1c, Nodes1d, FreeList1b, FreeList1c),
            !:Tree = promise_unique_tree(
                measured_tree(Nodes1d, FreeList1c, NewRootIdx, Count0 + 1))
        else
            insert_non_full(DummyKey, Compare, Root0, Key,
                unsafe_promise_unique(Nodes0), Nodes1,
                FreeList0, FreeList1),
            !:Tree = promise_unique_tree(
                measured_tree(Nodes1, FreeList1, Root0, Count0 + 1))
        )
    ).

mt_size(Tree) = Tree ^ mt_count.

mt_root_measure(Tree) = Meas :-
    Root = Tree ^ mt_root,
    ( if Root = -1 then
        Meas = mt_mempty
    else
        array.lookup(Tree ^ mt_nodes, Root, Node),
        Meas = Node ^ mt_node_meas
    ).

mt_collect(Tree, Keys) :-
    collect_impl(Tree ^ mt_nodes, Tree ^ mt_root, [], Keys).

mt_clear(DummyKey, _OldTree, NewTree) :-
    mt_new(DummyKey, NewTree).

mt_build_from_sorted(DummyKey, SortedList, Tree) :-
    Len = list.length(SortedList),
    ( if Len = 0 then
        mt_new(DummyKey, Tree)
    else
        % Convert list to array
        array.from_list(SortedList, SortedArr),
        Identity = mt_mempty : M,
        EmptyNode = make_empty_node(DummyKey, Identity),
        array.init(Len, EmptyNode, Nodes0),
        build_recursive(DummyKey, SortedArr, 0, Len, RootIdx,
            Nodes0, Nodes1, [], FreeList1),
        Tree = promise_unique_tree(
            measured_tree(Nodes1, FreeList1, RootIdx, Len))
    ).

mt_find_by_weight(Tree, Target, WeightOf, Result) :-
    Root = Tree ^ mt_root,
    ( if Root = -1 then
        error("mt_find_by_weight: empty tree")
    else
        find_by_weight_impl(Tree ^ mt_nodes, Root, Target, 0.0, 0,
            WeightOf, Result)
    ).

%-----------------------------------------------------------------------------%
:- end_module measured_tree234.
%-----------------------------------------------------------------------------%
