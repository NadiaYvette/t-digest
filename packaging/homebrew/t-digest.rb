class TDigest < Formula
  desc "Dunning t-digest implementations in multiple languages"
  homepage "https://github.com/NadiaYvette/t-digest"
  url "https://github.com/NadiaYvette/t-digest/archive/refs/tags/v0.1.0.tar.gz"
  version "0.1.0"
  license "MIT"
  sha256 "PLACEHOLDER_SHA256"

  def install
    # Documentation
    doc.install "LICENSE" if File.exist?("LICENSE")

    # Ruby
    (share/"t-digest/ruby").install "ruby/tdigest.rb"

    # Haskell
    (share/"t-digest/haskell").install "haskell/TDigest.hs"
    (share/"t-digest/haskell").install "haskell/Main.hs"

    # Common Lisp
    (share/"t-digest/common-lisp").install "common-lisp/tdigest.lisp"
    (share/"t-digest/common-lisp").install "common-lisp/demo.lisp"

    # Scheme
    (share/"t-digest/scheme").install "scheme/tdigest.scm"
    (share/"t-digest/scheme").install "scheme/demo.scm"

    # SML
    (share/"t-digest/sml").install "sml/tdigest.sml"
    (share/"t-digest/sml").install "sml/demo.sml"
    (share/"t-digest/sml").install "sml/demo.mlb"

    # Ada
    (share/"t-digest/ada").install "ada/tdigest.ads"
    (share/"t-digest/ada").install "ada/tdigest.adb"
    (share/"t-digest/ada").install "ada/demo.adb"

    # Prolog
    (share/"t-digest/prolog").install "prolog/tdigest.pl"
    (share/"t-digest/prolog").install "prolog/demo.pl"

    # Mercury
    (share/"t-digest/mercury").install "mercury/tdigest.m"
    (share/"t-digest/mercury").install "mercury/demo.m"
  end

  test do
    assert_predicate share/"t-digest/ruby/tdigest.rb", :exist?
    assert_predicate share/"t-digest/haskell/TDigest.hs", :exist?
    assert_predicate share/"t-digest/common-lisp/tdigest.lisp", :exist?
    assert_predicate share/"t-digest/scheme/tdigest.scm", :exist?
    assert_predicate share/"t-digest/sml/tdigest.sml", :exist?
    assert_predicate share/"t-digest/ada/tdigest.ads", :exist?
    assert_predicate share/"t-digest/prolog/tdigest.pl", :exist?
    assert_predicate share/"t-digest/mercury/tdigest.m", :exist?
  end
end
