# Primii pași

Acest proiect conține implementări ale t-digest în opt limbaje de programare. Fiecare implementare utilizează varianta merging digest cu funcția de scară K_1 (arcsin).

## Compilare și rulare

### Ruby

Nu necesită compilare. Rulați direct:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compilați cu GHC și rulați:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Rulați ca script cu SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Rulați cu CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compilați cu MLton și rulați:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compilați cu GNAT și rulați:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Rulați cu SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compilați cu compilatorul Mercury și rulați:

```bash
cd mercury
mmc --make demo && ./demo
```
