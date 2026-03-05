# Prise en main

Ce projet contient des implémentations du t-digest dans huit langages de programmation. Chaque implémentation utilise la variante merging digest avec la fonction d'échelle K_1 (arc sinus).

## Compiler et exécuter

### Ruby

Aucune compilation nécessaire. Exécuter directement :

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compiler avec GHC et exécuter :

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Exécuter comme script avec SBCL :

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Exécuter avec CHICKEN Scheme :

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compiler avec MLton et exécuter :

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compiler avec GNAT et exécuter :

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Exécuter avec SWI-Prolog :

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compiler avec le compilateur Mercury et exécuter :

```bash
cd mercury
mmc --make demo && ./demo
```
