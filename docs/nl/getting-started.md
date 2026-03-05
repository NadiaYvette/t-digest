# Aan de slag

Dit project bevat t-digest-implementaties in acht programmeertalen. Elke implementatie gebruikt de merging-digest-variant met de K_1-schaalfunctie (arcsinus).

## Compileren en uitvoeren

### Ruby

Geen compilatie nodig. Direct uitvoeren:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compileren met GHC en uitvoeren:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Als script uitvoeren met SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Uitvoeren met CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compileren met MLton en uitvoeren:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compileren met GNAT en uitvoeren:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Uitvoeren met SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compileren met de Mercury-compiler en uitvoeren:

```bash
cd mercury
mmc --make demo && ./demo
```
