# References

## Primary Sources

1. **Dunning, T. and Ertl, O.** (2019).
   "Computing Extremely Accurate Quantiles Using t-Digests."
   *arXiv preprint* arXiv:1902.04023.
   <https://arxiv.org/abs/1902.04023>

   The main reference for the t-digest algorithm as implemented in this
   project. Describes the merging digest variant, scale functions K0
   through K3, the compression invariant, and empirical accuracy analysis.

2. **Dunning, T.** (2021).
   "The t-digest: Efficient estimates of distributions."
   *Software Impacts*, 7, 100049.
   <https://doi.org/10.1016/j.simpa.2020.100049>

   A shorter overview paper describing the practical impact and
   applications of the t-digest.

3. **Dunning, T.** (2024).
   *t-digest reference implementation* (Java).
   <https://github.com/tdunning/t-digest>

   The canonical open-source implementation maintained by the original
   author.

## Related Work

4. **Greenwald, M. and Khanna, S.** (2001).
   "Space-Efficient Online Computation of Quantile Summaries."
   *Proc. ACM SIGMOD*, pp. 58--66.
   <https://doi.org/10.1145/375663.375670>

   The GK sketch: a deterministic quantile summary with epsilon-rank
   guarantees. Not mergeable.

5. **Shrivastava, N., Buragohain, C., Agrawal, D., and Suri, S.** (2004).
   "Medians and Beyond: New Aggregation Techniques for Sensor Networks."
   *Proc. ACM SenSys*, pp. 239--249.
   <https://doi.org/10.1145/1031495.1031524>

   The Q-digest: a mergeable quantile sketch for integer-valued data
   using a tree over the value universe.

6. **Karnin, Z., Lang, K., and Liberty, E.** (2016).
   "Optimal Quantile Approximation in Streams."
   *Proc. IEEE FOCS*, pp. 71--78.
   <https://doi.org/10.1109/FOCS.2016.17>

   The KLL sketch: achieves optimal space/accuracy trade-off for
   epsilon-rank quantile approximation. Mergeable.

7. **Masson, C., Rim, J. E., and Lee, H. K.** (2019).
   "DDSketch: A Fast and Fully-Mergeable Quantile Sketch with
   Relative-Error Guarantees."
   *Proc. VLDB Endowment*, 12(12), pp. 2195--2205.
   <https://doi.org/10.14778/3352063.3352135>

   DDSketch: provides relative (multiplicative) error guarantees using
   logarithmically-spaced bins. Fully mergeable and very fast.

8. **Gan, E., Ding, J., Tai, K. S., Sharan, V., and Bailis, P.** (2018).
   "Moment-Based Quantile Sketches for Efficient High Cardinality
   Aggregation Queries."
   *Proc. VLDB Endowment*, 11(11), pp. 1647--1660.
   <https://doi.org/10.14778/3236187.3236212>

   The moments sketch: stores statistical moments and reconstructs the
   distribution via maximum entropy optimization.
