# Mula Pantas

Projek ini mengandungi pelaksanaan t-digest dalam 8 bahasa pengaturcaraan. Ikuti arahan di bawah untuk membina dan menjalankan setiap pelaksanaan.

## Klon Repositori

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Membina dan Menjalankan Setiap Bahasa

### Ruby

```bash
ruby demo.rb
```

Tiada kebergantungan luaran. Disyorkan menggunakan Ruby 2.7 atau lebih baharu.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

Memerlukan GHC (Glasgow Haskell Compiler). Jalankan dalam direktori `haskell/`.

### Common Lisp

```bash
sbcl --script demo.lisp
```

Memerlukan SBCL (Steel Bank Common Lisp). Jalankan dalam direktori `common-lisp/`.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

Memerlukan CHICKEN Scheme. Jalankan dalam direktori `scheme/`.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

Memerlukan pengkompil MLton. Jalankan dalam direktori `sml/`.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

Memerlukan GNAT (pengkompil Ada daripada GNU). Jalankan dalam direktori `ada/`.

### Prolog

```bash
swipl demo.pl
```

Memerlukan SWI-Prolog. Jalankan dalam direktori `prolog/`.

### Mercury

```bash
mmc --make demo && ./demo
```

Memerlukan pengkompil Mercury. Jalankan dalam direktori `mercury/`.

## Output Demo

Setiap demo melaksanakan langkah-langkah berikut:

1. Memulakan t-digest
2. Menambah data sampel
3. Mengira dan memaparkan pelbagai kuantil (median, p90, p99, dll.)
4. Memaparkan perbandingan antara nilai anggaran dan nilai teori
