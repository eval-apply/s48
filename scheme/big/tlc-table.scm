; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

;; transport link cells hash table
;; Ghuloum, Dybvig 2007

;; TODO
;;  - mutable/immutable, tlc-table-mutable?
;;  - initial size if no size given
;;  - shall the hashtable grow/shrink over time?
;;  - equal-hash
;;  - string-ci-hash
;;  - symbol-hash
;;  - tlc-table-copy

;; record type for table

(define-record-type tlc-table :tlc-table
  (really-make-tlc-table size buckets hash-function 
			 equivalence-function tconc)
  tlc-table?
  (size tlc-table-size)                                 ; number of buckets
  (buckets tlc-table-buckets)                           ; vector of buckets
  (hash-function tlc-table-hash-function)               ; hash function
  (equivalence-function tlc-table-equivalence-function) ; equivalence function
  (tconc tlc-table-tconc))      ; to track the links that need rehashing

;; minimal size of a tlc table
(define *tlc-table-min-size* 1)

;; initialize buckets

(define (tlc-table-initialize-buckets! buckets)
  (let fill-with-index! ((vector buckets)
			 (n (- (vector-length buckets) 1)))
      (if (>= n 0)
	  (begin
	    (vector-set! vector n n)
	    (fill-with-index! vector (- n 1))))))
  
;; smart constructor

(define (make-tlc-table-internally size hash-function 
				   equiv-function use-tconc-queue)
  (let* ((size (max size *tlc-table-min-size*))
	 (buckets (make-vector size))
	 (tconc (and use-tconc-queue (make-tconc-queue))))
    (tlc-table-initialize-buckets! buckets)
    (really-make-tlc-table size buckets hash-function equiv-function tconc)))

;; default hash functions

(define (tlc-table-default-eq-hash-function object)
  (memory-status (enum memory-status-option pointer-hash) object))

;; adjust results of hash function to table size

(define (tlc-table-hash-value size value)
  (let ((v (remainder value size)))
    (if (< v 0)
	(- v)
	v)))

(define (tlc-table-calculate-hash table object)
  (tlc-table-hash-value (tlc-table-size table)
			((tlc-table-hash-function table) object)))

;; access link chains

(define (set-tlc-table-entry! table index link)
  (vector-set! (tlc-table-buckets table) index link))

(define (tlc-table-entry table index)
  (vector-ref (tlc-table-buckets table) index))

;; insert links

(define (tlc-table-insert-link table link)
  (let* ((key (transport-link-cell-key link))
	 (index (tlc-table-calculate-hash table (transport-link-cell-key link))))
    (set-transport-link-cell-next! link (tlc-table-entry table index))
    (set-tlc-table-entry! table index link)))

