# Primeiros passos

Este projeto contem implementacoes do t-digest em 28 linguagens de programacao. Cada implementacao utiliza a variante merging digest com a funcao de escala K_1 (arco seno).

## Compilar e executar

### Haskell

**Pre-requisitos:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

O modulo `TDigest` utiliza apenas bibliotecas `base` (nenhum projeto Cabal ou Stack e necessario).

**Utilizacao no seu proprio codigo:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**Pre-requisitos:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

O arquivo `tdigest.rb` contem tanto a biblioteca como uma demo no bloco `if __FILE__ == $PROGRAM_NAME`. Para utilizar como biblioteca:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**Pre-requisitos:** GNAT (compilador Ada do GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

O pacote esta dividido em `tdigest.ads` (especificacao), `tdigest.adb` (corpo) e o pacote generico de arvore 2-3-4 `tree234.ads`/`tree234.adb`. Para utilizar no seu proprio projeto, inclua `with TDigest;` no seu codigo fonte e compile todos os arquivos juntos.

---

### Common Lisp

**Pre-requisitos:** SBCL ou qualquer implementacao ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Para uso interativo:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**Pre-requisitos:** CHICKEN Scheme (`csi`) ou qualquer Scheme R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Ou com Guile:

```bash
guile demo.scm
```

Nota: Os literais `+inf.0` e `-inf.0` sao utilizados para o infinito. Se a sua implementacao Scheme usar constantes diferentes, pode ser necessario ajustar as definicoes de `+inf` e `-inf` no inicio de `tdigest.scm`.

---

### Standard ML

**Pre-requisitos:** MLton (para compilacao) ou SML/NJ (para uso interativo)

**Com MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Com SML/NJ:**

```bash
cd sml/
sml demo.sml
```

O arquivo MLB (`demo.mlb`) lista a biblioteca base e os arquivos fonte para o sistema de compilacao do MLton.

---

### Prolog

**Pre-requisitos:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

A demo carrega o modulo `tdigest` e e executada automaticamente atraves da diretiva `:- initialization(main, main).`.

Para uso interativo:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**Pre-requisitos:** Compilador Mercury (`mmc`)

**Versao puramente funcional** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Versao mutavel** (arvore 2-3-4 com tipos de unicidade):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

O sistema de compilacao Mercury compila automaticamente as dependencias (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, etc.).

---

### C

**Pre-requisitos:** GCC ou Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**Pre-requisitos:** G++ ou Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**Pre-requisitos:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**Pre-requisitos:** Cargo e toolchain Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**Pre-requisitos:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**Pre-requisitos:** Compilador Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**Pre-requisitos:** Python 3 (sem dependencias externas)

```bash
cd python/
python3 demo.py
```

---

### Julia

**Pre-requisitos:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**Pre-requisitos:** Compilador OCaml com ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**Pre-requisitos:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**Pre-requisitos:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**Pre-requisitos:** GFortran ou outro compilador Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**Pre-requisitos:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**Pre-requisitos:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**Pre-requisitos:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**Pre-requisitos:** Compilador Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**Pre-requisitos:** Compilador Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**Pre-requisitos:** DMD ou LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**Pre-requisitos:** .NET SDK ou Mono

**Com .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Com Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**Pre-requisitos:** Compilador Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
