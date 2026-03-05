# cfari ke lidne velski

## se nitcu samtci

do nitcu lo vi samtci:
- la `git`
- le samtci poi se nitcu fi le bangu poi do djica (ko tcidu le vi liste)

## cpacu le fonxa mupli

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## zbasu gi'e pilno fi ro le bangu

### Ruby

do nitcu la `ruby` (2.7 ja za'u).

```bash
cd ruby
ruby tdigest.rb
```

le mupli cu zbasu le t-digest gi'e jmina lo 10000 datni gi'e te cusku le gradu stuzi jdice.

### Haskell

do nitcu la `ghc` (le Haskell zbasu samtci).

```bash
cd haskell
ghc -O2 Main.hs -o demo
./demo
```

### Ada

do nitcu la `gnatmake` (le Ada zbasu samtci poi se jmina la GCC).

```bash
cd ada
gnatmake demo.adb
./demo
```

### Common Lisp

do nitcu la `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

do nitcu la `csi` (CHICKEN Scheme).

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

do nitcu la `mlton` (MLton zbasu samtci) ja la `sml` (SML/NJ).

la MLton:

```bash
cd sml
mlton demo.mlb
./demo
```

la SML/NJ:

```bash
cd sml
sml demo.sml
```

### Prolog

do nitcu la `swipl` (SWI-Prolog).

```bash
cd prolog
swipl demo.pl
```

### Mercury

do nitcu la `mmc` (le Mercury zbasu samtci).

```bash
cd mercury
mmc --make demo
./demo
```

## le mupli cu zukte ma

ro le mupli cu zukte le vi:

1. **zbasu le t-digest** — le gradu ciste fancu cu la'o zoi K_1 zoi gi'e le delta cu 100
2. **jmina lo 10000 datni** — le datni cu dunli vrici fi le 0 bi'o 1
3. **te cusku le gradu stuzi jdice** — le jdice be le 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9% gradu stuzi
4. **te cusku le CDF jdice** — le jdice be le CDF fi le datni stuzi
5. **cipra le nu jorne** — zbasu re t-digest gi'e jorne gi'e cipra le jdice

le te cusku cu se cusku le gradu stuzi jdice gi'e le fliba gi'e le gradu girzu namcu.

## le za'e bavlamdei

do pu tcidu le vi fa ko zbasu le do ke samtci. ko pilno le t-digest fi le do ke datni!
