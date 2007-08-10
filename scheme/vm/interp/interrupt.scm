; Copyright (c) 1993-2001 by Richard Kelsey and Jonathan Rees. See file COPYING.
; Code for handling interrupts.

; New interrupt handler vector in *val*

(define-opcode set-interrupt-handlers!
  (cond ((or (not (vm-vector? *val*))
	     (< (vm-vector-length *val*) interrupt-count))
	 (raise-exception wrong-type-argument 0 *val*))
	(else
	 (let ((temp (shared-ref *interrupt-handlers*)))
	   (shared-set! *interrupt-handlers* *val*)
	   (set! *val* temp)
	   (goto continue 0)))))

; New interrupt mask as fixnum in *val*

(define-opcode set-enabled-interrupts!
  (let ((old *enabled-interrupts*))
    (set-enabled-interrupts! (extract-fixnum *val*))
    (set! *val* (enter-fixnum old))
    (goto continue 0)))

; Save the current interpreter state and call an interrupt handler.

(define (handle-interrupt)
  (push *val*)
  (receive (code pc)
      (current-code+pc)
    (push code)
    (push (enter-fixnum pc)))
  (push-interrupt-state)
  (push-adlib-continuation! (code+pc->code-pointer *interrupt-return-code*
						   return-code-pc))
  (goto find-and-call-interrupt-handler))

; We now have three places interrupts are caught:
;  - during a byte-code call
;  - during a native-code call
;  - during a native-code poll
; The two native calls can be done using the same method.  Argh.  We need
; to save the proposal and enabled interrupts and still end up with a template
; on top of the stack.  Just make a return pointer with two extra pointer
; slots at the top.  The native-dispatch code pops the code pointer and
; template, pushes the extra state, and then ... .  No.  The simple thing
; to do is have the native code make one continuation and then we push a
; second, byte-coded one on top.  It's ugly no matter what.

; Ditto, except that we are going to return to the current continuation instead
; of continuating with the current template.

(define (push-native-interrupt-continuation)
  (push-interrupt-state)
  (push native-interrupt-continuation-descriptors)
  (push-continuation! (code+pc->code-pointer *interrupt-return-code*
					     return-code-pc)))

(define interrupt-state-descriptors 2)

(define native-interrupt-continuation-descriptors
  (enter-fixnum (+ 1		; this number
		   interrupt-state-descriptors)))

(define (push-interrupt-state)
  (push (current-proposal))
  (set-current-proposal! false)
  (push (enter-fixnum *enabled-interrupts*)))

(define (s48-pop-interrupt-state)
  (set-enabled-interrupts! (extract-fixnum (pop)))
  (set-current-proposal! (pop)))

(define (find-and-call-interrupt-handler)
  (let* ((pending-interrupt (get-highest-priority-interrupt!))
	 (arg-count (push-interrupt-args pending-interrupt))
	 (handlers (shared-ref *interrupt-handlers*)))
    (if (not (vm-vector? handlers))
	(error "interrupt handler is not a vector"))
    (set! *val* (vm-vector-ref handlers pending-interrupt))
    (if (not (closure? *val*))
	(error "interrupt handler is not a closure" pending-interrupt))
    (set-enabled-interrupts! 0)
    (goto call-interrupt-handler arg-count pending-interrupt)))

; Push the correct arguments for each type of interrupt.
;
; For alarm interrupts the interrupted template is passed to the handler
;  for use by code profilers.
; For gc interrupts we push the list of things to be finalized.
; For i/o-completion we push the channel and its status.

(define (push-interrupt-args pending-interrupt)
  (cond ((eq? pending-interrupt (enum interrupt alarm))
	 (push *interrupted-template*)
	 (set! *interrupted-template* false)
	 (push (enter-fixnum *enabled-interrupts*))
	 2)
	((eq? pending-interrupt (enum interrupt post-gc))
	 (push *finalize-these*)
	 (set! *finalize-these* null)
	 (push (enter-fixnum *enabled-interrupts*))
	 2)
	((eq? pending-interrupt (enum interrupt i/o-completion))
	 (let ((channel (dequeue-channel!)))
	   (if (not (channel-queue-empty?))
	       (note-interrupt! (enum interrupt i/o-completion)))
	   (push channel)
	   (push (channel-os-status channel))
	   (push (enter-fixnum *enabled-interrupts*))
	   3))
	((eq? pending-interrupt (enum interrupt os-signal))
	 (push *os-signal-type*)
	 (push *os-signal-argument*)
	 (set! *os-signal-type* false)
	 (set! *os-signal-argument* false)
	 (push (enter-fixnum *enabled-interrupts*))
	 3)
	(else
	 (push (enter-fixnum *enabled-interrupts*))
	 1)))

; Called from outside when an os-signal event is returned.

(define (s48-set-os-signal type argument)
  (set! *os-signal-type* type)
  (set! *os-signal-argument* argument))

(define *os-signal-type* false)
(define *os-signal-argument* false)

; Called from outside to initialize a new process.

