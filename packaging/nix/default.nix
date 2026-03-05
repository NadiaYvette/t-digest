{ lib
, stdenv
, ruby
, ghc
, sbcl
, swiProlog
, mlton
, gnat
, mercury
}:

stdenv.mkDerivation rec {
  pname = "t-digest";
  version = "0.1.0";

  src = ../..;

  nativeBuildInputs = [
    ruby
    ghc
  ];

  dontBuild = true;
  doCheck = false;

  installPhase = ''
    runHook preInstall

    # Documentation
    mkdir -p $out/share/doc/${pname}
    if [ -f LICENSE ]; then
      cp LICENSE $out/share/doc/${pname}/
    fi

    # Ruby
    mkdir -p $out/share/${pname}/ruby
    cp ruby/tdigest.rb $out/share/${pname}/ruby/

    # Haskell
    mkdir -p $out/share/${pname}/haskell
    cp haskell/TDigest.hs $out/share/${pname}/haskell/
    cp haskell/Main.hs $out/share/${pname}/haskell/

    # Common Lisp
    mkdir -p $out/share/${pname}/common-lisp
    cp common-lisp/tdigest.lisp $out/share/${pname}/common-lisp/
    cp common-lisp/demo.lisp $out/share/${pname}/common-lisp/

    # Scheme
    mkdir -p $out/share/${pname}/scheme
    cp scheme/tdigest.scm $out/share/${pname}/scheme/
    cp scheme/demo.scm $out/share/${pname}/scheme/

    # SML
    mkdir -p $out/share/${pname}/sml
    cp sml/tdigest.sml $out/share/${pname}/sml/
    cp sml/demo.sml $out/share/${pname}/sml/
    cp sml/demo.mlb $out/share/${pname}/sml/

    # Ada
    mkdir -p $out/share/${pname}/ada
    cp ada/tdigest.ads $out/share/${pname}/ada/
    cp ada/tdigest.adb $out/share/${pname}/ada/
    cp ada/demo.adb $out/share/${pname}/ada/

    # Prolog
    mkdir -p $out/share/${pname}/prolog
    cp prolog/tdigest.pl $out/share/${pname}/prolog/
    cp prolog/demo.pl $out/share/${pname}/prolog/

    # Mercury
    mkdir -p $out/share/${pname}/mercury
    cp mercury/tdigest.m $out/share/${pname}/mercury/
    cp mercury/demo.m $out/share/${pname}/mercury/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Dunning t-digest implementations in multiple languages";
    longDescription = ''
      The t-digest is a data structure for accurate on-line accumulation of
      rank-based statistics such as quantiles and trimmed means. This project
      provides implementations of the Dunning t-digest algorithm in eight
      programming languages: Ruby, Haskell, Common Lisp, Scheme, SML, Ada,
      Prolog, and Mercury.
    '';
    homepage = "https://github.com/NadiaYvette/t-digest";
    license = licenses.mit;
    maintainers = [ "Nadia Yvette Chambers <nadia.yvette.chambers@gmail.com>" ];
    platforms = platforms.all;
  };
}
