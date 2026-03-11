# Per iniziare

Questo progetto contiene implementazioni del t-digest in 28 linguaggi di programmazione. Ogni implementazione utilizza la variante merging digest con la funzione di scala K_1 (arcoseno).

## Compilare ed eseguire

### Haskell

**Prerequisiti:** GHC, pacchetti `fingertree` e `vector`

**Autonomo (senza strumento di build):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**Come pacchetto Cabal (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Il pacchetto Cabal espone due moduli di libreria:
`Data.Sketch.TDigest` (puro, basato su finger tree) e
`Data.Sketch.TDigest.Mutable` (mutabile, monade ST con vettori).

**Utilizzo nel proprio codice:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Prerequisiti:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Il file `tdigest.rb` contiene sia la libreria che una demo nel blocco `if __FILE__ == $PROGRAM_NAME`. Per utilizzarlo come libreria:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Prerequisiti:** GNAT (compilatore Ada di GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Il pacchetto e suddiviso in `tdigest.ads` (specifica), `tdigest.adb` (corpo) e il pacchetto generico dell'albero 2-3-4 `tree234.ads`/`tree234.adb`. Per utilizzarlo nel proprio progetto, aggiungere `with TDigest;` nel sorgente e compilare tutti i file insieme.

---

### Common Lisp

**Prerequisiti:** SBCL o qualsiasi implementazione ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Per l'uso interattivo:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Prerequisiti:** CHICKEN Scheme (`csi`) o qualsiasi Scheme R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Oppure con Guile:

```bash
guile demo.scm
```

Nota: I letterali `+inf.0` e `-inf.0` sono utilizzati per l'infinito. Se la propria implementazione Scheme utilizza costanti diverse, potrebbe essere necessario modificare le definizioni di `+inf` e `-inf` all'inizio di `tdigest.scm`.

---

### Standard ML

**Prerequisiti:** MLton (per la compilazione) o SML/NJ (per l'uso interattivo)

**Con MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Con SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Il file MLB (`demo.mlb`) elenca la libreria base e i file sorgente per il sistema di compilazione di MLton.

---

### Prolog

**Prerequisiti:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

La demo carica il modulo `tdigest` e viene eseguita automaticamente tramite la direttiva `:- initialization(main, main).`.

Per l'uso interattivo:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Prerequisiti:** Compilatore Mercury (`mmc`)

**Versione puramente funzionale** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Versione mutabile** (albero 2-3-4 con tipi di unicita):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Il sistema di compilazione Mercury compila automaticamente le dipendenze (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, ecc.).

---

### C

**Prerequisiti:** GCC o Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Prerequisiti:** G++ o Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Prerequisiti:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Prerequisiti:** Cargo e toolchain Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**Prerequisiti:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Prerequisiti:** Compilatore Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Prerequisiti:** Python 3 (nessuna dipendenza esterna)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Prerequisiti:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Prerequisiti:** Compilatore OCaml con ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Prerequisiti:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Prerequisiti:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Prerequisiti:** GFortran o un altro compilatore Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Prerequisiti:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Prerequisiti:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Prerequisiti:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Prerequisiti:** Compilatore Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Prerequisiti:** Compilatore Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Prerequisiti:** DMD o LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Prerequisiti:** .NET SDK o Mono

**Con .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Con Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Prerequisiti:** Compilatore Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
