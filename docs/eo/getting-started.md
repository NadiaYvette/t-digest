# Unuaj paŝoj

Ĉi tiu projekto enhavas realigojn de t-digest en ok programlingvoj. Ĉiu realigo uzas la variaĵon merging digest kun la skalfunkcio K_1 (arksinuso).

## Kompili kaj ruli

### Ruby

Kompilado ne necesas. Rulu rekte:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Kompilu per GHC kaj rulu:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Rulu kiel skripton per SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Rulu per CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Kompilu per MLton kaj rulu:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Kompilu per GNAT kaj rulu:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Rulu per SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Kompilu per la Mercury-kompililo kaj rulu:

```bash
cd mercury
mmc --make demo && ./demo
```
