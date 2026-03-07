;;;; tdigest.lisp -- Dunning t-digest (merging digest variant) with K1 scale function
;;;; Uses an array-backed 2-3-4 tree with four-component monoidal measures.

;;; ---------------------------------------------------------------------------
;;; Centroid: a single cluster with a mean and weight
;;; ---------------------------------------------------------------------------

(defstruct centroid
  (mean   0.0d0 :type double-float)
  (weight 0.0d0 :type double-float))

;;; ---------------------------------------------------------------------------
;;; Measure / trait functions for tree234
;;; ---------------------------------------------------------------------------

(defun centroid-measure-fn (c)
  "Compute the monoidal measure of a single centroid."
  (tree234:make-tree234-measure
   :weight (centroid-weight c)
   :count 1
   :max-mean (centroid-mean c)
   :mean-weight-sum (* (centroid-mean c) (centroid-weight c))))

(defun centroid-combine-fn (a b)
  "Combine two measures monoidally."
  (tree234:make-tree234-measure
   :weight (+ (tree234:tree234-measure-weight a)
              (tree234:tree234-measure-weight b))
   :count (+ (tree234:tree234-measure-count a)
             (tree234:tree234-measure-count b))
   :max-mean (max (tree234:tree234-measure-max-mean a)
                  (tree234:tree234-measure-max-mean b))
   :mean-weight-sum (+ (tree234:tree234-measure-mean-weight-sum a)
                       (tree234:tree234-measure-mean-weight-sum b))))

(defun centroid-identity-fn ()
  "Return the monoidal identity measure."
  (tree234:make-tree234-measure
   :weight 0.0d0
   :count 0
   :max-mean most-negative-double-float
   :mean-weight-sum 0.0d0))

(defun centroid-compare-fn (a b)
  "Compare two centroids by mean. Returns <0, 0, or >0."
  (let ((ma (centroid-mean a))
        (mb (centroid-mean b)))
    (cond ((< ma mb) -1)
          ((> ma mb)  1)
          (t          0))))

;;; ---------------------------------------------------------------------------
;;; T-Digest structure
;;; ---------------------------------------------------------------------------

