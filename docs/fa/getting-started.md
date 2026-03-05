<!-- توجه: این سند باید با قالب‌بندی RTL نمایش داده شود. از dir="rtl" در عنصر HTML محتوی استفاده کنید. -->

# شروع سریع

این پروژه شامل پیاده‌سازی t-digest در ۸ زبان برنامه‌نویسی است. دستورالعمل‌های زیر را برای ساخت و اجرای هر پیاده‌سازی دنبال کنید.

## شبیه‌سازی مخزن

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## ساخت و اجرا در هر زبان

### Ruby

```bash
ruby demo.rb
```

بدون وابستگی خارجی. استفاده از Ruby نسخه ۲.۷ یا بالاتر توصیه می‌شود.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

نیاز به GHC (Glasgow Haskell Compiler) دارد. در پوشه `haskell/` اجرا کنید.

### Common Lisp

```bash
sbcl --script demo.lisp
```

نیاز به SBCL (Steel Bank Common Lisp) دارد. در پوشه `common-lisp/` اجرا کنید.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

نیاز به CHICKEN Scheme دارد. در پوشه `scheme/` اجرا کنید.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

نیاز به کامپایلر MLton دارد. در پوشه `sml/` اجرا کنید.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

نیاز به GNAT (کامپایلر Ada از GNU) دارد. در پوشه `ada/` اجرا کنید.

### Prolog

```bash
swipl demo.pl
```

نیاز به SWI-Prolog دارد. در پوشه `prolog/` اجرا کنید.

### Mercury

```bash
mmc --make demo && ./demo
```

نیاز به کامپایلر Mercury دارد. در پوشه `mercury/` اجرا کنید.

## خروجی نمونه‌ها

هر نمونه مراحل زیر را انجام می‌دهد:

1. مقداردهی اولیه t-digest
2. افزودن داده‌های نمونه
3. محاسبه و نمایش چندک‌های مختلف (میانه، p90، p99 و غیره)
4. نمایش مقایسه بین مقادیر تخمینی و مقادیر نظری