(define (tlc-table-add table key value)
  (let ((link (make-transport-link-cell key value (tlc-table-tconc table) #f)))
    (tlc-table-insert-link table link)))

;; get index of link chain

(define (tlc-table-index-of-link x)
  (if (number? x)
      x
      (tlc-table-index-of-link (transport-link-cell-next x))))

;; delete links

(define (tlc-table-delete-link table link)
  (let* ((index (tlc-table-index-of-link link))
	 (chain (tlc-table-entry table index)))
    (letrec ((delete-loop 
	      (lambda (chain)
		(and (transport-link-cell? chain)
		     (let ((x (transport-link-cell-next chain)))
		       (if (transport-link-cell? x)
			   (if (eq? x link)
			       (set-transport-link-cell-next!
				chain (transport-link-cell-next x))
			       (delete-loop x))
			   (set-transport-link-cell-next! chain x)))))))
      (if (eq? chain link)
	  (set-tlc-table-entry! table index
				(transport-link-cell-next link))
	  (delete-loop chain)))))

;; lookup

(define (tlc-table-direct-lookup table key)
  (let ((index (tlc-table-calculate-hash table key)))
    (let lookup ((x (tlc-table-entry table index)))
      (and (transport-link-cell? x)
	   (if (eq? (transport-link-cell-key x) key)
	       x
	       (lookup (transport-link-cell-next x)))))))

(define (tlc-table-rehash-link table link)
  (tlc-table-delete-link table link)
  (tlc-table-add table 
		 (transport-link-cell-key link) 
		 (transport-link-cell-value link)))

(define (tlc-table-rehash-lookup table key)
  (let ((tconc (tlc-table-tconc table)))
    (and (not (tconc-queue-empty? tconc))
	 (let ((link (tconc-queue-dequeue! tconc)))
	   (begin
	     (tlc-table-rehash-link table link)
	     (if (eq? (transport-link-cell-key link) key)
		 link
		 (tlc-table-rehash-lookup table key)))))))

(define (tlc-table-lookup-link table key)
  (or (tlc-table-direct-lookup table key)
      (tlc-table-rehash-lookup table key)))

(define (tlc-table-rehash-lookup-for-deletion table key)
  (let ((tconc (tlc-table-tconc table)))
    (and (not (tconc-queue-empty? tconc))
	 (let ((link (tconc-queue-dequeue! tconc)))
	   (if (eq? (transport-link-cell-key link) key)
	       link
	       (begin
		 (tlc-table-rehash-link table link)
		 (tlc-table-rehash-lookup-for-deletion table key)))))))

;; There are rare occasions where a link is enqueued to the tconc
;; queue during garbage collection that is hashed into the same bucket
;; as before.  So, strictly speaking, there is no need for the link to
;; go into the tconc queue because a direct lookup finds it anyways.
;; But if the user really wants to delete a link, we have to make sure
;; that it is removed from the tconc queue so that a later lookup will
;; not resurrect the link.  Thus, we first walk the tconc queue and
;; then see if we can still find the link on a direct lookup.  This
;; makes the removal of an tlc-table entry very expensive, because
;; worst case all links in the tconc queue are rehashed whenever the
;; user deletes an element from the tlc table.
;;
;; For non-deleting lookups it does not matter if the link is still in
;; the tconc.  At some point in time, the link will be rehashed to the
;; same bucket as it was before.  This is unneeded but way cheaper
;; than checking and acting to prevent such a situation.
(define (tlc-table-lookup-link-for-deletion table key)
  (or (tlc-table-rehash-lookup-for-deletion table key)
      (tlc-table-direct-lookup table key)))

;; exported functions below

;; constructors

(define (make-non-default-tlc-table hash-function equiv size)
  (make-tlc-table-internally size hash-function equiv #t))

(define (make-eq-tlc-table size)
  (make-non-default-tlc-table tlc-table-default-eq-hash-function eq? size))

(define make-tlc-table make-eq-tlc-table)

;; lookup

(define (tlc-table-ref table key not-found)
  (let ((x (tlc-table-lookup-link table key)))
    (if x
	(transport-link-cell-value x)
	not-found)))

;; set

(define (tlc-table-set! table key value)
  (let ((x (tlc-table-lookup-link table key)))
    (if x
	(set-transport-link-cell-value! x value)
	(tlc-table-add table key value))))

;; delete

(define (tlc-table-delete! table key not-found)
  (let ((x (tlc-table-lookup-link-for-deletion table key)))
    (if x
	(tlc-table-delete-link table x)
	not-found)))

;; contains?

(define (tlc-table-contains? table key)
  (and (tlc-table-lookup-link table key) #t))

;; update

(define (tlc-table-update! table key proc not-found)
  (let ((x (tlc-table-lookup-link table key)))
    (if x
	(set-transport-link-cell-value! 
	 x
	 (proc (transport-link-cell-value x)))
	not-found)))

;; clear

(define (tlc-table-clear! table)
  (tlc-table-initialize-buckets! (tlc-table-buckets table))
  (tconc-queue-clear! (tlc-table-tconc table)))

;; debugging

(define (tlc-table-distribution table)
  (let loop-table ((n (- (tlc-table-size table) 1))
		   (distribution '()))
    (let ((count
	   (let loop-chain ((x (tlc-table-entry table n))
			    (count 0))
	     (if (transport-link-cell? x)
		 (loop-chain (transport-link-cell-next x) (+ count 1))
		 count)))
	  (count-tconc
	   (let ((tconc (tlc-table-tconc table)))
	     (and tconc (pair? tconc)
		  (let loop-tconc ((x (car tconc))
				   (count 0))
		    (if (or (eq? x (cdr tconc))
			    (not (pair? x)))
			count
			(loop-tconc (cdr x) (+ count 1))))))))
      (if (> n 0)
	  (loop-table (- n 1) (cons (cons n count) distribution))
	  (cons (cons -1 count-tconc)
		(cons (cons n count) distribution))))))
