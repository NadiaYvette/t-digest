;;; demo.scm -- Demo / self-test for the t-digest library
;;; Run with: csi -R r5rs -script demo.scm

(load "tdigest.scm")

;;; ============================================================
;;; Formatting helpers
;;; ============================================================

(define (format-float x decimals)
  (let* ((neg (< x 0))
         (x (abs x))
         (factor (expt 10 decimals))
         (rounded (inexact->exact (round (* x factor))))
         (int-part (quotient rounded factor))
         (frac-part (remainder rounded factor))
         (frac-str (number->string frac-part))
         (pad (- decimals (string-length frac-str)))
         (frac-padded (string-append (make-string (max 0 pad) #\0)
                                     frac-str)))
    (string-append (if neg "-" "")
                   (number->string int-part)
                   "."
                   frac-padded)))

(define (pad-right str width)
  (if (>= (string-length str) width)
      str
      (string-append str (make-string (- width (string-length str)) #\space))))

(define (pad-left str width)
  (if (>= (string-length str) width)
      str
      (string-append (make-string (- width (string-length str)) #\space) str)))

;;; ============================================================
;;; Main demo
;;; ============================================================

(define (main)
  (let ((td (make-tdigest 100))
        (n 10000))

    ;; Insert n uniformly spaced values in [0, 1)
    (let loop ((i 0))
      (if (< i n)
          (begin
            (td-add! td (/ (exact->inexact i) (exact->inexact n)))
            (loop (+ i 1)))))

    (display "T-Digest demo: ")
    (display n)
    (display " uniform values in [0, 1)")
    (newline)
    (display "Centroids: ")
    (display (td-centroid-count td))
    (newline)
    (newline)

    ;; Quantile estimates
    (display "Quantile estimates (expected ~ q for uniform):")
    (newline)
    (for-each
     (lambda (q)
       (let* ((est (td-quantile td q))
              (err (abs (- est q))))
         (display "  q=")
         (display (pad-right (format-float q 3) 7))
         (display "  estimated=")
         (display (pad-left (format-float est 6) 10))
         (display "  error=")
         (display (format-float err 6))
         (newline)))
     '(0.001 0.01 0.1 0.25 0.5 0.75 0.9 0.99 0.999))

    (newline)

    ;; CDF estimates
    (display "CDF estimates (expected ~ x for uniform):")
    (newline)
    (for-each
     (lambda (x)
       (let* ((est (td-cdf td x))
              (err (abs (- est x))))
         (display "  x=")
         (display (pad-right (format-float x 3) 7))
         (display "  estimated=")
         (display (pad-left (format-float est 6) 10))
         (display "  error=")
         (display (format-float err 6))
         (newline)))
     '(0.001 0.01 0.1 0.25 0.5 0.75 0.9 0.99 0.999))

    (newline)

    ;; Merge test
    (let ((td1 (make-tdigest 100))
          (td2 (make-tdigest 100)))
      (let loop ((i 0))
        (if (< i 5000)
            (begin
              (td-add! td1 (/ (exact->inexact i) 10000.0))
              (loop (+ i 1)))))
      (let loop ((i 5000))
        (if (< i 10000)
            (begin
              (td-add! td2 (/ (exact->inexact i) 10000.0))
              (loop (+ i 1)))))
      (td-merge! td1 td2)

      (display "After merge of two halves:")
      (newline)
      (display "  median=")
      (display (format-float (td-quantile td1 0.5) 6))
      (display " (expected ~0.5)")
      (newline)
      (display "  p99   =")
      (display (format-float (td-quantile td1 0.99) 6))
      (display " (expected ~0.99)")
      (newline)
      (display "  p01   =")
      (display (format-float (td-quantile td1 0.01) 6))
      (display " (expected ~0.01)")
      (newline)
      (display "  centroids=")
      (display (td-centroid-count td1))
      (newline))))

(main)
