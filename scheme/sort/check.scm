;;; Little test harness, 'cause I'm paraoid about tricky code.
;;; ,open srfi-27 vector-heap-sort list-merge-sort vector-merge-sort vector-insertion-sort sorted

(define-test-suite sort-tests)

;;; For testing stable sort -- 3 & -3 compare the same.
(define (my< x y) (< (abs x) (abs y)))

(define (unstable-sort-test v) ; quick & heap vs simple insert
  (let ((v1 (vector-copy v))
	(v2 (vector-copy v)))
    (vector-heap-sort!    < v1)
    (vector-insert-sort!  < v2)
    (check-that v2 (is v1))
    (check-that v1 (is (lambda (v) (vector-sorted? < v))))))

(define (stable-sort-test v) ; insert, list & vector merge sorts
  (let ((v1 (vector-copy v))
	(v2 (vector-copy v))
	(v3 (list->vector (list-merge-sort! my< (vector->list v))))
	(v4 (list->vector (list-merge-sort  my< (vector->list v)))))
    (vector-merge-sort! my< v1)
    (vector-insert-sort! my< v2)
    (check-that v1 (is (lambda (v) (vector-sorted? my< v))))
    (check-that v2 (is v1))
    (check-that v3 (is v1))
    (check-that v4 (is v1))))

(define (run-sort-test sort-test count max-size)
  (let loop ((i 0))
    (if (< i count)
	(begin
	  (sort-test (random-vector (random-integer max-size)))
	  (loop (+ 1 i))))))

(define-test-case stable-sort sort-tests
  (run-sort-test stable-sort-test 20 4096))

(define-test-case unstable-sort sort-tests
  (run-sort-test unstable-sort-test 20 4096))

(define (random-vector size)
  (let ((v (make-vector size)))
    (fill-vector-randomly! v (* 10 size))
    v))

(define (fill-vector-randomly! v range)
  (let ((half (quotient range 2)))
    (do ((i (- (vector-length v) 1) (- i 1)))
	((< i 0))
      (vector-set! v i (- (random-integer range) half)))))

(define (vector-portion-copy vec start end)
  (let* ((len (vector-length vec))
	 (new-len (- end start))
	 (new (make-vector new-len)))
    (do ((i start (+ i 1))
	 (j 0 (+ j 1)))
	((= i end) new)
      (vector-set! new j (vector-ref vec i)))))

(define (vector-copy vec)
  (vector-portion-copy vec 0 (vector-length vec)))