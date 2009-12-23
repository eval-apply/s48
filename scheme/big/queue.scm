; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

;;;; Queues

;;; The elements in a queue are stored in an ordinary list.  When the
;;; queue is not empty, it maintains pointers to both the first pair
;;; in the list (in the HEAD field) and the last pair in the list (in
;;; the TAIL field).  When the queue is empty, both the HEAD and TAIL
;;; fields are set to '().
;;;
;;; The procedures exported from this module never give away pointers
;;; to the pairs in a queue's list, and never attach pairs provided by
;;; other code to a queue's list.  Once pairs are in a queue's list,
;;; their CARs are never modified, so there is no need to use
;;; PROVISIONAL-CAR.  However, pairs' CDRs are (necessarily) modified
;;; by ENQUEUE! and other queue operations, so all accesses to and
;;; modifications of CDRs must be provisional.

(define-synchronized-record-type queue :queue
  (really-make-queue uid head tail)
  (head tail)     	;synchronize on these
  queue?
  (uid queue-uid)       ;for debugging
  ;; Despite the names, these accessors and modifiers are all
  ;; provisional.
  (head real-queue-head set-queue-head!)
  (tail queue-tail set-queue-tail!))

;; A few of the examples in the comments below use the following
;; utility function:
;;
;; (define (prov-cell-push! c x)
;;   (ensure-atomicity!
;;    (provisional-cell-set! c (cons x (provisional-cell-ref c)))))

;;; Unique IDs and discloser for debugging.

(define *next-queue-uid* (make-cell 1))

(define (next-queue-uid)
  (atomically
    (let ((uid (provisional-cell-ref *next-queue-uid*)))
      (provisional-cell-set! *next-queue-uid* (+ uid 1))
      uid)))

