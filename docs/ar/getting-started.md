<!-- ملاحظة: يجب عرض هذا المستند بتنسيق RTL. استخدم dir="rtl" في عنصر HTML المحتوي. -->

# البدء السريع

يحتوي هذا المشروع على تطبيقات t-digest بـ 28 لغة برمجة. كل تطبيق مستقل بذاته في مجلده الخاص ولا توجد اعتماديات بين اللغات. اتبع التعليمات أدناه لبناء وتشغيل كل تطبيق.

## استنساخ المستودع

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## البناء والتشغيل في كل لغة

### Haskell

**المتطلبات:** GHC، حزمتا `fingertree` و`vector`

**بدون أداة بناء (مستقل):**

```bash
cd haskell/
cabal install --lib fingertree vector  # one-time setup
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

**كحزمة Cabal (`dunning-t-digest`):**

```bash
cd haskell/
cabal build all
cabal run dunning-t-digest-demo
```

تكشف حزمة Cabal عن وحدتي مكتبة:
`Data.Sketch.TDigest` (صافية، مدعومة بشجرة الأصابع) و
`Data.Sketch.TDigest.Mutable` (قابلة للتعديل، ST monad مع متجهات).

**الاستخدام في شفرتك الخاصة:**

```haskell
import Data.Sketch.TDigest

main :: IO ()
main = do
  let td = foldl' (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

### Ruby

**المتطلبات:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

الملف `tdigest.rb` يحتوي على المكتبة والعرض التوضيحي في كتلة `if __FILE__ == $PROGRAM_NAME`. للاستخدام كمكتبة:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

### Ada

**المتطلبات:** GNAT (مترجم Ada من GNU)

```bash
cd ada/
gnatmake demo.adb
./demo
```

الحزمة مقسمة إلى `tdigest.ads` (المواصفات)، `tdigest.adb` (الجسم)، وحزمة الشجرة 2-3-4 العامة `tree234.ads`/`tree234.adb`. للاستخدام في مشروعك الخاص، أضف `with TDigest;` في مصدرك وارتب جميع الملفات معاً.

---

### Common Lisp

**المتطلبات:** SBCL، أو أي تطبيق ANSI Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

للاستخدام التفاعلي:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

### Scheme

**المتطلبات:** CHICKEN Scheme (`csi`)، أو أي Scheme يدعم R5RS/R7RS

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

أو مع Guile:

```bash
guile demo.scm
```

ملاحظة: يتم استخدام الثوابت `+inf.0` و`-inf.0` للدلالة على اللانهاية. إذا كان تطبيق Scheme الخاص بك يستخدم ثوابت مختلفة، فقد تحتاج إلى تعديل تعريفات `+inf` و`-inf` في أعلى `tdigest.scm`.

---

### Standard ML

**المتطلبات:** MLton (للترجمة) أو SML/NJ (للاستخدام التفاعلي)

**مع MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**مع SML/NJ:**

```bash
cd sml/
sml demo.sml
```

ملف MLB (`demo.mlb`) يسرد مكتبة basis والملفات المصدرية لنظام بناء MLton.

---

### Prolog

**المتطلبات:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

يقوم العرض التوضيحي بتحميل وحدة `tdigest` ويعمل تلقائياً عبر التوجيه `:- initialization(main, main).`.

للاستخدام التفاعلي:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

### Mercury

**المتطلبات:** مترجم Mercury (`mmc`)

**النسخة الوظيفية البحتة** (شجرة الأصابع):

```bash
cd mercury/
mmc --make demo
./demo
```

**النسخة القابلة للتعديل** (شجرة 2-3-4 مع أنواع التفرد):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

نظام بناء Mercury سيقوم تلقائياً بترجمة الاعتماديات (`tdigest.m`، `fingertree.m`، `measured_tree234.m`، إلخ).

---

### C

**المتطلبات:** GCC أو Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

### C++

**المتطلبات:** G++ أو Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

### Go

**المتطلبات:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

### Rust

**المتطلبات:** Cargo وسلسلة أدوات Rust

```bash
cd rust/
cargo run --release
```

---

### Java

**المتطلبات:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

### Kotlin

**المتطلبات:** مترجم Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

### Python

**المتطلبات:** Python 3 (بدون اعتماديات خارجية)

```bash
cd python/
python3 demo.py
```

---

### Julia

**المتطلبات:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

### OCaml

**المتطلبات:** مترجم OCaml مع ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

### Erlang

**المتطلبات:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

### Elixir

**المتطلبات:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

### Fortran

**المتطلبات:** GFortran أو أي مترجم Fortran 2003+

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

### Perl

**المتطلبات:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

### Lua

**المتطلبات:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

### R

**المتطلبات:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

### Zig

**المتطلبات:** مترجم Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

### Nim

**المتطلبات:** مترجم Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

### D

**المتطلبات:** DMD أو LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

### C#

**المتطلبات:** .NET SDK أو Mono

**مع .NET SDK:**

```bash
cd csharp/
dotnet run
```

**مع Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

### Swift

**المتطلبات:** مترجم Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```

## مخرجات العرض التوضيحي

يقوم كل عرض توضيحي بتنفيذ الخطوات التالية:

1. تهيئة t-digest
2. إضافة بيانات نموذجية
3. حساب وعرض شرائح مئوية مختلفة (الوسيط، p90، p99 وغيرها)
4. عرض مقارنة بين القيم المقدّرة والقيم النظرية
