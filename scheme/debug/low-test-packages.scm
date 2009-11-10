; no copyright

; (link-simple-system '(debug low-test) 'start low-test-system)

(define-structure low-test-system (export start)
  (define-all-operators)
  (files low-test))

(define-structure bignum-test-system (export start)
  (define-all-operators)
  (files bignum-test))
