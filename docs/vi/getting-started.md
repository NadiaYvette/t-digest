# Bắt đầu nhanh

Mỗi bản triển khai theo từng ngôn ngữ được chứa độc lập trong thư mục riêng.
Không có sự phụ thuộc chéo giữa các ngôn ngữ.

---

## Haskell

**Điều kiện tiên quyết:** GHC (Glasgow Haskell Compiler)

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

Module `TDigest` chỉ sử dụng thư viện `base` (không cần dự án Cabal hay Stack).

**Sử dụng trong mã nguồn của bạn:**

```haskell
import TDigest

main :: IO ()
main = do
  let td = foldl (flip add) empty [1.0 .. 10000.0]
  print (quantile 0.99 td)
```

---

## Ruby

**Điều kiện tiên quyết:** Ruby (>= 2.0)

```bash
cd ruby/
ruby tdigest.rb
```

Tệp `tdigest.rb` chứa cả thư viện và chương trình minh họa (trong khối `if __FILE__ == $PROGRAM_NAME`). Để sử dụng như thư viện:

```ruby
require_relative 'tdigest'

td = TDigest.new(100)
10_000.times { |i| td.add(i.to_f / 10_000) }
puts td.quantile(0.99)
```

---

## Ada

**Điều kiện tiên quyết:** GNAT (trình biên dịch Ada của GCC)

```bash
cd ada/
gnatmake demo.adb
./demo
```

Gói được chia thành `tdigest.ads` (đặc tả), `tdigest.adb` (thân), và gói cây 2-3-4 tổng quát `tree234.ads`/`tree234.adb`. Để sử dụng trong dự án của bạn, viết `with TDigest;` trong mã nguồn và biên dịch tất cả các tệp cùng nhau.

---

## Common Lisp

**Điều kiện tiên quyết:** SBCL hoặc bất kỳ bản triển khai ANSI Common Lisp nào

```bash
cd common-lisp/
sbcl --script demo.lisp
```

Sử dụng tương tác:

```lisp
(load "tdigest.lisp")
(let ((td (create-tdigest 100.0d0)))
  (loop for i below 10000
        do (tdigest-add td (/ (coerce i 'double-float) 10000.0d0)))
  (format t "p99 = ~F~%" (tdigest-quantile td 0.99d0)))
```

---

## Scheme

**Điều kiện tiên quyết:** CHICKEN Scheme (`csi`) hoặc bất kỳ Scheme R5RS/R7RS nào

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

Hoặc với Guile:

```bash
guile demo.scm
```

Lưu ý: Các literal `+inf.0` và `-inf.0` được sử dụng cho vô cực. Nếu bản triển khai Scheme của bạn sử dụng các hằng số khác, bạn có thể cần điều chỉnh định nghĩa `+inf` và `-inf` ở đầu tệp `tdigest.scm`.

---

## Standard ML

**Điều kiện tiên quyết:** MLton (để biên dịch) hoặc SML/NJ (sử dụng tương tác)

**Với MLton:**

```bash
cd sml/
mlton demo.mlb
./demo
```

**Với SML/NJ:**

```bash
cd sml/
sml demo.sml
```

Tệp MLB (`demo.mlb`) liệt kê thư viện basis và các tệp nguồn cho hệ thống xây dựng của MLton.

---

## Prolog

**Điều kiện tiên quyết:** SWI-Prolog

```bash
cd prolog/
swipl demo.pl
```

Chương trình minh họa tải module `tdigest` và tự động chạy thông qua chỉ thị `:- initialization(main, main).`.

Sử dụng tương tác:

```prolog
?- use_module(tdigest).
?- tdigest_new(100, TD0),
   tdigest_add(TD0, 42.0, 1.0, TD1),
   tdigest_add(TD1, 99.0, 1.0, TD2),
   tdigest_quantile(TD2, 0.5, Median).
```

---

## Mercury

**Điều kiện tiên quyết:** Trình biên dịch Mercury (`mmc`)

**Phiên bản hàm thuần túy** (finger tree):

