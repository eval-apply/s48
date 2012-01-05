; Part of Scheme 48 1.9.  See file COPYING for notices and license.

; Authors: Mike Sperber, Robert Ransom

;----------------
; External events

(define (initialize-external-events!)
  (set-interrupt-handler! (enum interrupt external-event)
			  external-event-handler))

; Exported procedure

(define (waiting-for-external-events?)
  (zap-condvar-orphans!)
  (not (null? (external-event-condvars))))

;----------------

; A session slot contains an alist mapping external-event uids to
; condvars for external events on that uid.  This works analogously to
; channels.

(define external-events-wait-condvars-slot
  (make-session-data-slot! '()))

(define (external-event-condvars)
  (session-data-ref external-events-wait-condvars-slot))

(define (set-external-event-condvars! condvars)
  (session-data-set! external-events-wait-condvars-slot condvars))

;; Return the condition variable for the specified external event UID,
;; adding a new one to the list if necessary.
;;
;; This function must be called with interrupts disabled.
(define (get-external-event-condvar! uid)
  (let loop ((condvars (external-event-condvars)))
    (cond
     ((null? condvars)
      ;; No condvar for this event yet -- create one.
      (let ((condvar (make-condvar)))
        (set-external-event-condvars! (cons (cons uid condvar)
				      (external-event-condvars)))
        condvar))
     ((= (caar condvars) uid)
      ;; Found an existing condvar for this event.
      (cdar condvars))
     (else
      (loop (cdr condvars))))))

(define (notify-external-event-condvar! condvar)
  (with-new-proposal (lose)
    (or (maybe-commit-and-set-condvar! condvar #t)
	(lose))))

(define (external-event-handler uid enabled-interrupts)
  (cond
   ((fetch-external-event-condvar! uid)
    => notify-external-event-condvar!)))

(define (wait-for-external-event uid)
  (let ((ints (disable-interrupts!))
        (condvar (get-external-event-condvar! uid)))
    (with-new-proposal (lose)
      (maybe-commit-and-wait-for-condvar condvar))
    (set-enabled-interrupts! ints)))

; This just deletes from the alist.

(define (fetch-external-event-condvar! uid)
  (let ((condvars (external-event-condvars)))
    (cond ((null? condvars)
	   #f)
	  ((= uid (caar condvars))
	   (set-external-event-condvars! (cdr condvars))
	   (cdar condvars))
	  (else
	   (let loop ((condvars (cdr condvars)) (prev condvars))
	     (cond ((null? condvars)
		    #f)
		   ((= uid (caar condvars))
		    (set-cdr! prev (cdr condvars))
		    (cdar condvars))
		   (else
		    (loop (cdr condvars) condvars))))))))

; Zap the condvars that no longer have waiters.

(define (zap-condvar-orphans!)
  (with-interrupts-inhibited
   (lambda ()
     (let loop ((condvars (external-event-condvars)) (okay '()))
       (if (null? condvars)
	   (set-external-event-condvars! okay)
	   (let ((condvar (cdar condvars)))
	     (loop (cdr condvars)
		   (if (condvar-has-waiters? condvar)
		       (cons (car condvars) okay)
		       (begin
			 (notify-external-event-condvar! condvar)
			 okay)))))))))
