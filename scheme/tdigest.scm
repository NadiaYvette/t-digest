;;; tdigest.scm -- Dunning's t-digest (merging digest variant)
;;; with K1 (arcsine) scale function.
;;;
;;; Compatible with R5RS / R7RS Scheme.

;;; ============================================================
;;; Portability: provide pi and infinity constants
;;; ============================================================

(define pi (* 4.0 (atan 1.0)))
(define +inf +inf.0)
(define -inf -inf.0)

;;; ============================================================
;;; Centroid: a pair (mean . weight)
;;; ============================================================

(define (make-centroid mean weight)
  (cons mean weight))

(define (centroid-mean c)
  (car c))

(define (centroid-weight c)
  (cdr c))

;;; ============================================================
;;; T-Digest record stored as a vector:
;;;   0: delta       (compression parameter)
;;;   1: centroids   (sorted list of centroids)
;;;   2: buffer      (list of centroids awaiting merge)
;;;   3: total-weight
;;;   4: min
;;;   5: max
;;;   6: buffer-cap  (delta * 5)
;;; ============================================================

(define (make-tdigest . args)
  (let ((delta (if (null? args) 100.0 (exact->inexact (car args)))))
    (let ((td (make-vector 7)))
      (vector-set! td 0 delta)
      (vector-set! td 1 '())                       ; centroids
      (vector-set! td 2 '())                       ; buffer
      (vector-set! td 3 0.0)                       ; total-weight
      (vector-set! td 4 +inf)                      ; min
      (vector-set! td 5 -inf)                      ; max
      (vector-set! td 6 (inexact->exact (ceiling (* delta 5.0)))) ; buffer-cap
      td)))

(define (td-delta td)        (vector-ref td 0))
(define (td-centroids td)    (vector-ref td 1))
(define (td-buffer td)       (vector-ref td 2))
(define (td-total-weight td) (vector-ref td 3))
(define (td-min td)          (vector-ref td 4))
(define (td-max td)          (vector-ref td 5))
(define (td-buffer-cap td)   (vector-ref td 6))

(define (td-set-centroids! td v)    (vector-set! td 1 v))
(define (td-set-buffer! td v)       (vector-set! td 2 v))
(define (td-set-total-weight! td v) (vector-set! td 3 v))
(define (td-set-min! td v)          (vector-set! td 4 v))
(define (td-set-max! td v)          (vector-set! td 5 v))

;;; ============================================================
;;; Scale function K1: k(q, delta) = (delta / (2*pi)) * asin(2q - 1)
;;; ============================================================

(define (k-scale q delta)
  (* (/ delta (* 2.0 pi))
     (asin (- (* 2.0 q) 1.0))))

;;; ============================================================
;;; Merge-sort for centroid lists (sort by mean, ascending).
;;; Iterative merge to avoid stack overflow on large lists.
;;; ============================================================

(define (merge-sorted a b)
  (let loop ((a a) (b b) (acc '()))
    (cond
      ((null? a) (append (reverse acc) b))
      ((null? b) (append (reverse acc) a))
      ((<= (centroid-mean (car a)) (centroid-mean (car b)))
       (loop (cdr a) b (cons (car a) acc)))
      (else
       (loop a (cdr b) (cons (car b) acc))))))

(define (mergesort lst)
  (let ((len (length lst)))
    (if (<= len 1)
        lst
        (let* ((mid (quotient len 2))
               (left (take-n lst mid))
               (right (drop-n lst mid)))
          (merge-sorted (mergesort left) (mergesort right))))))

(define (take-n lst n)
  (let loop ((lst lst) (n n) (acc '()))
    (if (or (<= n 0) (null? lst))
        (reverse acc)
        (loop (cdr lst) (- n 1) (cons (car lst) acc)))))

(define (drop-n lst n)
  (if (or (<= n 0) (null? lst))
      lst
      (drop-n (cdr lst) (- n 1))))

;;; ============================================================
;;; Compress: merge buffered values into centroids
;;; ============================================================

(define (td-compress! td)
  (let ((buf (td-buffer td))
        (centroids (td-centroids td)))
    (if (and (null? buf) (<= (length centroids) 1))
        td
        (let* ((all (mergesort (append centroids buf)))
               (delta (td-delta td))
               (n (td-total-weight td))
               (all-len (length all)))
          (td-set-buffer! td '())
          (if (null? all)
              (begin
                (td-set-centroids! td '())
                td)
              ;; Greedy merge pass
              (let loop ((items (cdr all))
                         (cur-mean (centroid-mean (car all)))
                         (cur-weight (centroid-weight (car all)))
                         (weight-so-far 0.0)
                         (result '()))
                (if (null? items)
                    (let ((final (reverse (cons (make-centroid cur-mean cur-weight)
                                                result))))
                      (td-set-centroids! td final)
                      td)
                    (let* ((item (car items))
                           (item-mean (centroid-mean item))
                           (item-weight (centroid-weight item))
                           (proposed (+ cur-weight item-weight))
                           (q0 (/ weight-so-far n))
                           (q1 (/ (+ weight-so-far proposed) n))
                           ;; Clamp into [0,1] for asin domain safety
                           (q0c (max 0.0 (min 1.0 q0)))
                           (q1c (max 0.0 (min 1.0 q1))))
                      ;; Merge if proposed weight <= 1 (single points)
                      ;; or the scale function allows it.
                      (if (or (and (<= proposed 1.0) (> all-len 1))
                              (<= (- (k-scale q1c delta) (k-scale q0c delta)) 1.0))
                          ;; Merge into current centroid (weighted mean)
                          (let ((new-mean (/ (+ (* cur-mean cur-weight)
                                                (* item-mean item-weight))
                                             proposed)))
                            (loop (cdr items)
                                  new-mean
                                  proposed
                                  weight-so-far
                                  result))
                          ;; Start a new centroid
                          (loop (cdr items)
                                item-mean
                                item-weight
                                (+ weight-so-far cur-weight)
                                (cons (make-centroid cur-mean cur-weight)
                                      result)))))))))))

;;; ============================================================
;;; Add a value (with optional weight) to the digest
;;; ============================================================

(define (td-add! td value . args)
  (let ((weight (if (null? args) 1.0 (exact->inexact (car args))))
        (val (exact->inexact value)))
    (td-set-buffer! td (cons (make-centroid val weight) (td-buffer td)))
    (td-set-total-weight! td (+ (td-total-weight td) weight))
    (if (< val (td-min td))
        (td-set-min! td val))
    (if (> val (td-max td))
        (td-set-max! td val))
    (if (>= (length (td-buffer td)) (td-buffer-cap td))
        (td-compress! td))
    td))

;;; ============================================================
;;; Quantile estimation
;;; ============================================================

(define (td-quantile td q)
  (if (not (null? (td-buffer td)))
      (td-compress! td))
  (let ((centroids (td-centroids td)))
    (cond
      ((null? centroids) #f)
      ((null? (cdr centroids))
       (centroid-mean (car centroids)))
      (else
       (let* ((q (max 0.0 (min 1.0 q)))
              (n (td-total-weight td))
              (target (* q n))
              (lo (td-min td))
              (hi (td-max td))
              (cv (list->vector centroids))
              (nc (vector-length cv)))

         ;; Check left boundary: target falls in left half of first centroid
         (let* ((first-c (vector-ref cv 0))
                (first-cw (centroid-weight first-c))
                (first-cm (centroid-mean first-c)))
           (if (< target (/ first-cw 2.0))
               ;; Interpolate between min and first centroid mean
               (if (<= first-cw 1.0)
                   lo
                   (+ lo (* (- first-cm lo)
                            (/ target (/ first-cw 2.0)))))
               ;; Check right boundary: target falls in right half of last centroid
               (let* ((last-c (vector-ref cv (- nc 1)))
                      (last-cw (centroid-weight last-c))
                      (last-cm (centroid-mean last-c))
                      (right-start (- n (/ last-cw 2.0))))
                 (if (> target right-start)
                     ;; Interpolate between last centroid mean and max
                     (if (<= last-cw 1.0)
                         hi
                         (+ last-cm (* (- hi last-cm)
                                       (/ (- target right-start)
                                          (/ last-cw 2.0)))))
                     ;; Walk middle centroids
                     (let loop ((i 0) (cumulative 0.0))
                       (if (>= i (- nc 1))
                           ;; Should not reach here, but return last mean as fallback
                           (centroid-mean (vector-ref cv (- nc 1)))
                           (let* ((c (vector-ref cv i))
                                  (cw (centroid-weight c))
                                  (cm (centroid-mean c))
                                  (mid (+ cumulative (/ cw 2.0)))
                                  (next-c (vector-ref cv (+ i 1)))
                                  (next-cw (centroid-weight next-c))
                                  (next-cm (centroid-mean next-c))
                                  (next-mid (+ cumulative cw (/ next-cw 2.0))))
                             (if (<= target next-mid)
                                 (let ((frac (if (= next-mid mid)
                                                 0.5
                                                 (/ (- target mid)
                                                    (- next-mid mid)))))
                                   (+ cm (* frac (- next-cm cm))))
                                 (loop (+ i 1)
                                       (+ cumulative cw)))))))))))))))

;;; ============================================================
;;; CDF estimation (inverse of quantile)
;;; ============================================================

(define (td-cdf td x)
  (if (not (null? (td-buffer td)))
      (td-compress! td))
  (let ((centroids (td-centroids td))
        (x (exact->inexact x)))
    (cond
      ((null? centroids) #f)
      ((<= x (td-min td)) 0.0)
      ((>= x (td-max td)) 1.0)
      (else
       (let* ((n (td-total-weight td))
              (lo (td-min td))
              (hi (td-max td))
              (cv (list->vector centroids))
              (nc (vector-length cv)))

         ;; Check left of first centroid
         (let* ((first-c (vector-ref cv 0))
                (first-cw (centroid-weight first-c))
                (first-cm (centroid-mean first-c)))
           (cond
             ;; x is to the left of the first centroid mean
             ((< x first-cm)
              (let ((frac (if (= first-cm lo) 1.0
                              (/ (- x lo) (- first-cm lo)))))
                (/ (* (/ first-cw 2.0) frac) n)))
             ;; x equals first centroid mean exactly
             ((and (= x first-cm) (= nc 1))
              (/ (/ first-cw 2.0) n))
             (else
              ;; Walk centroids
              (let loop ((i 0) (cumulative 0.0))
                (if (>= i nc)
                    1.0
                    (let* ((c (vector-ref cv i))
                           (cw (centroid-weight c))
                           (cm (centroid-mean c))
                           (mid (+ cumulative (/ cw 2.0))))
                      (cond
                        ;; Last centroid
                        ((= i (- nc 1))
                         (if (> x cm)
                             ;; Interpolate in the right tail
                             (let* ((tail-weight (- n cumulative (/ cw 2.0)))
                                    (frac (if (= hi cm) 0.0
                                              (/ (- x cm) (- hi cm)))))
                               (/ (+ mid (* tail-weight frac)) n))
                             ;; x <= cm: return midpoint
                             (/ mid n)))
                        ;; Middle centroids: check if x falls between c and next
                        (else
                         (let* ((next-c (vector-ref cv (+ i 1)))
                                (next-cw (centroid-weight next-c))
                                (next-cm (centroid-mean next-c))
                                (next-cumulative (+ cumulative cw))
                                (next-mid (+ next-cumulative (/ next-cw 2.0))))
                           (if (< x next-cm)
                               ;; x is between cm and next-cm: interpolate
                               (if (= cm next-cm)
                                   (/ (+ mid (/ (- next-mid mid) 2.0)) n)
                                   (let ((frac (/ (- x cm)
                                                  (- next-cm cm))))
                                     (/ (+ mid (* frac (- next-mid mid))) n)))
                               ;; Move to next centroid
                               (loop (+ i 1) (+ cumulative cw)))))))))))))))))

;;; ============================================================
;;; Merge another t-digest into this one
;;; ============================================================

(define (td-merge! td other)
  ;; Flush other's buffer first
  (if (not (null? (td-buffer other)))
      (td-compress! other))
  ;; Add all of other's centroids as buffered values
  (for-each
   (lambda (c)
     (td-add! td (centroid-mean c) (centroid-weight c)))
   (td-centroids other))
  td)

;;; ============================================================
;;; Utility: count centroids (after flushing buffer)
;;; ============================================================

(define (td-centroid-count td)
  (if (not (null? (td-buffer td)))
      (td-compress! td))
  (length (td-centroids td)))
