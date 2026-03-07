# सुरुवात करा

## पूर्वअटी

t-digest भांडारात 28 प्रोग्रामिंग भाषांमध्ये अंमलबजावणी आहे. प्रत्येक चालवण्यासाठी संबंधित भाषेचा संकलक किंवा दुभाषक स्थापित असणे आवश्यक आहे.

```bash
# भांडार क्लोन करा
git clone <repository-url>
cd t-digest
```

## Haskell

Haskell अंमलबजावणी GHC संकलक वापरते. अनुकूलन सक्षम करून संकलन करा:

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

## Ruby

Ruby अंमलबजावणीला कोणत्याही बाह्य ग्रंथालयाची गरज नाही. प्रात्यक्षिक चालवण्यासाठी:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada अंमलबजावणी GNAT संकलक वापरते:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp अंमलबजावणी SBCL दुभाषक वापरते:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme अंमलबजावणी CHICKEN Scheme (csi) दुभाषक आणि R5RS मानक वापरते:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

किंवा Guile सोबत:

```bash
guile demo.scm
```

## Standard ML

Standard ML अंमलबजावणी MLton संकलक वापरते:

**MLton सोबत:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ सोबत:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog अंमलबजावणी SWI-Prolog दुभाषक वापरते:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury अंमलबजावणी Melbourne Mercury संकलक वापरते:

**शुद्ध कार्यात्मक आवृत्ती** (फिंगर ट्री):

```bash
cd mercury/
mmc --make demo
./demo
```

**परिवर्तनीय आवृत्ती** (2-3-4 ट्री, युनिकनेस टाईप्ससह):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**पूर्वअटी:** GCC किंवा Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**पूर्वअटी:** G++ किंवा Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**पूर्वअटी:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**पूर्वअटी:** Cargo आणि Rust टूलचेन

```bash
cd rust/
cargo run --release
```

---

## Java

**पूर्वअटी:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**पूर्वअटी:** Kotlin संकलक

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**पूर्वअटी:** Python 3 (कोणतीही बाह्य अवलंबित्वे नाहीत)

```bash
cd python/
python3 demo.py
```

---

## Julia

**पूर्वअटी:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**पूर्वअटी:** OCaml संकलक आणि ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**पूर्वअटी:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**पूर्वअटी:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**पूर्वअटी:** GFortran किंवा इतर Fortran 2003+ संकलक

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**पूर्वअटी:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**पूर्वअटी:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**पूर्वअटी:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**पूर्वअटी:** Zig संकलक

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**पूर्वअटी:** Nim संकलक

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**पूर्वअटी:** DMD किंवा LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**पूर्वअटी:** .NET SDK किंवा Mono

**.NET SDK सोबत:**

```bash
cd csharp/
dotnet run
```

**Mono सोबत:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**पूर्वअटी:** Swift संकलक

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## सामान्य समस्या-निवारण

- **संकलक सापडला नाही** — खात्री करा की संबंधित भाषेचा संकलक किंवा दुभाषक तुमच्या PATH मध्ये आहे
- **संकलन त्रुटी** — तपासा की तुम्ही योग्य निर्देशिकेत आहात (`cd <भाषा>`)
- **परवानगी नाकारली** — संकलित बायनरीला चालवण्याची परवानगी द्या: `chmod +x demo`
