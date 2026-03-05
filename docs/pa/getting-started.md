# ਸ਼ੁਰੂਆਤ ਕਰੋ

## ਪੂਰਵ-ਲੋੜਾਂ

t-digest ਭੰਡਾਰ ਵਿੱਚ ਅੱਠ ਪ੍ਰੋਗ੍ਰਾਮਿੰਗ ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਅਮਲ ਹੈ। ਹਰੇਕ ਨੂੰ ਚਲਾਉਣ ਲਈ ਸੰਬੰਧਿਤ ਭਾਸ਼ਾ ਦਾ ਕੰਪਾਈਲਰ ਜਾਂ ਦੁਭਾਸ਼ੀਆ ਸਥਾਪਿਤ ਹੋਣਾ ਚਾਹੀਦਾ ਹੈ।

```bash
# ਭੰਡਾਰ ਕਲੋਨ ਕਰੋ
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby ਅਮਲ ਨੂੰ ਕਿਸੇ ਬਾਹਰੀ ਲਾਇਬ੍ਰੇਰੀ ਦੀ ਲੋੜ ਨਹੀਂ। ਪ੍ਰਦਰਸ਼ਨ ਚਲਾਉਣ ਲਈ:

```bash
cd ruby
ruby demo.rb
```

ਕਾਰਗੁਜ਼ਾਰੀ ਮਾਪ ਚਲਾਉਣ ਲਈ:

```bash
ruby bench.rb
```

## Haskell

Haskell ਅਮਲ GHC ਕੰਪਾਈਲਰ ਵਰਤਦਾ ਹੈ। ਅਨੁਕੂਲਨ ਨਾਲ ਕੰਪਾਈਲ ਕਰੋ:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp ਅਮਲ SBCL ਦੁਭਾਸ਼ੀਆ ਵਰਤਦਾ ਹੈ:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme ਅਮਲ CHICKEN Scheme (csi) ਦੁਭਾਸ਼ੀਆ ਅਤੇ R5RS ਮਿਆਰ ਵਰਤਦਾ ਹੈ:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML ਅਮਲ MLton ਕੰਪਾਈਲਰ ਵਰਤਦਾ ਹੈ। `.mlb` ਨਿਰਮਾਣ ਫ਼ਾਈਲ ਤੋਂ ਕੰਪਾਈਲ ਕਰੋ:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada ਅਮਲ GNAT ਕੰਪਾਈਲਰ ਵਰਤਦਾ ਹੈ। ਅਨੁਕੂਲਨ ਨਾਲ ਕੰਪਾਈਲ ਕਰੋ:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog ਅਮਲ SWI-Prolog ਦੁਭਾਸ਼ੀਆ ਵਰਤਦਾ ਹੈ:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury ਅਮਲ Melbourne Mercury ਕੰਪਾਈਲਰ ਵਰਤਦਾ ਹੈ:

```bash
cd mercury
mmc --make demo && ./demo
```

## ਆਮ ਸਮੱਸਿਆ-ਨਿਵਾਰਨ

- **ਕੰਪਾਈਲਰ ਨਹੀਂ ਮਿਲਿਆ** — ਯਕੀਨੀ ਬਣਾਓ ਕਿ ਸੰਬੰਧਿਤ ਭਾਸ਼ਾ ਦਾ ਕੰਪਾਈਲਰ ਜਾਂ ਦੁਭਾਸ਼ੀਆ ਤੁਹਾਡੇ PATH ਵਿੱਚ ਹੈ
- **ਕੰਪਾਈਲ ਗ਼ਲਤੀ** — ਜਾਂਚੋ ਕਿ ਤੁਸੀਂ ਸਹੀ ਡਾਇਰੈਕਟਰੀ ਵਿੱਚ ਹੋ (`cd <ਭਾਸ਼ਾ>`)
- **ਇਜਾਜ਼ਤ ਤੋਂ ਇਨਕਾਰ** — ਕੰਪਾਈਲ ਕੀਤੀ ਬਾਈਨਰੀ ਨੂੰ ਚਲਾਉਣ ਦੀ ਇਜਾਜ਼ਤ ਦਿਓ: `chmod +x demo`
