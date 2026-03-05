# Wiwit Cepet

Proyek iki ngemot implementasi t-digest ing 8 basa pemrograman. Tindakna pandhuan ing ngisor iki kanggo mbangun lan mbukak saben implementasi.

## Kloning Repositori

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Mbangun lan Mbukak Saben Basa

### Ruby

```bash
ruby demo.rb
```

Ora ana dependensi eksternal. Disaranake nggunakake Ruby 2.7 utawa luwih anyar.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

Mbutuhake GHC (Glasgow Haskell Compiler). Bukak ing direktori `haskell/`.

### Common Lisp

```bash
sbcl --script demo.lisp
```

Mbutuhake SBCL (Steel Bank Common Lisp). Bukak ing direktori `common-lisp/`.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

Mbutuhake CHICKEN Scheme. Bukak ing direktori `scheme/`.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

Mbutuhake kompiler MLton. Bukak ing direktori `sml/`.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

Mbutuhake GNAT (kompiler Ada saka GNU). Bukak ing direktori `ada/`.

### Prolog

```bash
swipl demo.pl
```

Mbutuhake SWI-Prolog. Bukak ing direktori `prolog/`.

### Mercury

```bash
mmc --make demo && ./demo
```

Mbutuhake kompiler Mercury. Bukak ing direktori `mercury/`.

## Output Demo

Saben demo nglakokake langkah-langkah iki:

1. Inisialisasi t-digest
2. Nambahake data sampel
3. Ngitung lan nampilake macem-macem kuantil (median, p90, p99, lsp.)
4. Nampilake perbandingan antara nilai estimasi lan nilai teoritis
