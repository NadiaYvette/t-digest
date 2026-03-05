# শুরু করুন

## পূর্বশর্ত

t-digest ভাণ্ডারে আটটি প্রোগ্রামিং ভাষায় বাস্তবায়ন রয়েছে। প্রতিটি চালাতে সংশ্লিষ্ট ভাষার সংকলক বা দোভাষী ইনস্টল থাকতে হবে।

```bash
# ভাণ্ডার ক্লোন করুন
git clone <repository-url>
cd t-digest
```

## Ruby

Ruby বাস্তবায়নের কোনো বাহ্যিক গ্রন্থাগারের প্রয়োজন নেই। প্রদর্শনী চালাতে:

```bash
cd ruby
ruby demo.rb
```

কার্যসম্পাদন মানদণ্ড চালাতে:

```bash
ruby bench.rb
```

## Haskell

Haskell বাস্তবায়ন GHC সংকলক ব্যবহার করে। পরিমার্জন সক্রিয় করে সংকলন করুন:

```bash
cd haskell
ghc -O2 Main.hs -o demo && ./demo
```

## Common Lisp

Common Lisp বাস্তবায়ন SBCL দোভাষী ব্যবহার করে:

```bash
cd common-lisp
sbcl --script demo.lisp
```

## Scheme

Scheme বাস্তবায়ন CHICKEN Scheme (csi) দোভাষী এবং R5RS মানক ব্যবহার করে:

```bash
cd scheme
csi -R r5rs -script demo.scm
```

## Standard ML

Standard ML বাস্তবায়ন MLton সংকলক ব্যবহার করে। `.mlb` নির্মাণ ফাইল থেকে সংকলন করুন:

```bash
cd sml
mlton demo.mlb && ./demo
```

## Ada

Ada বাস্তবায়ন GNAT সংকলক ব্যবহার করে। পরিমার্জন সক্রিয় করে সংকলন করুন:

```bash
cd ada
gnatmake -O2 demo.adb -o demo && ./demo
```

## Prolog

Prolog বাস্তবায়ন SWI-Prolog দোভাষী ব্যবহার করে:

```bash
cd prolog
swipl demo.pl
```

## Mercury

Mercury বাস্তবায়ন Melbourne Mercury সংকলক ব্যবহার করে:

```bash
cd mercury
mmc --make demo && ./demo
```

## সাধারণ সমস্যা সমাধান

- **সংকলক পাওয়া যায়নি** — নিশ্চিত করুন সংশ্লিষ্ট ভাষার সংকলক বা দোভাষী আপনার PATH-এ আছে
- **সংকলন ত্রুটি** — যাচাই করুন আপনি সঠিক ডিরেক্টরিতে আছেন (`cd <ভাষা>`)
- **অনুমতি অস্বীকৃত** — সংকলিত বাইনারি চালানোর অনুমতি দিন: `chmod +x demo`
