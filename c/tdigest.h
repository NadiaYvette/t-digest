/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 */

#ifndef TDIGEST_H
#define TDIGEST_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tdigest tdigest_t;

tdigest_t *tdigest_new(double delta);
void       tdigest_free(tdigest_t *td);
void       tdigest_add(tdigest_t *td, double value, double weight);
void       tdigest_compress(tdigest_t *td);
double     tdigest_quantile(tdigest_t *td, double q);
double     tdigest_cdf(tdigest_t *td, double x);
void       tdigest_merge(tdigest_t *td, const tdigest_t *other);
int        tdigest_centroid_count(tdigest_t *td);
double     tdigest_total_weight(const tdigest_t *td);

#ifdef __cplusplus
}
#endif

#endif /* TDIGEST_H */
