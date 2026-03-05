# le t-digest — samtci be lo nu jdice le gradu poi jai barda ja cmalu fi le datni flu'ente

> **la .lojban.** cu bangu be lo logji. le gerna cu na mixre ja cfipu. ti noi uenzi cu se cusku fo la .lojban. .i le se cusku cu srana le t-digest samtci.

## mo fa le t-digest

le **t-digest** cu datni ciste poi se zbasu fi lo nu jdice le za'e gradu stuzi (la'o zoi quantile zoi) be le datni. do ka'e benji lo datni pa pa mai — ja lo barda girzu — gi'e cpacu le jdice be lo du'u "lo xo ce'i be le datni cu mleca le vi jdima." le t-digest cu na nitcu lo nu vreji ro le datni — ri cu jundi lo cmalu se vreji porsi noi ke'a goi ko'a se cusku fo lo za'e gradu stuzi ralju (la'o zoi centroid zoi).

mu'a do djica lo nu djuno le se go'i: "le jdima poi zmadu lo 99 ce'i be ro le jdima cu du ma." le t-digest cu satci mutce le jdice be le piso'iroi ke barda ja cmalu gradu stuzi. le se go'i cu se rinka le za'e gradu ciste fancu (la'o zoi scale function zoi) — le ka'e ciste cu pilno la'o zoi K_1 zoi noi sinuso fancu kei lo nu le gradu stuzi poi jibni 0 ja 1 cu se jundi lo cmalu ke gradu girzu. ni le gradu girzu cu cmalu kei fa ni le jdice cu satci.

le vajni ke tcila be le t-digest:

- **flu'ente datni** — le datni cu tolsti pa pa mai .i le t-digest cu zukte ro le datni gi'e na nitcu lo nu xruti fi le slabu datni. le temci cu la'o zoi O(1) zoi me'o se jmina.
- **jimte ke datnyvau** — ni so'i datni cu se jundi kei fa le t-digest cu clani cmalu. le datnyvau cu la'o zoi O(delta) zoi .i la .delta. cu lo 100 bi'o 200 ji'i.
- **piso'iroi ke satci** — le so'i za'e gradu catlu (la'o zoi quantile sketch zoi) cu dunli ke satci ro le gradu stuzi. le t-digest cu troci lo nu satci le piro'iroi ke barda ja cmalu gradu stuzi — le se go'i cu vajni lo nu catlu le tenpo be lo nu xruti (la'o zoi latency zoi).
- **ka'e jorne** — re t-digest ka'e se jorne fi le temci be la'o zoi O(delta log delta) zoi. le se go'i cu mapti lo nu le so'i skami cu zbasu le t-digest gi'e benji fi le ralju skami poi jorne ro le se go'i.

## le gradu ciste fancu

le gradu ciste fancu cu ciste le gradu stuzi (la'o zoi quantile zoi) fi le za'e cmima stuzi (la'o zoi index space zoi). le ciste cu rinka lo nu le gradu girzu poi jibni le cfari (la'o zoi q = 0 zoi) ja le fanmo (la'o zoi q = 1 zoi) cu cmalu — ni cmalu fa ni satci le jdice. le gradu girzu poi jibni le midju (la'o zoi q = 0.5 zoi) cu ka'e barda — le se go'i cu rinka lo nu le datnyvau cu se clani.

le ralju ke satci tcila cu le vi: ro le gradu girzu poi se cusku fo le gradu stuzi la'o zoi [q_L, q_R] zoi cu se jimte fi le nu la'o zoi k(q_R) - k(q_L) <= 1 zoi. le se go'i cu rinka lo nu le fliba cu jdika ri'a lo nu le gradu stuzi cu jibni 0 ja 1.

## le cmalu mupli

```
td = new TDigest(delta=100)

for each request_latency in stream:
    td.add(request_latency)

# "le jdima poi zmadu lo 99 ce'i be ro le xruti cu du ma?"
p99 = td.quantile(0.99)

# "lo xo ce'i be le xruti cu sutra fi lo 200ms?"
fraction = td.cdf(200.0)

# jorne le re skami ke t-digest
combined = merge(server_a.digest, server_b.digest)
```
