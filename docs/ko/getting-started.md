# 빠른 시작

이 프로젝트에는 8개 프로그래밍 언어로 구현된 t-digest가 포함되어 있습니다. 아래 지침에 따라 각 구현을 빌드하고 실행하세요.

## 저장소 복제

```bash
git clone https://github.com/example/t-digest.git
cd t-digest
```

## 각 언어별 빌드 및 실행

### Ruby

```bash
ruby demo.rb
```

외부 의존성 없음. Ruby 2.7 이상을 권장합니다.

### Haskell

```bash
ghc -O2 Main.hs -o demo && ./demo
```

GHC(Glasgow Haskell Compiler)가 필요합니다. `haskell/` 디렉터리에서 실행하세요.

### Common Lisp

```bash
sbcl --script demo.lisp
```

SBCL(Steel Bank Common Lisp)이 필요합니다. `common-lisp/` 디렉터리에서 실행하세요.

### Scheme

```bash
csi -R r5rs -script demo.scm
```

CHICKEN Scheme이 필요합니다. `scheme/` 디렉터리에서 실행하세요.

### Standard ML

```bash
mlton demo.mlb && ./demo
```

MLton 컴파일러가 필요합니다. `sml/` 디렉터리에서 실행하세요.

### Ada

```bash
gnatmake -O2 demo.adb -o demo && ./demo
```

GNAT(GNU Ada 컴파일러)가 필요합니다. `ada/` 디렉터리에서 실행하세요.

### Prolog

```bash
swipl demo.pl
```

SWI-Prolog가 필요합니다. `prolog/` 디렉터리에서 실행하세요.

### Mercury

```bash
mmc --make demo && ./demo
```

Mercury 컴파일러가 필요합니다. `mercury/` 디렉터리에서 실행하세요.

## 데모 출력

각 데모는 다음 작업을 수행합니다:

1. t-digest를 초기화
2. 샘플 데이터를 추가
3. 다양한 분위수(중앙값, p90, p99 등)를 계산하여 출력
4. 추정값과 이론값의 비교를 출력
