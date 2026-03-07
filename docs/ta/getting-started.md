# தொடங்குதல்

## முன்நிபந்தனைகள்

t-digest களஞ்சியத்தில் 28 நிரலாக்க மொழிகளில் செயலாக்கம் உள்ளது. ஒவ்வொன்றையும் இயக்க அந்தந்த மொழியின் தொகுப்பி அல்லது மொழிபெயர்ப்பி நிறுவப்பட்டிருக்க வேண்டும்.

```bash
# களஞ்சியத்தை நகலெடுக்கவும்
git clone <repository-url>
cd t-digest
```

## Haskell

Haskell செயலாக்கம் GHC தொகுப்பியைப் பயன்படுத்துகிறது. மேம்படுத்தலுடன் தொகுக்கவும்:

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

## Ruby

Ruby செயலாக்கத்திற்கு வெளிப்புற நூலகம் எதுவும் தேவையில்லை. செயல்விளக்கம் இயக்க:

```bash
cd ruby/
ruby tdigest.rb
```

## Ada

Ada செயலாக்கம் GNAT தொகுப்பியைப் பயன்படுத்துகிறது:

```bash
cd ada/
gnatmake demo.adb
./demo
```

## Common Lisp

Common Lisp செயலாக்கம் SBCL மொழிபெயர்ப்பியைப் பயன்படுத்துகிறது:

```bash
cd common-lisp/
sbcl --script demo.lisp
```

## Scheme

Scheme செயலாக்கம் CHICKEN Scheme (csi) மொழிபெயர்ப்பியுடன் R5RS தரநிலையைப் பயன்படுத்துகிறது:

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

அல்லது Guile உடன்:

```bash
guile demo.scm
```

## Standard ML

Standard ML செயலாக்கம் MLton தொகுப்பியைப் பயன்படுத்துகிறது:

**MLton உடன்:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**SML/NJ உடன்:**

```bash
cd sml/
sml demo.sml
```

## Prolog

Prolog செயலாக்கம் SWI-Prolog மொழிபெயர்ப்பியைப் பயன்படுத்துகிறது:

```bash
cd prolog/
swipl demo.pl
```

## Mercury

Mercury செயலாக்கம் Melbourne Mercury தொகுப்பியைப் பயன்படுத்துகிறது:

**தூய செயல்பாட்டு பதிப்பு** (விரல் மரம்):

```bash
cd mercury/
mmc --make demo
./demo
```

**மாறக்கூடிய பதிப்பு** (2-3-4 மரம், தனித்துவ வகைகளுடன்):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

---

## C

**முன்நிபந்தனைகள்:** GCC அல்லது Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**முன்நிபந்தனைகள்:** G++ அல்லது Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**முன்நிபந்தனைகள்:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**முன்நிபந்தனைகள்:** Cargo மற்றும் Rust கருவித்தொகுப்பு

```bash
cd rust/
cargo run --release
```

---

## Java

**முன்நிபந்தனைகள்:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**முன்நிபந்தனைகள்:** Kotlin தொகுப்பி

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**முன்நிபந்தனைகள்:** Python 3 (வெளிப்புற சார்புகள் இல்லை)

```bash
cd python/
python3 demo.py
```

---

## Julia

**முன்நிபந்தனைகள்:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**முன்நிபந்தனைகள்:** OCaml தொகுப்பி மற்றும் ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**முன்நிபந்தனைகள்:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**முன்நிபந்தனைகள்:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**முன்நிபந்தனைகள்:** GFortran அல்லது பிற Fortran 2003+ தொகுப்பி

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**முன்நிபந்தனைகள்:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**முன்நிபந்தனைகள்:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**முன்நிபந்தனைகள்:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**முன்நிபந்தனைகள்:** Zig தொகுப்பி

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**முன்நிபந்தனைகள்:** Nim தொகுப்பி

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**முன்நிபந்தனைகள்:** DMD அல்லது LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**முன்நிபந்தனைகள்:** .NET SDK அல்லது Mono

**.NET SDK உடன்:**

```bash
cd csharp/
dotnet run
```

**Mono உடன்:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**முன்நிபந்தனைகள்:** Swift தொகுப்பி

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

---

## பொதுவான சிக்கல் தீர்வு

- **தொகுப்பி கிடைக்கவில்லை** — சம்பந்தப்பட்ட மொழியின் தொகுப்பி அல்லது மொழிபெயர்ப்பி உங்கள் PATH-ல் உள்ளதா என உறுதிசெய்யவும்
- **தொகுப்புப் பிழை** — நீங்கள் சரியான அடைவில் உள்ளீர்களா என சரிபார்க்கவும் (`cd <மொழி>`)
- **அனுமதி மறுக்கப்பட்டது** — தொகுக்கப்பட்ட இருமக் கோப்பை இயக்க அனுமதி அளிக்கவும்: `chmod +x demo`
