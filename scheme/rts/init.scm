; Copyright (c) 1993-2004 by Richard Kelsey and Jonathan Rees. See file COPYING.

; System entry and exit

; Entry point from OS executive.  Procedures returned by USUAL-RESUMER
; are suitable for use as the second argument to WRITE-IMAGE.
;
; The placement of INITIALIZE-RECORDS! is questionable.  Important parts
; of the system are not in place when it is run.

(define (usual-resumer entry-point)
  (lambda (resume-arg in out error records)
    (initialize-rts in out error
     (lambda ()
       (initialize-records! records)
       (warn-about-undefined-imported-bindings)
       (entry-point (vector->list resume-arg))))))

(define (warn-about-undefined-imported-bindings)
  (let ((undefined-bindings (find-undefined-imported-bindings)))
    (do ((size (vector-length undefined-bindings))
	 (i 0 (+ 1 i)))
	((= i size))
      (debug-message "undefined imported binding "
		     (shared-binding-name (vector-ref undefined-bindings i))))))

(define (initialize-rts in out error thunk)
  (initialize-session-data!)
  (initialize-dynamic-state!)
  (initialize-exceptions!
    (lambda ()
      (initialize-interrupts!
       spawn-on-root
       (lambda ()
	 (initialize-i/o (input-channel->port in)
			 (output-channel->port out)
	                 (output-channel->port error 0)  ; zero-length buffer
	     (lambda ()
	       (with-threads
		(lambda ()
		  (root-scheduler thunk
				  200           ; thread quantum, in msec
				  300)))))))))) ; port-flushing quantum

; Add the full/empty buffer handlers.

(initialize-i/o-handlers! define-exception-handler signal-exception)
