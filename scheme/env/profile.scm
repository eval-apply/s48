;;;;;; Rudimentary Scheme48 profiler                     -*- Scheme -*-

;;; Taylor Campbell wrote parts of the original code; he has placed them in the public domain.

(define-command-syntax 'profile "<command>" "profile execution"
                       '(command))

;; profiling information for each template
(define-record-type profinfo :profinfo
  (make-profinfo template callers totaltime occurs)
  profinfo?
  (template  profinfo-template)                           ; scheme code template
  (callers   profinfo-callers   profinfo-set-callers!)    ; table of callerinfos
  (totaltime profinfo-totaltime profinfo-set-totaltime!)  ; comu self independent of caller
  (occurs    profinfo-occurs    profinfo-set-occurs!)
  (tself     profinfo-tself     profinfo-set-tself!)
  (tchild    profinfo-tchild    profinfo-set-tchild!)
  )

;; hash function for callers table in profiling information
(define (profinfo-id pi)
  (template-id (profinfo-template pi)))

;; profiling data for template when being called by CALLER
(define-record-type callerinfo :callerinfo
  (make-callerinfo caller calls totaltime)
  callerinfo?
  (caller    callerinfo-caller)                               ; caller profinfo
  (calls     callerinfo-calls     callerinfo-set-calls!)      ; number of calls
  (totaltime callerinfo-totaltime callerinfo-set-totaltime!)) ; total time run

;; represents a stack entry (while profiling)
(define-record-type stackentry :stackentry
  (make-stackentry cont template calls firstseen seen)
  stackentry?
  (cont      stackentry-cont      stackentry-set-cont!)       ; scheme continuation
  (template  stackentry-template  stackentry-set-template!)   ; scheme code template
  (calls     stackentry-reccalls  stackentry-set-reccalls!)   ; recursive calls
  (firstseen stackentry-firstseen stackentry-set-firstseen!)  ; run-time first seen this entry
  (seen      stackentry-seen      stackentry-set-seen!))      ; seen this time? (boolean)


;;; Miscellaneous global stuff

(define *interrupt-time* #f)            ; (theoretical) ms between interrupts

(define *start-time* #f)                
(define *end-time* #f)

(define *saved-interrupt-handler* #f)   ; non-profiler interrupt handler
(define *profiler-continuation* #f)     ; profiler's top continuation

(define *profiler-lock* (make-lock))    ; exclusive lock for interrupt handler

(define *samples* #f)                   ; number of samples taken
(define *templates* #f)                 ; table of profinfo records

(define *profiler-lastrun* #f)          ; run-time of profiler runs
(define *profiler-thisrun* #f)

(define (run-time)
  (primitives:time (enum time-option run-time) #f))

(define interrupt/alarm (enum interrupt alarm))

(define (profiler-continuation? cont)
  (eq? cont *profiler-continuation*))

(define (get-profinfo stack-entry)
  (if stack-entry
      (table-ref *templates* (stackentry-template stack-entry))
      #f))

;;; MAIN

(define (profile command)
    (profile-and-display (if (eq? (car command) 'run)
                             (eval `(LAMBDA () ,(cadr command))
                                   (environment-for-commands))
                             (lambda () (execute-command command)))
                         (current-output-port)))


(define (profile-and-display thunk
			     port)
  (calculate-tick-rate!)
  (receive results (do-profile thunk)
	   (propagate-times)
	   (display-result-overview port)
	   (display-flat-result port)
	   (newline port)
	   (display-tree-result port)
	   (apply values results)))

(define (do-profile thunk)
  (set! *start-time* (run-time))
  (set! *last-stack* #f)
  (set! *profiler-thisrun* #f)
  (set! *profiler-lastrun* #f)
  (set! *templates* (make-table template-id))
  (release-lock *profiler-lock*)
  (dynamic-wind
      (lambda ()
	(install-profiler-interrupt-handler)
	(start-periodic-interrupts!)
	)
      (lambda ()
	(primitive-cwcc
	 (lambda (profiler-cont)
	   (set! *profiler-continuation* profiler-cont)
	   (set! *samples* 0)
	   (thunk))))             ; run program!
      (lambda ()
	(set! *profiler-continuation* #f)
	(stop-periodic-interrupts!)
	(uninstall-profiler-interrupt-handler)))
  (set! *end-time* (run-time))
  
 ; (set! *profiler-lastrun* *profiler-thisrun*)
 ; (set! *profiler-thisrun* (run-time)) ; we cap this here, profiler could run some time
  (post-process-stack! *last-stack*)) ; process the last stack trace


;;; INTERRUPT HANDLING

(define (fib x)
  (if (< x 2)
      1
      (+ (fib (- x 1)) (fib (- x 2)))))

;; TODO: calculate useful time, if possible...
(define calculate-tick-rate!
  (lambda ()
    (let ((start-time (run-time)))
      (fib 30)  ; chosen more or less at random.
      (let ((end-time (run-time)))
	(set! *interrupt-time* (quotient (- end-time start-time) 50))
	(set! *interrupt-time* 50) ; REMOVE then
	(display *interrupt-time*)
	(display "ms interrupt time")
      (newline)))))

(define (start-periodic-interrupts!)
  (schedule-interrupt *interrupt-time*))

(define (stop-periodic-interrupts!)
  (schedule-interrupt 0))

(define (install-profiler-interrupt-handler)
    (set! *saved-interrupt-handler* (get-interrupt-handler interrupt/alarm))
    (set-interrupt-handler! interrupt/alarm handle-profiler-interrupt))

(define (uninstall-profiler-interrupt-handler)
  (let ((handler *saved-interrupt-handler*))
    (set! *saved-interrupt-handler* #f)
    (set-interrupt-handler! interrupt/alarm handler)))


(define (handle-profiler-interrupt template enabled)
  ;; After Scheme48 1.0's architectural changes TEMPLATE argument has
  ;; always been just #f.

  ;; first thing is getting the continuation, in tail position to prevent
  ;; capturing profiler functions
  (primitive-cwcc
   (lambda (cont)
     (if (maybe-obtain-lock *profiler-lock*)
	 (begin
	   (*saved-interrupt-handler* template enabled) ; thread system, ...
	   (if *profiler-continuation* (record-continuation! cont))
	   (release-lock *profiler-lock*)
	   ;; HACK: To override thread system interrupt scheduling, may cause
	   ;;       extreme performance loss on thread system?
	   (start-periodic-interrupts!))))))



;;; DISPLAY DATA

;; display s right-aligned in field with width w
(define (display-w s w port)
  (if (< (string-length s) w)
      (begin
	(display " " port)
	(display-w s (- w 1) port))
      (display s port)))

;; display number right-aligned in field with width w
(define (display-w-nr n w port)
  (if n
      (display-w (number->string (round n)) w port)
      (display-w "?" w port)))

;; same as above, but do not display 0 values
(define (display-w-nr-nz n w port)
  (if (= n 0)
      (display-w "" w port)
      (display-w-nr n w port)))

(define (display-sep-nrs nr1 nr2 sep w port)
  (display-w
   (string-append (number->string nr1) sep (number->string nr2))
   w
   port))

(define (display-sep-unequal-nrs nr1 nr2 sep w port)
  (display-w
   (if (= nr1 nr2)
       (number->string nr1)
       (string-append (number->string nr1) sep (number->string nr2)))
   w
   port))

(define (display-sep-nz-nrs nr1 nr2 sep w port)
  (display-w
   (if (> nr2 0)
       (string-append (number->string nr1) sep (number->string nr2))
       (number->string nr1))
   w
   port))
  
;; general profiling data
(define (display-result-overview port)
  (newline port)
  (newline port)
  
  (display "** Real run time: " port)
  (display (total-run-time) port)
  (display "ms" port)
  (newline port)
  (display "** Sampled run time: " port)
  (display (round (total-sampled-run-time)) port)
  (display "ms" port)
  (newline port)
  
  (display "** Samples: " port)
  (display *samples* port)
  (newline port))

(define (display-flat-result port)
  
  (display "** Flat result (times in ms): " port)
  (newline port)

  ;; gprof:
  ;;      %   cumulative   self              self     total           
  ;;   time   seconds   seconds    calls  ms/call  ms/call  name

  ; first caption row
  (display-w "" 7 port)
  (display-w "meas" 7 port)
  (display-w "meas" 7 port)
  (display-w "hist" 7 port)
  (display-w "hist" 7 port)
  (display-w "" 7 port)
  (display-w "" 14 port)
  (display-w "" 8 port)
  (display-w "" 5 port)
  (newline)
  
  
  ; third caption row
  (display-w "time" 7 port)
  (display-w "cumu" 7 port)
  (display-w "self" 7 port)
  (display-w "cumu" 7 port)
  (display-w "self" 7 port)
  (display-w "hist" 7 port)
  (display-w "calls" 14 port)
  (display-w "ms/call" 9 port)
  (display-w "name" 5 port)
  (newline)
  
  (table-walk (lambda (template profinfo)
		(display-profinfo-flat profinfo port)
		(newline port))
	      *templates*)
  )

;; display data "gprof call graph"-like
(define (display-tree-result port)
  
  (display "** Tree result (times in ms): " port)
  (newline port)

;  index % time    self  children    called     name
  
  (display-w "" 7 port)
  (display-w "meas" 7 port)
  (display-w "hist" 7 port)
  (display-w "hist" 7 port)
  (display-w "" 7 port)
  (display-w "" 12 port)
  (display-w "" 5 port)
  (newline)
  
  (display-w "time" 7 port)
  (display-w "time" 7 port)
  (display-w "" 7 port)
  (display-w "" 7 port)
  (display-w "" 7 port)
  (display-w "" 12 port)
  (display-w "" 5 port)
  (newline)
  
  (display-w "share" 7 port)
  (display-w "total" 7 port)
  (display-w "self" 7 port)
  (display-w "child" 7 port)
  (display-w "hist" 7 port)
  (display-w "calls" 12 port)
  (display-w "name" 5 port)
  (newline)

  
  (table-walk (lambda (template profinfo)
		(display-profinfo-tree profinfo port)
		(display "==========================================================================================" port)
		(newline port))
	      *templates*)
  )

;; Are there no functions for this!?
(define (number-as-percent-string nr)
  (if nr
      (let* ((expanded (truncate (* 10000 nr)))
	     (afterdot (round (inexact->exact (modulo expanded 100))))
	     (full     (round (inexact->exact (quotient (- expanded afterdot) 100)))))
	(string-append (number->string full)
		       "."
		       (number->string afterdot)
		       "%"))
      "?"))

(define (save/ a b)
  (if (= b 0)
      #f
      (/ a b)))

(define (display-profinfo-flat profinfo port)

  (let* ((template     (profinfo-template            profinfo))
	 (occurs       (profinfo-occurs              profinfo))
	 (callers      (profinfo-callers             profinfo))
	 (calls        (profinfo-total-calls         profinfo))
	 (reccalls     (profinfo-total-reccalls      profinfo))
	 (nonreccalls  (profinfo-total-nonreccalls   profinfo))
	 (totaltime    (profinfo-real-totaltime      profinfo))
	 (selftime     (profinfo-selftime            profinfo))
	 (tself        (profinfo-tself               profinfo))
	 (tchild       (profinfo-tchild              profinfo))
	 (ttotal       (+ tself tchild))
	 (timeshare    (save/ selftime (total-sampled-run-time)))
	 (ms/call      (save/ totaltime calls)))

    (display-w (number-as-percent-string timeshare)  7 port)
    (display-w-nr totaltime 7 port)
    (display-w-nr selftime 7 port)
    (display-w-nr (occurs->ms ttotal) 7 port)
    (display-w-nr (occurs->ms tself) 7 port)
    (display-w-nr occurs 7 port)
    (display-sep-nz-nrs nonreccalls reccalls "+" 14 port)
    (display-w-nr ms/call 9 port)
   
    (display " " port)
    (display-location template port))) ; name

(define (display-profinfo-tree primary-pi port)
  (let* ((template     (profinfo-template            primary-pi))
	 (callers      (profinfo-callers             primary-pi))
	 (occurs       (profinfo-occurs              primary-pi))
	 (calls        (profinfo-total-calls         primary-pi))
	 (reccalls     (profinfo-total-reccalls      primary-pi))
	 (nonreccalls  (profinfo-total-nonreccalls   primary-pi))
	 (tself        (profinfo-tself               primary-pi))
	 (tchild       (profinfo-tchild              primary-pi))
	 (totaltime    (profinfo-real-totaltime      primary-pi))
	 (timeshare    (save/ totaltime (total-sampled-run-time)))
	 (ms/call      (save/ totaltime calls)))

    ;; print parents
    (if (= (table-size callers) 0)
	(begin (display-w " " 47 port) (display "      <spontaneous>" port) (newline))
	(table-walk (lambda (caller-pi cinfo)
		      (if (not (eq? caller-pi primary-pi))
			  (let* ((template  (profinfo-template caller-pi))
				 (occurs    (profinfo-occurs   caller-pi))
				 (calls     (callerinfo-calls      cinfo))
				 (totaltime (callerinfo-totaltime  cinfo))
				 (share     (/ calls nonreccalls))
				 (tself-share  (* tself  share))  ; TODO: correct when recursive function?
				 (tchild-share (* tchild share)))

			    (display-w "" 7 port)
			    (display-w-nr totaltime 7 port)
			    (display-w-nr (occurs->ms tself-share) 7 port)
			    (display-w-nr (occurs->ms tchild-share) 7 port)
			    (display-w-nr occurs 7 port)
			    (display-sep-nrs calls nonreccalls "/" 12 port)
			    
			    (display "      " port)
			    (display-location template port)
			    (newline))))
		    callers))
    
    ;; print primary line
    (display-w (number-as-percent-string timeshare)  7 port)
    (display-w-nr totaltime 7 port)
    (display-w-nr (occurs->ms tself) 7 port)
    (display-w-nr (occurs->ms tchild) 7 port)
    (display-w-nr occurs 7 port)
    (display-sep-nz-nrs nonreccalls reccalls "+" 12 port)
    
    (display "   " port)
    (display-location template port)
    (newline)
    
    ;; print children
    (for-each (lambda (called-pi)
		(if (not (eq? called-pi primary-pi))
		    (let* ((template     (profinfo-template          called-pi))
			   (occurs       (profinfo-occurs            called-pi))
			   (cinfo        (profinfo-get-callerinfo    called-pi primary-pi))
			   (nonreccalls  (profinfo-total-nonreccalls called-pi))
			   (tself        (profinfo-tself             called-pi))
			   (tchild       (profinfo-tchild            called-pi))
			   (calls        (callerinfo-calls           cinfo))
			   (totaltime    (callerinfo-totaltime       cinfo))
			   (share        (/ calls nonreccalls))
			   (tself-share  (* tself  share))  ; TODO: correct when recursive function?
			   (tchild-share (* tchild share)))
		      
		      (display-w "" 7 port)
		      (display-w-nr totaltime 7 port)
		      (display-w-nr (occurs->ms tself-share) 7 port)
		      (display-w-nr (occurs->ms tchild-share) 7 port)
		      (display-w-nr occurs 7 port)
		      (display-sep-nrs calls nonreccalls "/" 12 port)
		      
		      (display "      " port)
		      (display-location template port)
		      (newline))))
	      (profinfo-calls primary-pi))))


;; displays functionname and file of a code template
(define (display-location template port)
  (let ((ddata (template-debug-data template)))
    (if (not (and (debug-data? ddata)
		  (pair? (debug-data-names ddata))))
	(write `(anonymous ,(if (debug-data? ddata)
				(debug-data-uid ddata)
				ddata))
	       port)
	(let loop ((names (debug-data-names ddata)))
	  (write (or (car names) '(anonymous)) port)
	  (if (pair? (cdr names))
	      (begin (display " in " port)
		     (loop (cdr names))))))))
  
;;; DATA CALCULATION

(define (occurs->ms occs)
  (round (/ (* occs (total-sampled-run-time))
	    *samples*)))

(define (total-run-time)
    (if (and *start-time*
	     *end-time*)
	(- *end-time* *start-time*)
	#f))

(define (total-sampled-run-time)
    (let ((tsrt 0))
      (table-walk (lambda (template profinfo)
		    (set! tsrt (+ tsrt (profinfo-selftime profinfo))))
		  *templates*)
      tsrt))

(define (profinfo-real-totaltime pi)
  (let ((t (profinfo-totaltime pi)))
    (if t t 0)))


(define (profinfo-get-callerinfo called caller)
  (let ((caller-list (profinfo-callers called)))
    (table-ref caller-list caller)))

;; returns a list of all profinfos the function calls
(define (profinfo-calls caller)
  (let ((lst '()))
    (table-walk (lambda (template profinfo)
		  (if (profinfo-get-callerinfo profinfo caller)
		      (set! lst (cons profinfo lst))))
		*templates*)
    (remove-duplicates lst)))

(define (profinfo-total-calls-done caller)
  (let ((cnt 0))
    (for-each (lambda (pi)
		(let ((cinfo (profinfo-get-callerinfo pi caller)))
		  (set! cnt (+ cnt (callerinfo-calls cinfo))))
		)
	      (profinfo-calls caller))
    cnt))
  
;; calculates the time spent in the function itself
;; by subtracting the time spent in childrens, when called by this function
(define (profinfo-selftime caller-pi)
  (let ((selftime (profinfo-real-totaltime caller-pi))
	(called-list (profinfo-calls caller-pi)))
    (for-each (lambda (called-pi)
		(if (not (eq? called-pi caller-pi)) ; recursive count to self
		    (let* ((cinfo (profinfo-get-callerinfo called-pi caller-pi))
			   (ci-tt (callerinfo-totaltime cinfo)))
		      (set! selftime (- selftime ci-tt)))))
	      called-list)
    selftime))

;; total non-recursive calls of this function
(define (profinfo-total-nonreccalls pi)
  (- (profinfo-total-calls pi)
     (profinfo-total-reccalls pi)))

;; total recursive calls of this function
(define (profinfo-total-reccalls pi)
  (let* ((cs (profinfo-callers pi))
	 (info (table-ref cs pi)))
    (if info
	(callerinfo-calls info)
	0)))

;; total number of calls (with recursive)
(define (profinfo-total-calls pi)
  (let ((cs    (profinfo-callers pi))
	(total 0))
    (table-walk (lambda (key cinfo)
		  (set! total (+ total (callerinfo-calls cinfo))))
		cs)
    total))

; returns the callinfo (calls, totaltime) for CALLED being called by CALLER
(define (profinfo-get-callerinfo called caller)
  (let ((caller-table (profinfo-callers called)))
    (table-ref caller-table caller)))

(define (propagate-time-of-child called-pi)
  (let ((caller-list (profinfo-callers           called-pi))
	(totalcalls  (profinfo-total-nonreccalls called-pi))
	(occs        (profinfo-occurs            called-pi)))
    (table-walk (lambda (caller-pi cinfo)
		  (if (not (eq? caller-pi
				called-pi))
		      (let* ((thiscalls (callerinfo-calls cinfo))
			     (share (round (/ (* occs thiscalls)
					      totalcalls))))
			; (display "share of ")
			; (display (profinfo-template caller-pi))
			; (display ": ")
			; (display share)
			; (display "/")
			; (display occs)
			; (newline)
			(profinfo-set-tchild! caller-pi
					      (+ (profinfo-tchild caller-pi)
						 share)))))
		caller-list)))

(define (propagate-finish pi)
  (let ((self (- (profinfo-occurs pi)
		 (profinfo-tchild pi))))
  (profinfo-set-tself! pi (if (< self 0) 0 self)))) ; bug

(define (propagate-times)
  ;; zero out
  (table-walk (lambda (template profinfo)
		(profinfo-set-tself! profinfo 0)
		(profinfo-set-tchild! profinfo 0))
	      *templates*)
  ;; propagate
  (table-walk (lambda (template profinfo)
		(propagate-time-of-child profinfo))
	      *templates*)
  ;; finish
  (table-walk (lambda (template profinfo)
		(propagate-finish profinfo))
	      *templates*)
  )


;;; RECORDING DATA (while target is running)

(define *last-stack* #f)  ; stack at last interrupt
(define *cur-stack* #f)   ; stack at this interrupt (to be built)


(define (last-stackentry)
    (if (null? *cur-stack*)
	#f
	(car *cur-stack*)))


;; adds one call to the profinfo of CALLED
(define (profinfo-count-call called caller)
  (if (and called caller)
      (let ((cs (profinfo-callers called)))
	(cond ((table-ref cs caller)
	       => (lambda (ci)
		    (callerinfo-set-calls! ci (+ 1 (callerinfo-calls ci)))))
	      (else
	       (table-set! cs caller (make-callerinfo caller 1 0)))))))


;; duplicate from sort/vector-util
(define (has-element list index)
  (cond
   ((zero? index)
    (if (pair? list)
	(values #t (car list))
	(values #f #f)))
   ((null? list)
    (values #f #f))
   (else
    (has-element (cdr list) (- index 1)))))

(define (list-ref-or-default list index default)
  (if list
      (call-with-values
	  (lambda () (has-element list index))
	(lambda (has? maybe)
	  (if has?
	      maybe
	      default)))
      default))

(define set-unseen-all!
  (lambda ()
    (and *last-stack*
	 (for-each (lambda (se)
		     (stackentry-set-seen! se #f))
		   *last-stack*))))

(define (seen? stackentry)
  (and stackentry
       (stackentry-seen stackentry)))
  
(define (seen! old-se se)
  (if old-se
      (begin
	(stackentry-set-firstseen! se (stackentry-firstseen old-se))
	(stackentry-set-seen! old-se #t))))

(define (time-passed se)
  (let* ((firstseen (stackentry-firstseen se))
	 (mid (if *profiler-lastrun*
		  (- *profiler-thisrun*
		     *profiler-lastrun*)
		  0))
	 (passed (- *profiler-thisrun*
		    firstseen)))
    (- passed (/ mid 2))))

;; process the stack entries that have the seen "bit" not set.
;; calculate the approximated run time
(define (post-process-stack! stack)
  (if stack
      (let loop ((stack  stack)
		 (caller-se #f))
	(if (not (null? stack))
	    (let* ((called-se (car stack))
		   (called-pi (get-profinfo called-se))
		   (reccalls  (stackentry-reccalls called-se)))
	      (if (= reccalls 0)
		  (begin
		    ;; record occurance
		    (profinfo-set-occurs! called-pi
					  (+ (profinfo-occurs called-pi) 1))
		    
		    ;; process unseen
		    (if (not (seen? called-se))
			(let* ((caller-pi  (get-profinfo caller-se))
			       (cinfo      (profinfo-get-callerinfo called-pi caller-pi))
			       (pi-tt      (profinfo-totaltime called-pi))
			       (timepassed (time-passed called-se)))
			  (profinfo-set-totaltime! called-pi (+ pi-tt timepassed))
			  (if cinfo
			      (callerinfo-set-totaltime! cinfo
							 (+ (callerinfo-totaltime cinfo)
							    timepassed)))))))
	      (loop (cdr stack)
		    called-se))))))


(define (record-call! caller-se called-se)
  (let* ((caller-template (if caller-se
			     (stackentry-template caller-se)
			     #f))
	 (called-template (stackentry-template called-se))
	 (caller-profinfo (get-profinfo caller-se))
	 (called-profinfo (get-profinfo called-se)))
    
    ;; if not profiled template yet, create one
    (if (not called-profinfo)
	(begin
	  (set! called-profinfo
		(make-profinfo called-template
			       (make-table profinfo-id)
			       0
			       0))
	  (table-set! *templates* called-template called-profinfo)))

    ;; if we know the caller, count it
    (profinfo-count-call called-profinfo caller-profinfo)))

(define (compare-continuation-args c1 c2)
  (let ((ac (continuation-arg-count c1))
	(ac2 (continuation-arg-count c2)))
    (if (= ac ac2)
	(let loop ((i 1))
	  (if (< i ac)
	      (if (eq? (continuation-arg c1 i)
		       (continuation-arg c2 i))
		  (loop (+ i 1))
		  #f)
	      #t))
	#f)))

(define (process-stack-traces!)
  ;; go from bottom to top and count calls
  (let loop ((pos 0)
	     (stack *cur-stack*)
	     (caller-se #f)
	     (diff-found #f))
    (if (not (null? stack))
	(let ((new-se (car stack)))
	  
	  ;; compare with last stack
	  (let ((old-se (list-ref-or-default *last-stack* pos #f))
		(rcdcall #f))
	    (if (or (not old-se)  ; not on old stack
		    diff-found)
		(begin
		  (set! rcdcall #t)
		  (set! diff-found #t))
		(if (not (eq? (stackentry-template old-se)        ; other template => other func
			      (stackentry-template new-se)))
		    (begin
		      (set! rcdcall #t)
		      (set! diff-found #t))
		    ;; same template...
		    (let ((old-cont (stackentry-cont old-se))
			  (new-cont (stackentry-cont new-se)))
		      (if (not (eq? old-cont new-cont))    ; other continuation, something changed
			  (begin
			    (set! diff-found #t) ; remember change upwards...
			    (if (and (eq? (continuation-pc old-cont)   ; same pc and arg-count, else
					  (continuation-pc new-cont))  ; may be just other place in func
				     (eq? (continuation-code old-cont)
					  (continuation-code new-cont))
				     (compare-continuation-args old-cont new-cont)) ; detects most tailcalls
				  (set! rcdcall #t)))))))
	   
	    (if rcdcall
		(record-call! caller-se new-se)
		(seen! old-se new-se))
	    
	    (loop (+ pos 1)
		  (cdr stack)
		  new-se
		  diff-found)))))
  
  (post-process-stack! *last-stack*))


(define (record-template! cont template)
  (if template
      (begin
	(let ((lse (last-stackentry))
	      (nse (make-stackentry cont template 0 (run-time) #f)))
	  
	  (if (and lse
		   (eq? (stackentry-template lse)
			template))
	      (stackentry-set-reccalls! lse
				     (+ 1 (stackentry-reccalls lse))))
	  
	  ;; consider recursion (disabled)
	  (set! *cur-stack*
		(cons nse *cur-stack*))
	  ))))


;; main record function (called from interrupt handler)
(define (record-continuation! cont)

;;  display ticks
;  (display (- (run-time) *start-time*))
;  (display "ms: rec")
;  (newline)
  
  ;; init
  (set! *cur-stack* '())
  (set! *profiler-lastrun* *profiler-thisrun*)
  (set! *profiler-thisrun* (run-time)) ; we cap this here, profiler could run some time
  (set! *samples* (+ *samples* 1))
   
  ;; record the current template
  (record-template! cont (find-template cont))

  ;; decent until we reach our own continuation
  (let loop ((cont (continuation-cont cont)))
    (if (and cont
	     (not (profiler-continuation? cont)))
	(let ((parent (continuation-cont cont)))
		(record-template! cont (continuation-template cont))
		(loop parent))))
  
  ;; process the stack built above
  (if (not (null? *cur-stack*))
      (begin
	(process-stack-traces!)
  
	;; save old stack
	(set! *last-stack* *cur-stack*)
	(set-unseen-all!))))



;; searchs the (moving?) template in the continuation
(define (find-template cont)
  (let ((len (continuation-length cont)))
    (let loop ((i 0))
      (and (< i len)
           (let ((elt (continuation-ref cont i)))
             (if (template? elt)
                 elt
                 (loop (+ i 1))))))))
