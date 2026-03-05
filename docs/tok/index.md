# t-digest — ilo nanpa pi sona e suli pi nanpa mute

> **toki pona** li toki lili. ona li jo e nimi 130 taso. lipu ni li kepeken toki pona tawa ni: jan li sona e ilo t-digest.

## seme li t-digest?

**t-digest** li ilo nanpa. sina pana e nanpa mute tawa ona — nanpa wan, nanpa wan, nanpa wan — ona li awen e sona lili lon insa ona. sina ken pana e nanpa ale tawa ona, taso ona li kepeken poki lili taso. tenpo ale la poki ona li suli sama.

sina wile sona e ni: "nanpa seme li suli tawa nanpa ale? nanpa pi mute 99 tan nanpa ale li suli seme?" t-digest li ken toki e ni. ona li sona pona mute tawa nanpa pi poka suli (nanpa pi suli ale) en nanpa pi poka lili (nanpa pi lili ale). ni li pona mute tawa sona pi tenpo tawa-kama lon kulupu ilo (latency).

t-digest li jo e nasin ni: ona li kulupu e nanpa lon kulupu lili. kulupu lili pi poka suli en poka lili li lili — tan ni la sona li pona lon poka ni. kulupu lili pi insa li ken suli — tan ni la poki li lili. nasin ni li "nasin pi ante suli" (scale function) — ona li toki e ni: kulupu lili li ken suli seme lon ma seme.

## ijo suli ona

- **nanpa li kama wan wan** — t-digest li ken kama jo e nanpa wan lon tenpo wan. sina ken ala e nanpa ale lon tenpo wan — ni li pona.
- **poki li lili awen** — sina pana e nanpa ale (nanpa tonsi, nanpa ale ale) tawa t-digest la poki li suli sama. poki li suli pi nanpa lili taso — la'o **O(delta)** la'o. nanpa delta li 100 anu 200 kepeken.
- **sona pona lon poka suli** — ilo nanpa ante li sona sama lon ma ale. t-digest li sona pona mute lon poka suli en poka lili — ma ni li suli tawa jan kepeken.
- **tu li ken kama wan** — t-digest tu li ken kama wan. ni li pona tawa ni: ilo mute li pali e t-digest wan wan, ilo mama li kama jo e ale, li wan e ale.

## nasin pi ante suli

nasin pi ante suli (scale function) li nasin ni: ona li toki e ni tawa t-digest: "kulupu lili li ken suli seme lon ma seme." lon poka suli en poka lili la kulupu lili li wile lili — tan ni la sona li pona. lon insa la kulupu lili li ken suli — tan ni la poki li lili. nasin open li la'o **K_1** la'o — ona li kepeken nasin sinuso.

## sitelen toki ilo

```
td = new TDigest(delta=100)

for each request_latency in stream:
    td.add(request_latency)

# "nanpa seme li suli tawa nanpa pi mute 99 tan nanpa ale?"
p99 = td.quantile(0.99)

# "nanpa pi mute seme tan nanpa ale li lili tawa 200ms?"
fraction = td.cdf(200.0)

# wan e t-digest tu tan ilo tu
combined = merge(server_a.digest, server_b.digest)
```
