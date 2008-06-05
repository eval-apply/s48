; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-test-suite tlc-table-tests)

(define max-table-size 1023)
(define table-step 23)
(define min-collect-times 2)
(define max-collect-times 5)

;;; helper functions

(define verbose-output? #f)

(define (msg . args)
  (if verbose-output?
      (begin
	(display (apply format args))
	(newline))))

(define (collect-n-times n)
  (msg "Doing ~a garbage collections" n)
  (do-ec (:range k 1 n) (collect)))

(define (random-number a b)
  (+ a (random-integer b)))

(define (collect-random-times)
  (do-ec (:range k 0 (random-number 5))
	 (collect)))

(define (random-numbers n a b)
  (list-ec (:range i 1 n) (random-number a b)))

(define (random-subset lst)
  (let ((len (length lst)))
    (list-ec (:list k (random-numbers (random-number 1 len) 0 (- len 1)))
      (list-ref lst k))))

(define-record-type rec :rec
  (really-make-rec a b)
  rec?
  (a rec-a set-rec-a!)
  (b rec-b))

(define (make-rec)
  (really-make-rec (random-value-from-set some-values)
		   (random-value-from-set some-values)))

(define some-values
  (list (lambda () (cons 1 2))
	(lambda () 23)
	(lambda () #t)
	(lambda () #f)
	(lambda () 23.42)
	(lambda () #\a)
	(lambda () 'symbol)
	(lambda () (vector 1 2 3))
	(lambda () (lambda (x) x))
	(lambda () (current-output-port))
	(lambda () "Uns ist in alten maeren wunders vil geseit")
	(lambda () (make-rec))))

(define some-other-values
  (list (lambda () (cons 23 42))
	(lambda () 42)
	(lambda () #t)
	(lambda () #f)
	(lambda () 42.23)
	(lambda () #\a)
	(lambda () 'symbol)
	(lambda () (vector 11 12 13))
	(lambda () (lambda (y) y))
	(lambda () (current-output-port))
	(lambda () "Reise, reise, levt das Kottchen, zurrt, zurrt, Hängematten")
	(lambda () (make-rec))))

(define (random-value-from-set set)
  (let ((max-index (- (length set) 1)))
    ((list-ref set (random-integer max-index)))))

(define (random-value)
  (random-value-from-set some-values))

(define (random-other-value)
  (random-value-from-set some-other-values))

;;; tests

;; very basic test
(define-test-case constructor-predicate tlc-table-tests
  (check-that
   (tlc-table? (make-tlc-table 23))
   (is-true)))

;; create empty tables
(define-test-case empty-tables tlc-table-tests
  (do-ec
   (:range size 1 max-table-size 64)
   (check-that
    (tlc-table? (make-tlc-table size))
    (is-true))))

;; create empty tables and collect
(define-test-case empty-tables-collect tlc-table-tests
  (do-ec
    (:range size 1 max-table-size 64)
    (let ((t (make-tlc-table size)))
      (collect)
      (check-that (tlc-table? t) (is-true)))))

;; create empty tables and collect n times
(define-test-case empty-tables-collect-n-times tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let ((t (make-tlc-table size)))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (check-that (tlc-table? t) (is-true)))))

;; basic test for set!, contains?, and ref
(define-test-case set/ref tlc-table-tests
  (let ((t (make-tlc-table 23))
	(obj (cons 1 2)))
    (tlc-table-set! t obj obj)
    (let ((res-1 (tlc-table-ref t obj #f))
	  (res-2 (tlc-table-ref t (cons 1 2) #f)))
      (check-that (tlc-table-contains? t obj) (is-true))
      (check-that (tlc-table-contains? t (cons 1 2)) (is-false))
      (check res-1 => obj)
      (check-that res-2 (is-false)))))

;; create empty table and call ref a few times
(define-test-case empty/ref tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let ((t (make-tlc-table size)))
     (do-ec
      (:list v some-values)
      (begin
	(check-that (tlc-table-contains? t (v)) (is-false))
	(check-that (tlc-table-ref t (v) #f) (is-false)))))))

;; create table and fill it a bit
(define-test-case empty/set tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (check-that
    (let ((t (make-tlc-table size)))
      (do-ec
       (:list v some-values)
       (tlc-table-set! t (v) (cons 23 42)))
	#t)
    (is-true))))

;; create a table, fill it, and read entries
(define-test-case many/set/ref tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let ((t (make-tlc-table size))
	 (values (map (lambda (v) (v)) some-values)))
     (do-ec
      (:list v values)
      (begin
	(tlc-table-set! t v v)
	(check-that (tlc-table-contains? t v) (is-true))
	(check (tlc-table-ref t v #f) => v))))))

;; update one entry multiple times in a row
(define-test-case update-often tlc-table-tests
  (let ((t (make-tlc-table 23))
	(obj (cons 23 42)))
    (do-ec
     (:range i 1 1024)
     (tlc-table-set! t obj i))
    (tlc-table-set! t obj obj)
    (check-that (tlc-table-contains? t obj) (is-true))
    (check (tlc-table-ref t obj #f) => obj)))

;; one collection to ref the heap ready for the tests with many
;; collections
(collect)

;; create a table with one entry, collect, find it again
(define-test-case set/collect/ref tlc-table-tests
  (let ((table (make-tlc-table 23))
	(obj (cons 23 42))
	(val (cons 65 99)))
    (tlc-table-set! table obj val)
    (collect)
    (check (tlc-table-ref table obj #f) => val)))

;; fill a table with objects and retrieve them after one collection
(define-test-case set-n/collect/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n))))
     (do-ec
      (:list o objs)
      (tlc-table-set! table o o))
     (collect)
     (do-ec
      (:list o objs)
      (check(tlc-table-ref table o #f) => o)))))

;; fill a table with objects and retrieve them after n collections
(define-test-case set-n/collect-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n))))
     (do-ec
      (:list o objs)
      (tlc-table-set! table o o))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o objs)
      (check (tlc-table-ref table o #f) => o)))))

;; create a table with no entry, delete, and try to find it
(define-test-case delete/ref tlc-table-tests
  (let ((table (make-tlc-table 23))
	(obj (cons 23 42))
	(val (cons 65 99)))
    (check-that
     (tlc-table-delete! table obj #f)
     (is-false))
    (check-that 
     (tlc-table-ref table obj #f)
     (is-false))))

;; create a table with one entry, delete, and try to find it again
(define-test-case set/delete/ref tlc-table-tests
  (let ((table (make-tlc-table 23))
	(obj (cons 23 42))
	(val (cons 65 99)))
    (tlc-table-set! table obj val)
    (check-that
     (tlc-table-delete! table obj #f)
     (opposite (is-false)))
    (check-that
     (tlc-table-ref table obj #f)
     (is-false))))

;; create a table with some entries that all go into the same bucket,
;; delete them, and try to find them again
(define-test-case set-n-in-one-bucket/delete-n/ref-n tlc-table-tests
  (let ((table (make-tlc-table 1))
	(val (cons 65 99)))
    (do-ec
     (:range n 1 23)
     (tlc-table-set! table n val))
    (do-ec
     (:range n 1 23)
     (check (tlc-table-ref table n #f) => val))
    (do-ec
     (:range n 1 23)
     (check-that
      (tlc-table-delete! table n #f)
      (opposite (is-false))))
    (do-ec
     (:range n 1 23)
     (check (tlc-table-ref table n #f) => #f))))

;; create a table with one entry, collect, delete, and try to find it
;; again
(define-test-case set/collect/delete/ref tlc-table-tests
  (let ((table (make-tlc-table 23))
	(obj (cons 23 42))
	(val (cons 65 99)))
    (tlc-table-set! table obj val)
    (collect)
    (check-that
     (tlc-table-delete! table obj #f)
     (opposite (is-false)))
    (check-that
     (tlc-table-ref table obj #f)
     (is-false))))

;; fill a table with objects, delete some, and retrieve them after one
;; collection
(define-test-case set-n/collect/delete-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (delobjs (list-ec (: i n) (cons (+ i max-table-size) n))))
     (do-ec
      (:list o delobjs)
      (tlc-table-set! table o o))
     (collect)
     (do-ec
      (:list o objs)
      (tlc-table-set! table o o))
     (collect)
     (do-ec
      (:list o delobjs)
      (check-that
       (tlc-table-delete! table o #f)
       (opposite (is-false))))
     (collect)
     (do-ec
      (:list o delobjs)
      (check-that
       (tlc-table-ref table o #f)
       (is-false)))
     (do-ec
      (:list o objs)
      (check (tlc-table-ref table o #f) => o)))))

;; fill a table with objects, delete some, and retrieve the others
;; after n collections
(define-test-case set-n/collect-n/delete-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (delobjs (list-ec (: i n) (cons i n))))
     (do-ec
      (:list o delobjs)
      (tlc-table-set! table o o))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o objs)
      (tlc-table-set! table o o))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o delobjs)
      (check-that
       (tlc-table-delete! table o #f)
       (opposite (is-false))))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o delobjs)
      (check-that
       (tlc-table-ref table o #f)
       (is-false)))
     (do-ec
      (:list o objs)
      (check (tlc-table-ref table o #f) => o)))))

;; create a table with one weak entry and find it again
(define-test-case weak-set/ref tlc-table-tests
  (let* ((table (make-tlc-table 23))
	 (obj (cons 23 42))
	 (wp (make-weak-pointer obj))
	 (val (cons 65 99)))
    (tlc-table-set! table wp val)
    (check (tlc-table-ref table wp #f) => val)))

;; create a table with one weak entry, collect and find it again
(define-test-case weak-set/collect/ref tlc-table-tests
  (let* ((table (make-tlc-table 23))
	 (obj (cons 23 42))
	 (wp (make-weak-pointer obj))
	 (val (cons 65 99)))
    (tlc-table-set! table wp val)
    (collect)
    (check (tlc-table-ref table wp #f) => val)))

;; fill a table with weak objects and retrieve them after one
;; collection
(define-test-case weak-set-n/collect/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (wobjs (map make-weak-pointer objs)))
     (do-ec
      (:list o wobjs)
      (tlc-table-set! table o o))
     (collect)
     (do-ec
      (:list o wobjs)
      (check (tlc-table-ref table o #f) => o)))))

;; fill a table with weak objects and retrieve them after n
;; collections
(define-test-case weak-set-n/collect-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (wobjs (map make-weak-pointer objs)))
     (do-ec
      (:list o wobjs)
      (tlc-table-set! table o o))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o wobjs)
      (check (tlc-table-ref table o #f) => o)))))

;; create a table with no weak entry, delete, and try to find it
(define-test-case weak-delete/ref tlc-table-tests
  (let* ((table (make-tlc-table 23))
	 (obj (cons 23 42))
	 (wobj (make-weak-pointer obj))
	 (val (cons 65 99)))
    (check-that
     (tlc-table-delete! table wobj #f)
     (is-false))
    (check-that
     (tlc-table-ref table wobj #f)
     (is-false))))

;; create a table with one weak entry, delete, and try to find it
;; again
(define-test-case weak-set/delete/ref tlc-table-tests
  (let* ((table (make-tlc-table 23))
	 (obj (cons 23 42))
	 (wobj (make-weak-pointer obj))
	 (val (cons 65 99)))
    (tlc-table-set! table wobj val)
    (check-that
     (tlc-table-delete! table wobj #f)
     (opposite (is-false)))
    (check-that
     (tlc-table-ref table wobj #f)
     (is-false))))

;; create a table with one weak entry, collect, delete, and try to
;; find it again
(define-test-case weak-set/collect/delete/ref tlc-table-tests
  (let* ((table (make-tlc-table 23))
	 (obj (cons 23 42))
	 (wobj (make-weak-pointer obj))
	 (val (cons 65 99)))
    (tlc-table-set! table wobj val)
    (collect)
    (check-that
     (tlc-table-delete! table wobj #f)
     (opposite (is-false)))
    (check-that
     (tlc-table-ref table wobj #f)
     (is-false))))

;; fill a table with weak objects, delete some, and retrieve the
;; others after one collection
(define-test-case weak-set-n/collect/delete-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (wobjs (map make-weak-pointer objs))
	  (delobjs (list-ec (: i n) (cons (+ i 100) 42)))
	  (delwobjs (map make-weak-pointer delobjs)))
     (do-ec
      (:list o wobjs)
      (tlc-table-set! table o o))
     (do-ec
      (:list o delwobjs)
      (tlc-table-set! table o o))
     (do-ec
      (:list o delwobjs)
      (check (tlc-table-ref table o #f) => o))
     (do-ec
      (:list o wobjs)
      (check (tlc-table-ref table o #f) => o))
     (collect)
     (do-ec
      (:list o delwobjs)
      (check-that
       (tlc-table-delete! table o #f)
       (opposite (is-false))))
     (do-ec
      (:list o delwobjs)
      (check-that
       (tlc-table-ref table o #f)
       (is-false)))
     (do-ec
      (:list o wobjs)
      (check (tlc-table-ref table o #f) => o)))))

;; fill a table with weak objects, delete some, and retrieve the
;; others after n collections
(define-test-case weak-set-n/collect-n/delete-n/ref-n tlc-table-tests
  (do-ec
   (:range size 1 max-table-size table-step)
   (let* ((table (make-tlc-table size))
	  (n (* 3 size))
	  (objs (list-ec (: i n) (cons i n)))
	  (wobjs (map make-weak-pointer objs))
	  (delobjs (list-ec (: i n) (cons (+ i 100) 42)))
	  (delwobjs (map make-weak-pointer delobjs)))
     (do-ec
      (:list o wobjs)
      (tlc-table-set! table o o))
     (do-ec
      (:list o delwobjs)
      (tlc-table-set! table o o))
     (collect-n-times (random-number min-collect-times max-collect-times))
     (do-ec
      (:list o delwobjs)
      (check-that
       (tlc-table-delete! table o #f)
       (opposite (is-false))))
     (do-ec
      (:list o wobjs)
      (check (tlc-table-ref table o #f) => o))
     (do-ec
      (:list o delwobjs)
      (check-that
       (tlc-table-ref table o #f)
       (is-false))))))

;; TODO: random set/collect/delete/ref weak/non-weak stress test
