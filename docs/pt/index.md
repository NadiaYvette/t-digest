# t-digest — Estimativa online de quantis

## O que é um t-digest?

O **t-digest** é uma estrutura de dados compacta para estimar quantis e percentis a partir de um fluxo de dados. Foi desenvolvido por Ted Dunning e é especialmente útil em cenários onde grandes volumes de dados precisam ser processados sem manter todos os valores em memória. Em vez de armazenar cada ponto de dados individualmente, o t-digest resume a distribuição num número limitado de chamados centróides.

O que distingue o t-digest é a sua excelente precisão nas caudas da distribuição. Enquanto muitos métodos aproximados perdem precisão justamente nos percentis extremos (por exemplo, o percentil 99,9), o t-digest oferece aí os seus melhores resultados. Isto torna-o ideal para monitorização de latências, métricas de SLA e deteção de anomalias.

O t-digest funciona de forma incremental: novos valores podem ser adicionados a qualquer momento sem necessidade de recalcular o resumo existente. Além disso, vários t-digests podem ser fundidos (merge), o que permite o cálculo distribuído em múltiplos nós.

## Propriedades-chave

- **Processamento em fluxo (streaming/online)** — Os valores são adicionados um a um ou em lotes, sem necessidade de manter todo o conjunto de dados em memória.
- **Memória limitada O(delta)** — O número de centróides é controlado pelo parâmetro de compressão delta e permanece constante independentemente do volume de dados.
- **Alta precisão nas caudas** — Os erros de estimativa são menores nos extremos da distribuição (perto de 0 e 1), exatamente onde mais importa na prática.

## O conceito de função de escala

O t-digest utiliza uma **função de escala** para determinar o tamanho máximo que um centróide pode atingir numa determinada posição da distribuição. Perto das caudas (quantis próximos de 0 ou 1), a função de escala permite apenas centróides muito pequenos, o que garante alta precisão. No centro da distribuição, os centróides podem ser maiores, pois aí uma menor precisão é aceitável. A função de escala utilizada neste projeto é K_1, baseada no arco seno: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Exemplo em pseudocódigo

```
# Criar um novo t-digest com parâmetro de compressão 100
td = TDigest(delta=100)

# Adicionar valores
para i de 0 a 9999:
    td.add(i / 10000.0)

# Consultar quantis
mediana  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Consultar valor CDF (direção inversa)
posição = td.cdf(0.42)         # ~0.42
```

## Próximo passo

Consulte o guia de [Primeiros passos](getting-started.md) para compilar e executar as implementações.
