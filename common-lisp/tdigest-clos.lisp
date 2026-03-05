;;;; tdigest-clos.lisp -- CLOS (generic-function) interface for the t-digest.
;;;; Wraps the struct-based implementation from tdigest.lisp with an
;;;; object-oriented API using CLOS generic functions.

(load (merge-pathnames "tdigest.lisp" *load-truename*))

;;; ---------------------------------------------------------------------------
;;; CLOS wrapper class
;;; ---------------------------------------------------------------------------

(defclass tdigest-object ()
  ((digest :initarg :digest
           :accessor tdigest-object-digest
           :documentation "The underlying struct-based tdigest instance."))
  (:documentation
   "A CLOS wrapper around the struct-based tdigest, providing a generic
function interface for method dispatch and extensibility."))

(defun make-tdigest-object (&optional (delta 100.0d0))
  "Create a new tdigest-object with the given compression parameter DELTA."
  (make-instance 'tdigest-object :digest (create-tdigest delta)))

;;; ---------------------------------------------------------------------------
;;; Generic functions
;;; ---------------------------------------------------------------------------

(defgeneric add-value (digest value &key weight)
  (:documentation
   "Add VALUE to the digest with an optional WEIGHT (default 1)."))

(defgeneric query-quantile (digest q)
  (:documentation
   "Estimate the value at quantile Q (0..1) from the digest."))

(defgeneric query-cdf (digest x)
  (:documentation
   "Estimate the cumulative distribution function at X."))

(defgeneric merge-digests (digest1 digest2)
  (:documentation
   "Merge DIGEST2 into DIGEST1. DIGEST1 is modified in place."))

(defgeneric compress-digest (digest)
  (:documentation
   "Force compression of buffered values into the centroid list."))

(defgeneric digest-total-weight (digest)
  (:documentation
   "Return the total weight of all values added to the digest."))

(defgeneric digest-centroid-count (digest)
  (:documentation
   "Return the number of centroids (compresses any pending buffer first)."))

(defgeneric digest-min (digest)
  (:documentation "Return the minimum observed value."))

(defgeneric digest-max (digest)
  (:documentation "Return the maximum observed value."))

;;; ---------------------------------------------------------------------------
;;; Method implementations
;;; ---------------------------------------------------------------------------

(defmethod add-value ((obj tdigest-object) value &key (weight 1.0d0))
  (tdigest-add (tdigest-object-digest obj) value weight)
  obj)

(defmethod query-quantile ((obj tdigest-object) q)
  (tdigest-quantile (tdigest-object-digest obj) q))

(defmethod query-cdf ((obj tdigest-object) x)
  (tdigest-cdf (tdigest-object-digest obj) x))

(defmethod merge-digests ((obj1 tdigest-object) (obj2 tdigest-object))
  (tdigest-merge (tdigest-object-digest obj1)
                 (tdigest-object-digest obj2))
  obj1)

(defmethod compress-digest ((obj tdigest-object))
  (tdigest-compress (tdigest-object-digest obj))
  obj)

(defmethod digest-total-weight ((obj tdigest-object))
  (tdigest-total-weight (tdigest-object-digest obj)))

(defmethod digest-centroid-count ((obj tdigest-object))
  (tdigest-centroid-count (tdigest-object-digest obj)))

(defmethod digest-min ((obj tdigest-object))
  (tdigest-min-val (tdigest-object-digest obj)))

(defmethod digest-max ((obj tdigest-object))
  (tdigest-max-val (tdigest-object-digest obj)))

;;; ---------------------------------------------------------------------------
;;; Convenience: print-object
;;; ---------------------------------------------------------------------------

(defmethod print-object ((obj tdigest-object) stream)
  (let ((td (tdigest-object-digest obj)))
    (print-unreadable-object (obj stream :type t :identity t)
      (format stream "centroids=~D weight=~,1F delta=~,1F"
              (tdigest-centroid-count td)
              (tdigest-total-weight td)
              (tdigest-delta td)))))
