# Primeros pasos

Este proyecto contiene implementaciones del t-digest en ocho lenguajes de programación. Cada implementación utiliza la variante merging digest con la función de escala K_1 (arcoseno).

## Compilar y ejecutar

### Ruby

No requiere compilación. Ejecutar directamente:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compilar con GHC y ejecutar:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Ejecutar como script con SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Ejecutar con CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compilar con MLton y ejecutar:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compilar con GNAT y ejecutar:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Ejecutar con SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compilar con el compilador Mercury y ejecutar:

```bash
cd mercury
mmc --make demo && ./demo
```
