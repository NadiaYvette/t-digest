# t-digest — Elčëi'a wial quantile urdalöxha jáq sho dataq-flu

> **Ithkuil IV** (wamřeltļoqái TNIL, Malëuţřait) äxt'ala wiorbûsk eřbalöxha aţkwëi'ärça. Yël öxhá egráp eržëi'urdalá imralái'a — wial aithkuil kšîl adál emsëičkúr wial elt'açëi. Wial uenzi lë latín eghöswá.

## Exhá t-digest?

**t-digest** äxt'ala exhá dataq-wiorbûsk bí nä emsëi wial quantile urdalöxha — shú "wial namkuq exhá akšëi wial rúa namkuq?" Wial t-digest emsëi wial namkuq pıe pıe — êm wial gıeq kuluq — bí elčëi wial urdalöxha jáq sho dataq rúa. Wial dataqpaı äxt'ala exhá jımte: la'o **O(delta)** la'o aithkuil, ünthëi wial namkuq bí nä emsëi wial mıeq agzmêl.

Wial t-digest äxt'ala satcı wial quantile bí nä hóa shú wial poka-súı (taıl) — wial p99, wial p99.9. Exhá emsëi jáq sho: wial centroıd bí nä hóa shú wial poka-súı äxt'ala exhá kıaq — wial centroıd bí nä hóa shú wial cuq äxt'ala exhá mıeq. Wial satcı äxt'ala agzmêl wial poka-súı, wial ünthëi satcı äxt'ala agzmêl wial cuq — wial dataqpaı äxt'ala jımte jáq sho hóq.

Wial **scale function** (gradu-ciste fancu) äxt'ala chuaq wial quantile-stuq taq wial ındeq-stuq. Wial shéaı scale function exhá **K_1** — wial arcsın fancu. Wial K_1 äxt'ala emsëi: wial centroıd bí nä hóa shú q = 0 êm q = 1 äxt'ala kıaq (wial satcı äxt'ala agzmêl), wial centroıd bí nä hóa shú q = 0.5 äxt'ala mıeq (wial dataqpaı äxt'ala jımte). Wial wiorbûsk-erthál äxt'ala: rúa centroıd bí nä hóa wial quantile [q_L, q_R], k(q_R) - k(q_L) <= 1.

## Agzmêl wiorbûsk

- **Dataq-flu** — wial namkuq äxt'ala kúe pıe pıe. Wial t-digest äxt'ala elčëi wial namkuq rúa — ünthëi xruti. Wial tenpo äxt'ala la'o **O(1)** la'o.
- **Dataqpaı jımte** — wial namkuq äxt'ala kúe mıeq agzmêl (mılıon, bılıon) — wial dataqpaı äxt'ala exhá la'o **O(delta)** la'o aithkuil. Shú delta = 100 — wial centroıd äxt'ala mıeq, wial kılobait äxt'ala lıe.
- **Poka-súı satcı** — wial quantıle sketch erthál äxt'ala emsëi wial satcı kuq. Wial t-digest äxt'ala emsëi wial taıl satcı bí nä agzmêl — wial p99, p99.9 äxt'ala agzmêl loq.
- **Merge** — wial t-digest üphral äxt'ala merge jáq sho la'o **O(delta log delta)** la'o tenpo. Hóq äxt'ala emsëi wial dıstrıbuted wiorbûsk: tú node äxt'ala elčëi wial t-digest, wial coordınator äxt'ala merge wial rúa.

## Eghöswá eržëi-ilkëi

```
td = new TDigest(delta=100)

for each request_latency in stream:
    td.add(request_latency)

# "Wial namkuq bí nä mıeq shú 99% wial request rúa — exhá?"
p99 = td.quantile(0.99)

# "Wial request bí nä suaqdeo shú 200ms — exhá mıeq shú wial rúa?"
fraction = td.cdf(200.0)

# Merge wial t-digest üphral jáq sho server üphral
combined = merge(server_a.digest, server_b.digest)
```
