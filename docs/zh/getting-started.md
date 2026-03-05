# 快速入门

本项目包含 8 种编程语言的 t-digest 实现。请按照以下说明构建和运行各个实现。

## 克隆仓库

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 各语言的构建与运行

### Ruby

```bash
ruby demo.rb
```

无外部依赖。建议使用 Ruby 2.7 及以上版本。

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

需要 GHC（Glasgow Haskell Compiler）。请在 `haskell/` 目录下执行。

### Common Lisp

```bash
sbcl --script demo.lisp
```

需要 SBCL（Steel Bank Common Lisp）。请在 `common-lisp/` 目录下执行。

### Scheme

```bash
csi -R r5rs -script demo.scm
```

需要 CHICKEN Scheme。请在 `scheme/` 目录下执行。

### Standard ML

```bash
mlton demo.mlb && ./demo
```

需要 MLton 编译器。请在 `sml/` 目录下执行。

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

需要 GNAT（GNU Ada 编译器）。请在 `ada/` 目录下执行。

### Prolog

```bash
swipl demo.pl
```

需要 SWI-Prolog。请在 `prolog/` 目录下执行。

### Mercury

```bash
mmc --make demo && ./demo
```

需要 Mercury 编译器。请在 `mercury/` 目录下执行。

## 演示输出

每个演示程序执行以下操作：

1. 初始化 t-digest
2. 添加样本数据
3. 计算并输出各种分位数（中位数、p90、p99 等）
4. 输出估计值与理论值的比较结果
