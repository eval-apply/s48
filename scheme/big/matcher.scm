; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Combinators for predicates, useful for test suites.

(define-record-type matcher :matcher 
  (make-matcher predicate
		sexpr)
  matcher?
  (predicate matcher-predicate)
  (sexpr matcher-sexpr))

(define-record-discloser :matcher
  (lambda (m)
    (list 'matcher (matcher-sexpr m))))

(define (matches? matcher val)
  ((matcher-predicate matcher) val))

(define (is p? . rest)
  (cond ((pair? rest)
	 (let ((val (car rest)))
	   (make-matcher (lambda (x)
			   (p? x val))
			 `(is ,p? ,val))))
	((procedure? p?)
	 (make-matcher p? `(is ,p?)))
	(else (make-matcher (lambda (x)
			      (equal? x p?))
			    `(is ,p?)))))

(define (anything)
  (make-matcher (lambda (x) #t)
		`anything))

(define (opposite matcher)
  (make-matcher (lambda (x)
		  (not (matches? matcher x)))
		`(not ,(matcher-sexpr matcher))))

(define (is-true)
  (make-matcher (lambda (x) x)
		'is-true))

(define (is-false)
  (make-matcher (lambda (x) (not x))
		'is-false))

(define (is-null)
  (make-matcher (lambda (x) (null? x))
		'is-false))

(define (is-within val epsilon)
  (make-matcher (lambda (x)
		  (and (number? x)
		       (< (magnitude (- val x )) epsilon)))
		`(is-within ,val ,epsilon)))

(define (member-of list)
  (make-matcher (lambda (x) (member x list))
		`(is-member ,list)))

(define (all-of . matchers)
  (make-matcher (lambda (x)
		  (every? (lambda (matcher)
			    (matches? matcher x))
			  matchers))
		`(all-of ,@(map matcher-sexpr matchers))))

(define (any-of . matchers)
  (make-matcher (lambda (x)
		  (any? (lambda (matcher)
			    (matches? matcher x))
			  matchers))
		`(any-of ,@(map matcher-sexpr matchers))))

(define (list-where-all matcher)
  (make-matcher (lambda (l)
		  (and (list? l)
		       (every? (lambda (x)
				 (matches? matcher x))
			       l)))
		`(list-where-each ,matcher)))

(define (list-where-any matcher)
  (make-matcher (lambda (l)
		  (and (list? l)
		       (any? (lambda (x)
			       (matches? matcher x))
			     l)))
		`(list-where-any ,matcher)))

(define (list-of . matchers)
  (let ((count (length matchers)))
    (make-matcher (lambda (x)
		    (and (list? x)
			 (let loop ((matchers matchers)
				    (els x))
			   (cond
			    ((null? matchers) (null? els))
			    ((null? els) #f)
			    (else
			     (and (matches? (car matchers) (car els))
				  (loop (cdr matchers) (cdr els))))))))
		  `(list-of ,@matchers))))
