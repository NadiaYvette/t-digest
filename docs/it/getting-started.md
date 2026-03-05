# Per iniziare

Questo progetto contiene implementazioni del t-digest in otto linguaggi di programmazione. Ogni implementazione utilizza la variante merging digest con la funzione di scala K_1 (arcoseno).

## Compilare ed eseguire

### Ruby

Nessuna compilazione necessaria. Eseguire direttamente:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compilare con GHC ed eseguire:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Eseguire come script con SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Eseguire con CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compilare con MLton ed eseguire:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compilare con GNAT ed eseguire:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Eseguire con SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compilare con il compilatore Mercury ed eseguire:

```bash
cd mercury
mmc --make demo && ./demo
```
