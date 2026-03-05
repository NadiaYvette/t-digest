# Начало работы

Этот проект содержит реализации t-digest на восьми языках программирования. Каждая реализация использует вариант merging digest с функцией масштабирования K_1 (арксинус).

## Компиляция и запуск

### Ruby

Компиляция не требуется. Запустите непосредственно:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Скомпилируйте с помощью GHC и запустите:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Запустите как скрипт с помощью SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Запустите с помощью CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Скомпилируйте с помощью MLton и запустите:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Скомпилируйте с помощью GNAT и запустите:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Запустите с помощью SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Скомпилируйте с помощью компилятора Mercury и запустите:

```bash
cd mercury
mmc --make demo && ./demo
```
