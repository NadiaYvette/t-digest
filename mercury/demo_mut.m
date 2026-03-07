%-----------------------------------------------------------------------------%
% demo_mut.m -- Smoke test for the mutable t-digest implementation.
%
% Compile with: mmc --make demo_mut
%-----------------------------------------------------------------------------%

:- module demo_mut.
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
:- import_module tdigest_mut.

%-----------------------------------------------------------------------------%
% Simple LCG PRNG
%-----------------------------------------------------------------------------%

:- func lcg_next(int) = int.

lcg_next(S) = (1664525 * S + 1013904223) mod (1 << 32).

:- func lcg_double(int) = float.

lcg_double(S) = float.float(int.abs(S) mod (1 << 30)) /
                float.float(1 << 30).

:- pred lcg_add_values(int::in, int::in, mut_tdigest::di,
    mut_tdigest::uo, int::out) is det.

lcg_add_values(N, Seed, !TD, SeedOut) :-
    ( if N =< 0 then
        SeedOut = Seed
    else
        S1 = lcg_next(Seed),
        V = lcg_double(S1),
        mut_add_value(V, !TD),
        lcg_add_values(N - 1, S1, !TD, SeedOut)
    ).

%-----------------------------------------------------------------------------%
% Formatting helper
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
% Main
%-----------------------------------------------------------------------------%

main(!IO) :-
    NumValues = 10000,
    Delta = 100.0,

    io.write_string("Mutable T-Digest demo: ", !IO),
    io.write_int(NumValues, !IO),
    io.write_string(" uniform values in [0, 1)\n", !IO),

    % Build mutable t-digest.
    mut_new(Delta, TD0),
    lcg_add_values(NumValues, 42, TD0, TD1, _SeedOut),

    % Query centroid count.
    mut_centroid_count(TD1, TD2, CCount),
    io.write_string("Centroids: ", !IO),
    io.write_int(CCount, !IO),
    io.nl(!IO),
    io.nl(!IO),

    % Quantile estimates.
    io.write_string("Quantile estimates (expected ~ q for uniform):\n", !IO),
    print_quantile(TD2, 0.001, TD3, !IO),
    print_quantile(TD3, 0.01, TD4, !IO),
    print_quantile(TD4, 0.1, TD5, !IO),
    print_quantile(TD5, 0.25, TD6, !IO),
    print_quantile(TD6, 0.5, TD7, !IO),
    print_quantile(TD7, 0.75, TD8, !IO),
    print_quantile(TD8, 0.9, TD9, !IO),
    print_quantile(TD9, 0.99, TD10, !IO),
    print_quantile(TD10, 0.999, TD11, !IO),
    io.nl(!IO),

    % CDF estimates.
    io.write_string("CDF estimates (expected ~ x for uniform):\n", !IO),
    print_cdf(TD11, 0.001, TD12, !IO),
    print_cdf(TD12, 0.01, TD13, !IO),
    print_cdf(TD13, 0.1, TD14, !IO),
    print_cdf(TD14, 0.25, TD15, !IO),
    print_cdf(TD15, 0.5, TD16, !IO),
    print_cdf(TD16, 0.75, TD17, !IO),
    print_cdf(TD17, 0.9, TD18, !IO),
    print_cdf(TD18, 0.99, TD19, !IO),
    print_cdf(TD19, 0.999, _TD20, !IO),
    io.nl(!IO),

    io.write_string("Done.\n", !IO).

:- pred print_quantile(mut_tdigest::di, float::in, mut_tdigest::uo,
    io::di, io::uo) is det.

print_quantile(!.TD, Q, !:TD, !IO) :-
    mut_quantile(!.TD, Q, !:TD, Est),
    Err = float.abs(Est - Q),
    io.write_string("  q=" ++ pad_right(6, format_float(3, Q)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

:- pred print_cdf(mut_tdigest::di, float::in, mut_tdigest::uo,
    io::di, io::uo) is det.

print_cdf(!.TD, X, !:TD, !IO) :-
    mut_cdf(!.TD, X, !:TD, Est),
    Err = float.abs(Est - X),
    io.write_string("  x=" ++ pad_right(6, format_float(3, X)) ++
        "  estimated=" ++ format_float(6, Est) ++
        "  error=" ++ format_float(6, Err) ++ "\n", !IO).

%-----------------------------------------------------------------------------%
:- end_module demo_mut.
%-----------------------------------------------------------------------------%
