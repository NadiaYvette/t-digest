# Prise en main

Ce projet contient des implementations du t-digest dans 28 langages de programmation. Chaque implementation utilise la variante merging digest avec la fonction d'echelle K_1 (arc sinus).

## Compiler et executer

### Haskell

**Prerequis :** GHC, paquets `fingertree` et `vector`

**Autonome (sans outil de construction) :**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**En tant que paquet Cabal (`dunning-t-digest`) :**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

Le paquet Cabal expose deux modules de bibliotheque :
`Data.Sketch.TDigest` (pur, base sur un finger tree) et
`Data.Sketch.TDigest.Mutable` (mutable, monade ST avec vecteurs).

**Utilisation dans votre propre code :**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Prerequis :** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Le fichier `tdigest.rb` contient a la fois la bibliotheque et une demo dans le bloc `if __FILE__ == $PROGRAM_NAME`. Pour l'utiliser comme bibliotheque :

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Prerequis :** GNAT (compilateur Ada de GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Le package est divise en `tdigest.ads` (specification), `tdigest.adb` (corps) et le package generique d'arbre 2-3-4 `tree234.ads`/`tree234.adb`. Pour l'utiliser dans votre propre projet, ajoutez `with TDigest;` dans votre source et compilez tous les fichiers ensemble.

---

### Common Lisp

**Prerequis :** SBCL ou toute implementation ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Pour une utilisation interactive :

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Prerequis :** CHICKEN Scheme (`csi`) ou tout Scheme R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Ou avec Guile :

```bash
guile demo.scm
```

Remarque : Les litteraux `+inf.0` et `-inf.0` sont utilises pour l'infini. Si votre implementation Scheme utilise des constantes differentes, vous devrez peut-etre ajuster les definitions de `+inf` et `-inf` en haut de `tdigest.scm`.

---

### Standard ML

**Prerequis :** MLton (pour la compilation) ou SML/NJ (pour une utilisation interactive)

**Avec MLton :**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Avec SML/NJ :**

```bash
cd sml/
sml demo.sml
```

Le fichier MLB (`demo.mlb`) liste la bibliotheque de base et les fichiers source pour le systeme de compilation de MLton.

---

### Prolog

**Prerequis :** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

La demo charge le module `tdigest` et s'execute automatiquement via la directive `:- initialization(main, main).`.

Pour une utilisation interactive :

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Prerequis :** Compilateur Mercury (`mmc`)

**Version purement fonctionnelle** (finger tree) :

```bash
cd mercury/
mmc --make demo
./demo
```

**Version mutable** (arbre 2-3-4 avec types d'unicite) :

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Le systeme de compilation Mercury compile automatiquement les dependances (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, etc.).

---

### C

**Prerequis :** GCC ou Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Prerequis :** G++ ou Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Prerequis :** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Prerequis :** Cargo et toolchain Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**Prerequis :** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Prerequis :** Compilateur Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Prerequis :** Python 3 (aucune dependance externe)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Prerequis :** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Prerequis :** Compilateur OCaml avec ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Prerequis :** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Prerequis :** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Prerequis :** GFortran ou un autre compilateur Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Prerequis :** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Prerequis :** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Prerequis :** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Prerequis :** Compilateur Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Prerequis :** Compilateur Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Prerequis :** DMD ou LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Prerequis :** .NET SDK ou Mono

**Avec .NET SDK :**

```bash
cd csharp/
dotnet run
```

**Avec Mono :**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Prerequis :** Compilateur Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
