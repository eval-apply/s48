; Part of Scheme 48 1.9.  See file COPYING for notices and license. 


(define *count* 0)

(define (increment)
  (set! *count* (+ *count* 1)))

(define (value)
  *count*)

(define (test out)
  (increment)
  (increment)
  (write-number (value) out)
  (newline out))

(test (current-output-port))
