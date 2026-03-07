# શરૂઆત કરો

## પૂર્વજરૂરિયાતો

t-digest ભંડારમાં 28 પ્રોગ્રામિંગ ભાષાઓમાં અમલીકરણ છે. દરેકને ચલાવવા માટે સંબંધિત ભાષાનું સંકલક કે દુભાષિયું સ્થાપિત હોવું જોઈએ.

```bash
# ભંડાર ક્લોન કરો
git clone <repository-url>
cd t-digest
```

## Haskell

Haskell અમલીકરણ GHC સંકલકનો ઉપયોગ કરે છે. શ્રેષ્ઠીકરણ સાથે સંકલન કરો:

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

## Ruby

Ruby અમલીકરણને કોઈ બાહ્ય પુસ્તકાલયની જરૂર નથી. પ્રદર્શન ચલાવવા:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada અમલીકરણ GNAT સંકલકનો ઉપયોગ કરે છે:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp અમલીકરણ SBCL દુભાષિયાનો ઉપયોગ કરે છે:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme અમલીકરણ CHICKEN Scheme (csi) દુભાષિયા સાથે R5RS માનકનો ઉપયોગ કરે છે:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

અથવા Guile સાથે:

```bash
guile demo.scm
```

## Standard ML

Standard ML અમલીકરણ MLton સંકલકનો ઉપયોગ કરે છે:

**MLton સાથે:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ સાથે:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog અમલીકરણ SWI-Prolog દુભાષિયાનો ઉપયોગ કરે છે:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury અમલીકરણ Melbourne Mercury સંકલકનો ઉપયોગ કરે છે:

**શુદ્ધ કાર્યાત્મક સંસ્કરણ** (ફિંગર ટ્રી):

```bash
cd mercury/
mmc --make demo
./demo
```

**પરિવર્તનશીલ સંસ્કરણ** (2-3-4 ટ્રી, યુનિકનેસ ટાઈપ સાથે):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**પૂર્વજરૂરિયાતો:** GCC અથવા Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**પૂર્વજરૂરિયાતો:** G++ અથવા Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**પૂર્વજરૂરિયાતો:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**પૂર્વજરૂરિયાતો:** Cargo અને Rust ટૂલચેઇન

```bash
cd rust/
cargo run --release
```

---

## Java

**પૂર્વજરૂરિયાતો:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**પૂર્વજરૂરિયાતો:** Kotlin સંકલક

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**પૂર્વજરૂરિયાતો:** Python 3 (કોઈ બાહ્ય નિર્ભરતા નથી)

```bash
cd python/
python3 demo.py
```

---

## Julia

**પૂર્વજરૂરિયાતો:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**પૂર્વજરૂરિયાતો:** OCaml સંકલક અને ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**પૂર્વજરૂરિયાતો:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**પૂર્વજરૂરિયાતો:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**પૂર્વજરૂરિયાતો:** GFortran અથવા અન્ય Fortran 2003+ સંકલક

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**પૂર્વજરૂરિયાતો:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**પૂર્વજરૂરિયાતો:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**પૂર્વજરૂરિયાતો:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**પૂર્વજરૂરિયાતો:** Zig સંકલક

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**પૂર્વજરૂરિયાતો:** Nim સંકલક

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**પૂર્વજરૂરિયાતો:** DMD અથવા LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**પૂર્વજરૂરિયાતો:** .NET SDK અથવા Mono

**.NET SDK સાથે:**

```bash
cd csharp/
dotnet run
```

**Mono સાથે:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**પૂર્વજરૂરિયાતો:** Swift સંકલક

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## સામાન્ય સમસ્યા-નિવારણ

- **સંકલક મળ્યું નહીં** — ખાતરી કરો કે સંબંધિત ભાષાનું સંકલક કે દુભાષિયું તમારા PATH માં છે
- **સંકલન ત્રુટિ** — ચકાસો કે તમે યોગ્ય ડિરેક્ટરીમાં છો (`cd <ભાષા>`)
- **પરવાનગી નકારી** — સંકલિત બાઈનરીને ચલાવવાની પરવાનગી આપો: `chmod +x demo`
