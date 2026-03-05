# t-digest — Interreta kvantila taksado

## Kio estas t-digest?

**t-digest** estas kompakta datumstrukturo por taksi kvantilojn kaj procentilojn el datumfluo. Ĝi estis ellaborita de Ted Dunning kaj estas aparte utila en scenaroj, kie enormaj datumvolumenoj devas esti prilaboritaj sen konservi ĉiujn valorojn en la memoro. Anstataŭ konservi ĉiun apartan datumpunkton, la t-digest resumas la distribuon en limigita nombro da tiel nomataj centroidoj.

Tio, kio distingas la t-digest, estas ĝia bonega precizeco en la vostoj de la distribuo. Dum multaj aproksimaj metodoj perdas precizecon ĝuste ĉe ekstremaj procentiloj (ekzemple la 99,9-a procentilo), la t-digest liveras tie siajn plej bonajn rezultojn. Tio igas ĝin ideala por monitorado de latenteco, SLA-metrikoj kaj detektado de anomalioj.

La t-digest funkcias inkremente: novaj valoroj povas esti aldonitaj iam ajn sen neceso rekalkuladi la ekzistantan resumon. Krome, pluraj t-digest-oj povas esti kunfanditaj (merge), kio ebligas distribuitan komputadon tra pluraj nodoj.

## Ĉefaj ecoj

- **Flua/interreta prilaborado** — Valoroj estas aldonataj unuope aŭ en grupoj, sen neceso teni la tutan datumaron en la memoro.
- **Limigita memoruzo O(delta)** — La nombro de centroidoj estas kontrolata de la kunprema parametro delta kaj restas konstanta sendepende de la datumvolumeno.
- **Alta vosta precizeco** — La taksaj eraroj estas plej malgrandaj ĉe la ekstremaĵoj de la distribuo (proksime al 0 kaj 1), precize tie, kie tio plej gravas en la praktiko.

## La koncepto de la skalfunkcio

La t-digest uzas **skalfunkcion** por determini la maksimuman grandecon, kiun centroido povas atingi ĉe donita pozicio de la distribuo. Proksime al la vostoj (kvantiloj proksimaj al 0 aŭ 1) la skalfunkcio permesas nur tre malgrandajn centroidojn, kio certigas altan precizecon. En la mezo de la distribuo la centroidoj povas esti pli grandaj, ĉar tie malpli da precizeco estas akceptebla. La skalfunkcio uzata en ĉi tiu projekto estas K_1, bazita sur la arksinuso: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Ekzemplo en pseŭdokodo

```
# Krei novan t-digest kun kunprema parametro 100
td = TDigest(delta=100)

# Aldoni valorojn
por i de 0 ĝis 9999:
    td.add(i / 10000.0)

# Demandi kvantilojn
mediano  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Demandi CDF-valoron (inversa direkto)
rango = td.cdf(0.42)           # ~0.42
```

## Pluen

Konsultu la gvidilon [Unuaj paŝoj](getting-started.md) por kompili kaj ruli la realigojn.
