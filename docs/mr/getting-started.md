# सुरुवात करा

## पूर्वअटी

t-digest भांडारात आठ प्रोग्रामिंग भाषांमध्ये अंमलबजावणी आहे. प्रत्येक चालवण्यासाठी संबंधित भाषेचा संकलक किंवा दुभाषक स्थापित असणे आवश्यक आहे.

```bash
# भांडार क्लोन करा
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby अंमलबजावणीला कोणत्याही बाह्य ग्रंथालयाची गरज नाही. प्रात्यक्षिक चालवण्यासाठी:

```bash
cd ruby
ruby demo.rb
```

कार्यक्षमता चाचणी चालवण्यासाठी:

```bash
ruby bench.rb
```

## Haskell

Haskell अंमलबजावणी GHC संकलक वापरते. अनुकूलन सक्षम करून संकलन करा:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp अंमलबजावणी SBCL दुभाषक वापरते:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme अंमलबजावणी CHICKEN Scheme (csi) दुभाषक आणि R5RS मानक वापरते:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML अंमलबजावणी MLton संकलक वापरते. `.mlb` निर्माण फाइलमधून संकलन करा:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada अंमलबजावणी GNAT संकलक वापरते. अनुकूलन सक्षम करून संकलन करा:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog अंमलबजावणी SWI-Prolog दुभाषक वापरते:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury अंमलबजावणी Melbourne Mercury संकलक वापरते:

```bash
cd mercury
mmc --make demo && ./demo
```

## सामान्य समस्या-निवारण

- **संकलक सापडला नाही** — खात्री करा की संबंधित भाषेचा संकलक किंवा दुभाषक तुमच्या PATH मध्ये आहे
- **संकलन त्रुटी** — तपासा की तुम्ही योग्य निर्देशिकेत आहात (`cd <भाषा>`)
- **परवानगी नाकारली** — संकलित बायनरीला चालवण्याची परवानगी द्या: `chmod +x demo`
