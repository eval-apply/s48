; Part of Scheme 48 1.9.  See file COPYING for notices and license.



(define (fact n)
  (if (= n 0)
      1
      (* n (fact (- n 1)))))
