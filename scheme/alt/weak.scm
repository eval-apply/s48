; Part of Scheme 48 1.9.  See file COPYING for notices and license.


(define (make-weak-pointer x) (cons '<weak> x))
(define weak-pointer-ref cdr)
(define (weak-pointer? x)
  (and (pair? x) (eq? (car x) '<weak>)))

