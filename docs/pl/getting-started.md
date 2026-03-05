# Pierwsze kroki

Ten projekt zawiera implementacje t-digest w ośmiu językach programowania. Każda implementacja wykorzystuje wariant merging digest z funkcją skalującą K_1 (arcussinus).

## Kompilacja i uruchamianie

### Ruby

Kompilacja nie jest wymagana. Uruchom bezpośrednio:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Skompiluj za pomocą GHC i uruchom:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Uruchom jako skrypt za pomocą SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Uruchom za pomocą CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Skompiluj za pomocą MLton i uruchom:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Skompiluj za pomocą GNAT i uruchom:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Uruchom za pomocą SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Skompiluj za pomocą kompilatora Mercury i uruchom:

```bash
cd mercury
mmc --make demo && ./demo
```
