# t-digest

Online quantile estimation with the Dunning t-digest algorithm.

<!-- badges -->
![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

## Overview

This repository contains implementations of the **merging t-digest** data
structure in eight programming languages. The t-digest provides fast,
memory-bounded, mergeable approximation of quantiles (percentiles) from
streaming data, with especially high accuracy in the tails (p99, p99.9,
etc.).

All implementations use the **K1 (arcsine) scale function** as described
in Dunning & Ertl (2019).

## Implementations

| Language      | Files                              | Style              |
|---------------|------------------------------------|---------------------|
| Haskell       | `haskell/TDigest.hs`, `Main.hs`   | Pure functional     |
| Ruby          | `ruby/tdigest.rb`                  | Object-oriented     |
| Ada           | `ada/tdigest.ads`, `tdigest.adb`   | Imperative/record   |
| Common Lisp   | `common-lisp/tdigest.lisp`         | Struct-based        |
| Scheme        | `scheme/tdigest.scm`               | Functional/mutable  |
| Standard ML   | `sml/tdigest.sml`                  | Pure functional     |
| Prolog        | `prolog/tdigest.pl`                | Logic/relational    |
| Mercury       | `mercury/tdigest.m`                | Pure functional     |

## Quick Start

### Haskell

```bash
cd haskell/
ghc -O2 -o demo Main.hs TDigest.hs
./demo
```

### Ruby

```bash
cd ruby/
ruby tdigest.rb
```

### Ada

```bash
cd ada/
gnatmake demo.adb
./demo
```

### Common Lisp

```bash
cd common-lisp/
sbcl --script demo.lisp
```

### Scheme

```bash
cd scheme/
csi -R r5rs -script demo.scm
```

### Standard ML

```bash
cd sml/
mlton demo.mlb
./demo
```

### Prolog

```bash
cd prolog/
swipl demo.pl
```

### Mercury

```bash
cd mercury/
mmc --make demo
./demo
```

## Documentation

Full documentation is available in the `docs/` directory and can be
built with [mdBook](https://rust-lang.github.io/mdBook/):

```bash
cd docs/
mdbook build
```

The documentation includes:

- **Introduction** -- What is a t-digest and why use it
- **Building Intuition** -- A gentle, diagram-heavy walkthrough of the
  core ideas
- **Algorithm Details** -- Formal pseudocode, scale function variants,
  accuracy analysis, and comparison with other quantile sketches
- **API Reference** -- Function signatures and usage for all eight
  language implementations
- **Getting Started** -- Build and run instructions for every language
- **References** -- Academic papers and related work

## Algorithm Summary

The t-digest maintains a sorted list of weighted centroids that
approximate the empirical CDF. A scale function (K1 / arcsine) ensures
that centroids near the tails (q near 0 or 1) are kept small for high
accuracy, while centroids near the median can grow large to save space.

Key properties:

- **O(1) amortized add** (for fixed compression parameter delta)
- **O(delta) space** -- typically a few hundred centroids
- **Mergeable** -- combine digests from distributed workers in
  O(delta log delta) time
- **High tail accuracy** -- error shrinks as you approach q=0 or q=1

## License

MIT License

Copyright (c) 2025 Nadia Yvette Chambers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Citation

If you use this software in academic work, please cite:

```bibtex
@article{dunning2019computing,
  title={Computing Extremely Accurate Quantiles Using t-Digests},
  author={Dunning, Ted and Ertl, Otmar},
  journal={arXiv preprint arXiv:1902.04023},
  year={2019}
}
```
