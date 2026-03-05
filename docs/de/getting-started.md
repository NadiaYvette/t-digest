# Erste Schritte

Dieses Projekt enthält t-digest-Implementierungen in acht Programmiersprachen. Jede Implementierung verwendet die Merging-Digest-Variante mit der K_1-Skalierungsfunktion (Arkussinus).

## Bauen und Ausführen

### Ruby

Keine Kompilierung erforderlich. Direkt ausführen:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Mit GHC kompilieren und ausführen:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Mit SBCL als Skript ausführen:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Mit CHICKEN Scheme ausführen:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Mit MLton kompilieren und ausführen:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Mit GNAT kompilieren und ausführen:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Mit SWI-Prolog ausführen:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Mit dem Mercury-Compiler kompilieren und ausführen:

```bash
cd mercury
mmc --make demo && ./demo
```
