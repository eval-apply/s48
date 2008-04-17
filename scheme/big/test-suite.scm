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
     (check (and ?actual #t) => #t))
    ((check ?actual => ?expected)
     (check ?actual (=> equal?) ?expected))
    ((check ?actual (=> ?equal?) ?expected)
     (let ((expected ?expected)
	   (equal? ?equal?))

       (call-with-current-continuation
	(lambda (exit)
	  (with-exception-handler
	   (lambda (c)
	     (primitive-cwcc
	      (lambda (cont)
		(register-failure!
		 (make-check-failure (fluid $test-case)
				     '?actual #f c cont '?expected expected equal?))))
	     (exit))
	   (lambda ()
	     (let ((actual ?actual))
	       (if (not (equal? actual expected))
		   (register-failure!
		    (make-check-failure (fluid $test-case)
					'?actual actual #f #f '?expected expected equal?))))))))))))

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
     (let ((matcher ?matcher))
       
       (call-with-current-continuation
	(lambda (exit)
	  (with-exception-handler
	   (lambda (c)
	     (primitive-cwcc
	      (lambda (cont)
		(register-failure!
		 (make-check-failure (fluid $test-case)
				     '?actual #f c cont matcher #f #f))))
	     (exit))
	   (lambda ()
	     (let ((actual ?actual))
	       (if (not (matches? matcher actual))
		   (register-failure!
		    (make-check-failure (fluid $test-case)
					'?actual actual #f #f matcher #f #f))))))))))))

(define-syntax check-exception-that
  (syntax-rules ()
    ((check-exception-that ?actual ?matcher)
     (let ((matcher ?matcher))
       (guard
	(c
	 ((not (matches? matcher c))
	  (register-failure!
	   (make-check-exception-failure (fluid $test-case)
					 '?actual #f c matcher)))
	 (else (values)))
	
	(let ((actual ?actual))
	  (register-failure!
	   (make-check-exception-failure (fluid $test-case)
					 '?actual actual #f matcher))))))))

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
		      expected expected-val
		      equal?-proc)
  check-failure?
  (test-case check-failure-test-case)
  (actual-expr check-failure-actual-expr)
  (actual-val check-failure-actual-val)
  ;; may be #f
  (actual-condition check-failure-actual-condition)
  ;; #f when ACTUAL-CONDITION is #f, otherwise continuation (not escape procedure!)
  (continuation check-failure-continuation)
  ;; either an S-expression representing the expected expression or a matcher
  (expected check-failure-expected)
  (expected-val check-failure-expected-val)
  (equal?-proc check-failure-equal?-proc))

; is EXPR a literal whose value is VAL?
(define (literal-of? expr val)
  (or (equal? val expr)
      (and (pair? expr)
	   (eq? 'quote (car expr))
	   (pair? (cdr expr))
	   (equal? val (cadr expr)))))

(define-record-discloser :check-failure
  (lambda (f)
    (list 'check-failure
	  (check-failure-test-case f)
	  (list 'actual 
		(check-failure-actual-expr f)
		(or (check-failure-actual-condition f)
		    (check-failure-actual-val f)))
	  (cons 'expected
		(let ((expr (check-failure-expected f))
		      (val (check-failure-expected-val f)))
		  (cond
		   ((matcher? expr) (list (matcher-sexpr expr)))
		   ((literal-of? expr val) (list val))
		   (else (list expr val)))))
	  (check-failure-equal?-proc f))))

(define-record-type check-exception-failure :check-exception-failure
  (make-check-exception-failure test-case
				actual-expr actual-val actual-condition criterion)
  check-exception-failure?
  (test-case check-exception-failure-test-case)
  (actual-expr check-exception-failure-actual-expr)
  (actual-val check-exception-failure-actual-val)
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
		    (check-exception-failure-actual-val f)))
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
  (let ((p (current-error-port)))
    (let* ((cas (failure-test-case f))
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
	(let ((expr (check-failure-expected f))
	      (val (check-failure-expected-val f)))
	  (display " EXPECTED value " p)
	  (if (matcher? expr)
	      (begin
		(display "THAT " p)
		(write (matcher-sexpr expr) p))
	      (begin
		(write val p)
		(if (not (literal-of? expr val))
		    (begin
		      (display " of " p)
		      (write expr p))))))
	(newline p)
	(display "INSTEAD got " p)
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
	(display " EXPECTED exception" p)
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
	(display "INSTEAD got " p)
	(cond
	 ((check-exception-failure-actual-condition f)
	  => (lambda (con)
	       (display "exception with condition:" p)
	       (display-condition con p)))
	 (else
	  (write (check-exception-failure-actual-val f) p)
	  (newline p)))))
      
      (newline p))))
