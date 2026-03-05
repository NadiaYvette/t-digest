# 快速入門

呢個專案包含 8 種程式語言嘅 t-digest 實作。跟住下面嘅說明嚟建置同執行各個實作。

## 複製儲存庫

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 各語言嘅建置同執行

### Ruby

```bash
ruby demo.rb
```

冇外部相依性。建議用 Ruby 2.7 或者以上版本。

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

需要 GHC（Glasgow Haskell Compiler）。喺 `haskell/` 目錄入面執行。

### Common Lisp

```bash
sbcl --script demo.lisp
```

需要 SBCL（Steel Bank Common Lisp）。喺 `common-lisp/` 目錄入面執行。

### Scheme

```bash
csi -R r5rs -script demo.scm
```

需要 CHICKEN Scheme。喺 `scheme/` 目錄入面執行。

### Standard ML

```bash
mlton demo.mlb && ./demo
```

需要 MLton 編譯器。喺 `sml/` 目錄入面執行。

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

需要 GNAT（GNU 嘅 Ada 編譯器）。喺 `ada/` 目錄入面執行。

### Prolog

```bash
swipl demo.pl
```

需要 SWI-Prolog。喺 `prolog/` 目錄入面執行。

### Mercury

```bash
mmc --make demo && ./demo
```

需要 Mercury 編譯器。喺 `mercury/` 目錄入面執行。

## 示範輸出

每個示範程式會做以下嘢：

1. 初始化 t-digest
2. 加入樣本資料
3. 計算同顯示各種分位數（中位數、p90、p99 等等）
4. 顯示估計值同理論值嘅比較結果
