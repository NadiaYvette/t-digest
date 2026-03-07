# t-digest — Struktur Data Anggaran Kuantil Secara Penstriman

## Gambaran Keseluruhan

**t-digest** ialah struktur data kebarangkalian yang direka untuk menganggar kuantil (persentil) daripada aliran data dengan cekap. Algoritma ini dicipta oleh Ted Dunning dan membolehkan pemprosesan data secara berurutan dalam mod penstriman tanpa perlu menyimpan semua data dalam memori, sambil memberikan anggaran kuantil yang tepat.

Sifat paling unggul t-digest ialah ketepatan yang sangat tinggi di bahagian ekor (tail) taburan. Walaupun ketepatan berhampiran median mungkin sedikit rendah, tetapi apabila menganggar kuantil yang melampau seperti persentil ke-99 atau ke-99.9, t-digest menunjukkan ketepatan yang sangat tinggi. Sifat ini amat penting dalam aplikasi sebenar seperti pemantauan SLA dan analisis kependaman.

Secara dalaman, t-digest mengumpulkan titik data ke dalam gugusan yang dipanggil "sentroid" (centroid). Jumlah memori yang digunakan dikawal oleh parameter pemampatan δ, dan beroperasi dengan memori terhad O(δ) yang tidak bergantung kepada jumlah keseluruhan data input.

## Sifat-sifat Utama

- **Pemprosesan penstriman / dalam talian** — Boleh menambah titik data satu persatu, tidak perlu menyimpan semua data dalam memori
- **Memori terhad O(δ)** — Jumlah memori yang digunakan hanya bergantung kepada parameter pemampatan δ, tidak bergantung kepada jumlah data
- **Ketepatan ekor** — Mencapai ketepatan yang sangat tinggi di kedua-dua hujung taburan (berhampiran 0% dan 100%)
- **Boleh digabung** — Beberapa t-digest boleh digabungkan, sesuai untuk sistem teragih

## Konsep Fungsi Skala

Teras t-digest ialah "fungsi skala" (scale function). Fungsi skala mengawal seberapa besar sentroid boleh membesar pada setiap kedudukan dalam taburan. Di bahagian tengah taburan, sentroid dibenarkan menjadi besar (mengandungi banyak titik data); di bahagian ekor, hanya sentroid kecil yang dibenarkan. Melalui mekanisme ini, lebih banyak sentroid diletakkan di bahagian ekor, seterusnya meningkatkan ketepatan anggaran di ekor.

## Contoh Penggunaan (Kod Pseudo)

```
# Cipta t-digest (parameter pemampatan δ = 100)
td = TDigest.new(delta: 100)

# Tambah titik data satu persatu
td.add(1.0)
td.add(2.5)
td.add(3.7)
td.add(100.0)
td.add(0.01)

# Boleh memproses data yang banyak tanpa masalah
for value in data_stream:
    td.add(value)

# Tanya kuantil
median    = td.quantile(0.5)    # Median
p99       = td.quantile(0.99)   # Persentil ke-99
p999      = td.quantile(0.999)  # Persentil ke-99.9

# Pertanyaan songsang: dapatkan nilai CDF bagi sesuatu nilai
cdf_value = td.cdf(42.0)        # Nisbah data yang kurang daripada atau sama dengan 42.0
```

## Langkah Seterusnya

Projek ini tersedia dalam 28 bahasa pengaturcaraan.

Lihat panduan [Mula Pantas](getting-started.md) untuk mempelajari cara membina dan menjalankan pelaksanaan dalam setiap bahasa.
