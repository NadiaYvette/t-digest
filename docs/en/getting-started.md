# Getting Started

Each language implementation is self-contained in its own directory.
There are no cross-language dependencies.

---

## Haskell

**Prerequisites:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

The module `TDigest` uses only `base` libraries (no Cabal or Stack
project is required).

**Using in your own code:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Prerequisites:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

The file `tdigest.rb` contains both the library and a demo in the
`if __FILE__ == $PROGRAM_NAME` block. To use it as a library:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Prerequisites:** GNAT (GCC Ada compiler)

```bash
cd ada/
gnatmake demo.adb
./demo
```

The package is split into `tdigest.ads` (spec) and `tdigest.adb` (body).
To use in your own project, `with TDigest;` in your source and compile
both files together.

---

## Common Lisp

**Prerequisites:** SBCL, or any ANSI Common Lisp implementation

```bash
cd common-lisp/
sbcl --script demo.lisp
```

To use interactively:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Prerequisites:** CHICKEN Scheme (`csi`), or any R5RS/R7RS Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Or with Guile:

```bash
guile demo.scm
```

Note: The `+inf.0` and `-inf.0` literals are used for infinity. If your
Scheme implementation uses different constants, you may need to adjust
the definitions of `+inf` and `-inf` at the top of `tdigest.scm`.

---

## Standard ML

**Prerequisites:** MLton (for compilation) or SML/NJ (for interactive use)

**With MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**With SML/NJ:**

```bash
cd sml/
sml demo.sml
```

The MLB file (`demo.mlb`) lists the basis library and source files for
MLton's build system.

---

## Prolog

**Prerequisites:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

The demo loads the `tdigest` module and runs automatically via the
`:- initialization(main, main).` directive.

To use interactively:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Prerequisites:** Mercury compiler (`mmc`)

```bash
cd mercury/
mmc --make demo
./demo
```

The Mercury build system will automatically compile `tdigest.m` as a
dependency of `demo.m`.

---

## Running All Demos

From the project root, you can run all demos in sequence:

```bash
echo "=== Haskell ===" && (cd haskell && ghc -O2 -o demo Main.hs TDigest.hs && ./demo)
echo "=== Ruby ===" && (cd ruby && ruby tdigest.rb)
echo "=== Ada ===" && (cd ada && gnatmake demo.adb && ./demo)
echo "=== Common Lisp ===" && (cd common-lisp && sbcl --script demo.lisp)
echo "=== Scheme ===" && (cd scheme && csi -R r5rs -script demo.scm)
echo "=== SML ===" && (cd sml && mlton demo.mlb && ./demo)
echo "=== Prolog ===" && (cd prolog && swipl demo.pl)
echo "=== Mercury ===" && (cd mercury && mmc --make demo && ./demo)
```
