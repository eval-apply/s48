; Part of Scheme 48 1.9.  See file COPYING for notices and license. 


(define (identity x) x)  ; can't get much more polymorphic than that

(define (test x)
  (cond (#f
	 (vector-ref (identity (make-vector 3)) 2))
	(else
	 (+ (identity (+ x 3)) (identity (+ x 2))))))

