# open kepeken t-digest

## ilo ni li wile e seme?

sina wile e ilo ni:
- ilo `git`
- ilo pi toki ilo wan anu mute (o lukin e ni)

## kama jo e lipu mama

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## pali en kepeken lon toki ilo ale

### Ruby

sina wile e ilo `ruby` (nanpa 2.7 anu suli).

```bash
cd ruby
ruby tdigest.rb
```

ilo ni li pali e t-digest, li pana e nanpa 10000, li toki e sona pi suli pi nanpa.

### Haskell

sina wile e ilo `ghc` (ilo pali pi toki Haskell).

```bash
cd haskell
ghc -O2 Main.hs -o demo
./demo
```

### Ada

sina wile e ilo `gnatmake` (ilo pali pi toki Ada lon insa GCC).

```bash
cd ada
gnatmake demo.adb
./demo
```

### Common Lisp

sina wile e ilo `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

sina wile e ilo `csi` (CHICKEN Scheme).

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

sina wile e ilo `mlton` (ilo pali MLton) anu ilo `sml` (SML/NJ).

kepeken MLton:

```bash
cd sml
mlton demo.mlb
./demo
```

kepeken SML/NJ:

```bash
cd sml
sml demo.sml
```

### Prolog

sina wile e ilo `swipl` (SWI-Prolog).

```bash
cd prolog
swipl demo.pl
```

### Mercury

sina wile e ilo `mmc` (ilo pali pi toki Mercury).

```bash
cd mercury
mmc --make demo
./demo
```

## ilo ni li pali e seme?

ilo pi toki ilo ale li pali e ni:

1. **pali e t-digest** — nasin pi ante suli li K_1, nanpa delta li 100
2. **pana e nanpa 10000** — nanpa li sama lon 0 tawa 1
3. **toki e sona pi suli pi nanpa** — sona pi nanpa suli 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **toki e sona CDF** — sona pi mute pi nanpa lon ma
5. **wan e t-digest tu** — pali e t-digest tu, wan e ona, lukin e sona

ilo li toki e ni: sona pi suli pi nanpa, ante pi sona en nanpa lon, mute pi kulupu lili.

## tawa

sina sona e ni la o pali e ilo sina kepeken t-digest!
