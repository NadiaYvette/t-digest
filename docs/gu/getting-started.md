# શરૂઆત કરો

## પૂર્વજરૂરિયાતો

t-digest ભંડારમાં આઠ પ્રોગ્રામિંગ ભાષાઓમાં અમલીકરણ છે. દરેકને ચલાવવા માટે સંબંધિત ભાષાનું સંકલક કે દુભાષિયું સ્થાપિત હોવું જોઈએ.

```bash
# ભંડાર ક્લોન કરો
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby અમલીકરણને કોઈ બાહ્ય પુસ્તકાલયની જરૂર નથી. પ્રદર્શન ચલાવવા:

```bash
cd ruby
ruby demo.rb
```

કાર્યક્ષમતા ચકાસણી ચલાવવા:

```bash
ruby bench.rb
```

## Haskell

Haskell અમલીકરણ GHC સંકલકનો ઉપયોગ કરે છે. શ્રેષ્ઠીકરણ સાથે સંકલન કરો:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp અમલીકરણ SBCL દુભાષિયાનો ઉપયોગ કરે છે:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme અમલીકરણ CHICKEN Scheme (csi) દુભાષિયા સાથે R5RS માનકનો ઉપયોગ કરે છે:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML અમલીકરણ MLton સંકલકનો ઉપયોગ કરે છે. `.mlb` નિર્માણ ફાઈલથી સંકલન કરો:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada અમલીકરણ GNAT સંકલકનો ઉપયોગ કરે છે. શ્રેષ્ઠીકરણ સાથે સંકલન કરો:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog અમલીકરણ SWI-Prolog દુભાષિયાનો ઉપયોગ કરે છે:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury અમલીકરણ Melbourne Mercury સંકલકનો ઉપયોગ કરે છે:

```bash
cd mercury
mmc --make demo && ./demo
```

## સામાન્ય સમસ્યા-નિવારણ

- **સંકલક મળ્યું નહીં** — ખાતરી કરો કે સંબંધિત ભાષાનું સંકલક કે દુભાષિયું તમારા PATH માં છે
- **સંકલન ત્રુટિ** — ચકાસો કે તમે યોગ્ય ડિરેક્ટરીમાં છો (`cd <ભાષા>`)
- **પરવાનગી નકારી** — સંકલિત બાઈનરીને ચલાવવાની પરવાનગી આપો: `chmod +x demo`
