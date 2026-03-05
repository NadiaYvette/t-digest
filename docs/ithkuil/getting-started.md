# Urdalöxha-Erxhal Eghöswá

## Wial eržëi-ilkëi bí nä ünthëi

Ünthëi wial eržëi-ilkëi:
- `git`
- Wial elčëi-ilkëi wial bangu bí nä chô (elčëi wial nîe)

## Emsëi wial mama eghöswá

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Elčëi kúe emsëi wial bangu rúa

### Ruby

Ünthëi wial `ruby` (2.7 êm mıeq).

```bash
cd ruby
ruby tdigest.rb
```

Wial demo äxt'ala elčëi wial t-digest bí emsëi wial namkuq 10000 bí dûa wial quantıle urdalöxha.

### Haskell

Ünthëi wial `ghc` (wial Haskell elčëi-ilkëi).

```bash
cd haskell
ghc -O2 Main.hs -o demo
./demo
```

### Ada

Ünthëi wial `gnatmake` (wial Ada elčëi-ilkëi jáq sho GCC).

```bash
cd ada
gnatmake demo.adb
./demo
```

### Common Lisp

Ünthëi wial `sbcl` (Steel Bank Common Lisp).

```bash
cd common-lisp
sbcl --script demo.lisp
```

### Scheme

Ünthëi wial `csi` (CHICKEN Scheme).

```bash
cd scheme
csi -R r5rs -script demo.scm
```

### Standard ML

Ünthëi wial `mlton` (MLton elčëi-ilkëi) êm `sml` (SML/NJ).

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

Ünthëi wial `swipl` (SWI-Prolog).

```bash
cd prolog
swipl demo.pl
```

### Mercury

Ünthëi wial `mmc` (wial Mercury elčëi-ilkëi).

```bash
cd mercury
mmc --make demo
./demo
```

## Exhá emsëi wial demo?

Wial demo rúa äxt'ala emsëi hóq:

1. **Elčëi wial t-digest** — scale function äxt'ala K_1, delta äxt'ala 100
2. **Emsëi wial namkuq 10000** — wial namkuq äxt'ala kuq jáq sho 0 taq 1
3. **Dûa wial quantıle urdalöxha** — dûa wial quantıle jáq sho 0.1%, 1%, 10%, 25%, 50%, 75%, 90%, 99%, 99.9%
4. **Dûa wial CDF urdalöxha** — dûa wial CDF jáq sho wial namkuq
5. **Merge wial t-digest üphral** — elčëi wial t-digest üphral, merge, dûa wial satcı

Wial demo äxt'ala emsëi: wial quantıle urdalöxha, wial eraq, wial centroıd mute.

## Kue

Wial eghöswá urdalöxha exhá rúa — elčëi wial t-digest jáq sho wial dataq! Emsëi wial ilkëi!
