;;;; bench.lisp -- Benchmark / asymptotic-behavior tests for Common Lisp t-digest
;;;; Run with: sbcl --script bench.lisp

(load (merge-pathnames "tdigest.lisp" *load-truename*))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defvar *pass-count* 0)
(defvar *fail-count* 0)

(defun get-time-ms ()
  "Return current time in milliseconds (internal real time)."
  (* 1000.0d0 (/ (get-internal-real-time) internal-time-units-per-second)))

(defmacro time-block (&body body)
  "Execute BODY and return elapsed time in milliseconds."
  (let ((t0 (gensym)) (t1 (gensym)))
    `(let ((,t0 (get-time-ms)))
       ,@body
       (let ((,t1 (get-time-ms)))
         (- ,t1 ,t0)))))

(defun check (label ok)
  (if ok
      (progn
        (incf *pass-count*)
        (format t "  ~A  PASS~%" label))
      (progn
        (incf *fail-count*)
        (format t "  ~A  FAIL~%" label))))

(defun ratio-ok-p (ratio expected &optional (lo 0.5) (hi 3.0))
  (and (>= ratio (* expected lo))
       (<= ratio (* expected hi))))

;;; Simple LCG random number generator (no external deps)
(defvar *rng-state* 12345)
(defun simple-random ()
  "Return a pseudo-random double in [0, 1)."
  (setf *rng-state* (mod (+ (* *rng-state* 1103515245) 12345) (expt 2 31)))
  (/ (coerce *rng-state* 'double-float) (coerce (expt 2 31) 'double-float)))

;;; ---------------------------------------------------------------------------

(format t "=== T-Digest Asymptotic Behavior Tests (Common Lisp) ===~%~%")

;;; ---------------------------------------------------------------------------
;;; Test 1: add() is amortized O(1)
;;; ---------------------------------------------------------------------------

(format t "--- Test 1: add() is amortized O(1) ---~%")

(defvar *sizes* '(1000 10000 100000 1000000))
(defvar *times-1*
  (mapcar (lambda (n)
            (let ((td (create-tdigest 100.0d0)))
              (let ((ms (time-block
                          (dotimes (i n)
                            (tdigest-add td (/ (coerce i 'double-float)
                                               (coerce n 'double-float)))))))
                (format t "  N=~9D  time=~,1Fms~%" n ms)
                ms)))
          *sizes*))

(loop for i from 1 below (length *sizes*)
      for n = (nth i *sizes*)
      for expected = (/ (coerce n 'double-float)
                        (coerce (nth (1- i) *sizes*) 'double-float))
      for ratio = (/ (nth i *times-1*) (nth (1- i) *times-1*))
      do (check (format nil "N=~D  ratio=~,2F (expected ~~~,1F)" n ratio expected)
                (ratio-ok-p ratio expected)))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Test 2: Centroid count bounded by O(delta)
;;; ---------------------------------------------------------------------------

(format t "--- Test 2: Centroid count bounded by O(delta) ---~%")

(let ((delta 100.0d0))
  (dolist (n *sizes*)
    (let ((td (create-tdigest delta)))
      (dotimes (i n)
        (tdigest-add td (/ (coerce i 'double-float) (coerce n 'double-float))))
      (let ((cc (tdigest-centroid-count td)))
        (check (format nil "N=~9D  centroids=~4D  (delta=~D, limit=~D)"
                       n cc (round delta) (* 5 (round delta)))
               (<= cc (* 5 (round delta))))))))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Test 3: Query time independent of N
;;; ---------------------------------------------------------------------------

(format t "--- Test 3: Query time independent of N ---~%")

(defvar *query-sizes* '(1000 10000 100000))
(defvar *query-times*
  (mapcar (lambda (n)
            (let ((td (create-tdigest 100.0d0)))
              (dotimes (i n)
                (tdigest-add td (/ (coerce i 'double-float) (coerce n 'double-float))))
              (tdigest-compress td)
              (let* ((iterations 10000)
                     (ms (time-block
                           (dotimes (j iterations)
                             (tdigest-quantile td 0.5d0)
                             (tdigest-cdf td 0.5d0))))
                     (us-per (/ (* ms 1000.0d0) iterations)))
                (format t "  N=~9D  query_time=~,2Fus~%" n us-per)
                us-per)))
          *query-sizes*))

(loop for i from 1 below (length *query-sizes*)
      for ratio = (/ (nth i *query-times*) (nth (1- i) *query-times*))
      do (check (format nil "N=~D  ratio=~,2F (expected ~~1.0)"
                        (nth i *query-sizes*) ratio)
                (ratio-ok-p ratio 1.0d0 0.2d0 5.0d0)))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Test 4: Tail accuracy improves with delta
;;; ---------------------------------------------------------------------------

(format t "--- Test 4: Tail accuracy improves with delta ---~%")

(let ((deltas '(50.0d0 100.0d0 200.0d0))
      (tail-qs '(0.01d0 0.001d0 0.99d0 0.999d0))
      (n-acc 100000))
  (dolist (q tail-qs)
    (let ((errors
           (mapcar (lambda (d)
                     (let ((td (create-tdigest d)))
                       (dotimes (i n-acc)
                         (tdigest-add td (/ (coerce i 'double-float)
                                            (coerce n-acc 'double-float))))
                       (let* ((est (tdigest-quantile td q))
                              (err (abs (- est q))))
                         (format t "  delta=~5D  q=~6,3F  error=~,6F~%"
                                 (round d) q err)
                         err)))
                   deltas)))
      (loop for i from 1 below (length deltas)
            do (let ((ok (<= (nth i errors)
                             (+ (* (nth (1- i) errors) 1.5d0) 0.001d0))))
                 (check (format nil "delta=~D q=~,3F error decreases (~,6F <= ~,6F)"
                                (round (nth i deltas)) q
                                (nth i errors) (nth (1- i) errors))
                        ok))))))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Test 5: Merge preserves weight and accuracy
;;; ---------------------------------------------------------------------------

(format t "--- Test 5: Merge preserves weight and accuracy ---~%")

(let* ((n-merge 10000)
       (td1 (create-tdigest 100.0d0))
       (td2 (create-tdigest 100.0d0)))
  (dotimes (i (/ n-merge 2))
    (tdigest-add td1 (/ (coerce i 'double-float) (coerce n-merge 'double-float))))
  (dotimes (i (/ n-merge 2))
    (tdigest-add td2 (/ (coerce (+ i (/ n-merge 2)) 'double-float)
                        (coerce n-merge 'double-float))))

  (let ((w-before (+ (tdigest-total-weight td1) (tdigest-total-weight td2))))
    (tdigest-merge td1 td2)
    (let ((w-after (tdigest-total-weight td1)))
      (check (format nil "weight_before=~,0F  weight_after=~,0F  (equal)" w-before w-after)
             (< (abs (- w-before w-after)) 1.0d-9))))

  (let* ((median (tdigest-quantile td1 0.5d0))
         (median-err (abs (- median 0.5d0))))
    (check (format nil "median_error=~,6F  (< 0.05)" median-err)
           (< median-err 0.05d0)))

  (let* ((p99 (tdigest-quantile td1 0.99d0))
         (p99-err (abs (- p99 0.99d0))))
    (check (format nil "p99_error=~,6F  (< 0.05)" p99-err)
           (< p99-err 0.05d0))))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Test 6: compress is O(n log n)
;;; ---------------------------------------------------------------------------

(format t "--- Test 6: compress is O(n log n) ---~%")

(defvar *compress-sizes* '(500 5000 50000))
(defvar *compress-times*
  (mapcar (lambda (buf-n)
            (let ((td (create-tdigest 100.0d0)))
              ;; Fill the buffer directly by adding items but with huge buffer cap
              ;; We use a fresh digest and add buf-n items then compress
              (dotimes (i buf-n)
                (let ((v (simple-random)))
                  ;; Add to buffer manually
                  (vector-push-extend (make-centroid :mean v :weight 1.0d0)
                                      (tdigest-buffer td))
                  (incf (tdigest-total-weight td) 1.0d0)
                  (when (< v (tdigest-min-val td))
                    (setf (tdigest-min-val td) v))
                  (when (> v (tdigest-max-val td))
                    (setf (tdigest-max-val td) v))))
              (let ((ms (time-block (tdigest-compress td))))
                (format t "  buf_n=~8D  compress_time=~,2Fms~%" buf-n ms)
                ms)))
          *compress-sizes*))

(loop for i from 1 below (length *compress-sizes*)
      for n0 = (coerce (nth (1- i) *compress-sizes*) 'double-float)
      for n1 = (coerce (nth i *compress-sizes*) 'double-float)
      for expected = (/ (* n1 (log n1 2)) (* n0 (log n0 2)))
      for ratio = (/ (nth i *compress-times*) (nth (1- i) *compress-times*))
      do (check (format nil "buf_n=~D  ratio=~,2F (expected ~~~,1F)"
                        (nth i *compress-sizes*) ratio expected)
                (and (>= ratio (* expected 0.3d0))
                     (<= ratio (* expected 4.0d0)))))

(format t "~%")

;;; ---------------------------------------------------------------------------
;;; Summary
;;; ---------------------------------------------------------------------------

(let ((total (+ *pass-count* *fail-count*)))
  (format t "Summary: ~D/~D tests passed~%" *pass-count* total))
