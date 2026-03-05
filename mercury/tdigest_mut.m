%-----------------------------------------------------------------------------%
% tdigest_mut.m
%
% Stateful predicate interface for the Dunning t-digest.
% Provides a mutable-style API using in/out threading, wrapping the
% pure functions from tdigest.m. This interface is convenient for
% imperative-style code and integrates naturally with Mercury's
% state-variable (!TD) notation.
%
% For true destructive update, the tdigest type would need to be
% wrapped in a store or use unique arrays internally. This module
% provides the ergonomic benefit of predicate-style threading without
% requiring changes to the underlying pure data structure.
%-----------------------------------------------------------------------------%

:- module tdigest_mut.
:- interface.

:- import_module tdigest.
:- import_module float.
:- import_module int.

%-----------------------------------------------------------------------------%
% Stateful predicates (in/out threaded)
%
% These predicates take the t-digest as an in/out state variable,
% allowing imperative-style code:
%
%   tdigest_mut.add(1.0, !TD),
%   tdigest_mut.add(2.0, !TD),
%   tdigest_mut.quantile(0.5, !TD, Median)
%
%-----------------------------------------------------------------------------%

    % Add a single value (weight 1.0) to the digest.
    %
:- pred add(float::in, tdigest::in, tdigest::out) is det.

    % Add a value with a given weight.
    %
:- pred add_weighted(float::in, float::in, tdigest::in, tdigest::out) is det.

    % Force compression of buffered values into the centroid list.
    %
:- pred compress(tdigest::in, tdigest::out) is det.

    % Estimate the value at quantile Q (0..1).
    % The digest may be compressed as a side-effect, so it is threaded.
    %
:- pred quantile(float::in, tdigest::in, tdigest::out, float::out) is det.

    % Estimate the CDF value at X.
    % The digest may be compressed as a side-effect, so it is threaded.
    %
:- pred cdf(float::in, tdigest::in, tdigest::out, float::out) is det.

    % Merge another digest (read-only) into this one.
    %
:- pred merge(tdigest::in, tdigest::in, tdigest::out) is det.

    % Return the number of centroids after compressing any pending buffer.
    %
:- pred centroid_count(tdigest::in, tdigest::out, int::out) is det.

%-----------------------------------------------------------------------------%
:- implementation.
%-----------------------------------------------------------------------------%

add(Value, TD0, TD) :-
    TD = tdigest.add_value(Value, TD0).

add_weighted(Value, Weight, TD0, TD) :-
    TD = tdigest.add(TD0, Value, Weight).

compress(TD0, TD) :-
    TD = tdigest.compress(TD0).

quantile(Q, TD0, TD, Value) :-
    TD = tdigest.ensure_compressed(TD0),
    Value = tdigest.quantile(TD, Q).

cdf(X, TD0, TD, Value) :-
    TD = tdigest.ensure_compressed(TD0),
    Value = tdigest.cdf(TD, X).

merge(Other, TD0, TD) :-
    TD = tdigest.merge_digests(TD0, Other).

centroid_count(TD0, TD, Count) :-
    TD = tdigest.ensure_compressed(TD0),
    Count = tdigest.centroid_count(TD).

%-----------------------------------------------------------------------------%
:- end_module tdigest_mut.
%-----------------------------------------------------------------------------%
