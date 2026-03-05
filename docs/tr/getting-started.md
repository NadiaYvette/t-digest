# Hızlı Başlangıç

Bu proje, 8 programlama dilinde t-digest uygulamalarını içermektedir. Her uygulamayı derlemek ve çalıştırmak için aşağıdaki talimatları izleyin.

## Depoyu Klonlama

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Her Dilde Derleme ve Çalıştırma

### Ruby

```bash
ruby demo.rb
```

Harici bağımlılık yoktur. Ruby 2.7 veya üstü önerilir.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

GHC (Glasgow Haskell Compiler) gereklidir. `haskell/` dizininde çalıştırın.

### Common Lisp

```bash
sbcl --script demo.lisp
```

SBCL (Steel Bank Common Lisp) gereklidir. `common-lisp/` dizininde çalıştırın.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

CHICKEN Scheme gereklidir. `scheme/` dizininde çalıştırın.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

MLton derleyicisi gereklidir. `sml/` dizininde çalıştırın.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

GNAT (GNU Ada derleyicisi) gereklidir. `ada/` dizininde çalıştırın.

### Prolog

```bash
swipl demo.pl
```

SWI-Prolog gereklidir. `prolog/` dizininde çalıştırın.

### Mercury

```bash
mmc --make demo && ./demo
```

Mercury derleyicisi gereklidir. `mercury/` dizininde çalıştırın.

## Demo Çıktısı

Her demo aşağıdaki adımları gerçekleştirir:

1. t-digest'i başlatır
2. Örnek veri ekler
3. Çeşitli kantilleri (medyan, p90, p99 vb.) hesaplar ve görüntüler
4. Tahmin değerleri ile teorik değerler arasındaki karşılaştırmayı görüntüler