```bash
cd mercury/
mmc --make demo
./demo
```

**Phiên bản có thể thay đổi** (cây 2-3-4 với kiểu duy nhất):

```bash
cd mercury/
mmc --make demo_mut
./demo_mut
```

Hệ thống xây dựng Mercury sẽ tự động biên dịch các phụ thuộc (`tdigest.m`, `fingertree.m`, `measured_tree234.m`, v.v.).

---

## C

**Điều kiện tiên quyết:** GCC hoặc Clang

```bash
cd c/
gcc -O2 -lm -o demo demo.c tdigest.c
./demo
```

---

## C++

**Điều kiện tiên quyết:** G++ hoặc Clang++ (C++17)

```bash
cd cpp/
g++ -O2 -std=c++17 -o demo demo.cpp tdigest.cpp
./demo
```

---

## Go

**Điều kiện tiên quyết:** Go (>= 1.18)

```bash
cd go/demo
go run .
```

---

## Rust

**Điều kiện tiên quyết:** Cargo và bộ công cụ Rust

```bash
cd rust/
cargo run --release
```

---

## Java

**Điều kiện tiên quyết:** JDK (>= 11)

```bash
cd java/
javac Tree234.java TDigest.java Demo.java
java Demo
```

---

## Kotlin

**Điều kiện tiên quyết:** Trình biên dịch Kotlin

```bash
cd kotlin/
kotlinc Tree234.kt TDigest.kt Demo.kt -include-runtime -d demo.jar
java -jar demo.jar
```

---

## Python

**Điều kiện tiên quyết:** Python 3 (không có phụ thuộc bên ngoài)

```bash
cd python/
python3 demo.py
```

---

## Julia

**Điều kiện tiên quyết:** Julia (>= 1.6)

```bash
cd julia/
julia demo.jl
```

---

## OCaml

**Điều kiện tiên quyết:** Trình biên dịch OCaml và ocamlfind

```bash
cd ocaml/
ocamlfind ocamlopt tdigest.ml demo.ml -o demo
./demo
```

---

## Erlang

**Điều kiện tiên quyết:** Erlang/OTP

```bash
cd erlang/
erlc tdigest.erl demo.erl
erl -noshell -s demo main -s init stop
```

---

## Elixir

**Điều kiện tiên quyết:** Elixir (>= 1.12)

```bash
cd elixir/
elixir demo.exs
```

---

## Fortran

**Điều kiện tiên quyết:** GFortran hoặc trình biên dịch Fortran 2003 trở lên

```bash
cd fortran/
gfortran -O2 -o demo tdigest.f90 demo.f90
./demo
```

---

## Perl

**Điều kiện tiên quyết:** Perl 5

```bash
cd perl/
perl -I. demo.pl
```

---

## Lua

**Điều kiện tiên quyết:** Lua (>= 5.1)

```bash
cd lua/
lua demo.lua
```

---

## R

**Điều kiện tiên quyết:** R (>= 3.0)

```bash
cd r/
Rscript demo.R
```

---

## Zig

**Điều kiện tiên quyết:** Trình biên dịch Zig

```bash
cd zig/
zig build-exe demo.zig -O ReleaseFast
./demo
```

---

## Nim

**Điều kiện tiên quyết:** Trình biên dịch Nim

```bash
cd nim/
nim c -d:release -o:demo demo.nim
./demo
```

---

## D

**Điều kiện tiên quyết:** DMD hoặc LDC2

```bash
cd d/
dmd -O -of=demo demo.d tdigest.d tree234.d
./demo
```

---

## C#

**Điều kiện tiên quyết:** .NET SDK hoặc Mono

**Với .NET SDK:**

```bash
cd csharp/
dotnet run
```

**Với Mono:**

```bash
cd csharp/
mcs -langversion:latest -out:demo.exe Demo.cs TDigest.cs Tree234.cs
mono demo.exe
```

---

## Swift

**Điều kiện tiên quyết:** Trình biên dịch Swift

```bash
cd swift/
swiftc -O -o demo tree234.swift tdigest.swift demo.swift
./demo
```
