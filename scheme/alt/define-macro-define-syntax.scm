; Part of Scheme 48 1.9.  See file COPYING for notices and license.

(define-macro (define-syntax macro-name transformer . stuff)
  `(define-macro (,macro-name . args)
     (,transformer (cons ',macro-name args)
		   (lambda (x) x)
		   eq?)))
