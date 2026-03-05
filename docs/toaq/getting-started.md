# Sho chô t-digest

## Báq daq lıq bí nä dûe

Dûe jí báq daq lıq:
- `git`
- Báq lıq chuq bí nä pûa báq bangu bí nä chô jí (lûeq báq nîe)

## Kûeq jí báq mama shodaı

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Chuq bí hóa jáq sho báq bangu rúa

### Ruby

Dûe jí `ruby` (2.7 hóe mıeq).

```bash
cd ruby
ruby tdigest.rb
```

Báq demo nä chuq báq t-digest bí nä pûeq báq namkuq 10000 bí nä dûa báq quantıle da.

### Haskell

Dûe jí `ghc` (báq Haskell chuq lıq).

```bash
cd haskell
ghc -O2 Main.hs -o demo
./demo
```

### Ada

Dûe jí `gnatmake` (báq Ada chuq lıq jáq sho GCC).

```bash
cd ada
gnatmake demo.adb
./demo
```

### Common Lisp

Dûe jí `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Dûe jí `csi` (CHICKEN Scheme).

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Dûe jí `mlton` (MLton chuq lıq) hóe `sml` (SML/NJ).

Jáq sho MLton:

```bash
cd sml
mlton demo.mlb
./demo
```

Jáq sho SML/NJ:

```bash
cd sml
sml demo.sml
```

### Prolog

Dûe jí `swipl` (SWI-Prolog).

```bash
cd prolog
swipl demo.pl
```

### Mercury

Dûe jí `mmc` (báq Mercury chuq lıq).

```bash
cd mercury
mmc --make demo
./demo
```

## Hı raı bı nä hóa moq?

Báq demo rúa nä hóa hóq:

1. **Chuq báq t-digest** — scale functıon nä K_1, delta nä 100
2. **Pûeq báq namkuq 10000** — báq namkuq nä kuq jáq sho 0 taq 1
3. **Dûa báq quantıle** — dûa báq quantıle jáq sho 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **Dûa báq CDF** — dûa báq CDF jáq sho báq namkuq
5. **Merge báq t-digest fıeq** — chuq báq t-digest fıeq, merge, dûa báq satcı

Báq demo nä kuq: báq quantıle urdalöxha, báq eraq, báq centroıd mute.

## Kue

Chô jí báq lıq suaq la nä chuq t-digest jáq sho báq dataq suaq!
