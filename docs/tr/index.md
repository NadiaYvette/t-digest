# t-digest — Akış Tabanlı Kantil Tahmin Veri Yapısı

## Genel Bakış

**t-digest**, veri akışlarından kantilleri (yüzdelikleri) verimli bir şekilde tahmin etmek için tasarlanmış olasılıksal bir veri yapısıdır. Ted Dunning tarafından geliştirilen bu algoritma, tüm veriyi bellekte tutmaya gerek kalmadan verileri akış halinde sıralı olarak işleyerek doğru kantil tahminleri sunar.

t-digest'in en belirgin özelliği, dağılımın kuyruk (tail) bölgelerinde özellikle yüksek doğruluğa sahip olmasıdır. Medyan civarındaki doğruluk biraz düşük olabilse de, 99. yüzdelik veya 99.9. yüzdelik gibi uç kantillerin tahmininde son derece yüksek doğruluk sağlar. Bu özellik, SLA izleme ve gecikme analizi gibi pratik uygulamalarda büyük önem taşır.

Dahili olarak t-digest, veri noktalarını "centroid" (ağırlık merkezi) adı verilen kümelere toplayarak saklar. Kullanılan bellek miktarı sıkıştırma parametresi δ tarafından kontrol edilir ve toplam giriş verisi sayısından bağımsız olarak O(δ) sınırlı bellekle çalışır.

## Temel Özellikler

- **Akış / çevrimiçi işleme** — Veri noktaları tek tek eklenebilir, tüm verilerin bellekte tutulmasına gerek yoktur
- **Sınırlı bellek O(δ)** — Bellek kullanımı yalnızca sıkıştırma parametresi δ'ya bağlıdır, veri miktarından bağımsızdır
- **Kuyruk doğruluğu** — Dağılımın her iki ucunda (%0 ve %100'e yakın) özellikle yüksek doğruluk sağlar
- **Birleştirilebilir** — Birden fazla t-digest birleştirilebilir, dağıtık sistemler için uygundur

## Ölçek Fonksiyonu Kavramı

t-digest'in özünde "ölçek fonksiyonu" (scale function) bulunur. Ölçek fonksiyonu, dağılımın her konumunda centroid'lerin ne kadar büyüyebileceğini kontrol eder. Dağılımın orta bölgesinde centroid'lerin büyük olmasına (çok sayıda veri noktası içermesine) izin verilirken, kuyruk bölgesinde yalnızca küçük centroid'lere izin verilir. Bu mekanizma sayesinde kuyruk bölgesinde daha fazla centroid yerleştirilir ve kuyrukta tahmin doğruluğu artar.

## Kullanım Örneği (Sözde Kod)

```
# t-digest oluştur (sıkıştırma parametresi δ = 100)
td = TDigest.new(delta: 100)

# Veri noktalarını tek tek ekle
td.add(1.0)
td.add(2.5)
td.add(3.7)
td.add(100.0)
td.add(0.01)

# Büyük miktarda veri sorunsuz işlenebilir
for value in data_stream:
    td.add(value)

# Kantil sorgula
median    = td.quantile(0.5)    # Medyan
p99       = td.quantile(0.99)   # 99. yüzdelik
p999      = td.quantile(0.999)  # 99.9. yüzdelik

# Ters sorgu: bir değerin CDF değerini al
cdf_value = td.cdf(42.0)        # 42.0'dan küçük veya eşit veri oranı
```

## Sonraki Adım

Her dildeki uygulamaların nasıl derleneceğini ve çalıştırılacağını öğrenmek için [Hızlı Başlangıç](getting-started.md) kılavuzuna bakın.
