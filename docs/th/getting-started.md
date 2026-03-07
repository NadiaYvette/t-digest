# เริ่มต้นใช้งาน

การนำไปใช้งานในแต่ละภาษาจะอยู่ในไดเรกทอรีของตัวเองอย่างอิสระ
ไม่มีการพึ่งพาข้ามภาษา

---

## Haskell

**สิ่งที่ต้องมี:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

โมดูล `TDigest` ใช้เฉพาะไลบรารี `base` เท่านั้น (ไม่ต้องการโปรเจกต์ Cabal หรือ Stack)

**การใช้งานในโค้ดของคุณ:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**สิ่งที่ต้องมี:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

ไฟล์ `tdigest.rb` ประกอบด้วยทั้งไลบรารีและโปรแกรมสาธิต (ในบล็อก `if __FILE__ == $PROGRAM_NAME`) หากต้องการใช้เป็นไลบรารี:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**สิ่งที่ต้องมี:** GNAT (คอมไพเลอร์ Ada ของ GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

แพ็กเกจแบ่งออกเป็น `tdigest.ads` (สเปค), `tdigest.adb` (บอดี้) และแพ็กเกจต้นไม้ 2-3-4 แบบเจเนอริก `tree234.ads`/`tree234.adb` หากต้องการใช้ในโปรเจกต์ของคุณ ให้เขียน `with TDigest;` ในซอร์สโค้ดและคอมไพล์ไฟล์ทั้งหมดด้วยกัน

---

## Common Lisp

**สิ่งที่ต้องมี:** SBCL หรือ ANSI Common Lisp ใดก็ได้

```bash
cd common-lisp/
sbcl --script demo.lisp
```

การใช้งานแบบโต้ตอบ:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**สิ่งที่ต้องมี:** CHICKEN Scheme (`csi`) หรือ Scheme R5RS/R7RS ใดก็ได้

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

หรือใช้ Guile:

```bash
guile demo.scm
```

หมายเหตุ: ใช้ลิเทอรัล `+inf.0` และ `-inf.0` สำหรับค่าอินฟินิตี้ หากการนำ Scheme ไปใช้งานของคุณใช้ค่าคงที่อื่น อาจต้องปรับแก้คำจำกัดความของ `+inf` และ `-inf` ที่ด้านบนของ `tdigest.scm`

---

## Standard ML

**สิ่งที่ต้องมี:** MLton (สำหรับคอมไพล์) หรือ SML/NJ (สำหรับใช้แบบโต้ตอบ)

**ใช้ MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**ใช้ SML/NJ:**

```bash
cd sml/
sml demo.sml
```

ไฟล์ MLB (`demo.mlb`) ระบุไลบรารี basis และไฟล์ซอร์สสำหรับระบบบิลด์ของ MLton

---

## Prolog

**สิ่งที่ต้องมี:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

โปรแกรมสาธิตโหลดโมดูล `tdigest` และทำงานอัตโนมัติผ่านไดเร็กทีฟ `:- initialization(main, main).`

การใช้งานแบบโต้ตอบ:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**สิ่งที่ต้องมี:** คอมไพเลอร์ Mercury (`mmc`)

**เวอร์ชันฟังก์ชันนอลล้วน** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**เวอร์ชัน mutable** (ต้นไม้ 2-3-4 พร้อมประเภทความเป็นเอกลักษณ์):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

ระบบบิลด์ของ Mercury จะคอมไพล์ดีเพนเดนซี (`tdigest.m`, `fingertree.m`, `measured_tree234.m` ฯลฯ) โดยอัตโนมัติ

---

## C

**สิ่งที่ต้องมี:** GCC หรือ Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**สิ่งที่ต้องมี:** G++ หรือ Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**สิ่งที่ต้องมี:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**สิ่งที่ต้องมี:** Cargo และชุดเครื่องมือ Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**สิ่งที่ต้องมี:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**สิ่งที่ต้องมี:** คอมไพเลอร์ Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**สิ่งที่ต้องมี:** Python 3 (ไม่มีการพึ่งพาภายนอก)

```bash
cd python/
python3 demo.py
```

---

## Julia

**สิ่งที่ต้องมี:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**สิ่งที่ต้องมี:** คอมไพเลอร์ OCaml และ ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**สิ่งที่ต้องมี:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**สิ่งที่ต้องมี:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**สิ่งที่ต้องมี:** GFortran หรือคอมไพเลอร์ Fortran 2003 ขึ้นไป

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**สิ่งที่ต้องมี:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**สิ่งที่ต้องมี:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**สิ่งที่ต้องมี:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**สิ่งที่ต้องมี:** คอมไพเลอร์ Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**สิ่งที่ต้องมี:** คอมไพเลอร์ Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**สิ่งที่ต้องมี:** DMD หรือ LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**สิ่งที่ต้องมี:** .NET SDK หรือ Mono

**ใช้ .NET SDK:**

```bash
cd csharp/
dotnet run
```

**ใช้ Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**สิ่งที่ต้องมี:** คอมไพเลอร์ Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
