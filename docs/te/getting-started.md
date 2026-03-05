# ప్రారంభించండి

## ముందస్తు అవసరాలు

t-digest భాండాగారంలో ఎనిమిది ప్రోగ్రామింగ్ భాషలలో అమలు ఉంది. ప్రతిదాన్ని నడపడానికి సంబంధిత భాష యొక్క కంపైలర్ లేదా ఇంటర్‌ప్రెటర్ ఇన్‌స్టాల్ చేయబడి ఉండాలి.

```bash
# భాండాగారం క్లోన్ చేయండి
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby అమలుకు బాహ్య లైబ్రరీలు అవసరం లేదు. ప్రదర్శన నడపడానికి:

```bash
cd ruby
ruby demo.rb
```

పనితీరు మానదండం నడపడానికి:

```bash
ruby bench.rb
```

## Haskell

Haskell అమలు GHC కంపైలర్ ఉపయోగిస్తుంది. శ్రేష్ఠీకరణతో కంపైల్ చేయండి:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp అమలు SBCL ఇంటర్‌ప్రెటర్ ఉపయోగిస్తుంది:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme అమలు CHICKEN Scheme (csi) ఇంటర్‌ప్రెటర్‌తో R5RS ప్రమాణం ఉపయోగిస్తుంది:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML అమలు MLton కంపైలర్ ఉపయోగిస్తుంది. `.mlb` నిర్మాణ ఫైల్ నుండి కంపైల్ చేయండి:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada అమలు GNAT కంపైలర్ ఉపయోగిస్తుంది. శ్రేష్ఠీకరణతో కంపైల్ చేయండి:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog అమలు SWI-Prolog ఇంటర్‌ప్రెటర్ ఉపయోగిస్తుంది:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury అమలు Melbourne Mercury కంపైలర్ ఉపయోగిస్తుంది:

```bash
cd mercury
mmc --make demo && ./demo
```

## సాధారణ సమస్యా పరిష్కారం

- **కంపైలర్ కనుగొనబడలేదు** — సంబంధిత భాష యొక్క కంపైలర్ లేదా ఇంటర్‌ప్రెటర్ మీ PATH లో ఉందని నిర్ధారించుకోండి
- **కంపైల్ దోషం** — మీరు సరైన డైరెక్టరీలో ఉన్నారో లేదో తనిఖీ చేయండి (`cd <భాష>`)
- **అనుమతి నిరాకరించబడింది** — కంపైల్ చేసిన బైనరీకి అమలు అనుమతి ఇవ్వండి: `chmod +x demo`
