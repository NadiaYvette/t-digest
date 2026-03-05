# Початок роботи

Цей проєкт містить реалізації t-digest вісьмома мовами програмування. Кожна реалізація використовує варіант merging digest із функцією масштабування K_1 (арксинус).

## Компіляція та запуск

### Ruby

Компіляція не потрібна. Запустіть безпосередньо:

```bash
cd ruby
ruby tdigest.rb
```

### Haskell

Скомпілюйте за допомогою GHC та запустіть:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

### Common Lisp

Запустіть як скрипт за допомогою SBCL:

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Запустіть за допомогою CHICKEN Scheme:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Скомпілюйте за допомогою MLton та запустіть:

```bash
cd sml
mlton demo.mlb && ./demo
```

### Ada

Скомпілюйте за допомогою GNAT та запустіть:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

### Prolog

Запустіть за допомогою SWI-Prolog:

```bash
cd prolog
swipl demo.pl
```

### Mercury

Скомпілюйте за допомогою компілятора Mercury та запустіть:

```bash
cd mercury
mmc --make demo && ./demo
```
