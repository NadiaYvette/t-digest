# t-digest — Online-Quantilschätzung

## Was ist ein t-digest?

Der **t-digest** ist eine kompakte Datenstruktur zur Schätzung von Quantilen und Perzentilen aus einem Datenstrom. Er wurde von Ted Dunning entwickelt und eignet sich besonders für Szenarien, in denen riesige Datenmengen verarbeitet werden müssen, ohne alle Werte im Speicher zu halten. Statt jeden einzelnen Datenpunkt zu speichern, fasst der t-digest die Datenverteilung in einer begrenzten Anzahl von sogenannten Zentroiden zusammen.

Das Besondere am t-digest ist seine hervorragende Genauigkeit in den Randbereichen der Verteilung. Während viele approximative Verfahren gerade bei extremen Perzentilen (z. B. dem 99,9. Perzentil) ungenau werden, liefert der t-digest dort die besten Ergebnisse. Das macht ihn ideal für die Überwachung von Latenzzeiten, SLA-Metriken und Anomalieerkennung.

Der t-digest arbeitet inkrementell: Neue Werte können jederzeit hinzugefügt werden, ohne die bisherige Zusammenfassung neu berechnen zu müssen. Außerdem lassen sich mehrere t-digests zusammenführen (Merge), was eine verteilte Berechnung über mehrere Knoten hinweg ermöglicht.

## Schlüsseleigenschaften

- **Streaming / Online-Verarbeitung** — Werte werden einzeln oder in Chargen hinzugefügt, ohne den gesamten Datensatz im Speicher halten zu müssen.
- **Begrenzter Speicherverbrauch O(delta)** — Die Anzahl der Zentroide wird durch den Kompressionsparameter delta gesteuert und bleibt unabhängig von der Datenmenge konstant.
- **Hohe Randgenauigkeit** — Die Schätzfehler sind an den Rändern der Verteilung (nahe 0 und 1) am kleinsten, genau dort, wo es in der Praxis am meisten darauf ankommt.

## Das Konzept der Skalierungsfunktion

Der t-digest verwendet eine **Skalierungsfunktion** (engl. scale function), um zu bestimmen, wie groß ein Zentroid an einer bestimmten Stelle der Verteilung werden darf. In der Nähe der Ränder (Quantile nahe 0 oder 1) erlaubt die Skalierungsfunktion nur sehr kleine Zentroide, was zu hoher Genauigkeit führt. In der Mitte der Verteilung dürfen die Zentroide größer sein, da hier geringere Genauigkeit akzeptabel ist. Die in diesem Projekt verwendete Skalierungsfunktion ist K_1, die auf dem Arkussinus basiert: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Pseudocode-Beispiel

```
# Neuen t-digest mit Kompressionsparameter 100 erstellen
td = TDigest(delta=100)

# Werte hinzufügen
für i von 0 bis 9999:
    td.add(i / 10000.0)

# Quantile abfragen
median   = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# CDF-Wert abfragen (umgekehrte Richtung)
rang = td.cdf(0.42)            # ~0.42
```

## Weiter

Lesen Sie die [Erste Schritte](getting-started.md)-Anleitung, um die Implementierungen zu bauen und auszuführen.
