; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define (compare-n-ary =? a b . rest)
  (and (=? a b)
       (let loop ((x b)
		  (rest rest))
	 (if (null? rest)
	     #t
	     (and (=? x (car rest))
		  (loop (car rest) (cdr rest)))))))

(define-syntax define-n-ary-comparison
  (syntax-rules ()
    ((define-n-ary-comparison ?name ?binary-name)
     (define (?name a b . rest)
       (apply compare-n-ary ?binary-name a b rest)))))

; avoid re-normalizing on each transitivity step
(define-syntax define-n-ary-normalizing-comparison
  (syntax-rules ()
    ((define-n-ary-normalizing-comparison ?name ?normalize ?binary-name)
     (define (?name a b . rest)
       (apply compare-n-ary ?binary-name (?normalize a) (?normalize b)
	      (map ?normalize rest))))))