(define-record-discloser :queue
  (lambda (q)
    (list 'queue (queue-uid q))))

;;; Constructors.

;; MAKE-QUEUE - Create a new, empty queue.
(define (make-queue)
  (really-make-queue (next-queue-uid) '() '()))

;; LIST->QUEUE - Create a new queue containing a list of elements.
;;
;; This does not use the other queue operations because they would add
;; unnecessary synchronization overhead.  Even if this procedure
;; temporarily set the current proposal to #F, each call to ENQUEUE!
;; would create and commit a proposal unnecessarily.
(define (list->queue xs)
  (if (null? xs)
      (make-queue)
      (let ((head (cons (car xs) '())))
        (let loop ((xs (cdr xs))
                   (lag head))
          (if (null? xs)
              (really-make-queue (next-queue-uid) head lag)
              (let ((cur (cons (car xs) '())))
                (set-cdr! lag cur)
                (loop (cdr xs) cur)))))))

;; Slow reference version:
;; (define (list->queue xs)
;;   (atomically             ;do not clutter existing transaction
;;    (let ((q (make-queue)))
;;      (for-each (lambda (x) (enqueue! q x)) xs)
;;      q)))

;;; Internal utilities.

;; ENQUEUE-MANY-NO-COPY! - Attach a list to the tail of the queue.
;; The last pair in the list must be passed as the third argument.
;;
;; No argument checking is performed.
(define (enqueue-many-no-copy! q xs xs-tail)
  (ensure-atomicity!
   (let ((tail (queue-tail q)))
     (cond
      ((null? tail)
       (set-queue-head! q xs))
      (else
       (provisional-set-cdr! tail xs)))
     (set-queue-tail! q xs-tail))))

;; QUEUE-PROC-CALLER-*REALLY*-MESSED-UP! - Removes the current
;; proposal and raises an error with a rather more useful message than
;; the fool^H^H^H^Hprogrammer who provoked this error deserves.
(define (queue-proc-caller-*really*-messed-up! who q)
  (define the-nasty-message
    " called on empty or inconsistent queue with a proposal active")
  (remove-current-proposal!)
  (assertion-violation who
                       (string-append (symbol->string who)
                                      the-nasty-message)
                       q))

;;; The exported procedures for manipulating queues.

;; QUEUE-EMPTY? - Returns #F if the queue is not empty, or #T if the
;; queue is empty.
(define (queue-empty? q)
  ;; ENSURE-ATOMICITY is not necessary here.
  (null? (real-queue-head q)))

;; ENQUEUE! - Enqueue one element.
(define (enqueue! q v)
  ;; ENSURE-ATOMICITY! is not necessary here.
  (let ((p (cons v '())))
    (enqueue-many-no-copy! q p p)))

;; ENQUEUE-MANY! - Enqueue a list of elements.
(define (enqueue-many! q xs)
  ;; ENSURE-ATOMICITY! is not necessary here, and not using it reduces
  ;; the risk of raising an exception (while traversing a
  ;; caller-provided value as a list) with a proposal active.
  (if (not (null? xs))
      (let ((xs-copy (cons (car xs) '())))
        (let loop ((xs (cdr xs))
                   (prev xs-copy))
          (if (null? xs)
              (enqueue-many-no-copy! q xs-copy prev)
              (let ((cur (cons (car xs) '())))
                (set-cdr! prev cur)
                (loop (cdr xs) cur)))))))

;; QUEUE-HEAD-OR-VALUE - Return the first element in the queue, or
;; return VALUE if the queue is empty.
(define (queue-head-or-value q value)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (if (null? head)
	 value
	 (car head)))))

;; QUEUE-HEAD-OR-THUNK - Return the first element in the queue, or
;; tail-call THUNK if the queue is empty.
;;
;; THUNK is tail-called so that, if this function is called without a
;; proposal active, THUNK will not use the proposal created by this
;; function.  This is especially important if THUNK raises an
;; exception.
(define queue-head-or-thunk
  (let ((unreleased (make-cell 'unreleased))) ;similar in use to the
                                              ; VM's unreleased value
    (lambda (q thunk)
      (let ((x (queue-head-or-value q unreleased)))
        (if (eq? x unreleased)
            (thunk)
            x)))))

;; QUEUE-HEAD - Return the first element in the queue, or raise an
;; error if the queue is empty.
;;
;; DO NOT CALL THIS FUNCTION WITH A PROPOSAL ACTIVE UNLESS
;; QUEUE-EMPTY? HAS RETURNED #F!
(define (queue-head q)
  (queue-head-or-thunk
   q
   (lambda ()
     (if (proposal-active?)
         (queue-proc-caller-*really*-messed-up! 'queue-head q)
         (assertion-violation 'queue-head "empty queue" q)))))

;; MAYBE-QUEUE-HEAD - Return the first element in the queue, or return
;; #F if the queue is empty.
(define (maybe-queue-head q)
  (queue-head-or-value q #f))

;; DEQUEUE-OR-VALUE! - Remove and return the first element in the
;; queue, or return VALUE if the queue is empty.
(define (dequeue-or-value! q value)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (cond
      ((null? head)
       ;; empty; return VALUE
       value)
      (else
       (let ((new-head (provisional-cdr head)))
	 ;; The preceding line must use PROVISIONAL-CDR; see below.
	 (set-queue-head! q new-head)
	 (if (null? new-head)
	     (set-queue-tail! q '())))
       (car head))))))
;; If NEW-HEAD were set to (CDR HEAD) above, the following code would
;; return a value EQUAL? to '(#f a):
;;
;; (let ((q (make-queue))
;;       (c (make-cell '())))
;;   (enqueue! q 'a)
;;   (ensure-atomicity!
;;    (enqueue! q 'b)
;;    (prov-cell-push! c (maybe-dequeue! q)))
;;   (prov-cell-push! c (maybe-dequeue! q))
;;   (cell-ref c))
;;
;; The result should be EQUAL? to '(b a).

;; DEQUEUE-OR-THUNK! - Remove and return the first element in the
;; queue, or tail-call THUNK if the queue is empty.
;;
;; THUNK is tail-called here for the same reason as it is in
;; QUEUE-HEAD-OR-THUNK.
(define dequeue-or-thunk!
  (let ((unreleased (make-cell 'unreleased))) ;similar in use to the
                                              ; VM's unreleased value
    (lambda (q thunk)
      (let ((x (dequeue-or-value! q unreleased)))
        (if (eq? x unreleased)
            (thunk)
            x)))))

;; DEQUEUE! - Remove and return the first element in the queue, or
;; raise an error if the queue is empty.
;;
;; DO NOT CALL THIS FUNCTION WITH A PROPOSAL ACTIVE UNLESS
;; QUEUE-EMPTY? HAS RETURNED #F!
(define (dequeue! q)
  (dequeue-or-thunk!
   q
   (lambda ()
     (if (proposal-active?)
         (queue-proc-caller-*really*-messed-up! 'dequeue q)
         (assertion-violation 'dequeue! "empty queue" q)))))

;; MAYBE-DEQUEUE! - Remove and return the first element in the queue,
;; or return #F if the queue is empty.
(define (maybe-dequeue! q)
  (dequeue-or-value! q #f))

;; EMPTY-QUEUE! - Make the queue empty.
(define (empty-queue! q)
  (ensure-atomicity!
   (set-queue-head! q '())
   (set-queue-tail! q '())))

;;; Queue operations not used in the Scheme 48 system, and known to be
;;; *very* slow.  These operations may be removed from this package in
;;; a future revision.

;; These operations could be made to run faster when called without an
;; active proposal by locking out all other threads from accessing the
;; queue and then using non-provisional operations on the queue's
;; list.  This would require another field in the queue record type
;; and one additional provisional read in each of the queue operations
;; above.  The operations below would still run slowly when called
;; with a proposal active.

;; QUEUE->LIST - Return a list of the elements in the queue.
(define (queue->list q)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (cond
      ((null? head)
       '())
      (else
       (let loop ((acc '())
                  (qp head))
         (let ((new-acc (cons (car qp) acc))
               ;; The next line must use PROVISIONAL-CDR; see below.
               (qp-cdr (provisional-cdr qp)))
           (if (null? qp-cdr)
	       (reverse new-acc)
               (loop new-acc qp-cdr)))))))))
;; If QP-CDR were set to (CDR QP) above, the following code would
;; return a value EQUAL? to '(a):
;;
;; (let ((q (make-queue))
;;       (c (make-cell 'OOPS)))
;;   (enqueue! q 'a)
;;   (ensure-atomicity!
;;    (enqueue! q 'b)
;;    (provisional-cell-set! c (queue->list q)))
;;   (cell-ref c))
;;
;; The result should be EQUAL? to '(a b).

;; QUEUE-LENGTH - Return the number of elements in the queue.
;;
;; QUEUE-LENGTH could be sped up by having all queue-modifying
;; operations maintain a count of the number of elements in the queue.
;; This would make the queue operations which *are* currently used in
;; the system much slower (e.g. ENQUEUE! currently performs 4 or 5
;; provisional operations on 2 or 3 locations; maintaining a queue
;; length counter would require it to perform another provisional read
;; and write on another location).
(define (queue-length q)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (cond
      ((null? head)
       0)
      (else
       (let loop ((acc 0)
                  (qp head))
         (let ((new-acc (+ acc 1))
	       (qp-cdr (provisional-cdr qp)))
           ;; The preceding line must use PROVISIONAL-CDR; see below.
           (if (null? qp-cdr)
	       new-acc
               (loop new-acc qp-cdr)))))))))
;; If QP-CDR were set to (CDR QP) above, the following code would
;; return a value EQUAL? to 1:
;;
;; (let ((q (make-queue))
;;       (c (make-cell 'OOPS)))
;;   (enqueue! q 'a)
;;   (ensure-atomicity!
;;    (enqueue! q 'b)
;;    (provisional-cell-set! c (queue-length q)))
;;   (cell-ref c))
;;
;; The result should be EQUAL? to 2.

;; ON-QUEUE? - Returns #T if VALUE is currently in the queue (as
;; determined by EQV?), and returns #F if VALUE is not in the queue.
(define (on-queue? q value)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (cond
      ((null? head)
       #f)
      (else
       (let loop ((qp head))
         (if (eqv? value (car qp))
             #t
             (let ((qp-cdr (provisional-cdr qp)))
               ;; The preceding line must use PROVISIONAL-CDR; see
               ;; below.
               (if (null? qp-cdr)
		   #f
                   (loop qp-cdr))))))))))
;; If QP-CDR were set to (CDR QP) above, the following code would
;; return a value EQUAL? to #f:
;;
;; (let ((q (make-queue))
;;       (c (make-cell 'OOPS)))
;;   (enqueue! q 'a)
;;   (ensure-atomicity!
;;    (enqueue! q 'b)
;;    (provisional-cell-set! c (on-queue? q 'b)))
;;   (cell-ref c))
;;
;; The result should be EQUAL? to #t.

;; DELETE-FROM-QUEUE-IF! - INTERNAL - Removes the first element in the
;; queue satisfying PRED; returns #T if an element is removed, #F
;; otherwise.
;;
;; PRED is called with a proposal active.  PRED must not raise an
;; exception, and should not have side effects.
;;
;; Because of these restrictions on PRED and the fact that this
;; procedure may be removed due to its sloth, DELETE-FROM-QUEUE-IF! is
;; not exported.
(define (delete-from-queue-if! q pred)
  (ensure-atomicity
   (let ((head (real-queue-head q)))
     (cond
      ((null? head)
       #f)
      (else
       (let loop ((qp head)
                  (provisional-set-prev-obj-field! set-queue-head!)
                  (prev-obj q)
                  (new-tail-if-prev-obj-field-is-set-to-null '()))
         (let ((qp-cdr (provisional-cdr qp)))
           ;; The preceding line must use PROVISIONAL-CDR; see below.
           (cond
            ((pred (car qp))
             (provisional-set-prev-obj-field! prev-obj qp-cdr)
             (if (null? qp-cdr)
                 (set-queue-tail!
                  q
                  new-tail-if-prev-obj-field-is-set-to-null))
             #t)
            ((null? qp-cdr)
             #f)
            (else
             (loop qp-cdr
                   provisional-set-cdr!
                   qp
                   qp))))))))))
;; If QP-CDR were set to (CDR QP) above, the following code would
;; return a value EQUAL? to '(b a #f):
;;
;; (let ((q (make-queue))
;;       (c (make-cell '())))
;;   (enqueue! q 'a)
;;   (ensure-atomicity!
;;    (enqueue! q 'b)
;;    (prov-cell-push! c (delete-from-queue! q 'b))
;;    (prov-cell-push! c (maybe-dequeue! q))
;;    (prov-cell-push! c (maybe-dequeue! q)))
;;   (cell-ref c))
;;
;; The result should be EQUAL? to '(#f a #t).

;; DELETE-FROM-QUEUE! - Removes the first element in the queue EQV? to
;; VALUE; returns #T if an element is removed, #F otherwise.
(define (delete-from-queue! q value)
  (delete-from-queue-if! q (lambda (x) (eqv? value x))))
