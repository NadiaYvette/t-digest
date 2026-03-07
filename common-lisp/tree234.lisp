;;;; tree234.lisp -- Generic array-backed 2-3-4 tree with monoidal measures
;;;;
;;;; Node pool is an adjustable vector of node structs with a free list.
;;;; Top-down insertion (split 4-nodes on the way down).
;;;;
;;;; Constructor takes four function arguments:
;;;;   measure-fn  : key -> measure
;;;;   combine-fn  : measure x measure -> measure
;;;;   identity-fn : () -> measure
;;;;   compare-fn  : key x key -> fixnum (<0, 0, >0)

(defpackage #:tree234
  (:use #:cl)
  (:export #:tree234-measure
           #:tree234-measure-weight
           #:tree234-measure-count
           #:tree234-measure-max-mean
           #:tree234-measure-mean-weight-sum
           #:make-tree234-measure

           #:make-tree234
           #:tree234-insert
           #:tree234-collect
           #:tree234-find-by-weight
           #:tree234-build-from-sorted
           #:tree234-clear
           #:tree234-size
           #:tree234-root-measure

           #:weight-result
           #:weight-result-key
           #:weight-result-cum-before
           #:weight-result-index
           #:weight-result-found))

(in-package #:tree234)

;;; ---------------------------------------------------------------------------
;;; Measure struct (four-component monoidal measure)
;;; ---------------------------------------------------------------------------

(defstruct (tree234-measure (:conc-name tree234-measure-))
  (weight         0.0d0                            :type double-float)
  (count          0                                :type fixnum)
  (max-mean       most-negative-double-float       :type double-float)
  (mean-weight-sum 0.0d0                           :type double-float))

;;; ---------------------------------------------------------------------------
;;; Node struct
;;; ---------------------------------------------------------------------------

(defstruct (node234 (:conc-name n234-))
  (n        0   :type (integer 0 3))
  (keys     (make-array 3 :initial-element nil)  :type simple-vector)
  (children (make-array 4 :initial-element -1)   :type simple-vector)
  (measure  nil))

;;; ---------------------------------------------------------------------------
;;; Weight-result struct (returned by find-by-weight)
;;; ---------------------------------------------------------------------------

(defstruct weight-result
  (key        nil)
  (cum-before 0.0d0 :type double-float)
  (index      0     :type fixnum)
  (found      nil   :type boolean))

;;; ---------------------------------------------------------------------------
;;; Tree struct
;;; ---------------------------------------------------------------------------

(defstruct (tree234 (:constructor %make-tree234))
  (nodes      (make-array 16 :adjustable t :fill-pointer 0) :type vector)
  (free-list  nil :type list)
  (root       -1  :type fixnum)
  (count      0   :type fixnum)
  ;; Function slots
  (measure-fn   nil :type (or null function))
  (combine-fn   nil :type (or null function))
  (identity-fn  nil :type (or null function))
  (compare-fn   nil :type (or null function)))

(defun make-tree234 (&key measure-fn combine-fn identity-fn compare-fn)
  "Create a new 2-3-4 tree with the given trait functions."
  (%make-tree234 :measure-fn measure-fn
                 :combine-fn combine-fn
                 :identity-fn identity-fn
                 :compare-fn compare-fn))

;;; ---------------------------------------------------------------------------
;;; Internal helpers
;;; ---------------------------------------------------------------------------

(declaim (inline node-ref alloc-node free-node is-leaf is-4node))

(defun node-ref (tree idx)
  "Access node at index IDX in the pool."
  (declare (type fixnum idx))
  (aref (tree234-nodes tree) idx))

(defun alloc-node (tree)
  "Allocate a fresh node, returning its index."
  (let ((fl (tree234-free-list tree)))
    (if fl
        (let ((idx (car fl)))
          (setf (tree234-free-list tree) (cdr fl))
          ;; Reset the node
          (let ((nd (node-ref tree idx)))
            (setf (n234-n nd) 0)
            (fill (n234-keys nd) nil)
            (fill (n234-children nd) -1)
            (setf (n234-measure nd) (funcall (tree234-identity-fn tree))))
          idx)
        (let ((idx (fill-pointer (tree234-nodes tree)))
              (nd (make-node234 :measure (funcall (tree234-identity-fn tree)))))
          (vector-push-extend nd (tree234-nodes tree))
          idx))))

(defun free-node (tree idx)
  (push idx (tree234-free-list tree)))

(defun is-leaf (tree idx)
  (declare (type fixnum idx))
  (= -1 (the fixnum (svref (n234-children (node-ref tree idx)) 0))))

(defun is-4node (tree idx)
  (declare (type fixnum idx))
  (= 3 (n234-n (node-ref tree idx))))

;;; ---------------------------------------------------------------------------
;;; Recompute measure
;;; ---------------------------------------------------------------------------

(defun recompute-measure (tree idx)
  "Recompute the monoidal measure for node at IDX."
  (declare (type fixnum idx))
  (let* ((nd (node-ref tree idx))
         (n  (n234-n nd))
         (combine (tree234-combine-fn tree))
         (measure-fn (tree234-measure-fn tree))
         (m  (funcall (tree234-identity-fn tree))))
    (dotimes (i (1+ n))
      (let ((child (the fixnum (svref (n234-children nd) i))))
        (when (/= child -1)
          (setf m (funcall combine m (n234-measure (node-ref tree child))))))
      (when (< i n)
        (setf m (funcall combine m (funcall measure-fn (svref (n234-keys nd) i))))))
    (setf (n234-measure nd) m)))

;;; ---------------------------------------------------------------------------
;;; Split a 4-node child
;;; ---------------------------------------------------------------------------

(defun split-child (tree parent-idx child-pos)
  "Split the 4-node child at CHILD-POS of PARENT-IDX."
  (declare (type fixnum parent-idx child-pos))
  (let* ((child-idx (the fixnum (svref (n234-children (node-ref tree parent-idx)) child-pos)))
         (cnd (node-ref tree child-idx))
         ;; Save child data before alloc (may grow vector)
         (k0  (svref (n234-keys cnd) 0))
         (k1  (svref (n234-keys cnd) 1))
         (k2  (svref (n234-keys cnd) 2))
         (c0  (svref (n234-children cnd) 0))
         (c1  (svref (n234-children cnd) 1))
         (c2  (svref (n234-children cnd) 2))
         (c3  (svref (n234-children cnd) 3))
         ;; Allocate right node (may invalidate cnd reference)
         (right-idx (alloc-node tree)))
    ;; Fill right node: k2, c2, c3
    (let ((rnd (node-ref tree right-idx)))
      (setf (n234-n rnd) 1)
      (setf (svref (n234-keys rnd) 0) k2)
      (setf (svref (n234-children rnd) 0) c2)
      (setf (svref (n234-children rnd) 1) c3))
    ;; Shrink child (left): k0, c0, c1
    (let ((lnd (node-ref tree child-idx)))
      (setf (n234-n lnd) 1)
      (setf (svref (n234-keys lnd) 0) k0)
      (setf (svref (n234-keys lnd) 1) nil)
      (setf (svref (n234-keys lnd) 2) nil)
      (setf (svref (n234-children lnd) 0) c0)
      (setf (svref (n234-children lnd) 1) c1)
      (setf (svref (n234-children lnd) 2) -1)
      (setf (svref (n234-children lnd) 3) -1))
    ;; Recompute measures for left and right
    (recompute-measure tree child-idx)
    (recompute-measure tree right-idx)
    ;; Insert k1 into parent at child-pos, shift keys/children
    (let ((pnd (node-ref tree parent-idx)))
      (loop for i from (n234-n pnd) downto (1+ child-pos)
            do (setf (svref (n234-keys pnd) i) (svref (n234-keys pnd) (1- i)))
               (setf (svref (n234-children pnd) (1+ i))
                     (svref (n234-children pnd) i)))
      (setf (svref (n234-keys pnd) child-pos) k1)
      (setf (svref (n234-children pnd) (1+ child-pos)) right-idx)
      (incf (n234-n pnd)))
    (recompute-measure tree parent-idx)))

;;; ---------------------------------------------------------------------------
;;; Insert into non-full node
;;; ---------------------------------------------------------------------------

(defun insert-non-full (tree idx key)
  "Insert KEY into subtree rooted at non-full node IDX."
  (declare (type fixnum idx))
  (if (is-leaf tree idx)
      ;; Insert key in sorted position
      (let* ((nd (node-ref tree idx))
             (pos (n234-n nd))
             (compare (tree234-compare-fn tree)))
        (loop while (and (> pos 0)
                         (< (the fixnum (funcall compare key (svref (n234-keys nd) (1- pos)))) 0))
              do (setf (svref (n234-keys nd) pos) (svref (n234-keys nd) (1- pos)))
                 (decf pos))
        (setf (svref (n234-keys nd) pos) key)
        (incf (n234-n nd))
        (recompute-measure tree idx))
      ;; Internal node: find child to descend
      (let* ((nd (node-ref tree idx))
             (compare (tree234-compare-fn tree))
             (pos 0))
        (loop while (and (< pos (n234-n nd))
                         (>= (the fixnum (funcall compare key (svref (n234-keys nd) pos))) 0))
              do (incf pos))
        ;; If child is a 4-node, split first
        (when (is-4node tree (the fixnum (svref (n234-children (node-ref tree idx) ) pos)))
          (split-child tree idx pos)
          ;; Re-fetch nd since split may have moved things
          (let ((nd2 (node-ref tree idx)))
            (when (>= (the fixnum (funcall compare key (svref (n234-keys nd2) pos))) 0)
              (incf pos))))
        (insert-non-full tree (the fixnum (svref (n234-children (node-ref tree idx)) pos)) key)
        (recompute-measure tree idx))))

;;; ---------------------------------------------------------------------------
;;; Public: insert
;;; ---------------------------------------------------------------------------

(defun tree234-insert (tree key)
  "Insert KEY into the 2-3-4 tree."
  (if (= (tree234-root tree) -1)
      ;; Empty tree
      (let ((idx (alloc-node tree)))
        (let ((nd (node-ref tree idx)))
          (setf (n234-n nd) 1)
          (setf (svref (n234-keys nd) 0) key))
        (recompute-measure tree idx)
        (setf (tree234-root tree) idx)
        (incf (tree234-count tree)))
      ;; Non-empty: if root is 4-node, split it
      (progn
        (when (is-4node tree (tree234-root tree))
          (let ((old-root (tree234-root tree))
                (new-root (alloc-node tree)))
            (setf (svref (n234-children (node-ref tree new-root)) 0) old-root)
            (setf (tree234-root tree) new-root)
            (split-child tree new-root 0)))
        (insert-non-full tree (tree234-root tree) key)
        (incf (tree234-count tree)))))

;;; ---------------------------------------------------------------------------
;;; Public: collect (in-order traversal)
;;; ---------------------------------------------------------------------------

(defun tree234-collect (tree)
  "Collect all keys in-order into a list, then return as a vector."
  (let ((result (make-array (tree234-count tree) :fill-pointer 0)))
    (labels ((walk (idx)
               (when (/= idx -1)
                 (let ((nd (node-ref tree idx)))
                   (dotimes (i (1+ (n234-n nd)))
                     (walk (the fixnum (svref (n234-children nd) i)))
                     (when (< i (n234-n nd))
                       (vector-push (svref (n234-keys nd) i) result)))))))
      (walk (tree234-root tree)))
    result))

;;; ---------------------------------------------------------------------------
;;; Public: find-by-weight
;;; ---------------------------------------------------------------------------

(defun subtree-count (tree idx)
  "Count elements in subtree at IDX."
  (declare (type fixnum idx))
  (if (= idx -1)
      0
      (let ((nd (node-ref tree idx))
            (c 0))
        (declare (type fixnum c))
        (incf c (n234-n nd))
        (dotimes (i (1+ (n234-n nd)))
          (let ((child (the fixnum (svref (n234-children nd) i))))
            (when (/= child -1)
              (incf c (subtree-count tree child)))))
        c)))

(defun find-by-weight-impl (tree idx target cum global-idx weight-of-fn)
  "Walk tree tracking cumulative weight. Returns a weight-result."
  (declare (type fixnum idx global-idx)
           (type double-float target cum))
  (when (= idx -1)
    (return-from find-by-weight-impl
      (make-weight-result :found nil)))
  (let ((nd (node-ref tree idx))
        (running-cum cum)
        (running-idx global-idx)
        (measure-fn (tree234-measure-fn tree)))
    (declare (type double-float running-cum)
             (type fixnum running-idx))
    (dotimes (i (1+ (n234-n nd)))
      ;; Process child
      (let ((child (the fixnum (svref (n234-children nd) i))))
        (when (/= child -1)
          (let ((child-weight (the double-float
                                   (funcall weight-of-fn
                                            (n234-measure (node-ref tree child))))))
            (when (>= (+ running-cum child-weight) target)
              (return-from find-by-weight-impl
                (find-by-weight-impl tree child target running-cum running-idx weight-of-fn)))
            (incf running-cum child-weight)
            (incf running-idx (subtree-count tree child)))))
      ;; Process key
      (when (< i (n234-n nd))
        (let* ((k (svref (n234-keys nd) i))
               (key-weight (the double-float
                                (funcall weight-of-fn (funcall measure-fn k)))))
          (when (>= (+ running-cum key-weight) target)
            (return-from find-by-weight-impl
              (make-weight-result :key k
                                  :cum-before running-cum
                                  :index running-idx
                                  :found t)))
          (incf running-cum key-weight)
          (incf running-idx))))
    (make-weight-result :found nil)))

(defun tree234-find-by-weight (tree target weight-of-fn)
  "Find the element where cumulative weight reaches TARGET.
WEIGHT-OF-FN takes a measure and returns a double-float weight."
  (if (= (tree234-root tree) -1)
      (make-weight-result :found nil)
      (find-by-weight-impl tree (tree234-root tree)
                           (coerce target 'double-float)
                           0.0d0 0 weight-of-fn)))

;;; ---------------------------------------------------------------------------
;;; Public: build-from-sorted
;;; ---------------------------------------------------------------------------

(defun build-recursive (tree sorted lo hi)
  "Build a balanced 2-3-4 tree from SORTED vector, range [LO, HI)."
  (declare (type fixnum lo hi))
  (let ((n (- hi lo)))
    (declare (type fixnum n))
    (when (<= n 0)
      (return-from build-recursive -1))
    (when (<= n 3)
      ;; Leaf node with 1-3 keys
      (let ((idx (alloc-node tree)))
        (let ((nd (node-ref tree idx)))
          (setf (n234-n nd) n)
          (dotimes (i n)
            (setf (svref (n234-keys nd) i) (aref sorted (+ lo i)))))
        (recompute-measure tree idx)
        (return-from build-recursive idx)))
    (if (<= n 7)
        ;; 2-node
        (let* ((mid (+ lo (floor n 2)))
               (left  (build-recursive tree sorted lo mid))
               (right (build-recursive tree sorted (1+ mid) hi))
               (idx   (alloc-node tree))
               (nd    (node-ref tree idx)))
          (setf (n234-n nd) 1)
          (setf (svref (n234-keys nd) 0) (aref sorted mid))
          (setf (svref (n234-children nd) 0) left)
          (setf (svref (n234-children nd) 1) right)
          (recompute-measure tree idx)
          idx)
        ;; 3-node
        (let* ((third (floor n 3))
               (m1 (+ lo third))
               (m2 (+ lo (* 2 third) 1))
               (c0 (build-recursive tree sorted lo m1))
               (c1 (build-recursive tree sorted (1+ m1) m2))
               (c2 (build-recursive tree sorted (1+ m2) hi))
               (idx (alloc-node tree))
               (nd  (node-ref tree idx)))
          (setf (n234-n nd) 2)
          (setf (svref (n234-keys nd) 0) (aref sorted m1))
          (setf (svref (n234-keys nd) 1) (aref sorted m2))
          (setf (svref (n234-children nd) 0) c0)
          (setf (svref (n234-children nd) 1) c1)
          (setf (svref (n234-children nd) 2) c2)
          (recompute-measure tree idx)
          idx))))

(defun tree234-build-from-sorted (tree sorted-vector)
  "Clear tree and rebuild from a sorted vector of keys."
  (tree234-clear tree)
  (when (zerop (length sorted-vector))
    (return-from tree234-build-from-sorted))
  (setf (tree234-count tree) (length sorted-vector))
  (setf (tree234-root tree)
        (build-recursive tree sorted-vector 0 (length sorted-vector))))

;;; ---------------------------------------------------------------------------
;;; Public: clear, size, root-measure
;;; ---------------------------------------------------------------------------

(defun tree234-clear (tree)
  "Remove all elements from the tree."
  (setf (fill-pointer (tree234-nodes tree)) 0)
  (setf (tree234-free-list tree) nil)
  (setf (tree234-root tree) -1)
  (setf (tree234-count tree) 0))

(defun tree234-size (tree)
  "Return the number of elements in the tree."
  (tree234-count tree))

(defun tree234-root-measure (tree)
  "Return the monoidal measure of the entire tree."
  (if (= (tree234-root tree) -1)
      (funcall (tree234-identity-fn tree))
      (n234-measure (node-ref tree (tree234-root tree)))))
