# آغاز کریں

## پیش شرائط

t-digest ذخیرے میں آٹھ پروگرامنگ زبانوں میں عمل درآمد موجود ہے۔ ہر ایک کو چلانے کے لیے متعلقہ زبان کا مرتب ساز (compiler) یا مترجم (interpreter) نصب ہونا ضروری ہے۔

```bash
# ذخیرہ کلون کریں
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby عمل درآمد کو کسی بیرونی کتب خانے کی ضرورت نہیں۔ مظاہرہ چلانے کے لیے:

```bash
cd ruby
ruby demo.rb
```

کارکردگی پیمائش چلانے کے لیے:

```bash
ruby bench.rb
```

## Haskell

Haskell عمل درآمد GHC مرتب ساز استعمال کرتا ہے۔ بہینہ سازی کے ساتھ مرتب کریں:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp عمل درآمد SBCL مترجم استعمال کرتا ہے:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme عمل درآمد CHICKEN Scheme (csi) مترجم اور R5RS معیار استعمال کرتا ہے:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML عمل درآمد MLton مرتب ساز استعمال کرتا ہے۔ `.mlb` تعمیری فائل سے مرتب کریں:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada عمل درآمد GNAT مرتب ساز استعمال کرتا ہے۔ بہینہ سازی کے ساتھ مرتب کریں:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog عمل درآمد SWI-Prolog مترجم استعمال کرتا ہے:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury عمل درآمد Melbourne Mercury مرتب ساز استعمال کرتا ہے:

```bash
cd mercury
mmc --make demo && ./demo
```

## عام مسائل کا حل

- **مرتب ساز نہیں ملا** — یقینی بنائیں کہ متعلقہ زبان کا مرتب ساز یا مترجم آپ کے PATH میں ہے
- **ترتیب میں خرابی** — جانچیں کہ آپ صحیح ڈائریکٹری میں ہیں (`cd <زبان>`)
- **اجازت سے انکار** — مرتب شدہ بائنری کو چلانے کی اجازت دیں: `chmod +x demo`
