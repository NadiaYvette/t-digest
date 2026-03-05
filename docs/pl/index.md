# t-digest — Estymacja kwantyli w trybie online

## Czym jest t-digest?

**t-digest** to kompaktowa struktura danych służąca do estymacji kwantyli i percentyli ze strumienia danych. Została opracowana przez Teda Dunninga i jest szczególnie przydatna w scenariuszach, w których ogromne ilości danych muszą być przetwarzane bez przechowywania wszystkich wartości w pamięci. Zamiast zapisywać każdy punkt danych osobno, t-digest podsumowuje rozkład w ograniczonej liczbie tzw. centroidów.

Tym, co wyróżnia t-digest, jest doskonała dokładność w ogonach rozkładu. Podczas gdy wiele metod przybliżonych traci precyzję właśnie przy ekstremalnych percentylach (np. 99,9. percentyl), t-digest dostarcza tam najlepsze wyniki. Czyni go to idealnym narzędziem do monitorowania opóźnień, metryk SLA i wykrywania anomalii.

t-digest działa przyrostowo: nowe wartości mogą być dodawane w dowolnym momencie bez konieczności przeliczania dotychczasowego podsumowania. Ponadto kilka t-digestów można ze sobą scalić (merge), co umożliwia obliczenia rozproszone na wielu węzłach.

## Kluczowe właściwości

- **Przetwarzanie strumieniowe (streaming/online)** — Wartości dodawane są pojedynczo lub partiami, bez konieczności przechowywania całego zbioru danych w pamięci.
- **Ograniczone zużycie pamięci O(delta)** — Liczba centroidów jest kontrolowana przez parametr kompresji delta i pozostaje stała niezależnie od ilości danych.
- **Wysoka dokładność w ogonach** — Błędy estymacji są najmniejsze na krańcach rozkładu (blisko 0 i 1), czyli dokładnie tam, gdzie w praktyce jest to najważniejsze.

## Koncepcja funkcji skalującej

t-digest wykorzystuje **funkcję skalującą**, aby określić maksymalny rozmiar centroidu w danym miejscu rozkładu. W pobliżu ogonów (kwantyle bliskie 0 lub 1) funkcja skalująca dopuszcza jedynie bardzo małe centroidy, co zapewnia wysoką dokładność. W środku rozkładu centroidy mogą być większe, ponieważ mniejsza dokładność jest tam akceptowalna. Funkcja skalująca używana w tym projekcie to K_1, oparta na arcussinusie: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Przykład w pseudokodzie

```
# Utworzenie nowego t-digest z parametrem kompresji 100
td = TDigest(delta=100)

# Dodawanie wartości
dla i od 0 do 9999:
    td.add(i / 10000.0)

# Zapytanie o kwantyle
mediana  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Zapytanie o wartość CDF (kierunek odwrotny)
ranga = td.cdf(0.42)           # ~0.42
```

## Dalej

Zapoznaj się z przewodnikiem [Pierwsze kroki](getting-started.md), aby skompilować i uruchomić implementacje.
