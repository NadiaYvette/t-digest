%-----------------------------------------------------------------------------%
% demo.m -- Demo / self-test for the t-digest library.
%
% Compile with: mmc --make demo
%-----------------------------------------------------------------------------%

:- module demo.
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
:- import_module tdigest.

%-----------------------------------------------------------------------------%
% Simple LCG PRNG (no external dependency)
%-----------------------------------------------------------------------------%

:- func lcg_next(int) = int.

lcg_next(S) = (1664525 * S + 1013904223) mod (1 << 32).

:- func lcg_double(int) = float.

lcg_double(S) = float.float(int.abs(S) mod (1 << 30)) /
                float.float(1 << 30).

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
    TD0 = tdigest.new(Delta),
    TD = list.foldl(tdigest.add_value, Values, TD0),

    io.write_string("T-Digest demo: ", !IO),
    io.write_int(NumValues, !IO),
    io.write_string(" uniform values in [0, 1)\n", !IO),
    io.write_string("Centroids: ", !IO),
    io.write_int(tdigest.centroid_count(TD), !IO),
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
    TDm1 = list.foldl(tdigest.add_value, Vals1, tdigest.new(Delta)),
    TDm2 = list.foldl(tdigest.add_value, Vals2, tdigest.new(Delta)),
    TDm = tdigest.merge_digests(TDm1, TDm2),

    io.write_string("After merge of two 5000-element digests:\n", !IO),
    Median = tdigest.quantile(TDm, 0.5),
    io.write_string("  median=" ++ format_float(6, Median) ++
        " (expected ~0.5)\n", !IO),
    P99 = tdigest.quantile(TDm, 0.99),
    io.write_string("  p99   =" ++ format_float(6, P99) ++
        " (expected ~0.99)\n", !IO),
    io.write_string("  centroids=", !IO),
    io.write_int(tdigest.centroid_count(TDm), !IO),
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

:- pred print_quantile_line(tdigest.tdigest::in, float::in,
    io::di, io::uo) is det.

print_quantile_line(TD, Q, !IO) :-
    Est = tdigest.quantile(TD, Q),
    Err = float.abs(Est - Q),
    io.write_string("  q=" ++ pad_right(6, format_float(3, Q)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

:- pred print_cdf_line(tdigest.tdigest::in, float::in,
    io::di, io::uo) is det.

print_cdf_line(TD, X, !IO) :-
    Est = tdigest.cdf(TD, X),
    Err = float.abs(Est - X),
    io.write_string("  x=" ++ pad_right(6, format_float(3, X)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

%-----------------------------------------------------------------------------%
:- end_module demo.
%-----------------------------------------------------------------------------%
