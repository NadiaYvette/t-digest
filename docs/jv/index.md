# t-digest — Struktur Data kanggo Ngira-ngira Kuantil kanthi Streaming

## Ringkesan

**t-digest** yaiku struktur data probabilistik sing dirancang kanggo ngira-ngira kuantil (persentil) saka aliran data kanthi efisien. Algoritma iki diciptakake dening Ted Dunning, bisa ngolah data siji-siji kanthi cara streaming tanpa perlu nyimpen kabeh data ing memori, nanging tetep menehi estimasi kuantil sing akurat.

Sifat paling unggul saka t-digest yaiku akurasi sing dhuwur banget ing bagian buntut (tail) distribusi. Sanajan akurasi ing cedhake median bisa uga rada kurang, nanging nalika ngira-ngira kuantil sing ekstrem kayata persentil ka-99 utawa ka-99.9, t-digest nduweni akurasi sing dhuwur banget. Sifat iki penting banget kanggo aplikasi nyata kayata monitoring SLA lan analisis latensi.

Ing njero, t-digest nglumpukake titik-titik data dadi kluster sing diarani "centroid" (pusat massa). Jumlah memori sing digunakake dikontrol dening parameter kompresi δ, lan operasi kanthi memori winates O(δ) sing ora gumantung marang jumlah total data input.

## Sifat-sifat Utama

- **Pemrosesan streaming / online** — Bisa nambahake titik data siji-siji, ora perlu nyimpen kabeh data ing memori
- **Memori winates O(δ)** — Jumlah memori sing digunakake mung gumantung marang parameter kompresi δ, ora gumantung marang jumlah data
- **Akurasi buntut** — Nggayuh akurasi sing dhuwur banget ing ujung loro distribusi (cedhak 0% lan 100%)
- **Bisa digabung** — Pirang-pirang t-digest bisa digabungake, cocog kanggo sistem terdistribusi

## Konsep Fungsi Skala

Inti saka t-digest yaiku "fungsi skala" (scale function). Fungsi skala ngontrol sepira gedhene centroid bisa tuwuh ing saben posisi distribusi. Ing bagian tengah distribusi, centroid diijinake dadi gedhe (ngemot akeh titik data); ing bagian buntut, mung centroid cilik sing diijinake. Kanthi mekanisme iki, luwih akeh centroid sing dipasang ing bagian buntut, saengga akurasi estimasi ing buntut dadi luwih dhuwur.

## Conto Panganggo (Pseudocode)

```
# Gawe t-digest (parameter kompresi δ = 100)
td = TDigest.new(delta: 100)

# Nambahake titik data siji-siji
td.add(1.0)
td.add(2.5)
td.add(3.7)
td.add(100.0)
td.add(0.01)

# Bisa ngolah data akeh tanpa masalah
for value in data_stream:
    td.add(value)

# Takon kuantil
median    = td.quantile(0.5)    # Median
p99       = td.quantile(0.99)   # Persentil ka-99
p999      = td.quantile(0.999)  # Persentil ka-99.9

# Takon mbalik: golek nilai CDF saka nilai tartamtu
cdf_value = td.cdf(42.0)        # Proporsi data sing kurang utawa padha karo 42.0
```

## Langkah Sabanjure

Deleng pandhuan [Wiwit Cepet](getting-started.md) kanggo sinau carane mbangun lan mbukak implementasi ing saben basa.
