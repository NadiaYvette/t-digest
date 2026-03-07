<!-- توجه: این سند باید با قالب‌بندی RTL نمایش داده شود. از dir="rtl" در عنصر HTML محتوی استفاده کنید. -->

# شروع سریع

این پروژه شامل پیاده‌سازی t-digest در ۲۸ زبان برنامه‌نویسی است. هر پیاده‌سازی مستقل در پوشه خودش قرار دارد و وابستگی بین زبانی وجود ندارد. دستورالعمل‌های زیر را برای ساخت و اجرای هر پیاده‌سازی دنبال کنید.

## شبیه‌سازی مخزن

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## ساخت و اجرا در هر زبان

### Haskell

**پیش‌نیازها:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

ماژول `TDigest` فقط از کتابخانه‌های `base` استفاده می‌کند (نیازی به پروژه Cabal یا Stack نیست).

**استفاده در کد خودتان:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**پیش‌نیازها:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

فایل `tdigest.rb` شامل هم کتابخانه و هم نمونه اجرایی در بلوک `if __FILE__ == $PROGRAM_NAME` است. برای استفاده به عنوان کتابخانه:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**پیش‌نیازها:** GNAT (کامپایلر Ada از GNU)

```bash
cd ada/
gnatmake demo.adb
./demo
```

بسته به `tdigest.ads` (مشخصات)، `tdigest.adb` (بدنه) و بسته عمومی درخت 2-3-4 `tree234.ads`/`tree234.adb` تقسیم شده است. برای استفاده در پروژه خودتان، `with TDigest;` را در منبع خود بنویسید و همه فایل‌ها را با هم کامپایل کنید.

---

### Common Lisp

**پیش‌نیازها:** SBCL، یا هر پیاده‌سازی ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

برای استفاده تعاملی:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**پیش‌نیازها:** CHICKEN Scheme (`csi`)، یا هر Scheme سازگار با R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

یا با Guile:

```bash
guile demo.scm
```

توجه: از ثابت‌های `+inf.0` و `-inf.0` برای بی‌نهایت استفاده شده است. اگر پیاده‌سازی Scheme شما از ثابت‌های دیگری استفاده می‌کند، ممکن است نیاز باشد تعریف‌های `+inf` و `-inf` در بالای `tdigest.scm` را تغییر دهید.

---

### Standard ML

**پیش‌نیازها:** MLton (برای کامپایل) یا SML/NJ (برای استفاده تعاملی)

**با MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**با SML/NJ:**

```bash
cd sml/
sml demo.sml
```

فایل MLB (`demo.mlb`) کتابخانه basis و فایل‌های منبع را برای سیستم ساخت MLton فهرست می‌کند.

---

### Prolog

**پیش‌نیازها:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

نمونه اجرایی ماژول `tdigest` را بارگذاری می‌کند و به طور خودکار از طریق دستور `:- initialization(main, main).` اجرا می‌شود.

برای استفاده تعاملی:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**پیش‌نیازها:** کامپایلر Mercury (`mmc`)

**نسخه تابعی خالص** (درخت انگشتی):

```bash
cd mercury/
mmc --make demo
./demo
```

**نسخه تغییرپذیر** (درخت 2-3-4 با انواع یکتایی):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

سیستم ساخت Mercury به طور خودکار وابستگی‌ها (`tdigest.m`، `fingertree.m`، `measured_tree234.m` و غیره) را کامپایل می‌کند.

---

### C

**پیش‌نیازها:** GCC یا Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**پیش‌نیازها:** G++ یا Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**پیش‌نیازها:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**پیش‌نیازها:** Cargo و زنجیره ابزار Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**پیش‌نیازها:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**پیش‌نیازها:** کامپایلر Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**پیش‌نیازها:** Python 3 (بدون وابستگی خارجی)

```bash
cd python/
python3 demo.py
```

---

### Julia

**پیش‌نیازها:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**پیش‌نیازها:** کامپایلر OCaml با ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**پیش‌نیازها:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**پیش‌نیازها:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**پیش‌نیازها:** GFortran یا هر کامپایلر Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**پیش‌نیازها:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**پیش‌نیازها:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**پیش‌نیازها:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**پیش‌نیازها:** کامپایلر Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**پیش‌نیازها:** کامپایلر Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**پیش‌نیازها:** DMD یا LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**پیش‌نیازها:** .NET SDK یا Mono

**با .NET SDK:**

```bash
cd csharp/
dotnet run
```

**با Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**پیش‌نیازها:** کامپایلر Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## خروجی نمونه‌ها

هر نمونه مراحل زیر را انجام می‌دهد:

1. مقداردهی اولیه t-digest
2. افزودن داده‌های نمونه
3. محاسبه و نمایش چندک‌های مختلف (میانه، p90، p99 و غیره)
4. نمایش مقایسه بین مقادیر تخمینی و مقادیر نظری
