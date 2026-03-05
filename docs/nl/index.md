# t-digest — Online kwantielschatting

## Wat is een t-digest?

De **t-digest** is een compacte datastructuur voor het schatten van kwantielen en percentielen uit een datastroom. De structuur werd ontwikkeld door Ted Dunning en is bijzonder geschikt voor scenario's waarin enorme hoeveelheden data verwerkt moeten worden zonder alle waarden in het geheugen te bewaren. In plaats van elk afzonderlijk datapunt op te slaan, vat de t-digest de verdeling samen in een begrensd aantal zogenaamde centroïden.

Wat de t-digest onderscheidt, is zijn uitstekende nauwkeurigheid in de staarten van de verdeling. Terwijl veel benaderingsmethoden juist bij extreme percentielen (zoals het 99,9e percentiel) onnauwkeurig worden, levert de t-digest daar de beste resultaten. Dit maakt hem ideaal voor het monitoren van latentie, SLA-metrieken en anomaliedetectie.

De t-digest werkt incrementeel: nieuwe waarden kunnen op elk moment worden toegevoegd zonder de bestaande samenvatting opnieuw te hoeven berekenen. Bovendien kunnen meerdere t-digests worden samengevoegd (merge), wat gedistribueerde berekening over meerdere knooppunten mogelijk maakt.

## Belangrijkste eigenschappen

- **Streaming-/onlineverwerking** — Waarden worden één voor één of in batches toegevoegd, zonder de volledige dataset in het geheugen te hoeven houden.
- **Begrensd geheugengebruik O(delta)** — Het aantal centroïden wordt bepaald door de compressieparameter delta en blijft constant, ongeacht de hoeveelheid data.
- **Hoge staartnauwkeurigheid** — De schattingsfouten zijn het kleinst aan de uiteinden van de verdeling (dicht bij 0 en 1), precies waar het er in de praktijk het meest toe doet.

## Het concept van de schaalfunctie

De t-digest gebruikt een **schaalfunctie** om te bepalen hoe groot een centroïde op een bepaalde positie in de verdeling mag worden. Dicht bij de staarten (kwantielen nabij 0 of 1) staat de schaalfunctie slechts zeer kleine centroïden toe, wat zorgt voor hoge nauwkeurigheid. In het midden van de verdeling mogen de centroïden groter zijn, omdat daar minder nauwkeurigheid aanvaardbaar is. De schaalfunctie die in dit project wordt gebruikt, is K_1, gebaseerd op de arcsinus: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Pseudocode-voorbeeld

```
# Nieuwe t-digest aanmaken met compressieparameter 100
td = TDigest(delta=100)

# Waarden toevoegen
voor i van 0 tot 9999:
    td.add(i / 10000.0)

# Kwantielen opvragen
mediaan  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# CDF-waarde opvragen (omgekeerde richting)
rang = td.cdf(0.42)            # ~0.42
```

## Verder

Raadpleeg de gids [Aan de slag](getting-started.md) om de implementaties te compileren en uit te voeren.
