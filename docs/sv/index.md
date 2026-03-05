# t-digest — Kvantiluppskattning i realtid

## Vad är en t-digest?

**t-digest** är en kompakt datastruktur för att uppskatta kvantiler och percentiler från en dataström. Den utvecklades av Ted Dunning och lämpar sig särskilt för scenarier där enorma datamängder måste bearbetas utan att alla värden lagras i minnet. Istället för att spara varje enskild datapunkt sammanfattar t-digest fördelningen i ett begränsat antal så kallade centroider.

Det som utmärker t-digest är dess utmärkta noggrannhet i fördelningens svansar. Medan många approximativa metoder tappar i precision just vid extrema percentiler (till exempel den 99,9:e percentilen), levererar t-digest där sina bästa resultat. Detta gör den idealisk för övervakning av latens, SLA-mått och anomalidetektering.

t-digest arbetar inkrementellt: nya värden kan läggas till när som helst utan att den befintliga sammanfattningen behöver räknas om. Dessutom kan flera t-digest-strukturer slås samman (merge), vilket möjliggör distribuerad beräkning över flera noder.

## Nyckalegenskaper

- **Strömmande/online-bearbetning** — Värden läggs till ett i taget eller i omgångar, utan att hela datamängden behöver hållas i minnet.
- **Begränsat minnesbehov O(delta)** — Antalet centroider styrs av kompressionsparametern delta och förblir konstant oavsett datamängdens storlek.
- **Hög svansnoggrannhet** — Uppskattningsfelen är minst vid fördelningens ytterligheter (nära 0 och 1), precis där det spelar störst roll i praktiken.

## Konceptet med skalfunktionen

t-digest använder en **skalfunktion** för att avgöra hur stor en centroid får bli vid en given position i fördelningen. Nära svansarna (kvantiler nära 0 eller 1) tillåter skalfunktionen endast mycket små centroider, vilket säkerställer hög noggrannhet. I mitten av fördelningen kan centroiderna vara större, eftersom lägre noggrannhet är acceptabel där. Skalfunktionen som används i detta projekt är K_1, baserad på arcussinus: `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Pseudokodexempel

```
# Skapa en ny t-digest med kompressionsparameter 100
td = TDigest(delta=100)

# Lägga till värden
för i från 0 till 9999:
    td.add(i / 10000.0)

# Fråga efter kvantiler
median   = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Fråga efter CDF-värde (omvänd riktning)
rang = td.cdf(0.42)            # ~0.42
```

## Fortsätt

Läs guiden [Kom igång](getting-started.md) för att kompilera och köra implementationerna.
