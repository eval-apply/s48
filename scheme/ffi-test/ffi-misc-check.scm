; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Author: Harald Glab-Plhak

;; test for the new ffi

(define-test-suite ffi-misc-tests)

(define-test-case ffi-call-scheme-test ffi-misc-tests
  (check 
   (let ((result (ffi-call-scheme (lambda args
				    (apply + args)) 
				  
				  3 4 5 6)))
     result)
   => 15))

(define-test-case ffi-values-test ffi-misc-tests
  (check
   (let ((value (ffi-make-strange-value 10 "LolliPop")))
     (let ((result(ffi-strange-value->list value)))
       (ffi-strange-value-free value)
       result))
   => '(10 . "LolliPop")))

(define-test-case ffi-weak-pointer ffi-misc-tests
  (let ((w (make-weak-pointer (cons 23 42))))
    (check (equal? (cons 23 42) (weak-pointer-ref w)))
    (collect)
    (check (not (weak-pointer-ref w)))))

(define-test-case ffi-weak-pointer-2 ffi-misc-tests
  (let ((w (ffi-make-weak-pointer (cons 23 42))))
    (check (ffi-weak-pointer? w))
    (check (equal? (cons 23 42) (ffi-weak-pointer-ref w)))
    (collect)
    (check (not (ffi-weak-pointer-ref w)))))

(define-test-case ffi-strings-test ffi-misc-tests
  (let ((string "Grüße"))
    (let ((latin-1 (ffi-check-string-latin-1 string))
	  (utf-8 (ffi-check-string-utf-8 string)))
      (check (eq? (byte-vector-ref latin-1 2) 252))
      (check (eq? (byte-vector-ref latin-1 3) 223))
      (check (eq? (byte-vector-ref utf-8 3) 188))
      (check (eq? (byte-vector-ref utf-8 5) 159)))))
