# Primeiros passos

Este projeto contém implementações do t-digest em oito linguagens de programação. Cada implementação utiliza a variante merging digest com a função de escala K_1 (arco seno).

## Compilar e executar

### Ruby

Não necessita de compilação. Executar diretamente:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Compilar com GHC e executar:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Executar como script com SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Executar com CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Compilar com MLton e executar:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Compilar com GNAT e executar:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Executar com SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Compilar com o compilador Mercury e executar:

```bash
cd mercury
mmc --make demo && ./demo
```
