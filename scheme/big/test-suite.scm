; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Support for writing and running test suites

(define-record-type test-suite :test-suite
  (really-make-test-suite name test-cases)
  test-suite?
  (name test-suite-name)
  (test-cases test-suite-cases set-test-suite-cases!))

(define-record-discloser :test-suite
  (lambda (t)
    (list 'test-suite
	  (test-suite-name t))))

(define-record-type compound-test-suite :compound-test-suite 
  (make-compound-test-suite name components)
  compound-test-suite?
  (name compound-test-suite-name)
  (components compound-test-suite-components))

(define-record-discloser :compound-test-suite
  (lambda (t)
    (list 'compound-test-suite
	  (compound-test-suite-name t)
	  (compound-test-suite-components t))))

(define (make-test-suite name)
  (really-make-test-suite name '()))

(define-syntax define-test-suite
  (syntax-rules ()
    ((define-test-suite ?name)
     (define ?name (make-test-suite '?name)))
    ((define-test-suite ?name (?comp0 ...))
     (define ?name (make-compound-test-suite '?name (list ?comp0 ...))))))

(define (add-test-case! suite case)
  (let ((same-name?
	 (lambda (a-case)
	   (eq? (test-case-name case) (test-case-name a-case)))))
    (cond
     ((any same-name?
	   (test-suite-cases suite))
      => (lambda (duplicate)
	   (warning 'define-test-case! "duplicate test case, removing old one" duplicate)
	   (set-test-suite-cases! suite
				  (delete same-name? (test-suite-cases suite)))))))

  (set-test-suite-cases! suite
			 (cons case (test-suite-cases suite))))

(define (zap-test-suite! suite)
  (set-test-suite-cases! suite '()))

(define-record-type test-case :test-case
  (make-test-case name suite thunk)
  test-case?
  (name test-case-name)
  (suite test-case-suite)
  (thunk test-case-thunk))

(define-record-discloser :test-case 
  (lambda (c)
    (list 'test-case (test-case-name c))))

(define-syntax define-test-case
  (syntax-rules ()
    ((define-test-case ?name ?suite ?body0 ?body1 ...)
     (let ((suite ?suite))
       (add-test-case! suite
		       (make-test-case '?name
				       suite
				       (lambda ()
					 ?body0 ?body1 ...)))))))

(define-syntax define-test-cases
  (syntax-rules ()
    ((define-test-cases ?suite
       (?name ?body0 ?body1 ...) ...)
     (begin
       (define-test-case ?name ?suite ?body0 ?body1 ...) ...))))

(define-syntax check
  (syntax-rules (=> not)
    ((check ?actual)
     (check-that ?actual (is-true)))
    ((check (not ?actual))
     (check-that ?actual (is-false)))
    ((check ?actual => ?expected)
     (check-that ?actual (is equal? ?expected)))
    ((check ?actual (=> ?equal?) ?expected)
     (check-that ?actual (is ?equal? ?expected)))))

(define (always-true _)
  #t)

(define-syntax check-exception
  (syntax-rules (=>)
    ((check-exception ?actual)
     (check-exception ?actual => always-true))
    ((check-exception ?actual => ?predicate)
     (let ((predicate ?predicate))
       (guard
	(c
	 ((not (predicate c))
	  (register-failure!
	   (make-check-exception-failure (fluid $test-case)
					 '?actual #f c predicate)))
	 (else (values)))
	
	(let ((actual ?actual))
	  (register-failure!
	   (make-check-exception-failure (fluid $test-case)
					 '?actual actual #f predicate))))))))

; Idea stolen from latest JUnit
(define-syntax check-that
  (syntax-rules ()
    ((check-that ?actual ?matcher)
     (check-that-1 (lambda () ?actual) '?actual ?matcher))
    ((check-that ?actual ?matcher ...)
     (check-that-n (lambda () ?actual) '?actual ?matcher ...))))

(define (catching-failures actual-thunk actual-exp pos expected consumer)
  (call-with-current-continuation
   (lambda (exit)
     (with-exception-handler
      (lambda (c)
	(primitive-cwcc
	 (lambda (cont)
	   (register-failure!
	    (make-check-failure (fluid $test-case)
				actual-exp #f c cont pos expected))))
	(exit))
      (lambda ()
	(call-with-values actual-thunk consumer))))))

(define (check-that-1 actual-thunk actual-exp matcher)
  (catching-failures
   actual-thunk actual-exp #f matcher
   (lambda actual-values
     (cond
      ((not (= 1 (length actual-values)))
       (register-failure!
	(make-check-failure (fluid $test-case)
			    actual-exp actual-values #f #f 'size (list matcher))))
      ((not (matches? matcher (car actual-values)))
       (register-failure!
	 (make-check-failure (fluid $test-case)
			     actual-exp (car actual-values) #f #f #f matcher)))))))
  
(define (check-that-n actual-thunk actual-exp . matchers)
  (catching-failures
   actual-thunk actual-exp 'all matchers
   (lambda actual-values
     (if (not (= (length actual-values)
		 (length matchers)))
	 (register-failure!
	  (make-check-failure (fluid $test-case)
			      actual-exp actual-values #f #f 'size matchers))
	 (let ((pos 0))
	   (for-each (lambda (matcher actual)
		       (if (not (matches? matcher actual))
			   (register-failure!
			    (make-check-failure (fluid $test-case)
						actual-exp actual #f #f pos matcher)))
		       (set! pos (+ 1 pos)))
		     matchers actual-values))))))

(define-syntax check-exception-that
  (syntax-rules ()
    ((check-exception-that ?actual ?matcher)
     (check-exception-that* (lambda () ?actual) '?actual ?matcher))))

(define (check-exception-that* actual-thunk actual-exp matcher)
  (guard
   (c
    ((not (matches? matcher c))
     (register-failure!
      (make-check-exception-failure (fluid $test-case)
				    actual-exp #f c matcher)))
    (else (values)))
	
   (call-with-values
       actual-thunk
     (lambda actual-vals
       (register-failure!
	(make-check-exception-failure (fluid $test-case)
				      actual-exp actual-vals #f matcher))))))

; special case: inexact
(define (=within tolerance)
  (lambda (z1 z2)
    (< (magnitude (- z2 z1)) tolerance)))

(define $test-case (make-fluid #f))
(define $failures (make-fluid #f))

(define (register-failure! failure)
  (let ((cell (fluid $failures)))
    (cell-set! cell
	       (cons failure (cell-ref cell)))))

(define-record-type check-failure :check-failure
  (make-check-failure test-case
		      actual-expr actual-val actual-condition continuation
		      pos expected)
  check-failure?
  (test-case check-failure-test-case)
  (actual-expr check-failure-actual-expr)
  (actual-val check-failure-actual-val)
  ;; may be #f
  (actual-condition check-failure-actual-condition)
  ;; #f when ACTUAL-CONDITION is #f, otherwise continuation (not escape procedure!)
  (continuation check-failure-continuation)
  ; #f, 'all, 'size or exact positive integer n denoting the nth return
  ; value out of several (0-based) that was wrong
  (pos check-failure-pos)
  ; a matcher, or, if POS is 'all, a list of matchers
  (expected check-failure-expected))

(define-record-discloser :check-failure
  (lambda (f)
    (list 'check-failure
	  (check-failure-test-case f)
	  (list 'actual 
		(check-failure-actual-expr f)
		(or (check-failure-actual-condition f)
		    (check-failure-actual-val f)))
	  (cons 'expected
		(let ((expr (check-failure-expected f)))
		  (if (matcher? expr)
		      (list (matcher-sexpr expr))
		      (map matcher-sexpr expr)))))))

(define-record-type check-exception-failure :check-exception-failure
  (make-check-exception-failure test-case
				actual-expr actual-vals actual-condition criterion)
  check-exception-failure?
  (test-case check-exception-failure-test-case)
  (actual-expr check-exception-failure-actual-expr)
  (actual-vals check-exception-failure-actual-vals)
  ;; may be #f
  (actual-condition check-exception-failure-actual-condition)
  ;; either a procedure or a matcher
  (criterion check-exception-failure-criterion))

(define-record-discloser :check-exception-failure
  (lambda (f)
    (list 'check-exception-failure
	  (check-exception-failure-test-case f)
	  (list 'actual 
		(check-exception-failure-actual-expr f)
		(or (check-exception-failure-actual-condition f)
		    (check-exception-failure-actual-vals f)))
	  (check-exception-failure-criterion f))))

(define (run-test-suite suite)
  (let ((p (current-error-port))
	(cell (make-cell '())))
    (let-fluid
     $failures cell
     (lambda ()
       (let recur ((suite suite))
	 (display "[" p)
	 (cond
	  ((test-suite? suite)
	   (display (test-suite-name suite) p)
	   (newline p)
	   (for-each (lambda (case)
		       (display " (" p)
		       (display (test-case-name case) p)
		       (let-fluid $test-case case
				  (test-case-thunk case))
		       (display ")" p)
		       (newline p))
		     (reverse (test-suite-cases suite))))
	  ((compound-test-suite? suite)
	   (display (compound-test-suite-name suite) p)
	   (newline p)
	   (for-each recur (compound-test-suite-components suite))))
	 (display "]" p)
	 (newline p) (newline p))))

    (let ((failures (reverse (cell-ref cell))))
      (if (null? failures)
	  (begin
	    (display "ALL TESTS SUCCEDED" p)
	    (newline p))
	  (begin
	    (display "FAILURES:" p)
	    (newline p)
	    (for-each report-failure failures)))
      failures)))

(define (failure-test-case f)
  (cond
   ((check-failure? f)
    (check-failure-test-case f))
   ((check-exception-failure? f)
    (check-exception-failure-test-case f))))

(define (report-failure f)
  (let* ((p (current-error-port))
	 (cas (failure-test-case f))
	 (suite (test-case-suite cas)))
      
    (display "Test case " p)
    (display (test-case-name cas) p)
    (display " [" p)
    (display (test-suite-name suite) p)
    (display "] FAILED:" p)
    (newline p)

    (cond
     ((check-failure? f)
      (display "From expression " p)
      (write (check-failure-actual-expr f) p)
      (newline p)
      (let ((expr (check-failure-expected f))
	    (pos (check-failure-pos f)))
	(case pos
	  ((#f)
	   (display "EXPECTED value that " p)
	   (write (matcher-sexpr expr) p))
	  ((all)
	   (display "EXPECTED values that match " p)
	   (write (map matcher-sexpr expr) p))
	  ((size)
	   (display "EXPECTED " p)
	   (let ((l (length expr)))
	     (write l p)
	     (if (= l 1)
		 (display " value" p)
		 (display " values" p))))
	  (else
	   (display "EXPECTED value at " p)
	   (display (+ 1 pos) p)
	   (display "th position that " p) 
	   (write (matcher-sexpr expr) p)))
	(newline p)
	(display "INSTEAD GOT " p))
      (cond
       ((check-failure-actual-condition f)
	=> (lambda (con)
	     (display "exception with condition:" p)
	     (display-condition con p)
	     (display "PREVIEW:" p) (newline p)
	     (display-preview (continuation-preview (check-failure-continuation f)) p)))
       (else
	(write (check-failure-actual-val f) p)
	(newline p))))
     ((check-exception-failure? f)
      (display "From expression " p)
      (write (check-exception-failure-actual-expr f) p)
      (newline p)
      (display "EXPECTED exception" p)
      (let ((crit (check-exception-failure-criterion f)))
	(cond 
	 ((eq? always-true crit))
	 ((matcher? crit)
	  (display " with condition matching " p)
	  (write (matcher-sexpr crit) p))
	 (else
	  (display " with condition matching " p)
	  (write crit p))))
      (newline p)
      (display "INSTEAD got" p)
      (cond
       ((check-exception-failure-actual-condition f)
	=> (lambda (con)
	     (display " exception with condition:" p)
	     (display-condition con p)))
       (else
	(for-each (lambda (val)
		    (display #\space p)
		    (write val p))
		  (check-exception-failure-actual-vals f))
	(newline p)))))
      
    (newline p)))
