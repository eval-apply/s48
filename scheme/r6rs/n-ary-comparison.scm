; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Tricky business, as we want to typecheck all arguments, and avoid
; redundant normalizations.

; x is already wrapped
(define (compare-n-ary name =? wrap pred x . rest)
  (let loop ((x x)
	     (rest rest))
    (or (null? rest)
	(let ((next (wrap (car rest))))
	  (if (=? x next)
	      (loop next (cdr rest))
	      (check-pred name pred (cdr rest)))))))

(define (check-pred name pred lis)
  (cond
   ((find (lambda (x)
	    (not (pred x)))
	  lis)
    => (lambda (wrong)
	 (assertion-violation name
			      "invalid argument"
			      wrong)))
   (else #f)))

(define-syntax define-n-ary-comparison
  (syntax-rules ()
    ((define-n-ary-comparison ?name ?pred ?wrap ?binary-name)
     (define (?name a b . rest)
       (let ((bw (?wrap b)))
	 (cond
	  ((?binary-name (?wrap a) bw)
	   (or (null? rest)
	       (apply compare-n-ary '?name ?binary-name ?wrap ?pred bw rest)))
	  ((null? rest) #f)
	  (else (check-pred '?name ?pred rest))))))))