(defstruct tdigest
  (delta        100.0d0       :type double-float)
  (tree         (tree234:make-tree234
                 :measure-fn  #'centroid-measure-fn
                 :combine-fn  #'centroid-combine-fn
                 :identity-fn #'centroid-identity-fn
                 :compare-fn  #'centroid-compare-fn))
  (buffer       (make-array 0 :element-type 'centroid :adjustable t :fill-pointer 0)
                              :type (vector centroid))
  (buffer-cap   500           :type fixnum)
  (total-weight 0.0d0         :type double-float)
  (min-val      most-positive-double-float :type double-float)
  (max-val      most-negative-double-float :type double-float))

(defun create-tdigest (&optional (delta 100.0d0))
  "Create a new t-digest with the given compression parameter DELTA."
  (let ((d (coerce delta 'double-float)))
    (make-tdigest :delta d
                  :buffer-cap (ceiling (* d 5.0d0)))))

;;; ---------------------------------------------------------------------------
;;; Scale function K1 (arcsine)
;;; ---------------------------------------------------------------------------

(defun k1 (q delta)
  "K1 scale function: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)."
  (declare (type double-float q delta))
  (* (/ delta (* 2.0d0 pi))
     (asin (- (* 2.0d0 q) 1.0d0))))

;;; ---------------------------------------------------------------------------
;;; Merge a centroid into an existing centroid (weighted mean update)
;;; ---------------------------------------------------------------------------

(defun merge-centroid (target source)
  "Merge SOURCE centroid into TARGET centroid using weighted mean."
  (let* ((w1 (centroid-weight target))
         (w2 (centroid-weight source))
         (new-weight (+ w1 w2)))
    (setf (centroid-mean target)
          (/ (+ (* (centroid-mean target) w1)
                (* (centroid-mean source) w2))
             new-weight))
    (setf (centroid-weight target) new-weight)))

;;; ---------------------------------------------------------------------------
;;; Add a value to the digest
;;; ---------------------------------------------------------------------------

(defun tdigest-add (td value &optional (weight 1.0d0))
  "Add VALUE with WEIGHT to the t-digest TD. Triggers compression when the
buffer is full."
  (let ((v (coerce value 'double-float))
        (w (coerce weight 'double-float)))
    (vector-push-extend (make-centroid :mean v :weight w)
                        (tdigest-buffer td))
    (incf (tdigest-total-weight td) w)
    (when (< v (tdigest-min-val td))
      (setf (tdigest-min-val td) v))
    (when (> v (tdigest-max-val td))
      (setf (tdigest-max-val td) v))
    (when (>= (length (tdigest-buffer td))
              (tdigest-buffer-cap td))
      (tdigest-compress td)))
  td)

;;; ---------------------------------------------------------------------------
;;; Compress: merge centroids + buffer, greedy re-cluster
;;; ---------------------------------------------------------------------------

(defun centroid-mean< (a b)
  (< (centroid-mean a) (centroid-mean b)))

(defun tdigest-compress (td)
  "Compress the t-digest TD by merging buffered values into the centroid list."
  (let ((buf  (tdigest-buffer td))
        (tree (tdigest-tree td)))
    (when (and (zerop (length buf))
               (<= (tree234:tree234-size tree) 1))
      (return-from tdigest-compress td))

    ;; Collect all centroids from tree and buffer into a single sorted vector
    (let* ((tree-cents (tree234:tree234-collect tree))
           (total-count (+ (length tree-cents) (length buf)))
           (all (make-array total-count :element-type 'centroid)))
      ;; Copy tree centroids
      (loop for i below (length tree-cents)
            do (setf (aref all i) (aref tree-cents i)))
      ;; Copy buffer
      (loop for i below (length buf)
            do (setf (aref all (+ (length tree-cents) i)) (aref buf i)))
      ;; Sort by mean
      (setf all (sort all #'centroid-mean<))

      ;; Reset buffer
      (setf (fill-pointer (tdigest-buffer td)) 0)

      ;; Greedy merge pass
      (let* ((n (tdigest-total-weight td))
             (delta (tdigest-delta td))
             (new-cents (make-array 0 :element-type 'centroid
                                      :adjustable t :fill-pointer 0))
             (weight-so-far 0.0d0))
        ;; Start with a copy of the first item
        (vector-push-extend (make-centroid :mean (centroid-mean (aref all 0))
                                           :weight (centroid-weight (aref all 0)))
                            new-cents)
        (loop for i from 1 below total-count
              do (let* ((current (aref new-cents (1- (length new-cents))))
                        (item (aref all i))
                        (proposed (+ (centroid-weight current)
                                     (centroid-weight item)))
                        (q0 (/ weight-so-far n))
                        (q1 (/ (+ weight-so-far proposed) n)))
                   (if (or (and (<= proposed 1.0d0) (> total-count 1))
                           (<= (- (k1 q1 delta) (k1 q0 delta)) 1.0d0))
                       ;; Merge into current centroid
                       (merge-centroid current item)
                       ;; Start a new centroid
                       (progn
                         (incf weight-so-far (centroid-weight current))
                         (vector-push-extend
                          (make-centroid :mean (centroid-mean item)
                                         :weight (centroid-weight item))
                          new-cents)))))
        ;; Rebuild tree from sorted merged centroids
        (tree234:tree234-build-from-sorted tree new-cents))))
  td)

;;; ---------------------------------------------------------------------------
;;; Helper: collect centroids from tree as a simple-vector
;;; ---------------------------------------------------------------------------

(defun tdigest-centroids (td)
  "Return the current centroids as a vector (after flushing buffer if needed)."
  (tree234:tree234-collect (tdigest-tree td)))

;;; ---------------------------------------------------------------------------
;;; Quantile estimation
;;; ---------------------------------------------------------------------------

(defun tdigest-quantile (td q)
  "Estimate the value at quantile Q (0..1) from the t-digest TD."
  (when (> (length (tdigest-buffer td)) 0)
    (tdigest-compress td))
  (let* ((tree (tdigest-tree td))
         (sz   (tree234:tree234-size tree)))
    (when (zerop sz)
      (return-from tdigest-quantile nil))
    (let ((cents (tree234:tree234-collect tree)))
      (when (= sz 1)
        (return-from tdigest-quantile (centroid-mean (aref cents 0))))

      ;; Clamp q
      (setf q (max 0.0d0 (min 1.0d0 (coerce q 'double-float))))

      (let* ((n (tdigest-total-weight td))
             (target (* q n))
             (num-cents (length cents))
             (cumulative 0.0d0))
        (loop for i below num-cents
              for c = (aref cents i)
              for mid = (+ cumulative (/ (centroid-weight c) 2.0d0))
              do
                 ;; Left boundary: interpolate between min and first centroid
                 (when (and (= i 0) (< target (/ (centroid-weight c) 2.0d0)))
                   (if (= (centroid-weight c) 1.0d0)
                       (return-from tdigest-quantile (tdigest-min-val td))
                       (return-from tdigest-quantile
                         (+ (tdigest-min-val td)
                            (* (- (centroid-mean c) (tdigest-min-val td))
                               (/ target (/ (centroid-weight c) 2.0d0)))))))

                 ;; Right boundary: interpolate between last centroid and max
                 (when (= i (1- num-cents))
                   (let ((right-start (- n (/ (centroid-weight c) 2.0d0))))
                     (if (> target right-start)
                         (if (= (centroid-weight c) 1.0d0)
                             (return-from tdigest-quantile (tdigest-max-val td))
                             (return-from tdigest-quantile
                               (+ (centroid-mean c)
                                  (* (- (tdigest-max-val td) (centroid-mean c))
                                     (/ (- target right-start)
                                        (/ (centroid-weight c) 2.0d0))))))
                         (return-from tdigest-quantile (centroid-mean c)))))

                 ;; Middle: interpolate between adjacent centroid midpoints
                 (let* ((next-c (aref cents (1+ i)))
                        (next-mid (+ cumulative
                                     (centroid-weight c)
                                     (/ (centroid-weight next-c) 2.0d0))))
                   (when (<= target next-mid)
                     (let ((frac (if (= next-mid mid)
                                     0.5d0
                                     (/ (- target mid) (- next-mid mid)))))
                       (return-from tdigest-quantile
                         (+ (centroid-mean c)
                            (* frac (- (centroid-mean next-c)
                                       (centroid-mean c))))))))

                 (incf cumulative (centroid-weight c)))
        ;; Fallback
        (tdigest-max-val td)))))

;;; ---------------------------------------------------------------------------
;;; CDF estimation (inverse of quantile)
;;; ---------------------------------------------------------------------------

(defun tdigest-cdf (td x)
  "Estimate the cumulative distribution function at X for the t-digest TD."
  (when (> (length (tdigest-buffer td)) 0)
    (tdigest-compress td))
  (let* ((tree (tdigest-tree td))
         (sz   (tree234:tree234-size tree)))
    (when (zerop sz)
      (return-from tdigest-cdf nil))

    (let ((xd (coerce x 'double-float)))
      (when (<= xd (tdigest-min-val td))
        (return-from tdigest-cdf 0.0d0))
      (when (>= xd (tdigest-max-val td))
        (return-from tdigest-cdf 1.0d0))

      (let* ((cents (tree234:tree234-collect tree))
             (n (tdigest-total-weight td))
             (num-cents (length cents))
             (cumulative 0.0d0))
        (loop for i below num-cents
              for c = (aref cents i)
              do
                 ;; Left boundary: between min and first centroid
                 (when (= i 0)
                   (cond
                     ((< xd (centroid-mean c))
                      (let* ((inner-w (/ (centroid-weight c) 2.0d0))
                             (frac (if (= (centroid-mean c) (tdigest-min-val td))
                                       1.0d0
                                       (/ (- xd (tdigest-min-val td))
                                          (- (centroid-mean c) (tdigest-min-val td))))))
                        (return-from tdigest-cdf (/ (* inner-w frac) n))))
                     ((= xd (centroid-mean c))
                      (return-from tdigest-cdf
                        (/ (/ (centroid-weight c) 2.0d0) n)))))

                 ;; Right boundary
                 (when (= i (1- num-cents))
                   (if (> xd (centroid-mean c))
                       (let* ((inner-w (/ (centroid-weight c) 2.0d0))
                              (right-w (- n cumulative inner-w))
                              (frac (if (= (tdigest-max-val td) (centroid-mean c))
                                        0.0d0
                                        (/ (- xd (centroid-mean c))
                                           (- (tdigest-max-val td)
                                              (centroid-mean c))))))
                         (return-from tdigest-cdf
                           (/ (+ cumulative
                                 (/ (centroid-weight c) 2.0d0)
                                 (* right-w frac))
                              n)))
                       (return-from tdigest-cdf
                         (/ (+ cumulative (/ (centroid-weight c) 2.0d0)) n))))

                 ;; Middle: interpolate between adjacent centroid midpoints
                 (let* ((mid (+ cumulative (/ (centroid-weight c) 2.0d0)))
                        (next-c (aref cents (1+ i)))
                        (next-cumulative (+ cumulative (centroid-weight c)))
                        (next-mid (+ next-cumulative
                                     (/ (centroid-weight next-c) 2.0d0))))
                   (when (< xd (centroid-mean next-c))
                     (let ((frac (if (= (centroid-mean c) (centroid-mean next-c))
                                     0.5d0
                                     (/ (- xd (centroid-mean c))
                                        (- (centroid-mean next-c)
                                           (centroid-mean c))))))
                       (return-from tdigest-cdf
                         (/ (+ mid (* frac (- next-mid mid))) n)))))

                 (incf cumulative (centroid-weight c)))
        ;; Fallback
        1.0d0))))

;;; ---------------------------------------------------------------------------
;;; Merge another t-digest into this one
;;; ---------------------------------------------------------------------------

(defun tdigest-merge (td other)
  "Merge t-digest OTHER into t-digest TD."
  ;; First flush the other digest
  (when (> (length (tdigest-buffer other)) 0)
    (tdigest-compress other))
  ;; Add all centroids from other as buffered values
  (let ((other-cents (tree234:tree234-collect (tdigest-tree other))))
    (loop for c across other-cents
          do (tdigest-add td (centroid-mean c) (centroid-weight c))))
  td)

;;; ---------------------------------------------------------------------------
;;; Utility: centroid count after flushing buffer
;;; ---------------------------------------------------------------------------

(defun tdigest-centroid-count (td)
  "Return the number of centroids after compressing any buffered values."
  (when (> (length (tdigest-buffer td)) 0)
    (tdigest-compress td))
  (tree234:tree234-size (tdigest-tree td)))
