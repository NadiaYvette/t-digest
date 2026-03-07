# শুরু করুন

## পূর্বশর্ত

t-digest ভাণ্ডারে 28টি প্রোগ্রামিং ভাষায় বাস্তবায়ন রয়েছে। প্রতিটি চালাতে সংশ্লিষ্ট ভাষার সংকলক বা দোভাষী ইনস্টল থাকতে হবে।

```bash
# ভাণ্ডার ক্লোন করুন
git clone <repository-url>
cd t-digest
```

## Haskell

Haskell বাস্তবায়ন GHC সংকলক ব্যবহার করে। পরিমার্জন সক্রিয় করে সংকলন করুন:

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

## Ruby

Ruby বাস্তবায়নের কোনো বাহ্যিক গ্রন্থাগারের প্রয়োজন নেই। প্রদর্শনী চালাতে:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada বাস্তবায়ন GNAT সংকলক ব্যবহার করে:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp বাস্তবায়ন SBCL দোভাষী ব্যবহার করে:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme বাস্তবায়ন CHICKEN Scheme (csi) দোভাষী এবং R5RS মানক ব্যবহার করে:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

অথবা Guile-এর সাথে:

```bash
guile demo.scm
```

## Standard ML

Standard ML বাস্তবায়ন MLton সংকলক ব্যবহার করে:

**MLton-এর সাথে:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ-এর সাথে:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog বাস্তবায়ন SWI-Prolog দোভাষী ব্যবহার করে:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury বাস্তবায়ন Melbourne Mercury সংকলক ব্যবহার করে:

**বিশুদ্ধ কার্যকরী সংস্করণ** (ফিঙ্গার ট্রি):

```bash
cd mercury/
mmc --make demo
./demo
```

**পরিবর্তনযোগ্য সংস্করণ** (2-3-4 ট্রি, ইউনিকনেস টাইপ সহ):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**পূর্বশর্ত:** GCC বা Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**পূর্বশর্ত:** G++ বা Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**পূর্বশর্ত:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**পূর্বশর্ত:** Cargo এবং Rust টুলচেইন

```bash
cd rust/
cargo run --release
```

---

## Java

**পূর্বশর্ত:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**পূর্বশর্ত:** Kotlin সংকলক

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**পূর্বশর্ত:** Python 3 (কোনো বাহ্যিক নির্ভরতা নেই)

```bash
cd python/
python3 demo.py
```

---

## Julia

**পূর্বশর্ত:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**পূর্বশর্ত:** OCaml সংকলক এবং ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**পূর্বশর্ত:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**পূর্বশর্ত:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**পূর্বশর্ত:** GFortran বা অন্য Fortran 2003+ সংকলক

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**পূর্বশর্ত:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**পূর্বশর্ত:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**পূর্বশর্ত:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**পূর্বশর্ত:** Zig সংকলক

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**পূর্বশর্ত:** Nim সংকলক

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**পূর্বশর্ত:** DMD বা LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**পূর্বশর্ত:** .NET SDK বা Mono

**.NET SDK-এর সাথে:**

```bash
cd csharp/
dotnet run
```

**Mono-র সাথে:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**পূর্বশর্ত:** Swift সংকলক

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## সাধারণ সমস্যা সমাধান

- **সংকলক পাওয়া যায়নি** — নিশ্চিত করুন সংশ্লিষ্ট ভাষার সংকলক বা দোভাষী আপনার PATH-এ আছে
- **সংকলন ত্রুটি** — যাচাই করুন আপনি সঠিক ডিরেক্টরিতে আছেন (`cd <ভাষা>`)
- **অনুমতি অস্বীকৃত** — সংকলিত বাইনারি চালানোর অনুমতি দিন: `chmod +x demo`