(define (s48-reset-interrupts!)
  (set! *os-signal-type* false)
  (set! *os-signal-argument* false)
  (set! *enabled-interrupts* 0)
  (set! *pending-interrupts* 0)
  (set! s48-*pending-interrupt?* #f))

;(define-opcode poll
;  (if (and (interrupt-flag-set?)
;           (pending-interrupt?))
;      (begin
;        (push-simple-continuation! (address+ *code-pointer*
;                                             (code-offset 0)))
;        (push-native-interrupt-continuation)
;        (goto find-and-call-interrupt-handler))
;      (goto continue 2)))
	    
; Return from a call to an interrupt handler.

(define-opcode return-from-interrupt
  (let ((byte? (not (fixnum= (pop)
			     native-interrupt-continuation-descriptors))))
    (s48-pop-interrupt-state)
    (cond (byte?
	   (let ((pc (pop)))
	     (set-code-pointer! (pop) (extract-fixnum pc)))
	   (set! *val* (pop))
	   (goto interpret *code-pointer*))
	  (else
	   (goto return-values 0 null 0)))))

; Do nothing much until something happens.  To avoid race conditions this
; opcode is called with all interrupts disabled, so it has to return if
; any interrupt occurs, even a disabled one.

(define-primitive wait (fixnum-> boolean->)
  (lambda (max-wait minutes?)
    (if (and (not (pending-interrupt?))
	     (= 0 *pending-interrupts*))
	(wait-for-event max-wait minutes?))
    (goto return-unspecific 0)))

; The players:
;   *pending-interrupts*      A bit mask of pending interrupts
;   *enabled-interrupts*      A bit mask of enabled interrupts
;   s48-*pending-interrupt?*  True if either an event or interrupt is pending
;   s48-*pending-events?*     True if an event is pending
;
; When an asynchronous event occurs the OS sets S48-*PENDING-EVENTS?* and
; S48-*PENDING-INTERRUPT?* to true.
;
; When S48-*PENDING-EVENTS?* is true the VM calls (CURRENT-EVENTS) to get the
; pending events.
;
; The goals of all this mucking about are:
;   - no race conditions
;   - the VM operates synchronously; only the OS is asynchronous
;   - polling only requires testing S48-*PENDING-INTERRUPT?*

(define s48-*pending-events?* #f)

; Called asynchronously by the OS

(define (s48-note-event)
  (set! s48-*pending-events?* #t)       ; order required by non-atomicity
  (set-interrupt-flag!))

; Called when the interrupt flag is set, so either an event or interrupt is
; waiting (or both).  We process any events and then see if is an interrupt.

(define (pending-interrupt?)
  (if s48-*pending-events?*
      (begin
	(set! s48-*pending-events?* #f)
	(process-events)))
  (real-pending-interrupt?))

; Check for a pending interrupt, clearing the interrupt flag if there is
; none.  This and S48-NOTE-EVENT cooperate to avoid clearing the interrupt
; flag while an event is pending.

(define (real-pending-interrupt?)
  (cond ((= 0 (bitwise-and *pending-interrupts*
			   *enabled-interrupts*))
	 (clear-interrupt-flag!)
	 (if s48-*pending-events?*
	     (set-interrupt-flag!))
	 #f)
	(else
	 #t)))

(define (update-pending-interrupts)
  (if (real-pending-interrupt?)
      (set-interrupt-flag!)))

; Add INTERRUPT to the set of pending interrupts, then check to see if it
; is currently pending.

(define (note-interrupt! interrupt)
  (set! *pending-interrupts*
	(bitwise-ior *pending-interrupts* (interrupt-bit interrupt)))
  (update-pending-interrupts))

; Remove INTERRUPT from the set of pending interrupts, then recheck for pending
; interrupts; INTERRUPT may have been the only one.

(define (clear-interrupt! interrupt)
  (set! *pending-interrupts*
	(bitwise-and *pending-interrupts*
		     (bitwise-not (interrupt-bit interrupt))))
  (update-pending-interrupts))

; Install a new set of enabled interrupts.  As usual we have to recheck for
; enabled interrupts.

(define (set-enabled-interrupts! enabled)
  (set! *enabled-interrupts* enabled)
  (update-pending-interrupts))

; Disable all interrupts.

(define (disable-interrupts!)
  (set! s48-*pending-interrupt?* #f)
  (set! *enabled-interrupts* 0))

; Enable all interrupts.

(define (enable-interrupts!)
  (set-enabled-interrupts! -1))

; We don't need to mess with S48-*PENDING-INTERRUPT?* because all interrupts
; are about to be disabled.

(define (get-highest-priority-interrupt!)
  (let ((n (bitwise-and *pending-interrupts* *enabled-interrupts*)))
    (let loop ((i 0) (m 1))
      (cond ((= 0 (bitwise-and n m))
	     (loop (+ i 1) (* m 2)))
	    (else
	     (set! *pending-interrupts*
		   (bitwise-and *pending-interrupts* (bitwise-not m)))
	     i)))))

; Process any pending OS events.  PROCESS-EVENT returns a mask of any interrupts
; that have just occured.

(define (process-events)
  (let loop ()
    (receive (type channel status)
	(get-next-event)
      (set! *pending-interrupts*
	    (bitwise-ior (process-event type channel status)
			 *pending-interrupts*))
      (if (not (eq? type (enum events no-event)))
	  (loop)))))

; Do whatever processing the event requires.

(define (process-event event channel status)
  (cond ((eq? event (enum events alarm-event))
	 ;; Save the interrupted template for use by profilers.
	 ;; Except that we have no more templates and no more profiler.
	 ;(if (false? *interrupted-template*)
	 ;    (set! *interrupted-template* *template*))
	 (interrupt-bit (enum interrupt alarm)))
	((eq? event (enum events keyboard-interrupt-event))
	 (interrupt-bit (enum interrupt keyboard)))
	((eq? event (enum events io-completion-event))
	 (enqueue-channel! channel status)
	 (interrupt-bit (enum interrupt i/o-completion)))
	((eq? event (enum events os-signal-event))
	 (interrupt-bit (enum interrupt os-signal)))
	((eq? event (enum events no-event))
	 0)
	((eq? event (enum events error-event))
	 (error-message "OS error while getting event")
	 (error-message (error-string status))
	 0)
	(else
	 (error-message "unknown type of event")
	 0)))

; Return a bitmask for INTERRUPT.

(define (interrupt-bit interrupt)
  (shift-left 1 interrupt))

