# தொடங்குதல்

## முன்நிபந்தனைகள்

t-digest களஞ்சியத்தில் எட்டு நிரலாக்க மொழிகளில் செயலாக்கம் உள்ளது. ஒவ்வொன்றையும் இயக்க அந்தந்த மொழியின் தொகுப்பி அல்லது மொழிபெயர்ப்பி நிறுவப்பட்டிருக்க வேண்டும்.

```bash
# களஞ்சியத்தை நகலெடுக்கவும்
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby செயலாக்கத்திற்கு வெளிப்புற நூலகம் எதுவும் தேவையில்லை. செயல்விளக்கம் இயக்க:

```bash
cd ruby
ruby demo.rb
```

செயல்திறன் அளவீடு இயக்க:

```bash
ruby bench.rb
```

## Haskell

Haskell செயலாக்கம் GHC தொகுப்பியைப் பயன்படுத்துகிறது. மேம்படுத்தலுடன் தொகுக்கவும்:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp செயலாக்கம் SBCL மொழிபெயர்ப்பியைப் பயன்படுத்துகிறது:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme செயலாக்கம் CHICKEN Scheme (csi) மொழிபெயர்ப்பியுடன் R5RS தரநிலையைப் பயன்படுத்துகிறது:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML செயலாக்கம் MLton தொகுப்பியைப் பயன்படுத்துகிறது. `.mlb` கட்டமைப்பு கோப்பிலிருந்து தொகுக்கவும்:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada செயலாக்கம் GNAT தொகுப்பியைப் பயன்படுத்துகிறது. மேம்படுத்தலுடன் தொகுக்கவும்:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog செயலாக்கம் SWI-Prolog மொழிபெயர்ப்பியைப் பயன்படுத்துகிறது:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury செயலாக்கம் Melbourne Mercury தொகுப்பியைப் பயன்படுத்துகிறது:

```bash
cd mercury
mmc --make demo && ./demo
```

## பொதுவான சிக்கல் தீர்வு

- **தொகுப்பி கிடைக்கவில்லை** — சம்பந்தப்பட்ட மொழியின் தொகுப்பி அல்லது மொழிபெயர்ப்பி உங்கள் PATH-ல் உள்ளதா என உறுதிசெய்யவும்
- **தொகுப்புப் பிழை** — நீங்கள் சரியான அடைவில் உள்ளீர்களா என சரிபார்க்கவும் (`cd <மொழி>`)
- **அனுமதி மறுக்கப்பட்டது** — தொகுக்கப்பட்ட இருமக் கோப்பை இயக்க அனுமதி அளிக்கவும்: `chmod +x demo`
