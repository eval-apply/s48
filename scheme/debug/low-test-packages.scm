; Part of Scheme 48 1.9.  See file COPYING for notices and license.

; (link-simple-system '(debug low-test) 'start low-test-system)

(define-structure low-test-system (export start)
  (define-all-operators)
  (files low-test))

(define-structure bignum-test-system (export start)
  (define-all-operators)
  (files bignum-test))
