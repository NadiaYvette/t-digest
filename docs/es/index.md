# t-digest — Estimación de cuantiles en línea

## ¿Qué es un t-digest?

El **t-digest** es una estructura de datos compacta para estimar cuantiles y percentiles a partir de un flujo de datos. Fue desarrollado por Ted Dunning y resulta especialmente útil en escenarios donde se deben procesar grandes volúmenes de datos sin almacenar todos los valores en memoria. En lugar de guardar cada punto de datos individualmente, el t-digest resume la distribución en un número acotado de centroides.

Lo que distingue al t-digest es su excelente precisión en las colas de la distribución. Mientras que muchos métodos aproximados pierden precisión justamente en los percentiles extremos (como el percentil 99,9), el t-digest ofrece allí sus mejores resultados. Esto lo hace ideal para la monitorización de latencias, métricas de SLA y detección de anomalías.

El t-digest funciona de forma incremental: se pueden agregar nuevos valores en cualquier momento sin necesidad de recalcular el resumen existente. Además, varios t-digests pueden fusionarse (merge), lo que permite el cálculo distribuido a través de múltiples nodos.

## Propiedades clave

- **Procesamiento en flujo (streaming/online)** — Los valores se añaden uno a uno o en lotes, sin necesidad de mantener todo el conjunto de datos en memoria.
- **Memoria acotada O(delta)** — El número de centroides se controla mediante el parámetro de compresión delta y permanece constante independientemente del volumen de datos.
- **Alta precisión en las colas** — Los errores de estimación son menores en los extremos de la distribución (cerca de 0 y 1), precisamente donde más importa en la práctica.

## El concepto de función de escala

El t-digest utiliza una **función de escala** para determinar el tamaño máximo que puede tener un centroide en una posición determinada de la distribución. Cerca de las colas (cuantiles próximos a 0 o 1), la función de escala solo permite centroides muy pequeños, lo que garantiza alta precisión. En el centro de la distribución, los centroides pueden ser más grandes, ya que allí se tolera menor precisión. La función de escala utilizada en este proyecto es K_1, basada en el arcoseno: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Ejemplo en pseudocódigo

```
# Crear un nuevo t-digest con parámetro de compresión 100
td = TDigest(delta=100)

# Añadir valores
para i de 0 a 9999:
    td.add(i / 10000.0)

# Consultar cuantiles
mediana  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Consultar valor CDF (dirección inversa)
rango = td.cdf(0.42)           # ~0.42
```

## Siguiente paso

Consulte la guía de [Primeros pasos](getting-started.md) para compilar y ejecutar las implementaciones.
