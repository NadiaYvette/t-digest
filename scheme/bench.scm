;;; bench.scm -- Benchmark / asymptotic-behavior tests for Scheme t-digest
;;; Run with: csi -script bench.scm

(import (chicken time))

(load "tdigest.scm")

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(define pass-count 0)
(define fail-count 0)

(define (get-time-ms)
  (current-milliseconds))

(define (time-block thunk)
  "Execute thunk and return elapsed time in milliseconds."
  (let* ((t0 (get-time-ms))
         (result (thunk))
         (t1 (get-time-ms)))
    (- t1 t0)))

(define (check label ok)
  (if ok
      (begin
        (set! pass-count (+ pass-count 1))
        (display (string-append "  " label "  PASS"))
        (newline))
      (begin
        (set! fail-count (+ fail-count 1))
        (display (string-append "  " label "  FAIL"))
        (newline))))

(define (ratio-ok? ratio expected . args)
  (let ((lo (if (>= (length args) 1) (car args) 0.5))
        (hi (if (>= (length args) 2) (cadr args) 3.0)))
    (and (>= ratio (* expected lo))
         (<= ratio (* expected hi)))))

(define (number->string-fixed n decimals)
  "Format a number with fixed decimal places (simple version)."
  (let* ((factor (expt 10 decimals))
         (rounded (/ (round (* (abs n) factor)) factor))
         (str (number->string (exact->inexact rounded))))
    (if (< n 0)
        (string-append "-" str)
        str)))

(define (pad-right str width)
  (if (>= (string-length str) width)
      str
      (pad-right (string-append str " ") width)))

(define (pad-left str width)
  (if (>= (string-length str) width)
      str
      (pad-left (string-append " " str) width)))

;;; Simple LCG random
(define rng-state 12345)
(define (simple-random)
  (set! rng-state (modulo (+ (* rng-state 1103515245) 12345) (expt 2 31)))
  (/ (exact->inexact rng-state) (exact->inexact (expt 2 31))))

;;; ---------------------------------------------------------------------------

(display "=== T-Digest Asymptotic Behavior Tests (Scheme) ===")
(newline)(newline)

;;; ---------------------------------------------------------------------------
;;; Test 1: add() is amortized O(1)
;;; ---------------------------------------------------------------------------

(display "--- Test 1: add() is amortized O(1) ---")
(newline)

