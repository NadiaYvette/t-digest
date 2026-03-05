# 快速入門

本專案包含 8 種程式語言的 t-digest 實作。請依照以下說明建置和執行各個實作。

## 複製儲存庫

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 各語言的建置與執行

### Ruby

```bash
ruby demo.rb
```

無外部相依性。建議使用 Ruby 2.7 及以上版本。

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

需要 GHC（Glasgow Haskell Compiler）。請在 `haskell/` 目錄下執行。

### Common Lisp

```bash
sbcl --script demo.lisp
```

需要 SBCL（Steel Bank Common Lisp）。請在 `common-lisp/` 目錄下執行。

### Scheme

```bash
csi -R r5rs -script demo.scm
```

需要 CHICKEN Scheme。請在 `scheme/` 目錄下執行。

### Standard ML

```bash
mlton demo.mlb && ./demo
```

需要 MLton 編譯器。請在 `sml/` 目錄下執行。

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

需要 GNAT（GNU Ada 編譯器）。請在 `ada/` 目錄下執行。

### Prolog

```bash
swipl demo.pl
```

需要 SWI-Prolog。請在 `prolog/` 目錄下執行。

### Mercury

```bash
mmc --make demo && ./demo
```

需要 Mercury 編譯器。請在 `mercury/` 目錄下執行。

## 示範輸出

每個示範程式執行以下操作：

1. 初始化 t-digest
2. 添加樣本資料
3. 計算並輸出各種分位數（中位數、p90、p99 等）
4. 輸出估計值與理論值的比較結果
