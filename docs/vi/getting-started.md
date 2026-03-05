# Bắt đầu nhanh

Dự án này bao gồm các bản triển khai t-digest bằng 8 ngôn ngữ lập trình. Hãy làm theo hướng dẫn dưới đây để xây dựng và chạy từng bản triển khai.

## Sao chép kho mã nguồn

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## Xây dựng và chạy theo từng ngôn ngữ

### Ruby

```bash
ruby demo.rb
```

Không có phụ thuộc bên ngoài. Khuyến nghị sử dụng Ruby 2.7 trở lên.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

Cần có GHC (Glasgow Haskell Compiler). Chạy trong thư mục `haskell/`.

### Common Lisp

```bash
sbcl --script demo.lisp
```

Cần có SBCL (Steel Bank Common Lisp). Chạy trong thư mục `common-lisp/`.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

Cần có CHICKEN Scheme. Chạy trong thư mục `scheme/`.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

Cần có trình biên dịch MLton. Chạy trong thư mục `sml/`.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

Cần có GNAT (trình biên dịch Ada của GNU). Chạy trong thư mục `ada/`.

### Prolog

```bash
swipl demo.pl
```

Cần có SWI-Prolog. Chạy trong thư mục `prolog/`.

### Mercury

```bash
mmc --make demo && ./demo
```

Cần có trình biên dịch Mercury. Chạy trong thư mục `mercury/`.

## Kết quả đầu ra của chương trình minh họa

Mỗi chương trình minh họa thực hiện các bước sau:

1. Khởi tạo t-digest
2. Thêm dữ liệu mẫu
3. Tính toán và hiển thị các phân vị khác nhau (trung vị, p90, p99, v.v.)
4. Hiển thị so sánh giữa giá trị ước lượng và giá trị lý thuyết
