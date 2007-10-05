; Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees. See file COPYING.


(define-structures ((vm-utilities vm-utilities-interface))
  (open scheme)
  (files (util vm-utilities))
  (begin
;    (define-syntax assert
;      (lambda (exp rename compare)
;    	0))
    (define (assert x)
      (if (not x)
    	  (error "assertion failed")))
    ))

(define-structures ((external external-interface))
  (open scheme bitwise ps-memory
        bignum-low ; for s48-allocate-bignum
        (subset stob (b-vector-set! b-vector-ref b-vector-length))
        (subset memory (address->stob-descriptor address-after-header))
        (subset data (least-fixnum-value greatest-fixnum-value)))
  (for-syntax (open scheme)) ; for error
  (files (util external)))

(define-structures ((channel-io channel-interface)
		    (events event-interface))
  (open scheme big-scheme ps-memory ports
	(subset i/o		(current-error-port))
	(modify prescheme	(prefix prescheme:)
		                (expose open-input-file open-output-file
					close-input-port close-output-port
					errors)))
  (files (util s48-channel)))
