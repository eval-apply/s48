;;;;;; Rudimentary Scheme48 profiler                     -*- Scheme -*-

;;; Taylor Campbell wrote parts of the original code; he has placed them in the public domain.

(define-command-syntax 'profile "<command>" "profile execution"
                       '(command))

;; profiling information for each template
(define-record-type profinfo :profinfo
  (make-profinfo template callers occurs hist memoryuse)
  profinfo?
  (template  profinfo-template)                           ; scheme code template
  (callers   profinfo-callers   profinfo-set-callers!)    ; table of callerinfos
  (occurs    profinfo-occurs    profinfo-set-occurs!)
  (hist      profinfo-hist      profinfo-set-hist!)
  (tchild    profinfo-tchild    profinfo-set-tchild!)
  (toporder  profinfo-toporder  profinfo-set-toporder!)
  (dfn       profinfo-dfn       profinfo-set-dfn!)        ; depth-first number
  (cycle     profinfo-cycle     profinfo-set-cycle!)
  (memoryuse profinfo-memoryuse profinfo-set-memoryuse!))

(define-record-type cycleinfo :cycleinfo
  (make-cycleinfo number members)
  cycleinfo?
  (number  cycleinfo-number)                                 ; consecutive numbering
  (members cycleinfo-members cycleinfo-set-members!)         ; member profinfos
  (tchild  cycleinfo-tchild  cycleinfo-set-tchild!)
  )

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


;;; Global profiling stuff (independent of prof-data)

(define *interrupt-time* #f)            ; (theoretical) ms between interrupts

(define *saved-interrupt-handler* #f)   ; non-profiler interrupt handler
(define *profiler-continuation* #f)     ; profiler's top continuation

(define *profiler-lock* (make-lock))    ; exclusive lock for interrupt handler

(define *profiler-lastrun* #f)          ; run-time of profiler runs
(define *profiler-thisrun* #f)

(define *active-profile-data* #f)

(define *start-gc-count* 0)
(define *last-gc-count* 0)
(define *cur-gc-count* 0)
(define *last-avail-memory* 0)
(define *cur-avail-memory* 0)

(define interrupt/alarm (enum interrupt alarm))

(define default-interrupt-time 50)


;;; Miscellaneous global stuff

(define-record-type profile-data :profile-data
  (make-profile-data)
  (starttime profile-data-starttime set-profile-data-starttime!)
  (endtime   profile-data-endtime   set-profile-data-endtime!)
  (root      profile-data-root      set-profile-data-root!)
  (cycles    profile-data-cycles    set-profile-data-cycles!)
  (samples   profile-data-samples   set-profile-data-samples!)
  (templates profile-data-templates set-profile-data-templates!)
  (memoryuse profile-data-memoryuse set-profile-data-memoryuse!)
  (gcruns    profile-data-gcruns    set-profile-data-gcruns!))

(define (make-empty-profile-data)
  (let ((pd (make-profile-data)))
    (set-profile-data-memoryuse! pd 0)
    (set-profile-data-cycles! pd '())
  pd))

(define (run-time)
  (primitives:time (enum time-option run-time) #f))

;; debug display
(define (ddisplay x)
;  (display x)
  #f)

;; we overwrite template-id because of our special "root" template
(define (prof-template-id t)
  (if (string? t)
      0
      (template-id t)))

;; hash function for callers table in profiling information
(define (profinfo-id pi)
  (prof-template-id (profinfo-template pi)))


(define (profiler-continuation? cont)
  (eq? cont *profiler-continuation*))

(define (get-profinfo-from-template prof-data template)
  (table-ref (profile-data-templates prof-data) template))
  
(define (get-profinfo prof-data stack-entry)
  (if stack-entry
      (get-profinfo-from-template prof-data (stackentry-template stack-entry))
      #f))

(define (profile-set-interrupt-time! t)
  (set! *interrupt-time* t))

;;; MAIN

(define (profile command . interrupt-time)
  (profile-and-display (if (eq? (car command) 'run)
                             (eval `(LAMBDA () ,(cadr command))
                                   (environment-for-commands))
                             (lambda () (execute-command command)))
			 interrupt-time
                         (current-output-port)))

(define (profile-and-display thunk
			     interrupt-time
			     port)
;  (calculate-tick-rate!)
  (let ((prof-data (make-empty-profile-data)))
    (call-with-values
	(lambda ()
	  (if (null? interrupt-time)
	      (profile-thunk prof-data thunk)
	      (profile-thunk prof-data thunk (car interrupt-time))))
      (lambda results
	(profile-display prof-data port)
	(set-command-results! results)))))


(define (profile-thunk prof-data thunk . opt-args)
  
  ;; optional arguments: interrupt-time ...
  (case (length opt-args)
    ((1) ; interrupt time
     (let ((int-time (car opt-args)))
       (set! *interrupt-time* int-time))))
  
  ;; default interrupt time, if not set
  (if (not *interrupt-time*)
      (set! *interrupt-time* default-interrupt-time))

  (if *profiler-continuation*
      (error
       'profile-thunk
       "profiler can not be running twice at the same time" thunk)
      (begin
	(set! *active-profile-data* prof-data)
	(set! *last-stack*          #f)
	(set! *profiler-thisrun*    #f)
	(set! *profiler-lastrun*    #f)
	(set! *last-avail-memory*   (available-memory))
	(set! *start-gc-count*      (get-current-gc-count))
	(set! *last-gc-count*       *start-gc-count*)
	(release-lock *profiler-lock*)

	(set-profile-data-root!      prof-data "root")
	(set-profile-data-templates! prof-data (make-table prof-template-id))
	(set-profile-data-samples!   prof-data 0)
	(set-profile-data-starttime! prof-data (run-time))

	(call-with-values
	    (lambda ()
	      (dynamic-wind
		  (lambda ()
		    (install-profiler-interrupt-handler)
		    (start-periodic-interrupts!))
		  (lambda ()
		    (primitive-cwcc
		     (lambda (profiler-cont)
		       (set! *profiler-continuation* profiler-cont)
		       (thunk))))             ; run program!
		  (lambda ()
		    (set! *profiler-continuation* #f)
		    (stop-periodic-interrupts!)
		    (uninstall-profiler-interrupt-handler)
		    
		    (set-profile-data-endtime! prof-data (run-time))
		    (set-profile-data-gcruns!  prof-data (- (get-current-gc-count) *start-gc-count*))
		    
		    (post-process-stack! prof-data *last-stack*) ; process the last stack trace
		    
		    ;; do necessary calculations
		    (depth-numbering prof-data)
		    (propagate-times prof-data)
		    
		    (set! *active-profile-data*   #f))))
	  (lambda results
	    (apply values results))))))
	


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
	   (if *profiler-continuation* (record-continuation! *active-profile-data* cont))
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

(define (display-w-mem n w port)
  (if (> n 1000000000)
      (display-w (string-append (number->string (round (/ n 1000000))) "M") w port)
      (display-w (string-append (number->string (round (/ n 1000))) "k") w port)))

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

(define (parse-port-arg opt-port)
  (if (null? opt-port)
      (current-output-port)
      (car opt-port)))

(define (profile-display prof-data . opt-port)
  (let ((port (parse-port-arg opt-port)))
    (profile-display-overview prof-data port)
    (newline port)
    (if (> (profile-data-samples prof-data) 0)
	(begin 
	  (profile-display-flat prof-data port)
	  (newline port)
	  (profile-display-tree prof-data port))
	(display "No data collected!\n" port))))

;; general profiling data
(define (profile-display-overview prof-data . opt-port)
  (let ((port (parse-port-arg opt-port))
	(run-time (profile-data-runtime prof-data))
	(samples  (profile-data-samples prof-data)))
    
    (display "** Samples:        " port)
    (display samples port)
    (if (> samples 0)
	(begin
	  (display " (approx. one per " port)
	  (display (round (/ run-time samples)) port)
	  (display "ms)")))
    (newline port)

    (display "** Interrupt time: " port)
    (display *interrupt-time* port)
    (display "ms" port)
    (newline port)
    
    (display "** Real run time:  " port)
    (display run-time port)
    (display "ms" port)
    (newline port)
	  
    (if (> samples 0)
	(begin
	  (display "** Total memory:   " port)
	  (display (round (/ (profile-data-memoryuse prof-data) 1000)) port)
	  (display "k" port)
	  (newline port)
	  
	  (display "** GC runs:        " port)
	  (display (profile-data-gcruns prof-data) port)
	  (newline port)))))

(define (profile-display-flat prof-data . opt-port)
  (let ((port (parse-port-arg opt-port)))
    
    (display "** Flat result (times in ms): " port)
    (newline port)
    (newline port)
    
    ;; gprof:
    ;;      %   cumulative   self              self     total           
    ;;   time   seconds   seconds    calls  ms/call  ms/call  name
    
    (display-w "time" 7 port)
    (display-w "cumu" 7 port)
    (display-w "self" 7 port)
    (display-w "mem" 12 port)
    (display-w "calls" 14 port)
    (display-w "ms/call" 9 port)
    (display-w "name" 7 port)
    (newline port)

  ;; sort and print
  (let ((lst '())) 
    (table-walk (lambda (template profinfo)
		  (set! lst (cons profinfo lst)))
		(profile-data-templates prof-data))
    (set! lst (sort-list lst
			 (lambda (a b) 
			   (>= (profinfo-hist a)
			       (profinfo-hist b)))))
    (for-each (lambda (profinfo)
		(profile-display-profinfo-flat prof-data profinfo port))
	      lst))))

;; display data "gprof call graph"-like
(define (profile-display-tree prof-data . opt-port)
  (let ((port   (parse-port-arg opt-port))
	(cycles (profile-data-cycles prof-data)))
	 
    (display "** Tree result (times in ms): " port)
    (newline port)
    (newline port)
    
    (display-w "i" 3 port)
    (display-w "time" 8 port)
    (display-w "self" 7 port)
    (display-w "child" 7 port)
    (display-w "mem" 12 port)
    (display-w "calls" 12 port)
    (display-w "name" 7 port)
    (newline port)
    
    ;; sort and print
    (let ((sorted-templates 
	   (get-sorted-templates prof-data (lambda (pi) (- (profinfo-occurs pi)))))
	  (toporder 0))
      (for-each (lambda (profinfo)
		  (profinfo-set-toporder! profinfo toporder)
		  (set! toporder (+ toporder 1)))
		sorted-templates)
      (for-each (lambda (profinfo)
		  (profile-display-profinfo-tree prof-data profinfo port)
		  (display "==========================================================================================" port)
		  (newline port))
		sorted-templates))

    (if cycles
	(for-each (lambda (cyc)
		    (profile-display-cycle-tree prof-data cyc port))
		  cycles))))

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

(define (profile-display-profinfo-flat prof-data profinfo port)

  (let* ((template     (profinfo-template            profinfo))
	 (occurs       (profinfo-occurs              profinfo))
	 (calls        (profinfo-total-calls         profinfo))
	 (reccalls     (profinfo-total-reccalls      profinfo))
	 (nonreccalls  (profinfo-total-nonreccalls   profinfo))
	 (hist         (profinfo-hist                profinfo))
	 (memuse       (profinfo-memoryuse           profinfo))
	 (timeshare    (profinfo-timeshare prof-data profinfo))
	 (ttotal       (profinfo-total-ms  prof-data profinfo))
	 (tself        (profinfo-self-ms   prof-data profinfo))
	 (ms/call      (save/ (occurs->ms prof-data occurs) calls)))

    (if (not (eq? template (profile-data-root prof-data)))
	(begin
	  (display-w (number-as-percent-string timeshare)  7 port)
	  (display-w-nr ttotal 7 port)
	  (display-w-nr tself  7 port)
	  (display-w-mem memuse 12 port)
	  (display-sep-nz-nrs nonreccalls reccalls "+" 14 port)
	  (display-w-nr ms/call 9 port)
	  
	  (display "   " port)
	  (display-location prof-data template port) ; name
	  (newline port)
	  ))))

(define (profile-display-cycle-tree prof-data cycleinfo port)
  (let* ((number    (cycleinfo-number         cycleinfo))
	 (members   (cycleinfo-members        cycleinfo))
	 (callers   (cycleinfo-called-from    cycleinfo))
	 (intcalls  (cycleinfo-internal-calls cycleinfo))
	 (extcalls  (cycleinfo-external-calls cycleinfo))
	 (hist      (cycleinfo-hist           cycleinfo))
	 (tchild    (cycleinfo-tchild         cycleinfo))
	 (memuse    (cycleinfo-memoryuse      cycleinfo))
	 (fromextcalls (sumup-calls-int/ext-cycle cycleinfo #f))
	 (ttotal    (+ hist tchild))
	 (timeshare (save/ ttotal (profile-data-samples prof-data))))

    ;; print cycle callers
    (for-each
     (lambda (caller-pi)
       (let* ((calls        (cycleinfo-calls-from  cycleinfo caller-pi))
	      (share        (/ calls fromextcalls))
	      (tchild       (* tchild share))
	      (memuse       (* memuse share)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr (occurs->ms prof-data hist) 7 port)
	 (display-w-nr (occurs->ms prof-data tchild) 7 port)
	 (display-w-mem memuse 12 port)
	 (display-sep-nz-nrs calls fromextcalls "/" 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name prof-data caller-pi port)
	 (newline port)))
     callers)
    
    
    ;; print primary line
    (display-w-nr number 3 port)
    (display-w (number-as-percent-string timeshare) 8 port)
    (display-w-nr (occurs->ms prof-data hist) 7 port)
    (display-w-nr (occurs->ms prof-data tchild) 7 port)
    (display-w-mem memuse 12 port)
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
	      (nonreccalls  (profinfo-total-nonreccalls    member-pi))
	      (totalmemuse  (profinfo-memoryuse            member-pi))
	      (occurs       (profinfo-occurs               member-pi))
	      (hist         (profinfo-hist                 member-pi))
	      (tchild       (cycleinfo-tchild-member prof-data cycleinfo member-pi))
	      (share        (/ intcalls nonreccalls))
	      (memuse       (* totalmemuse share)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr (occurs->ms prof-data hist) 7 port)
	 (display-w-nr (occurs->ms prof-data tchild) 7 port)
	 (display-w-mem memuse 12 port)
	 (display-w-nr intcalls 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name prof-data member-pi port)
	 (newline port)))
     members)
    
    ;; print functions called out of the cycle
    (for-each
     (lambda (called-pi)
       (let* ((nonreccalls  (profinfo-total-nonreccalls   called-pi))
	      (totalmemuse  (profinfo-memoryuse           called-pi))
	      (calls        (cycleinfo-calls-to cycleinfo called-pi))
	      (share        (/ calls nonreccalls))
	      (memuse       (* totalmemuse share)))
	 (display-w "" 3 port)
	 (display-w "" 8 port)
	 (display-w-nr 0 7 port)
	 (display-w-nr 0 7 port)
	 (display-w-mem memuse 12 port)
	 (display-sep-nrs calls nonreccalls "/" 12 port)
	 
	 (display "      " port)
	 (display-profinfo-name prof-data called-pi port)
	 (newline port)))
     (cycleinfo-called-externals prof-data cycleinfo))))


(define (profile-display-profinfo-tree prof-data primary-pi port)
  (let* ((template     (profinfo-template            primary-pi))
	 (toporder     (profinfo-toporder            primary-pi))
	 (dfn          (profinfo-dfn                 primary-pi))
	 (callers      (profinfo-callers             primary-pi))
	 (occurs       (profinfo-occurs              primary-pi))
	 (calls        (profinfo-total-calls         primary-pi))
	 (reccalls     (profinfo-total-reccalls      primary-pi))
	 (nonreccalls  (profinfo-total-nonreccalls   primary-pi))
	 (memuse       (profinfo-memoryuse           primary-pi))
	 (upcalls      (profinfo-total-upcalls       primary-pi))
	 (hist         (profinfo-hist                primary-pi))
	 (tchild       (profinfo-tchild              primary-pi))
	 (primary-cyc  (profinfo-cycle               primary-pi))
	 (timeshare    (save/ occurs (profile-data-samples prof-data)))
	 (ms/call      (save/ (occurs->ms prof-data occurs) calls)))
    
    ;; print parents
    (if (= (table-size callers) 0)
	(if (not (eq? template (profile-data-root prof-data)))
	    (begin (display-w " " 49 port) (display "      <spontaneous>" port) (newline)))
	(table-walk
	 (lambda (caller-pi cinfo)
	   (if (not (eq? caller-pi primary-pi))
	       (let* ((template     (profinfo-template caller-pi))
		      (dfn          (profinfo-dfn      caller-pi))
		      (occurs       (profinfo-occurs   caller-pi))
		      (caller-cyc   (profinfo-cycle    caller-pi))
		      (calls        (callerinfo-calls  cinfo))
		      (share        (/ calls upcalls))
		      (tself-share  (* hist   share))  ; TODO: correct when recursive function?
		      (tchild-share (* tchild share))
		      (memuse-share (* memuse share)))
		 (display-w "" 3 port)
		 (display-w "" 8 port)

		 (if (or (not primary-cyc)
			 (not (eq? caller-cyc primary-cyc)))
		     (begin
		       (display-w-nr (occurs->ms prof-data tself-share) 7 port)
		       (display-w-nr (occurs->ms prof-data tchild-share) 7 port)
		       (display-w-mem memuse-share 12 port))
		     (begin
		       (display-w "" 7 port)
		       (display-w "" 7 port)
		       (display-w "" 12 port)))
		     
		 (display-sep-nrs calls nonreccalls "/" 12 port)
		 
		 (display "      " port)
		 (display-profinfo-name prof-data caller-pi port)
		 (newline port))))
	 callers))
    
    ;; print primary line
    (display-w-nr toporder 3 port)
    (display-w (number-as-percent-string timeshare) 8 port)
    (display-w-nr (occurs->ms prof-data hist) 7 port)
    (display-w-nr (occurs->ms prof-data tchild) 7 port)
    (display-w-mem memuse 12 port)
    (display-sep-nz-nrs nonreccalls reccalls "+" 12 port)
    
    (display "   " port)
    (display-profinfo-name prof-data primary-pi port)
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
		  (memuse       (profinfo-memoryuse           called-pi))
		  (share        (/ calls upcalls))
		  (tself-share  (* hist   share))  ; TODO: correct when recursive function?
		  (tchild-share (* tchild share))
		  (memuse-share (* memuse share)))
	     
	     (display-w "" 3 port)
	     (display-w "" 8 port)
	     
	     (if (or (not called-cyc)
		     (not (eq? called-cyc primary-cyc)))
		 (begin
		   (display-w-nr (occurs->ms prof-data tself-share) 7 port)
		   (display-w-nr (occurs->ms prof-data tchild-share) 7 port)
		   (display-w-mem memuse-share 12 port))
		 (begin
		   (display-w "" 7 port)
		   (display-w "" 7 port)
		   (display-w "" 12 port)))
	     
	     (display-sep-nrs calls nonreccalls "/" 12 port)
	     
	     (display "      " port)
	     (display-profinfo-name prof-data called-pi port)
	     (newline port))))
     (profinfo-calls prof-data primary-pi))))


;; displays functionname and file of a code template
(define (display-location prof-data template port)
  (if (eq? template (profile-data-root prof-data))
      (display "<profiler>" port)
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
			 (loop (cdr names)))))))))

(define (display-profinfo-name prof-data pi port)
  (let* ((template (profinfo-template pi))
	 (dfn      (profinfo-dfn      pi))
	 (cyc      (profinfo-cycle    pi)))
    
    (display-location prof-data template port)

    (if cyc
	(Begin
	  (display " <cycle " port)
	  (display (cycleinfo-number cyc))
	  (display ">" port)))
    
    (display " [" port)
    (display dfn port)
    (display "]" port)
    ))

;;; useful stuff

(define (memq? x l)
  (let loop ((l l))
    (cond ((null? l)       #f)
	  ((eq? x (car l)) #t)
	  (else            (loop (cdr l))))))

(define (remove-duplicates list)
  (do ((list list (cdr list))
       (res  '()  (if (memq? (car list) res)
                      res
                      (cons (car list) res))))
      ((null? list)
       res)))

;;; DATA CALCULATION

(define (occurs->ms prof-data occs)
  (round (/ (* occs (profile-data-runtime prof-data))
	    (profile-data-samples prof-data))))

(define (profile-data-runtime prof-data)
  (let ((st (profile-data-starttime prof-data))
	(et (profile-data-endtime   prof-data)))
    (if (or (eq? st (unspecific))
	    (eq? et (unspecific)))
	(unspecific)
	(- et st))))

;;; cycle stuff

(define (make-new-cycleinfo prof-data)
  (let ((new (make-cycleinfo (length (profile-data-cycles prof-data)) '())))
    new))

(define (cycleinfo-add prof-data ci)
  (if (not (memq? ci (profile-data-cycles prof-data)))
      (set-profile-data-cycles! prof-data (cons ci (profile-data-cycles prof-data)))))

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
			   (not (eq? caller-pi called-pi)))
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

(define (cycleinfo-memoryuse ci)
  (let ((tt 0))
    (cycleinfo-foreach-member
     ci
     (lambda (pi)
       (set! tt (+ tt
		   (profinfo-memoryuse pi)))))
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
(define (cycleinfo-called-externals prof-data ci)
  (let ((lst '()))
    (cycleinfo-foreach-member
     ci
     (lambda (member-pi)
       (let ((called-list (profinfo-calls prof-data member-pi)))
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
(define (cycleinfo-tchild-member prof-data ci member-pi)
  (let ((tt 0)
	(called-list (profinfo-calls prof-data member-pi)))
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
(define (xxxxxxxxxcycleinfo-calc-tchild prof-data ci)
  (let ((tt 0))
    (cycleinfo-foreach-member
     ci
     (lambda (caller-pi)
       (set! tt (+ tt (cycleinfo-tchild-member prof-data ci caller-pi)))))
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

(define (profinfo-timeshare prof-data profinfo)
  (let ((hist (profinfo-hist profinfo)))
    (save/ hist (profile-data-samples prof-data))))

(define (profinfo-total-ms prof-data profinfo)
  (let ((occurs (profinfo-occurs profinfo)))
    (occurs->ms prof-data occurs)))

(define (profinfo-self-ms prof-data profinfo)
  (let ((hist (profinfo-hist profinfo)))
    (occurs->ms prof-data hist)))
  

;; returns a list of all profinfos the function calls
(define (profinfo-calls prof-data caller-pi)
  (let ((lst '()))
    (table-walk (lambda (template called-pi)
		  (if (> (number-of-calls caller-pi called-pi) 0)
		      (set! lst (cons called-pi lst))))
		(profile-data-templates prof-data))
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

(define (get-sorted-templates prof-data property)
  (let ((lst '())) 
    (table-walk (lambda (template profinfo)
		  (set! lst (cons profinfo lst)))
		(profile-data-templates prof-data)) 
    (set! lst (sort-list lst
			 (lambda (a b) 
			   (< (property a)
			      (property b)))))
    lst))

(define (propagate-time-from-children prof-data caller-pi)
  (ddisplay "progating time for ")
  (ddisplay (profinfo-template caller-pi))
  (ddisplay " from children...\n")
  (let ((called-list (profinfo-calls prof-data caller-pi)))
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
	 
	 (if (and (not (eq? caller-pi called-pi))
		  (or (not called-cyc) (not (eq? called-cyc caller-cyc))))
	     (begin
		(let ((ctself
		       (if called-cyc
			   (cycleinfo-hist called-cyc)
			   (profinfo-hist  called-pi)))
		      (ctchild
		       (if called-cyc
			   (cycleinfo-tchild called-cyc)
			   (profinfo-tchild called-pi)))
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

(define (propagate-times prof-data)
  ;; zero out
  (table-walk (lambda (template profinfo)
		(profinfo-set-tchild! profinfo 0))
	      (profile-data-templates prof-data))
  (for-each (lambda (cyc)
	      (cycleinfo-set-tchild! cyc 0))
	      (profile-data-cycles prof-data))

  (for-each (lambda (template)
	      (propagate-time-from-children prof-data template))
	    (get-sorted-templates prof-data (lambda (pi) (- (profinfo-dfn pi))))))


;;; number function by their depth in the call stack
(define (profinfo-dfn-set? pi)
  (number? (profinfo-dfn pi)))
(define (profinfo-dfn-busy? pi)
  (eq? (profinfo-dfn pi) 'busy))

(define (build-cycle prof-data dfn-stack top-pi)
  ;; is it just a recursive call?
  (if (not (eq? (car dfn-stack) top-pi))
      (begin
	;; move down the stack till we find ourselves again, adding
	;; every function to our cycle
	(let ((cyc (make-new-cycleinfo prof-data)))
	  
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
	    (cycleinfo-add prof-data cyc)
	    
	    ;; update cycle information in profinfos
	    (for-each (lambda (memb)
			(profinfo-set-cycle! memb cyc))
		      (cycleinfo-members cyc))
	    ))))
	  
	 
;;; numbers all functions by their depth in the call stack
(define (depth-numbering prof-data)
  (let ((dfn-counter (table-size (profile-data-templates prof-data))))
    (letrec ((depth-number-function
	      (lambda (dfn-stack cur-pi)
		;; already set?
		(if (not (profinfo-dfn-set? cur-pi))
		    (begin
		      ;; is it busy? must be a cycle
		      (if (profinfo-dfn-busy? cur-pi)
			  (build-cycle prof-data dfn-stack cur-pi)
			  ;; no cycle
			  (begin
			    ;; pre-visit
			    (profinfo-set-dfn! cur-pi 'busy)
			    
			    ;; process children
			    (for-each (lambda (called-pi)
					(depth-number-function (cons cur-pi dfn-stack)
							       called-pi))
				      (profinfo-calls prof-data cur-pi))
			    
			    (set! dfn-counter (- dfn-counter 1))
			    
			    ;; post-visit
			    (profinfo-set-dfn! cur-pi dfn-counter)
			    )))))))

      ;; zero out
      (table-walk (lambda (template profinfo)
		    (profinfo-set-dfn! profinfo 'notset)
		    (profinfo-set-cycle! profinfo #f))
		  (profile-data-templates prof-data))
      
      ;; find root and number from there
      (if (profile-data-root prof-data)
	  (let ((root-pi (get-profinfo-from-template prof-data (profile-data-root prof-data))))
	    (if root-pi
		(depth-number-function '() root-pi)))))))

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
(define (post-process-stack! prof-data call-stack)
  (let ((gone-stackentries '()))
    (if call-stack
	(let loop ((stack          call-stack)
		   (caller-se      #f)
		   (seen-templates '()))
	  (if (not (null? stack))
	      (let* ((called-se (car stack))
		     (called-pi (get-profinfo prof-data called-se))
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
		
		;; if gone, record it
		(if (not (stackentry-seen called-se))
		    (set! gone-stackentries
			  (cons called-se gone-stackentries)))
		     
		(loop (cdr stack)
		      called-se
		      (cons template seen-templates))))))
    gone-stackentries))


(define (record-call! prof-data caller-se called-se)
  (let* ((caller-template (if caller-se
			     (stackentry-template caller-se)
			     #f))
	 (called-template (stackentry-template called-se))
	 (caller-profinfo (get-profinfo prof-data caller-se))
	 (called-profinfo (get-profinfo prof-data called-se)))
    
    ;; if not profiled template yet, create one
    (if (not called-profinfo)
	(begin
	  (set! called-profinfo
		(make-profinfo called-template
			       (make-table profinfo-id)
			       0 0 0))
	  (table-set! (profile-data-templates prof-data) called-template called-profinfo)))

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

(define (process-stack-traces! prof-data)
  (let ((stat-new-funcs  '())
	(stat-gone-funcs '())
	(stat-new-caller  #f)
	(stat-top         #f))
  
    ;; go from bottom to top and count calls
    (let loop ((pos 0)
	       (stack *cur-stack*)
	       (caller-se #f)
	       (diff-found #f))
      (if (not (null? stack))
	  (let ((new-se (car stack)))
	    ;; compare with last stack
	    (let ((old-se (list-ref-or-default *last-stack* pos #f))
		  (rcdcall #f)
		  (old-diff-found diff-found))
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

	      (if (and caller-se
		       (not (eq? diff-found
				 old-diff-found)))
		    (set! stat-new-caller caller-se))
	      
	      (if rcdcall
		  (begin  ; new call to fun
		    (set! stat-new-funcs (cons new-se stat-new-funcs))
		    (record-call! prof-data caller-se new-se))
		  (seen! old-se new-se))
	      
	      (loop (+ pos 1)
		    (cdr stack)
		    new-se
		    diff-found)))
	  (set! stat-top caller-se)))

    (set! stat-gone-funcs
	  (post-process-stack! prof-data *last-stack*))

    (analyze-memory-usage prof-data stat-top stat-new-funcs stat-new-caller stat-gone-funcs)
    
    ))


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
(define (record-continuation! prof-data cont)
  
  ;; init
  (set! *cur-stack*        '())
  (set! *profiler-lastrun* *profiler-thisrun*)
  (set! *profiler-thisrun* (run-time)) ; we cap this here, profiler could run some time
  (set! *cur-avail-memory* (available-memory))
  (set! *cur-gc-count*     (get-current-gc-count))
  (set-profile-data-samples! prof-data (+ 1 (profile-data-samples prof-data)))
  
  ;; record the current template
  (record-template! cont (find-template cont))

  ;; decent until we reach our own continuation
  (let loop ((cont (continuation-cont cont)))
    (if (and cont
	     (not (profiler-continuation? cont)))
	(let ((parent (continuation-cont cont)))
		(record-template! cont (continuation-template cont))
		(loop parent))))

  ;; record our root template
  (record-template! "root" (profile-data-root prof-data))
  
  ;; process the stack built above
  (if (not (null? *cur-stack*))
      (begin
	(process-stack-traces! prof-data)
  
	;; save old stack
	(set! *last-stack* *cur-stack*)
	(set-unseen-all!)))

  ;; save memory status
  (set! *last-avail-memory* (available-memory))
  (set! *last-gc-count*     (get-current-gc-count)))



;; searchs the (moving?) template in the continuation
(define (find-template cont)
  (let ((len (continuation-length cont)))
    (let loop ((i 0))
      (and (< i len)
           (let ((elt (continuation-ref cont i)))
             (if (template? elt)
                 elt
                 (loop (+ i 1))))))))



;;;;;; HEAP PROFILER

(define (available-memory)
  (primitives:memory-status (enum memory-status-option available) #f))

(define (get-current-gc-count)
  (primitives:memory-status (enum memory-status-option gc-count) #f))

(define (gc-running-meanwhile?)
  (> *cur-gc-count* *last-gc-count*))

(define (analyze-memory-usage prof-data top new caller gone)
  (if (gc-running-meanwhile?)
      (begin
	;; we need to know the free memory after GC to fix this
	(ddisplay "gc was running, crediting no memory usage...\n")
	#f)
      (begin
	(let* ((usage (- *last-avail-memory*
			 *cur-avail-memory*))
	       (cntnew  (length new))
	       (cntgone (length gone))
	       (dotop   (and top
			     (= cntnew 0)
			     (= cntgone 0)))
	       (totcnt (+ (if caller 1 0)
			  cntnew
			  cntgone))
	       (avgusage (/ usage totcnt))
	       (addmem (lambda (se amount)
			 (let ((pi (get-profinfo prof-data se)))
			   (profinfo-set-memoryuse!
			    pi
			    (+ (profinfo-memoryuse pi)
			       amount))))))

	  (if (< usage 0)
	      (warning
	       'profile-analyse-memory-usage
	       "usage < 0, somehow memory got free with no GC run!?\n")
	      (begin
		(set-profile-data-memoryuse!
		 prof-data
		 (+ (profile-data-memoryuse prof-data) usage))
		;; if the template at the top still the same, add all memory to it
		(if dotop
		    (addmem top usage)
		    ;; else distribute memory usage to all relevant templates
		    (begin
		      (if caller (addmem caller avgusage))
		      (for-each (lambda (se) (addmem se avgusage)) new)
		      (for-each (lambda (se) (addmem se avgusage)) gone)))))))))