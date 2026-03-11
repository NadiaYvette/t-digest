# cfari ke lidne velski

## se nitcu samtci

do nitcu lo vi samtci:
- la `git`
- le samtci poi se nitcu fi le bangu poi do djica (ko tcidu le vi liste)

## cpacu le fonxa mupli

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## zbasu gi'e pilno fi ro le bangu

### Haskell

**sarcu:** GHC, `fingertree` joi `vector` le samtci

**sezu'e (no zbasu tutci):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**tai le Cabal samtci (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

le Cabal samtci cu jarco re girzu samtci:
`Data.Sketch.TDigest` (junri, finger-tree-se jicmu) joi
`Data.Sketch.TDigest.Mutable` (galfi kakne, ST monad joi vektori).

**lo do ke kadno pilno:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

do nitcu la `ruby` (2.0 ja za'u).

```bash
cd ruby/
ruby tdigest.rb
```

le datnyvei `tdigest.rb` cu jmina le ciste gi'e le mupli .i lo nu pilno ri ku:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

do nitcu la `gnatmake` (le Ada zbasu samtci poi se jmina la GCC).

```bash
cd ada/
gnatmake demo.adb
./demo
```

le pekybau cu se fendi fi le `tdigest.ads` (tcila) gi'e le `tdigest.adb` (xadni) gi'e le `tree234.ads`/`tree234.adb` ke 2-3-4 tricu pekybau.

---

### Common Lisp

do nitcu la `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp/
sbcl --script demo.lisp
```

lo nu pilno fi le nu te preti:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

do nitcu la `csi` (CHICKEN Scheme).

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

ja la Guile:

```bash
guile demo.scm
```

ju'o ko jdice: le `+inf.0` gi'e le `-inf.0` cu se pilno fi le cimni. le do ke Scheme cu ka'e se stidi lo drata ke cimni namcu.

---

### Standard ML

do nitcu la `mlton` (MLton zbasu samtci) ja la `sml` (SML/NJ).

la MLton:

```bash
cd sml/
mlton demo.mlb
./demo
```

la SML/NJ:

```bash
cd sml/
sml demo.sml
```

le MLB datnyvei (`demo.mlb`) cu liste le jicmu ciste gi'e le fonxa datnyvei.

---

### Prolog

do nitcu la `swipl` (SWI-Prolog).

```bash
cd prolog/
swipl demo.pl
```

le mupli cu cpacu le `tdigest` mudul gi'e zukte zoi la `:- initialization(main, main).` la.

lo nu pilno fi le nu te preti:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

do nitcu la `mmc` (le Mercury zbasu samtci).

**le junri fancu mupli** (fingertree):

```bash
cd mercury/
mmc --make demo
./demo
```

**le se galfi mupli** (2-3-4 tricu):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

le Mercury zbasu ciste cu zukte lo nu zbasu le se nitcu (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, ktp.).

---

### C

do nitcu la `gcc` ja la `clang`.

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

do nitcu la `g++` ja la `clang++` (C++17).

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

do nitcu la `go` (1.18 ja za'u).

```bash
cd go/demo
go run .
```

---

### Rust

do nitcu la `cargo` gi'e le Rust ilaĉeno.

```bash
cd rust/
cargo run --release
```

---

### Java

do nitcu le JDK (11 ja za'u).

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

do nitcu le Kotlin zbasu samtci.

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

do nitcu la `python3` (na nitcu lo drata ciste).

```bash
cd python/
python3 demo.py
```

---

### Julia

do nitcu la `julia` (1.6 ja za'u).

```bash
cd julia/
julia demo.jl
```

---

### OCaml

do nitcu le OCaml zbasu samtci gi'e la ocamlfind.

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

do nitcu la Erlang/OTP.

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

do nitcu la `elixir` (1.12 ja za'u).

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

do nitcu la `gfortran` ja lo drata Fortran 2003+ zbasu samtci.

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

do nitcu la `perl` (Perl 5).

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

do nitcu la `lua` (5.1 ja za'u).

```bash
cd lua/
lua demo.lua
```

---

### R

do nitcu la `R` (3.0 ja za'u).

```bash
cd r/
Rscript demo.R
```

---

### Zig

do nitcu le Zig zbasu samtci.

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

do nitcu le Nim zbasu samtci.

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

do nitcu la `dmd` ja la `ldc2`.

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

do nitcu le .NET SDK ja la Mono.

**la .NET SDK:**

```bash
cd csharp/
dotnet run
```

**la Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

do nitcu le Swift zbasu samtci.

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## le mupli cu zukte ma

ro le mupli cu zukte le vi:

1. **zbasu le t-digest** — le gradu ciste fancu cu la'o zoi K_1 zoi gi'e le delta cu 100
2. **jmina lo 10000 datni** — le datni cu dunli vrici fi le 0 bi'o 1
3. **te cusku le gradu stuzi jdice** — le jdice be le 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9% gradu stuzi
4. **te cusku le CDF jdice** — le jdice be le CDF fi le datni stuzi
5. **cipra le nu jorne** — zbasu re t-digest gi'e jorne gi'e cipra le jdice

le te cusku cu se cusku le gradu stuzi jdice gi'e le fliba gi'e le gradu girzu namcu.

## le za'e bavlamdei

do pu tcidu le vi fa ko zbasu le do ke samtci. ko pilno le t-digest fi le do ke datni!
