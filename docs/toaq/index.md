# t-digest — Saqchuq bı nä dûa báq quantıle jáq sho báq dataq flu

> **Toaq** bı jí shéaı báq zujuq bı rúa da. Toaq nä chô jí báq logıq garna bı kúe da. Hí raı bı Toaq nä kuq hú jí bı hóq da — shú hóq nä hóa báq puq kıjı da.

## Hı raı bı t-digest da moq?

**t-digest** bı jáq sho báq dataq lıq bı nä dûa báq quantıle da. Jí nä pûeq báq namkuq hú pıe pıe — hóe nä pûeq báq gıeq kuluq — bí hóq nä dûa báq quantıle jáq sho báq dataq bí nä kúe shú tú namkuq da. Shú "hı namkuq bı nä mıeq shú 99% báq namkuq rúa moq?" — t-digest nä dûa hóq da. t-digest nä dûe báq dataqpaı múao — hóq nä hóa báq dataqpaı bí nä hóa shú la'o **O(delta)** la'o poq da.

t-digest nä dûa báq quantıle jáq sho báq poka súı (báq taıl) bí nä rıaq mıeq da. Hóq nä kúe jáq sho: báq centroıd bí nä hóa shú báq poka súı bı nä kıaq da, jaq báq centroıd bí nä hóa shú báq cuq bı nä mıeq da. Jáq sho hóq nä hóa báq dataqpaı lılı bí nä dûa báq taıl quantıle bí nä rıaq loq da.

Báq scale functıon nä chuaq báq quantıle stuq taq báq ındeq stuq da. Báq scale functıon shéaı (shú **K_1** — báq arcsın functıon) nä kúe shú: báq centroıd bí nä hóa shú báq poka (q = 0 hóe q = 1) bı nä kıaq da — jáq sho hóq nä hóa báq satcı taıl da. Báq centroıd bí nä hóa shú báq cuq (q = 0.5) bı nä mıeq da — jáq sho hóq nä hóa báq dataqpaı lılı da.

## Báq daq teq

- **Dataq flu** — báq namkuq nä kúe pıe pıe da. t-digest nä hóa hú rúa bí nä dûe báq namkuq gu da. Báq tenpo nä hóa la'o **O(1)** la'o da.
- **Dataqpaı jımte** — jí nä pûeq báq namkuq bí nä mıeq (mılıon, bılıon) la báq dataqpaı nä hóa la'o **O(delta)** la'o da. Shú delta = 100 la báq centroıd nä mıeq shú hí kılobait lıe da.
- **Taıl satcı** — báq quantıle sketch daq nä dûa báq quantıle rúa bí nä kuq satcı da. t-digest nä dûa báq taıl quantıle (p99, p99.9) bí nä rıaq loq da.
- **Kúe merge** — t-digest fıeq nä kúe merge shú la'o **O(delta log delta)** la'o tenpo da. Hóq nä pûa báq dıstrıbuted sıstım: tú node bı nä chuq báq t-digest da, bí báq coordınator nä merge báq rúa da.

## Shodaı lıq

```
td = new TDigest(delta=100)

for each request_latency in stream:
    td.add(request_latency)

# "Hı namkuq bı nä mıeq shú 99% báq request rúa moq?"
p99 = td.quantile(0.99)

# "Hí request bí nä suaqdeo shú 200ms bı nä mıeq shú hı ce moq?"
fraction = td.cdf(200.0)

# Merge báq t-digest fıeq jáq sho server fıeq
combined = merge(server_a.digest, server_b.digest)
```
