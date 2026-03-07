# Erste Schritte

Dieses Projekt enthält t-digest-Implementierungen in 28 Programmiersprachen. Jede Implementierung verwendet die Merging-Digest-Variante mit der K_1-Skalierungsfunktion (Arkussinus).

## Bauen und Ausführen

### Haskell

**Voraussetzungen:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Das Modul `TDigest` verwendet nur `base`-Bibliotheken (kein Cabal- oder Stack-Projekt erforderlich).

**Verwendung im eigenen Code:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Voraussetzungen:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Die Datei `tdigest.rb` enthält sowohl die Bibliothek als auch eine Demo im `if __FILE__ == $PROGRAM_NAME`-Block. Zur Verwendung als Bibliothek:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Voraussetzungen:** GNAT (GCC Ada-Compiler)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Das Paket ist aufgeteilt in `tdigest.ads` (Spezifikation), `tdigest.adb` (Implementierung) und das generische `tree234.ads`/`tree234.adb` 2-3-4-Baum-Paket. Zur Verwendung im eigenen Projekt `with TDigest;` in der Quelle angeben und alle Dateien zusammen kompilieren.

---

### Common Lisp

**Voraussetzungen:** SBCL oder jede ANSI-Common-Lisp-Implementierung

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Zur interaktiven Verwendung:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Voraussetzungen:** CHICKEN Scheme (`csi`) oder jedes R5RS/R7RS-Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Oder mit Guile:

```bash
guile demo.scm
```

Hinweis: Die Literale `+inf.0` und `-inf.0` werden fuer Unendlich verwendet. Falls Ihre Scheme-Implementierung andere Konstanten verwendet, muessen Sie die Definitionen von `+inf` und `-inf` am Anfang von `tdigest.scm` anpassen.

---

### Standard ML

**Voraussetzungen:** MLton (zur Kompilierung) oder SML/NJ (zur interaktiven Verwendung)

**Mit MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Mit SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Die MLB-Datei (`demo.mlb`) listet die Basisbibliothek und Quelldateien fuer MLtons Build-System auf.

---

### Prolog

**Voraussetzungen:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Die Demo laedt das `tdigest`-Modul und startet automatisch ueber die `:- initialization(main, main).`-Direktive.

Zur interaktiven Verwendung:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Voraussetzungen:** Mercury-Compiler (`mmc`)

**Rein funktionale Version** (Finger Tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Mutable Version** (2-3-4-Baum mit Uniqueness-Typen):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Das Mercury-Build-System kompiliert automatisch Abhaengigkeiten (`tdigest.m`, `fingertree.m`, `measured_tree234.m` usw.).

---

### C

**Voraussetzungen:** GCC oder Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Voraussetzungen:** G++ oder Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Voraussetzungen:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Voraussetzungen:** Cargo und Rust-Toolchain

```bash
cd rust/
cargo run --release
```

---

### Java

**Voraussetzungen:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Voraussetzungen:** Kotlin-Compiler

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Voraussetzungen:** Python 3 (keine externen Abhaengigkeiten)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Voraussetzungen:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Voraussetzungen:** OCaml-Compiler mit ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Voraussetzungen:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Voraussetzungen:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Voraussetzungen:** GFortran oder ein anderer Fortran-2003+-Compiler

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Voraussetzungen:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Voraussetzungen:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Voraussetzungen:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Voraussetzungen:** Zig-Compiler

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Voraussetzungen:** Nim-Compiler

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Voraussetzungen:** DMD oder LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Voraussetzungen:** .NET SDK oder Mono

**Mit .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Mit Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Voraussetzungen:** Swift-Compiler

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
