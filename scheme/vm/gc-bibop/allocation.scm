; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Interface to the VM for allocation

;; Everything else is defined via bibop-gc-external

;; For allocation done outside the VM.

(define (allocate-stob weak? type size)
  (let* ((traced? (< type least-b-vector-type))
	 (length-in-bytes (if traced?
			      (cells->bytes size)
			      size))
	 (needed (+ length-in-bytes (cells->bytes stob-overhead)))
	 (thing (if weak?
		    (s48-allocate-weak+gc needed)
		    (if traced?
			(s48-allocate-traced+gc needed)
			(s48-allocate-untraced+gc needed)))))
    (if (null-address? thing)
	(error "insufficient heap space for external allocation"))
    (store! thing (make-header type length-in-bytes))
    (address->stob-descriptor (address+ thing
                                        (cells->bytes stob-overhead)))))

(define (s48-allocate-stob type size)
  (allocate-stob #f type size))

(define (s48-allocate-weak-stob type size)
  (allocate-stob #t type size))
