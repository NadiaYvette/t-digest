# t-digest — Stima online dei quantili

## Che cos'è un t-digest?

Il **t-digest** è una struttura dati compatta per la stima di quantili e percentili da un flusso di dati. Sviluppato da Ted Dunning, è particolarmente adatto a scenari in cui enormi volumi di dati devono essere elaborati senza conservare tutti i valori in memoria. Invece di memorizzare ogni singolo punto dati, il t-digest riassume la distribuzione in un numero limitato di cosiddetti centroidi.

Ciò che distingue il t-digest è la sua eccellente precisione nelle code della distribuzione. Mentre molti metodi approssimati perdono precisione proprio nei percentili estremi (ad esempio il 99,9° percentile), il t-digest offre lì i suoi migliori risultati. Questo lo rende ideale per il monitoraggio delle latenze, le metriche SLA e il rilevamento di anomalie.

Il t-digest funziona in modo incrementale: nuovi valori possono essere aggiunti in qualsiasi momento senza dover ricalcolare il riepilogo esistente. Inoltre, più t-digest possono essere uniti (merge), consentendo il calcolo distribuito su più nodi.

## Proprietà chiave

- **Elaborazione in streaming (online)** — I valori vengono aggiunti uno alla volta o in blocchi, senza necessità di mantenere l'intero insieme di dati in memoria.
- **Memoria limitata O(delta)** — Il numero di centroidi è controllato dal parametro di compressione delta e rimane costante indipendentemente dalla quantità di dati.
- **Alta precisione nelle code** — Gli errori di stima sono minimi agli estremi della distribuzione (vicino a 0 e 1), esattamente dove conta di più nella pratica.

## Il concetto di funzione di scala

Il t-digest utilizza una **funzione di scala** per determinare la dimensione massima che un centroide può raggiungere in una determinata posizione della distribuzione. Vicino alle code (quantili prossimi a 0 o 1), la funzione di scala permette solo centroidi molto piccoli, garantendo un'alta precisione. Al centro della distribuzione, i centroidi possono essere più grandi, poiché una minore precisione è accettabile. La funzione di scala utilizzata in questo progetto è K_1, basata sull'arcoseno: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Esempio in pseudocodice

```
# Creare un nuovo t-digest con parametro di compressione 100
td = TDigest(delta=100)

# Aggiungere valori
per i da 0 a 9999:
    td.add(i / 10000.0)

# Interrogare i quantili
mediana  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Interrogare il valore CDF (direzione inversa)
rango = td.cdf(0.42)           # ~0.42
```

## Proseguire

Consultare la guida [Per iniziare](getting-started.md) per compilare ed eseguire le implementazioni.
