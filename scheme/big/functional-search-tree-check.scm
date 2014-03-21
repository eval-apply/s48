; Part of Scheme 48 1.9.  See file COPYING for notices and license.

; Authors: Mike Sperber

(define-test-suite functional-search-trees-tests)

(define (alist->search-tree = < l)
  (let loop ((st (make-search-tree = <))
	     (l l))
    (if (null? l)
	st
	(loop (search-tree-insert st (caar l) (cdar l))
	      (cdr l)))))

(define-test-case simple functional-search-trees-tests
  
  (let* ((l (map (lambda (n) (cons n (+ n 1))) 
		 '(0 1 2 3 4 5 6 7 8 9)))
	 (st (alist->search-tree = < l)))
    (for-each (lambda (p)
		(check-that (search-tree-ref st (car p)) 
			    (is (cdr p))))
	      l)
    (check-that (invalid-search-tree st) (is #f))))

(define (random-unique-list count n)
  (let loop ((count count)
	     (l '()))
    (if (zero? count)
	l
	(let ((x (random-integer n)))
	  (if (memv x l)
	      (loop count l)
	      (loop (- count 1) (cons x l)))))))

(define-test-case random functional-search-trees-tests
  (let* ((l (map (lambda (n) (cons n (+ n 1))) 
		 (random-unique-list 1000 100000)))
	 (st (alist->search-tree = < l)))
    (for-each (lambda (p)
		(check-that (search-tree-ref st (car p)) 
			    (is (cdr p))))
	      l)
    (check-that (invalid-search-tree st) (is #f))))

(define-test-case walk functional-search-trees-tests
  (let* ((l (map (lambda (n) (cons n (+ n 1))) 
		 (random-unique-list 1000 10000)))
	 (st (alist->search-tree = < l)))
    (let ((c '()))
      (search-tree-walk (lambda (key val)
			  (set! c (cons (cons key val) c)))
			st)

      (check-that (length c) (is (length l)))
      (for-each (lambda (p)
		  (check (member p c)))
		l))))

(define-test-case simple-delete functional-search-trees-tests
  (let ((l (map (lambda (n) (cons n (+ n 1))) 
		 '(0 1 2 3 4 5 6 7 8 9))))
    (let loop ((st (alist->search-tree = < l))
	       (l l))
      (if (pair? l)
	  (let ((st (search-tree-delete st (caar l))))
	    (check-that (search-tree-ref st (caar l)) (is #f))
	    (check-that (invalid-search-tree st) (is #f))
	    (loop st (cdr l)))))))

(define-test-case random-delete functional-search-trees-tests
  (let ((l (map (lambda (n) (cons n (+ n 1))) 
		(random-unique-list 1000 10000)))) 
    (let loop ((st (alist->search-tree = < l))
	       (l l))
      (if (pair? l)
	  (let ((st (search-tree-delete st (caar l))))
	    (check-that (search-tree-ref st (caar l)) (is #f))
	    (check-that (invalid-search-tree st) (is #f))
	    (loop st (cdr l)))))))
