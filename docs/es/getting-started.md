# Primeros pasos

Este proyecto contiene implementaciones del t-digest en 28 lenguajes de programacion. Cada implementacion utiliza la variante merging digest con la funcion de escala K_1 (arcoseno).

## Compilar y ejecutar

### Haskell

**Requisitos:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

El modulo `TDigest` utiliza solo bibliotecas `base` (no se requiere proyecto Cabal ni Stack).

**Uso en su propio codigo:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Requisitos:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

El archivo `tdigest.rb` contiene tanto la biblioteca como una demo en el bloque `if __FILE__ == $PROGRAM_NAME`. Para usarlo como biblioteca:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Requisitos:** GNAT (compilador Ada de GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

El paquete se divide en `tdigest.ads` (especificacion), `tdigest.adb` (cuerpo) y el paquete generico de arbol 2-3-4 `tree234.ads`/`tree234.adb`. Para usarlo en su propio proyecto, incluya `with TDigest;` en su codigo fuente y compile todos los archivos juntos.

---

### Common Lisp

**Requisitos:** SBCL o cualquier implementacion ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Para uso interactivo:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Requisitos:** CHICKEN Scheme (`csi`) o cualquier Scheme R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

O con Guile:

```bash
guile demo.scm
```

Nota: Se utilizan los literales `+inf.0` y `-inf.0` para el infinito. Si su implementacion de Scheme usa constantes diferentes, es posible que necesite ajustar las definiciones de `+inf` y `-inf` al inicio de `tdigest.scm`.

---

### Standard ML

**Requisitos:** MLton (para compilacion) o SML/NJ (para uso interactivo)

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

El archivo MLB (`demo.mlb`) lista la biblioteca base y los archivos fuente para el sistema de compilacion de MLton.

---

### Prolog

**Requisitos:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

La demo carga el modulo `tdigest` y se ejecuta automaticamente mediante la directiva `:- initialization(main, main).`.

Para uso interactivo:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Requisitos:** Compilador Mercury (`mmc`)

**Version puramente funcional** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Version mutable** (arbol 2-3-4 con tipos de unicidad):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

El sistema de compilacion de Mercury compila automaticamente las dependencias (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, etc.).

---

### C

**Requisitos:** GCC o Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Requisitos:** G++ o Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Requisitos:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Requisitos:** Cargo y toolchain de Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**Requisitos:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Requisitos:** Compilador Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Requisitos:** Python 3 (sin dependencias externas)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Requisitos:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Requisitos:** Compilador OCaml con ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Requisitos:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Requisitos:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Requisitos:** GFortran u otro compilador Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Requisitos:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Requisitos:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Requisitos:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Requisitos:** Compilador Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Requisitos:** Compilador Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Requisitos:** DMD o LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Requisitos:** .NET SDK o Mono

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

**Requisitos:** Compilador Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
