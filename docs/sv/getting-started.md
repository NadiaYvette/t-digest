# Kom igång

Detta projekt innehåller t-digest-implementationer i åtta programmeringsspråk. Varje implementation använder varianten merging digest med skalfunktionen K_1 (arcussinus).

## Kompilera och köra

### Ruby

Ingen kompilering behövs. Kör direkt:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Kompilera med GHC och kör:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Kör som skript med SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Kör med CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Kompilera med MLton och kör:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Kompilera med GNAT och kör:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Kör med SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Kompilera med Mercury-kompilatorn och kör:

```bash
cd mercury
mmc --make demo && ./demo
```
