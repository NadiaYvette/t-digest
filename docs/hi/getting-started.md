# आरंभ करें

## पूर्वापेक्षाएँ

t-digest भंडार में 28 प्रोग्रामिंग भाषाओं के कार्यान्वयन हैं। प्रत्येक को चलाने के लिए संबंधित भाषा का संकलक या दुभाषिया स्थापित होना चाहिए।

```bash
# भंडार क्लोन करें
git clone <repository-url>
cd t-digest
```

## Haskell

Haskell कार्यान्वयन GHC संकलक का उपयोग करता है। अनुकूलन सक्षम करके संकलित करें:

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

## Ruby

Ruby कार्यान्वयन को किसी बाहरी पुस्तकालय की आवश्यकता नहीं है। प्रदर्शन चलाने के लिए:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada कार्यान्वयन GNAT संकलक का उपयोग करता है:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp कार्यान्वयन SBCL दुभाषिया का उपयोग करता है:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme कार्यान्वयन CHICKEN Scheme (csi) दुभाषिया के साथ R5RS मानक का उपयोग करता है:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

या Guile के साथ:

```bash
guile demo.scm
```

## Standard ML

Standard ML कार्यान्वयन MLton संकलक का उपयोग करता है:

**MLton के साथ:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ के साथ:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog कार्यान्वयन SWI-Prolog दुभाषिया का उपयोग करता है:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury कार्यान्वयन Melbourne Mercury संकलक का उपयोग करता है:

**शुद्ध फंक्शनल संस्करण** (फिंगर ट्री):

```bash
cd mercury/
mmc --make demo
./demo
```

**परिवर्तनीय संस्करण** (2-3-4 ट्री, यूनिकनेस प्रकारों के साथ):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**पूर्वापेक्षाएँ:** GCC या Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**पूर्वापेक्षाएँ:** G++ या Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**पूर्वापेक्षाएँ:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**पूर्वापेक्षाएँ:** Cargo और Rust टूलचेन

```bash
cd rust/
cargo run --release
```

---

## Java

**पूर्वापेक्षाएँ:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**पूर्वापेक्षाएँ:** Kotlin संकलक

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**पूर्वापेक्षाएँ:** Python 3 (कोई बाहरी निर्भरता नहीं)

```bash
cd python/
python3 demo.py
```

---

## Julia

**पूर्वापेक्षाएँ:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**पूर्वापेक्षाएँ:** OCaml संकलक और ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**पूर्वापेक्षाएँ:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**पूर्वापेक्षाएँ:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**पूर्वापेक्षाएँ:** GFortran या अन्य Fortran 2003+ संकलक

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**पूर्वापेक्षाएँ:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**पूर्वापेक्षाएँ:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**पूर्वापेक्षाएँ:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**पूर्वापेक्षाएँ:** Zig संकलक

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**पूर्वापेक्षाएँ:** Nim संकलक

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**पूर्वापेक्षाएँ:** DMD या LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**पूर्वापेक्षाएँ:** .NET SDK या Mono

**.NET SDK के साथ:**

```bash
cd csharp/
dotnet run
```

**Mono के साथ:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**पूर्वापेक्षाएँ:** Swift संकलक

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## सामान्य समस्या-निवारण

- **संकलक नहीं मिला** — सुनिश्चित करें कि संबंधित भाषा का संकलक या दुभाषिया आपके PATH में है
- **संकलन त्रुटि** — जाँचें कि आप सही निर्देशिका में हैं (`cd <भाषा>`)
- **अनुमति अस्वीकृत** — संकलित बाइनरी को चलाने की अनुमति दें: `chmod +x demo`
