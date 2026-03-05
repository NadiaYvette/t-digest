# เริ่มต้นใช้งาน

โปรเจกต์นี้ประกอบด้วยการนำ t-digest ไปใช้งานใน 8 ภาษาโปรแกรม ทำตามคำแนะนำด้านล่างเพื่อสร้างและเรียกใช้งานในแต่ละภาษา

## โคลนคลังเก็บโค้ด

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## การสร้างและเรียกใช้งานตามภาษา

### Ruby

```bash
ruby demo.rb
```

ไม่มีการพึ่งพาภายนอก แนะนำให้ใช้ Ruby 2.7 ขึ้นไป

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

ต้องการ GHC (Glasgow Haskell Compiler) เรียกใช้งานในไดเรกทอรี `haskell/`

### Common Lisp

```bash
sbcl --script demo.lisp
```

ต้องการ SBCL (Steel Bank Common Lisp) เรียกใช้งานในไดเรกทอรี `common-lisp/`

### Scheme

```bash
csi -R r5rs -script demo.scm
```

ต้องการ CHICKEN Scheme เรียกใช้งานในไดเรกทอรี `scheme/`

### Standard ML

```bash
mlton demo.mlb && ./demo
```

ต้องการคอมไพเลอร์ MLton เรียกใช้งานในไดเรกทอรี `sml/`

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

ต้องการ GNAT (คอมไพเลอร์ Ada ของ GNU) เรียกใช้งานในไดเรกทอรี `ada/`

### Prolog

```bash
swipl demo.pl
```

ต้องการ SWI-Prolog เรียกใช้งานในไดเรกทอรี `prolog/`

### Mercury

```bash
mmc --make demo && ./demo
```

ต้องการคอมไพเลอร์ Mercury เรียกใช้งานในไดเรกทอรี `mercury/`

## ผลลัพธ์ของโปรแกรมสาธิต

โปรแกรมสาธิตแต่ละตัวจะดำเนินการดังนี้:

1. เริ่มต้น t-digest
2. เพิ่มข้อมูลตัวอย่าง
3. คำนวณและแสดงค่าควอนไทล์ต่าง ๆ (ค่ามัธยฐาน, p90, p99 เป็นต้น)
4. แสดงการเปรียบเทียบระหว่างค่าประมาณและค่าทฤษฎี
