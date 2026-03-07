;;;; demo.lisp -- Demo / self-test for the t-digest library
;;;; Run with: sbcl --script demo.lisp

(load (merge-pathnames "tree234.lisp" *load-truename*))
(load (merge-pathnames "tdigest.lisp" *load-truename*))

(defun main ()
  (let ((td (create-tdigest 100.0d0))
        (n 10000))

    ;; Insert 10000 uniformly spaced values in [0, 1)
    (loop for i below n
          do (tdigest-add td (/ (coerce i 'double-float)
                                (coerce n 'double-float))))

    (format t "T-Digest demo: ~D uniform values in [0, 1)~%" n)
    (format t "Centroids: ~D~%" (tdigest-centroid-count td))
    (terpri)

    (format t "Quantile estimates (expected ~~ q for uniform):~%")
    (dolist (q '(0.001d0 0.01d0 0.1d0 0.25d0 0.5d0 0.75d0 0.9d0 0.99d0 0.999d0))
      (let ((est (tdigest-quantile td q)))
        (format t "  q=~6,3F  estimated=~,6F  error=~,6F~%"
                q est (abs (- est q)))))

    (terpri)
    (format t "CDF estimates (expected ~~ x for uniform):~%")
    (dolist (x '(0.001d0 0.01d0 0.1d0 0.25d0 0.5d0 0.75d0 0.9d0 0.99d0 0.999d0))
      (let ((est (tdigest-cdf td x)))
        (format t "  x=~6,3F  estimated=~,6F  error=~,6F~%"
                x est (abs (- est x)))))

    ;; Test merge
    (let ((td1 (create-tdigest 100.0d0))
          (td2 (create-tdigest 100.0d0)))
      (loop for i below 5000
            do (tdigest-add td1 (/ (coerce i 'double-float) 10000.0d0)))
      (loop for i from 5000 below 10000
            do (tdigest-add td2 (/ (coerce i 'double-float) 10000.0d0)))
      (tdigest-merge td1 td2)

      (terpri)
      (format t "After merge:~%")
      (format t "  median=~,6F (expected ~~0.5)~%"
              (tdigest-quantile td1 0.5d0))
      (format t "  p99   =~,6F (expected ~~0.99)~%"
              (tdigest-quantile td1 0.99d0)))))

(main)
