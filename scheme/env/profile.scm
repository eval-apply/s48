;;;;;; Rudimentary Scheme48 profiler                     -*- Scheme -*-

;;; Taylor Campbell wrote parts of the original code; he has placed them in the public domain.

(define-command-syntax 'profile "<command>" "profile execution"
                       '(command))

;; profiling information for each template
(define-record-type profinfo :profinfo
  (make-profinfo template callers occurs hist)
  profinfo?
  (template  profinfo-template)                           ; scheme code template
  (callers   profinfo-callers   profinfo-set-callers!)    ; table of callerinfos
  (occurs    profinfo-occurs    profinfo-set-occurs!)
  (hist      profinfo-hist      profinfo-set-hist!)
  (tchild    profinfo-tchild    profinfo-set-tchild!)
  (toporder  profinfo-toporder  profinfo-set-toporder!)
  (dfn       profinfo-dfn       profinfo-set-dfn!)        ; depth-first number
  (cycle     profinfo-cycle     profinfo-set-cycle!)
  )

;; hash function for callers table in profiling information
(define (profinfo-id pi)
  (template-id (profinfo-template pi)))

(define-record-type cycleinfo :cycleinfo
  (make-cycleinfo number members)
  cycleinfo?
  (number  cycleinfo-number)                                 ; consecutive numbering
  (members cycleinfo-members cycleinfo-set-members!)         ; member profinfos
  (tchild  cycleinfo-tchild  cycleinfo-set-tchild!)
  )

(define *cycles* #f)

;; profiling data for template when being called by CALLER
(define-record-type callerinfo :callerinfo
  (make-callerinfo caller calls)
  callerinfo?
  (caller    callerinfo-caller)                            ; caller profinfo
  (calls     callerinfo-calls  callerinfo-set-calls!)      ; number of calls
  (tself     callerinfo-tself  callerinfo-set-tself!)      ; time spent in called self
  (tchild    callerinfo-tchild callerinfo-set-tchild!))    ; time spent in children of called

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

;; debug display
(define (ddisplay x)
;  (display x)
  #f)

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
	   (depth-numbering)
	   (propagate-times)
	   (display-result-overview port)
	   (if (> *samples* 0)
	       (begin
		 (display-flat-result port)
		 (newline port)
		 (display-tree-result port))
	       (display "No data collected!\n" port))
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
  
  (display "** Samples: " port)
  (display *samples* port)
  (newline port)
  (newline port))

(define (display-flat-result port)
  
  (display "** Flat result (times in ms): " port)
  (newline port)
  (newline port)
  
  ;; gprof:
  ;;      %   cumulative   self              self     total           
  ;;   time   seconds   seconds    calls  ms/call  ms/call  name
  
  (display-w "time" 7 port)
  (display-w "cumu" 7 port)
  (display-w "self" 7 port)
  (display-w "(hist)" 12 port)
  (display-w "calls" 14 port)
  (display-w "ms/call" 9 port)
  (display-w "name" 7 port)
  (newline port)

  ;; sort and print
  (let ((lst '())) 
    (table-walk (lambda (template profinfo)
		  (set! lst (cons profinfo lst)))
		*templates*)
    (set! lst (list-sort (lambda (a b) 
			   (>= (profinfo-hist a)
			       (profinfo-hist b)))
			 lst))
    (for-each (lambda (profinfo)
		(display-profinfo-flat profinfo port)
		(newline port))
	      lst)))

;; display data "gprof call graph"-like
(define (display-tree-result port)
  
  (display "** Tree result (times in ms): " port)
  (newline port)

  (newline port)
  (display-w "i" 3 port)
  (display-w "time" 8 port)
  (display-w "self" 7 port)
  (display-w "child" 7 port)
  (display-w "(hist)" 12 port)
  (display-w "calls" 12 port)
  (display-w "name" 7 port)
  (newline port)

  ;; sort and print
  (let ((sorted-templates 
	    (get-sorted-templates (lambda (pi) (- (profinfo-occurs pi)))))
	(toporder 0))
    (for-each (lambda (profinfo)
		(profinfo-set-toporder! profinfo toporder)
		(set! toporder (+ toporder 1)))
	      sorted-templates)
    (for-each (lambda (profinfo)
		(display-profinfo-tree profinfo port)
		(display "==========================================================================================" port)
		(newline port))
	      sorted-templates))
  
  (for-each (lambda (cyc)
	      (display-cycle-tree cyc port))
	    *cycles*)
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
	 (calls        (profinfo-total-calls         profinfo))
	 (reccalls     (profinfo-total-reccalls      profinfo))
	 (nonreccalls  (profinfo-total-nonreccalls   profinfo))
	 (hist         (profinfo-hist                profinfo))
	 (timeshare    (save/ hist *samples*))
	 (ms/call      (save/ (occurs->ms occurs) calls)))

    (display-w (number-as-percent-string timeshare)  7 port)
    (display-w-nr (occurs->ms occurs) 7 port)
    (display-w-nr (occurs->ms hist) 7 port)
    (display-sep-nz-nrs occurs hist "+" 12 port)
    (display-sep-nz-nrs nonreccalls reccalls "+" 14 port)
    (display-w-nr ms/call 9 port)
   
    (display "   " port)
    (display-location template port) ; name
    ))

(define (display-cycle-tree cycleinfo port)
  (let* ((number    (cycleinfo-number    cycleinfo))
	 (members   (cycleinfo-members   cycleinfo))
	 (callers   (cycleinfo-called-from cycleinfo))
	 (intcalls  (cycleinfo-internal-calls cycleinfo))
	 (extcalls  (cycleinfo-external-calls cycleinfo))
	 (hist      (cycleinfo-hist     cycleinfo))
	 (tchild    (cycleinfo-tchild    cycleinfo))
	 (fromextcalls     (sumup-calls-int/ext-cycle cycleinfo #f))
	 (ttotal    (+ hist tchild))
	 (timeshare (save/ ttotal *samples*)))

    ;; print cycle callers
    (for-each
     (lambda (caller-pi)
       (let* ((calls        (cycleinfo-calls-from  cycleinfo caller-pi))
	      (tchild       (/ (* tchild calls) fromextcalls)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr (occurs->ms hist) 7 port)
	 (display-w-nr (occurs->ms tchild) 7 port)
	 (display-w "" 12 port)
	 (display-sep-nz-nrs calls fromextcalls "/" 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name caller-pi port)
	 (newline port)))
     callers)
    
    
    ;; print primary line
    (display-w-nr number 3 port)
    (display-w (number-as-percent-string timeshare) 8 port)
    (display-w-nr (occurs->ms hist) 7 port)
    (display-w-nr (occurs->ms tchild) 7 port)
    (display-w "" 12 port)
    (display-sep-nz-nrs extcalls intcalls "+" 12 port)
    
    (display "   " port)
    (display "<cycle " port)
    (display number port)
    (display " as a whole>" port)
    (newline port)

    ;; print cycle members
    (for-each
     (lambda (member-pi)
       (let* ((intcalls     (calls-int/ext-cycle cycleinfo member-pi #t))
	      (occurs       (profinfo-occurs              member-pi))
	      (hist         (profinfo-hist                member-pi))
	      (tchild       (cycleinfo-tchild-member      cycleinfo member-pi)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr (occurs->ms hist) 7 port)
	 (display-w-nr (occurs->ms tchild) 7 port)
	 (display-w-nr occurs 12 port)
	 (display-w-nr intcalls 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name member-pi port)
	 (newline port)))
     members)
    
    ;; print functions called out of the cycle
    (for-each
     (lambda (called-pi)
       (let* ((nonreccalls  (profinfo-total-nonreccalls   called-pi))
	      (calls        (cycleinfo-calls-to cycleinfo called-pi)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr 0 7 port)
	 (display-w-nr 0 7 port)
	 (display-w "" 12 port)
	 (display-sep-nrs calls nonreccalls "/" 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name called-pi port)
	 (newline port)))
     (cycleinfo-called-externals cycleinfo))))



;; TODO: clean up unused variables
(define (display-profinfo-tree primary-pi port)
  (let* ((template     (profinfo-template            primary-pi))
	 (toporder     (profinfo-toporder            primary-pi))
	 (dfn          (profinfo-dfn                 primary-pi))
	 (callers      (profinfo-callers             primary-pi))
	 (occurs       (profinfo-occurs              primary-pi))
	 (calls        (profinfo-total-calls         primary-pi))
	 (reccalls     (profinfo-total-reccalls      primary-pi))
	 (nonreccalls  (profinfo-total-nonreccalls   primary-pi))
	 (upcalls      (profinfo-total-upcalls       primary-pi))
	 (hist         (profinfo-hist                primary-pi))
	 (tchild       (profinfo-tchild              primary-pi))
	 (primary-cyc  (profinfo-cycle               primary-pi))
	 (timeshare    (save/ occurs *samples*))
	 (ms/call      (save/ (occurs->ms occurs) calls)))
    
    ;; print parents
    (if (= (table-size callers) 0)
	(begin (display-w " " 49 port) (display "      <spontaneous>" port) (newline))
	(table-walk
	 (lambda (caller-pi cinfo)
	   (if (neq? caller-pi primary-pi)
	       (let* ((template     (profinfo-template caller-pi))
		      (dfn          (profinfo-dfn      caller-pi))
		      (occurs       (profinfo-occurs   caller-pi))
		      (caller-cyc   (profinfo-cycle    caller-pi))
		      (calls        (callerinfo-calls  cinfo))
		      (share        (/ calls upcalls))
		      (tself-share  (* hist   share))  ; TODO: correct when recursive function?
		      (tchild-share (* tchild share)))
		 (display-w "" 3 port)
		 (display-w "" 8 port)

		 (if (neq? caller-cyc primary-cyc)
		     (begin
		       (display-w-nr (occurs->ms tself-share) 7 port)
		       (display-w-nr (occurs->ms tchild-share) 7 port))
		     (begin
		       (display-w "" 7 port)
		       (display-w "" 7 port)))
		     
		 (display-w-nr occurs 12 port)
		 (display-sep-nrs calls nonreccalls "/" 12 port)
		 
		 (display "      " port)
		 (display-profinfo-name caller-pi port)
		 (newline port))))
	 callers))
    
    ;; print primary line
    (display-w-nr toporder 3 port)
    (display-w (number-as-percent-string timeshare) 8 port)
    (display-w-nr (occurs->ms hist) 7 port)
    (display-w-nr (occurs->ms tchild) 7 port)
    (display-sep-nz-nrs occurs hist "+" 12 port)
    (display-sep-nz-nrs nonreccalls reccalls "+" 12 port)
    
    (display "   " port)
    (display-profinfo-name primary-pi port)
    (newline port)
    
    ;; print children
    (for-each
     (lambda (called-pi)
       (if (not (eq? called-pi primary-pi))
	   (let* ((template     (profinfo-template            called-pi))
		  (dfn          (profinfo-dfn                 called-pi))
		  (occurs       (profinfo-occurs              called-pi))
		  (calls        (number-of-calls   primary-pi called-pi))
		  (nonreccalls  (profinfo-total-nonreccalls   called-pi))
		  (upcalls      (profinfo-upcalls  primary-pi called-pi))
		  (hist         (profinfo-hist                called-pi))
		  (tchild       (profinfo-tchild              called-pi))
		  (called-cyc   (profinfo-cycle               called-pi))
		  (share        (/ calls upcalls))
		  (tself-share  (* hist  share))  ; TODO: correct when recursive function?
		  (tchild-share (* tchild share)))
	     
	     (display-w "" 3 port)
	     (display-w "" 8 port)
	     
	     (if (neq? called-cyc primary-cyc)
		 (begin
		   (display-w-nr (occurs->ms tself-share) 7 port)
		   (display-w-nr (occurs->ms tchild-share) 7 port))
		 (begin
		   (display-w "" 7 port)
		   (display-w "" 7 port)))
	     
	     (display-w-nr occurs 12 port)
	     (display-sep-nrs calls nonreccalls "/" 12 port)
	     
	     (display "      " port)
	     (display-profinfo-name called-pi port)
	     (newline port))))
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

(define (display-profinfo-name pi port)
  (let* ((template (profinfo-template pi))
	 (dfn      (profinfo-dfn      pi))
	 (cyc      (profinfo-cycle    pi)))
    
    (display-location template port)

    (if cyc
	(begin
	  (display " <cycle " port)
	  (display (cycleinfo-number cyc))
	  (display ">" port)))
    
    (display " [" port)
    (display dfn port)
    (display "]" port)
    ))

;;; DATA CALCULATION

(define (occurs->ms occs)
  (round (/ (* occs (total-run-time))
	    *samples*)))

(define (total-run-time)
    (if (and *start-time*
	     *end-time*)
	(- *end-time* *start-time*)
	#f))

;;; cycle stuff

(define (make-new-cycleinfo)
  (let ((new (make-cycleinfo (length *cycles*) '())))
    new))

(define (cycleinfo-add ci)
  (if (not (memq? ci *cycles*))
      (set! *cycles* (cons ci *cycles*))))

(define (cycleinfo-add-member ci member)
  (let ((members (cycleinfo-members ci)))
    (if (not (memq? member members))
	(cycleinfo-set-members! ci (cons member members)))))

;; is profinfo a member of cycle ci?
(define (cycleinfo-member? ci profinfo)
  (memq? profinfo
	 (cycleinfo-members ci)))
  
(define (cycleinfo-foreach-member ci f)
  (for-each f (cycleinfo-members ci)))

;; number of calls to function called-pi from cycle or from outside of cycle
(define (calls-int/ext-cycle ci called-pi internal)
  (let ((cnt-calls 0)
	(caller-list (profinfo-callers called-pi)))
    (table-walk (lambda (caller-pi cinfo)
		  (if (and (eq? (cycleinfo-member? ci caller-pi)
				internal)
			   (neq? caller-pi called-pi))
		      (set! cnt-calls (+ cnt-calls (callerinfo-calls cinfo)))))
		caller-list)
    cnt-calls))

;; sum up internal calls of the cycle or calls from outside into the cycle
(define (sumup-calls-int/ext-cycle ci internal)
  (let ((cnt-calls 0))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (set! cnt-calls (+ cnt-calls (calls-int/ext-cycle ci member-pi internal)))))
    cnt-calls))

;; calls done in the cycle internally
(define (cycleinfo-internal-calls ci)
  (sumup-calls-int/ext-cycle ci #t))

;; calls done from outside into the cycle
(define (cycleinfo-external-calls ci)
  (sumup-calls-int/ext-cycle ci #f))

;; time spent in the functions of the cycle itself
(define (cycleinfo-hist ci)
  (let ((tt 0))
    (cycleinfo-foreach-member
     ci
     (lambda (pi)
       (set! tt (+ tt
		   (profinfo-hist pi)))))
    tt))


;; list of function profinfos the called cycle ci
(define (cycleinfo-called-from ci)
  (let ((lst '()))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (let ((caller-list (profinfo-callers member-pi)))
	 ;; add share of every function called from this cycle-function to total
	 (table-walk (lambda (caller-pi cinfo)
		     (if (and (not (cycleinfo-member? ci caller-pi))
			      (not (memq? caller-pi lst)))
			 (set! lst (cons caller-pi lst))))
		   caller-list))))
    lst))

;; list of function profinfos called from cycle ci
(define (cycleinfo-called-externals ci)
  (let ((lst '()))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (let ((called-list (profinfo-calls member-pi)))
	 ;; add share of every function called from this cycle-function to total
	 (for-each (lambda (called-pi)
		     (if (and (not (cycleinfo-member? ci called-pi))
			      (not (memq? called-pi lst)))
			 (set! lst (cons called-pi lst))))
		   called-list))))
    lst))

;; calls from cycle ci to some other function
(define (cycleinfo-calls-to ci called-pi)
  (let ((cnt-calls 0))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (set! cnt-calls (+ cnt-calls
			  (number-of-calls member-pi called-pi)))))
    cnt-calls))

;; calls to cycle ci from some other function
(define (cycleinfo-calls-from ci caller-pi)
  (let ((cnt-calls 0))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (set! cnt-calls (+ cnt-calls
			  (number-of-calls caller-pi member-pi)))))
    cnt-calls))


;; time spent in functions outside the cycle called from member-pi
(define (cycleinfo-tchild-member ci member-pi)
  (let ((tt 0)
	(called-list (profinfo-calls member-pi)))
    ;; add share of every function called from this cycle-function to total
    (for-each (lambda (called-pi)
		(if (and (not (eq? called-pi
				   member-pi))
			 (not (cycleinfo-member? ci called-pi)))
		    (let* ((thiscalls  (number-of-calls member-pi called-pi))
			   (totalcalls (profinfo-total-nonreccalls called-pi))
			   (occs       (profinfo-occurs            called-pi))
			   (share (/ (* occs thiscalls)
				     totalcalls)))
		      (set! tt (+ tt share)))))
	      called-list)
    tt))

;; time spent in functions outside the cycle, called from the cycle
(define (cycleinfo-tchild ci)
  (let ((tt 0))
    (cycleinfo-foreach-member
     ci
     (lambda (caller-pi)
       (set! tt (+ tt (cycleinfo-tchild-member ci caller-pi)))))
    tt))

(define (get-callerinfo caller called)
  (let* ((caller-list (profinfo-callers called))
	 (cinfo (table-ref caller-list caller)))
    cinfo))

(define (number-of-calls caller called)
  (let ((cinfo (get-callerinfo caller called)))
    (if cinfo
	(callerinfo-calls cinfo)
	0)))


;; total number of calls from caller to the member or its whole cycle
;; (without recursive and cyclic)
(define (profinfo-upcalls caller-pi called-pi)
  (let* ((cyc-called   (profinfo-cycle  called-pi))
	 (nonrec-calls (profinfo-total-nonreccalls called-pi)))
    (if cyc-called
	(cycleinfo-calls-from cyc-called caller-pi)
	nonrec-calls)))

;; total number of calls from caller to the member or its whole cycle
;; (without recursive and cyclic)
(define (profinfo-total-upcalls called-pi)
  (let* ((cyc-called   (profinfo-cycle  called-pi))
	 (nonrec-calls (profinfo-total-nonreccalls called-pi)))
    (if cyc-called
	(sumup-calls-int/ext-cycle cyc-called #f)
	nonrec-calls)))

;; number of calls from inside of it's own cycle
(define (profinfo-total-cycliccalls pi)
  (let ((cyc (profinfo-cycle pi)))
    (if cyc
(calls-int/ext-cycle cyc pi #t)
0)))



;; returns a list of all profinfos the function calls
(define (profinfo-calls caller-pi)
  (let ((lst '()))
    (table-walk (lambda (template called-pi)
		  (if (> (number-of-calls caller-pi called-pi) 0)
		      (set! lst (cons called-pi lst))))
		*templates*)
    (remove-duplicates lst)))

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

(define (get-sorted-templates property)
  (let ((lst '())) 
    (table-walk (lambda (template profinfo)
		  (set! lst (cons profinfo lst)))
		*templates*) 
    (set! lst (list-sort (lambda (a b) 
			   (< (property a)
			      (property b)))
			 lst))
    lst))

(define (propagate-time-from-children caller-pi)
  (ddisplay "progating time for ")
  (ddisplay (profinfo-template caller-pi))
  (ddisplay " from children...\n")
  (let ((called-list (profinfo-calls caller-pi)))
    (for-each
     (lambda (called-pi)
       (let* ((cinfo        (get-callerinfo    caller-pi called-pi))
	      (called-cyc   (profinfo-cycle              called-pi))
	      (caller-cyc   (profinfo-cycle    caller-pi))
	      (calls        (callerinfo-calls  cinfo))
	      (share        0)
	      (childshare   0))

	 (ddisplay (profinfo-template caller-pi))
	 (ddisplay "  -->  ")
	 (ddisplay (profinfo-template called-pi))
	 
	 (if (and (neq? caller-pi called-pi)
		  (or (not called-cyc) (neq? called-cyc caller-cyc)))
	     (begin
		(let ((ctself
		       (if called-cyc
			   (cycleinfo-hist called-cyc)
			   (profinfo-hist  called-pi)))
		      (ctchild
		       (if called-cyc
			   (cycleinfo-tchild called-cyc)
			   (profinfo-tchild  called-pi)))
		      (nonreccalls
		       (if called-cyc
			   (cycleinfo-external-calls called-cyc)
			   (profinfo-total-nonreccalls  called-pi))))
		  (ddisplay " ctself: ")
		  (ddisplay ctself)
		  (ddisplay ", ctchild: ")
		  (ddisplay ctchild)
		  (ddisplay ", nrc: ")
		  (ddisplay nonreccalls)
		  (set! share      (/ (* ctself  calls) nonreccalls))
		  (set! childshare (/ (* ctchild calls) nonreccalls))
		)))

	 
	 (ddisplay ", calls ")
	 (ddisplay (round calls))
	 (ddisplay ", share ")
	 (ddisplay (round share))
	 (ddisplay ", childshare ")
	 (ddisplay (round childshare))
	 (ddisplay "\n")

	 ;; add shares to arc information
	 (callerinfo-set-tself!  cinfo share)
	 (callerinfo-set-tchild! cinfo childshare)

	 ;; add everything to child share for parent
	 (profinfo-set-tchild! caller-pi
			       (+ (profinfo-tchild caller-pi)
				  (+ share childshare)))
	 (if caller-cyc
	     (cycleinfo-set-tchild! caller-cyc
				    (+ (cycleinfo-tchild caller-cyc)
				       (+ share childshare))))
	 ))
     called-list)))

(define (propagate-times)
  ;; zero out
  (table-walk (lambda (template profinfo)
		(profinfo-set-tchild! profinfo 0))
	      *templates*)
  (for-each (lambda (cyc)
	      (cycleinfo-set-tchild! cyc 0))
	      *cycles*)

  (for-each propagate-time-from-children
	    (get-sorted-templates (lambda (pi) (- (profinfo-dfn pi)))))
  )


;;; returns the function everything originates from,
;;; the one that has no caller
;;; TODO: this can return #f, when root is in a cycle
(define (get-root-function)
  (call-with-current-continuation
   (lambda (return)
     (table-walk (lambda (template profinfo)
		   (if (= (table-size (profinfo-callers profinfo)) 0)
		       (return profinfo)))
		 *templates*)
     (begin
       (display "root is in a cycle, needs to be fixed!\n")
       #f 
       ))))


;;; number function by their depth in the call stack
(define (profinfo-dfn-set? pi)
  (number? (profinfo-dfn pi)))
(define (profinfo-dfn-busy? pi)
  (eq? (profinfo-dfn pi) 'busy))

(define (build-cycle dfn-stack top-pi)
  ;; is it just a recursive call?
  (if (not (eq? (car dfn-stack) top-pi))
      (begin
	;; move down the stack till we find ourselves again, adding
	;; every function to our cycle
	(let ((cyc (make-new-cycleinfo)))
	  
	  (let loop ((stack dfn-stack))
	    (let* ((pi     (car stack))
		   (pi-cyc (profinfo-cycle pi)))
	      
	      (cycleinfo-add-member cyc pi)
	      
	      ;; if this function is in a cycle already, we all belong to this cycle too
	      (if pi-cyc
		  (begin
		    ;; copy members to this cycle
		    (for-each (lambda (memb)
				(cycleinfo-add-member pi-cyc memb))
			      (cycleinfo-members cyc))
		    (set! cyc pi-cyc)))
	      
	      (if (and (not (null? (cdr stack)))
		       (not (eq? pi top-pi)))
		  (loop (cdr stack)))))
	  
	    ;; add cycle globally
	    (cycleinfo-add cyc)
	    
	    ;; update cycle information in profinfos
	    (for-each (lambda (memb)
			(profinfo-set-cycle! memb cyc))
		      (cycleinfo-members cyc))
	    ))))
	  
	 
;;; numbers all functions by their depth in the call stack
(define (depth-numbering)
  (let ((dfn-counter (table-size *templates*)))
    (letrec ((depth-number-function
	      (lambda (dfn-stack cur-pi)
		;; already set?
		(if (not (profinfo-dfn-set? cur-pi))
		    (begin
		      ;; is it busy? must be a cycle
		      (if (profinfo-dfn-busy? cur-pi)
			  (build-cycle dfn-stack cur-pi)
			  ;; no cycle
			  (begin
			    ;; pre-visit
			    (profinfo-set-dfn! cur-pi 'busy)
			    
			    ;; process children
			    (for-each (lambda (called-pi)
					(depth-number-function (cons cur-pi dfn-stack)
							       called-pi))
				      (profinfo-calls cur-pi))
			    
			    (set! dfn-counter (- dfn-counter 1))
			    
			    ;; post-visit
			    (profinfo-set-dfn! cur-pi dfn-counter)
			    )))))))

      ;; zero out
      (set! *cycles* '())
      (table-walk (lambda (template profinfo)
		    (profinfo-set-dfn! profinfo 'notset)
		    (profinfo-set-cycle! profinfo #f))
		  *templates*)
      
      ;; find root and number from there
      (if (get-root-function)
	  (depth-number-function '() (get-root-function))))))


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
	       (table-set! cs caller (make-callerinfo caller 1)))))))


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
(define (post-process-stack! call-stack)
  (if call-stack
      (let loop ((stack          call-stack)
		 (caller-se      #f)
		 (seen-templates '()))
	(if (not (null? stack))
	    (let* ((called-se (car stack))
		   (called-pi (get-profinfo called-se))
		   (template  (stackentry-template called-se))
		   (reccalls  (stackentry-reccalls called-se)))
	      (if (and (= reccalls 0)
		       (not (memq? template seen-templates)))
		  (begin
		    ;; record occurance
		    (profinfo-set-occurs! called-pi
					  (+ (profinfo-occurs called-pi) 1))))

	      ;; if top element, count as running
	      (if (null? (cdr stack))
		  (profinfo-set-hist! called-pi
				      (+ (profinfo-hist called-pi) 1)))
	      
	      (loop (cdr stack)
		    called-se
		    (cons template seen-templates)))))))


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
			       0 0))
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
;  (display "\n\n")
;  (display "processing stack traces:\n")
;  (newline)
  ;; go from bottom to top and count calls
  (let loop ((pos 0)
	     (stack *cur-stack*)
	     (caller-se #f)
	     (diff-found #f))
    (if (not (null? stack))
	(let ((new-se (car stack)))
;	  (display pos)
;	  (display " - ")
;	  (display (stackentry-template new-se))
;	  (newline)
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
