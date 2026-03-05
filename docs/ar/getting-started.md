<!-- ملاحظة: يجب عرض هذا المستند بتنسيق RTL. استخدم dir="rtl" في عنصر HTML المحتوي. -->

# البدء السريع

يحتوي هذا المشروع على تطبيقات t-digest بثماني لغات برمجة. اتبع التعليمات أدناه لبناء وتشغيل كل تطبيق.

## استنساخ المستودع

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## البناء والتشغيل في كل لغة

### Ruby

```bash
ruby demo.rb
```

لا توجد اعتماديات خارجية. يُنصح باستخدام Ruby 2.7 أو أحدث.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

يتطلب GHC (Glasgow Haskell Compiler). شغّله من مجلد `haskell/`.

### Common Lisp

```bash
sbcl --script demo.lisp
```

يتطلب SBCL (Steel Bank Common Lisp). شغّله من مجلد `common-lisp/`.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

يتطلب CHICKEN Scheme. شغّله من مجلد `scheme/`.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

يتطلب مترجم MLton. شغّله من مجلد `sml/`.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

يتطلب GNAT (مترجم Ada من GNU). شغّله من مجلد `ada/`.

### Prolog

```bash
swipl demo.pl
```

يتطلب SWI-Prolog. شغّله من مجلد `prolog/`.

### Mercury

```bash
mmc --make demo && ./demo
```

يتطلب مترجم Mercury. شغّله من مجلد `mercury/`.

## مخرجات العرض التوضيحي

يقوم كل عرض توضيحي بتنفيذ الخطوات التالية:

1. تهيئة t-digest
2. إضافة بيانات نموذجية
3. حساب وعرض شرائح مئوية مختلفة (الوسيط، p90، p99 وغيرها)
4. عرض مقارنة بين القيم المقدّرة والقيم النظرية
