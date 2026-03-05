# t-digest — Estimation de quantiles en ligne

## Qu'est-ce qu'un t-digest ?

Le **t-digest** est une structure de données compacte permettant d'estimer les quantiles et les percentiles à partir d'un flux de données. Développé par Ted Dunning, il est particulièrement adapté aux scénarios où d'énormes volumes de données doivent être traités sans conserver toutes les valeurs en mémoire. Au lieu de stocker chaque point de données individuellement, le t-digest résume la distribution en un nombre borné de centroïdes.

Ce qui distingue le t-digest, c'est son excellente précision dans les queues de distribution. Alors que de nombreuses méthodes approximatives perdent en précision justement aux percentiles extrêmes (par exemple le 99,9e percentile), le t-digest y fournit ses meilleurs résultats. Cela le rend idéal pour la surveillance des latences, les métriques de SLA et la détection d'anomalies.

Le t-digest fonctionne de manière incrémentale : de nouvelles valeurs peuvent être ajoutées à tout moment sans avoir à recalculer le résumé existant. De plus, plusieurs t-digests peuvent être fusionnés (merge), ce qui permet le calcul distribué sur plusieurs nœuds.

## Propriétés clés

- **Traitement en flux (streaming/online)** — Les valeurs sont ajoutées une par une ou par lots, sans nécessité de conserver l'ensemble des données en mémoire.
- **Mémoire bornée O(delta)** — Le nombre de centroïdes est contrôlé par le paramètre de compression delta et reste constant quelle que soit la quantité de données.
- **Haute précision dans les queues** — Les erreurs d'estimation sont les plus faibles aux extrémités de la distribution (près de 0 et 1), précisément là où cela importe le plus en pratique.

## Le concept de fonction d'échelle

Le t-digest utilise une **fonction d'échelle** pour déterminer la taille maximale qu'un centroïde peut atteindre à une position donnée de la distribution. Près des queues (quantiles proches de 0 ou 1), la fonction d'échelle ne permet que de très petits centroïdes, ce qui garantit une haute précision. Au centre de la distribution, les centroïdes peuvent être plus grands, car une moindre précision y est acceptable. La fonction d'échelle utilisée dans ce projet est K_1, basée sur l'arc sinus : `k(q) = (delta / 2*pi) * arcsin(2*q - 1)`.

## Exemple en pseudocode

```
# Créer un nouveau t-digest avec paramètre de compression 100
td = TDigest(delta=100)

# Ajouter des valeurs
pour i de 0 à 9999 :
    td.add(i / 10000.0)

# Interroger les quantiles
médiane  = td.quantile(0.5)    # ~0.5
p99      = td.quantile(0.99)   # ~0.99
p999     = td.quantile(0.999)  # ~0.999

# Interroger la valeur CDF (direction inverse)
rang = td.cdf(0.42)            # ~0.42
```

## Suite

Consultez le guide de [Prise en main](getting-started.md) pour compiler et exécuter les implémentations.