(define sizes '(1000 10000 100000))
(define times-1
  (map (lambda (n)
         (let ((td (make-tdigest 100.0)))
           (let ((ms (time-block
                       (lambda ()
                         (let loop ((i 0))
                           (if (< i n)
                               (begin
                                 (td-add! td (/ (exact->inexact i) (exact->inexact n)))
                                 (loop (+ i 1)))))))))
             (display (string-append "  N=" (pad-left (number->string n) 9)
                                     "  time=" (number->string-fixed ms 1) "ms"))
             (newline)
             ms)))
       sizes))

(let loop ((i 1))
  (if (< i (length sizes))
      (let* ((n (list-ref sizes i))
             (expected (/ (exact->inexact n) (exact->inexact (list-ref sizes (- i 1)))))
             (ratio (/ (list-ref times-1 i) (list-ref times-1 (- i 1)))))
        (check (string-append "N=" (number->string n)
                              "  ratio=" (number->string-fixed ratio 2)
                              " (expected ~" (number->string-fixed expected 1) ")")
               (ratio-ok? ratio expected))
        (loop (+ i 1)))))

(newline)

;;; ---------------------------------------------------------------------------
;;; Test 2: Centroid count bounded by O(delta)
;;; ---------------------------------------------------------------------------

(display "--- Test 2: Centroid count bounded by O(delta) ---")
(newline)

(let ((delta 100.0))
  (for-each
   (lambda (n)
     (let ((td (make-tdigest delta)))
       (let loop ((i 0))
         (if (< i n)
             (begin
               (td-add! td (/ (exact->inexact i) (exact->inexact n)))
               (loop (+ i 1)))))
       (let ((cc (td-centroid-count td)))
         (check (string-append "N=" (pad-left (number->string n) 9)
                               "  centroids=" (pad-left (number->string cc) 4)
                               "  (delta=100, limit=500)")
                (<= cc 500)))))
   sizes))

(newline)

;;; ---------------------------------------------------------------------------
;;; Test 3: Query time independent of N
;;; ---------------------------------------------------------------------------

(display "--- Test 3: Query time independent of N ---")
(newline)

(define query-sizes '(1000 10000 100000))
(define query-times
  (map (lambda (n)
         (let ((td (make-tdigest 100.0)))
           (let loop ((i 0))
             (if (< i n)
                 (begin
                   (td-add! td (/ (exact->inexact i) (exact->inexact n)))
                   (loop (+ i 1)))))
           (td-compress! td)
           (let* ((iterations 5000)
                  (ms (time-block
                        (lambda ()
                          (let loop ((j 0))
                            (if (< j iterations)
                                (begin
                                  (td-quantile td 0.5)
                                  (td-cdf td 0.5)
                                  (loop (+ j 1))))))))
                  (us-per (/ (* ms 1000.0) iterations)))
             (display (string-append "  N=" (pad-left (number->string n) 9)
                                     "  query_time=" (number->string-fixed us-per 2) "us"))
             (newline)
             us-per)))
       query-sizes))

(let loop ((i 1))
  (if (< i (length query-sizes))
      (let* ((ratio (/ (list-ref query-times i) (list-ref query-times (- i 1)))))
        (check (string-append "N=" (number->string (list-ref query-sizes i))
                              "  ratio=" (number->string-fixed ratio 2)
                              " (expected ~1.0)")
               (ratio-ok? ratio 1.0 0.2 5.0))
        (loop (+ i 1)))))

(newline)

;;; ---------------------------------------------------------------------------
;;; Test 4: Tail accuracy improves with delta
;;; ---------------------------------------------------------------------------

(display "--- Test 4: Tail accuracy improves with delta ---")
(newline)

(let ((deltas '(50.0 100.0 200.0))
      (tail-qs '(0.01 0.001 0.99 0.999))
      (n-acc 100000))
  (for-each
   (lambda (q)
     (let ((errors
            (map (lambda (d)
                   (let ((td (make-tdigest d)))
                     (let loop ((i 0))
                       (if (< i n-acc)
                           (begin
                             (td-add! td (/ (exact->inexact i)
                                            (exact->inexact n-acc)))
                             (loop (+ i 1)))))
                     (let* ((est (td-quantile td q))
                            (err (abs (- est q))))
                       (display (string-append "  delta=" (pad-left (number->string (inexact->exact (round d))) 5)
                                               "  q=" (number->string-fixed q 3)
                                               "  error=" (number->string-fixed err 6)))
                       (newline)
                       err)))
                 deltas)))
       (let loop ((i 1))
         (if (< i (length deltas))
             (let ((ok (<= (list-ref errors i)
                           (+ (* (list-ref errors (- i 1)) 1.5) 0.001))))
               (check (string-append "delta=" (number->string (inexact->exact (round (list-ref deltas i))))
                                     " q=" (number->string-fixed q 3)
                                     " error decreases")
                      ok)
               (loop (+ i 1)))))))
   tail-qs))

(newline)

;;; ---------------------------------------------------------------------------
;;; Test 5: Merge preserves weight and accuracy
;;; ---------------------------------------------------------------------------

(display "--- Test 5: Merge preserves weight and accuracy ---")
(newline)

(let* ((n-merge 10000)
       (td1 (make-tdigest 100.0))
       (td2 (make-tdigest 100.0)))
  (let loop ((i 0))
    (if (< i (/ n-merge 2))
        (begin
          (td-add! td1 (/ (exact->inexact i) (exact->inexact n-merge)))
          (loop (+ i 1)))))
  (let loop ((i (/ n-merge 2)))
    (if (< i n-merge)
        (begin
          (td-add! td2 (/ (exact->inexact i) (exact->inexact n-merge)))
          (loop (+ i 1)))))

  (let ((w-before (+ (td-total-weight td1) (td-total-weight td2))))
    (td-merge! td1 td2)
    (let ((w-after (td-total-weight td1)))
      (check (string-append "weight_before=" (number->string-fixed w-before 0)
                            "  weight_after=" (number->string-fixed w-after 0) "  (equal)")
             (< (abs (- w-before w-after)) 0.001))))

  (let* ((median (td-quantile td1 0.5))
         (median-err (abs (- median 0.5))))
    (check (string-append "median_error=" (number->string-fixed median-err 6) "  (< 0.05)")
           (< median-err 0.05)))

  (let* ((p99 (td-quantile td1 0.99))
         (p99-err (abs (- p99 0.99))))
    (check (string-append "p99_error=" (number->string-fixed p99-err 6) "  (< 0.05)")
           (< p99-err 0.05))))

(newline)

;;; ---------------------------------------------------------------------------
;;; Test 6: compress is O(n log n)
;;; ---------------------------------------------------------------------------

(display "--- Test 6: compress is O(n log n) ---")
(newline)

(define compress-sizes '(500 5000 50000))
(define compress-times
  (map (lambda (buf-n)
         (let ((td (make-tdigest 100.0)))
           ;; Manually fill the buffer
           (let loop ((i 0) (buf '()))
             (if (< i buf-n)
                 (loop (+ i 1)
                       (cons (make-centroid (simple-random) 1.0) buf))
                 (begin
                   (td-set-buffer! td buf)
                   (td-set-total-weight! td (exact->inexact buf-n))
                   (td-set-min! td 0.0)
                   (td-set-max! td 1.0))))
           (let ((ms (time-block (lambda () (td-compress! td)))))
             (display (string-append "  buf_n=" (pad-left (number->string buf-n) 8)
                                     "  compress_time=" (number->string-fixed ms 2) "ms"))
             (newline)
             ms)))
       compress-sizes))

(let loop ((i 1))
  (if (< i (length compress-sizes))
      (let* ((n0 (exact->inexact (list-ref compress-sizes (- i 1))))
             (n1 (exact->inexact (list-ref compress-sizes i)))
             (expected (/ (* n1 (/ (log n1) (log 2)))
                          (* n0 (/ (log n0) (log 2)))))
             (ratio (/ (list-ref compress-times i) (list-ref compress-times (- i 1)))))
        (check (string-append "buf_n=" (number->string (list-ref compress-sizes i))
                              "  ratio=" (number->string-fixed ratio 2)
                              " (expected ~" (number->string-fixed expected 1) ")")
               (and (>= ratio (* expected 0.3))
                    (<= ratio (* expected 4.0))))
        (loop (+ i 1)))))

(newline)

;;; ---------------------------------------------------------------------------
;;; Summary
;;; ---------------------------------------------------------------------------

(display (string-append "Summary: " (number->string pass-count) "/"
                        (number->string (+ pass-count fail-count)) " tests passed"))
(newline)
