# クイックスタート

このプロジェクトには、8つのプログラミング言語による t-digest の実装が含まれています。以下の手順に従って、各実装をビルドおよび実行してください。

## リポジトリのクローン

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 各言語でのビルドと実行

### Ruby

```bash
ruby demo.rb
```

外部依存なし。Ruby 2.7以降を推奨します。

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

GHC（Glasgow Haskell Compiler）が必要です。`haskell/` ディレクトリから実行してください。

### Common Lisp

```bash
sbcl --script demo.lisp
```

SBCL（Steel Bank Common Lisp）が必要です。`common-lisp/` ディレクトリから実行してください。

### Scheme

```bash
csi -R r5rs -script demo.scm
```

CHICKEN Scheme が必要です。`scheme/` ディレクトリから実行してください。

### Standard ML

```bash
mlton demo.mlb && ./demo
```

MLton コンパイラが必要です。`sml/` ディレクトリから実行してください。

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

GNAT（GNUのAdaコンパイラ）が必要です。`ada/` ディレクトリから実行してください。

### Prolog

```bash
swipl demo.pl
```

SWI-Prolog が必要です。`prolog/` ディレクトリから実行してください。

### Mercury

```bash
mmc --make demo && ./demo
```

Mercury コンパイラが必要です。`mercury/` ディレクトリから実行してください。

## デモの出力

各デモは以下の処理を実行します：

1. t-digest を初期化
2. サンプルデータを追加
3. 各種分位数（中央値、p90、p99など）を計算して表示
4. 推定値と理論値の比較を出力
