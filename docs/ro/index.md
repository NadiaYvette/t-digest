# t-digest — Estimarea online a cuantilelor

## Ce este un t-digest?

**t-digest** este o structură de date compactă pentru estimarea cuantilelor și percentilelor dintr-un flux de date. A fost dezvoltată de Ted Dunning și este deosebit de utilă în scenarii în care volume uriașe de date trebuie procesate fără a păstra toate valorile în memorie. În loc să stocheze fiecare punct de date în mod individual, t-digest rezumă distribuția într-un număr limitat de așa-numiți centroizi.

Ceea ce distinge t-digest este precizia sa excelentă în cozile distribuției. În timp ce multe metode aproximative pierd precizie tocmai la percentilele extreme (de exemplu, percentila 99,9), t-digest oferă acolo cele mai bune rezultate. Acest lucru îl face ideal pentru monitorizarea latenței, metrici SLA și detectarea anomaliilor.

t-digest funcționează incremental: valori noi pot fi adăugate oricând, fără a fi necesar să se recalculeze rezumatul existent. În plus, mai multe t-digest-uri pot fi fuzionate (merge), ceea ce permite calculul distribuit pe mai multe noduri.

## Proprietăți cheie

- **Procesare în flux (streaming/online)** — Valorile sunt adăugate una câte una sau în loturi, fără a fi necesară păstrarea întregului set de date în memorie.
- **Memorie limitată O(delta)** — Numărul de centroizi este controlat de parametrul de compresie delta și rămâne constant, indiferent de volumul de date.
- **Precizie ridicată în cozi** — Erorile de estimare sunt cele mai mici la extremitățile distribuției (aproape de 0 și 1), exact acolo unde contează cel mai mult în practică.

## Conceptul funcției de scară

t-digest utilizează o **funcție de scară** pentru a determina dimensiunea maximă pe care un centroid o poate atinge la o anumită poziție a distribuției. Aproape de cozi (cuantile apropiate de 0 sau 1), funcția de scară permite doar centroizi foarte mici, ceea ce asigură o precizie ridicată. În centrul distribuției, centroizii pot fi mai mari, deoarece o precizie mai mică este acceptabilă acolo. Funcția de scară utilizată în acest proiect este K_1, bazată pe arcsin: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Exemplu în pseudocod

```
# Crearea unui nou t-digest cu parametrul de compresie 100
td = TDigest(delta=100)

# Adăugarea valorilor
pentru i de la 0 la 9999:
    td.add(i / 10000.0)

# Interogarea cuantilelor
mediană   = td.quantile(0.5)    # ~0.5
p99       = td.quantile(0.99)   # ~0.99
p999      = td.quantile(0.999)  # ~0.999

# Interogarea valorii CDF (direcție inversă)
rang = td.cdf(0.42)             # ~0.42
```

## Continuare

Consultați ghidul [Primii pași](getting-started.md) pentru a compila și rula implementările.
