# आरंभ करें

## पूर्वापेक्षाएँ

t-digest भंडार में आठ प्रोग्रामिंग भाषाओं के कार्यान्वयन हैं। प्रत्येक को चलाने के लिए संबंधित भाषा का संकलक या दुभाषिया स्थापित होना चाहिए।

```bash
# भंडार क्लोन करें
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby कार्यान्वयन को किसी बाहरी पुस्तकालय की आवश्यकता नहीं है। प्रदर्शन चलाने के लिए:

```bash
cd ruby
ruby demo.rb
```

निष्पादन मानक चलाने के लिए:

```bash
ruby bench.rb
```

## Haskell

Haskell कार्यान्वयन GHC संकलक का उपयोग करता है। अनुकूलन सक्षम करके संकलित करें:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp कार्यान्वयन SBCL दुभाषिया का उपयोग करता है:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme कार्यान्वयन CHICKEN Scheme (csi) दुभाषिया के साथ R5RS मानक का उपयोग करता है:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML कार्यान्वयन MLton संकलक का उपयोग करता है। `.mlb` निर्माण फ़ाइल से संकलित करें:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada कार्यान्वयन GNAT संकलक का उपयोग करता है। अनुकूलन सक्षम करके संकलित करें:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog कार्यान्वयन SWI-Prolog दुभाषिया का उपयोग करता है:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury कार्यान्वयन Melbourne Mercury संकलक का उपयोग करता है:

```bash
cd mercury
mmc --make demo && ./demo
```

## सामान्य समस्या-निवारण

- **संकलक नहीं मिला** — सुनिश्चित करें कि संबंधित भाषा का संकलक या दुभाषिया आपके PATH में है
- **संकलन त्रुटि** — जाँचें कि आप सही निर्देशिका में हैं (`cd <भाषा>`)
- **अनुमति अस्वीकृत** — संकलित बाइनरी को चलाने की अनुमति दें: `chmod +x demo`
