; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-structure r6rs-records-procedural-test (export r6rs-records-procedural-tests)
  (open scheme test-suites
	r6rs-records-procedural)
  (files record-procedural-check))

(define-structure r6rs-records-syntactic-test (export r6rs-records-syntactic-tests)
  (open scheme test-suites
	r6rs-records-procedural
	r6rs-records-inspection
	r6rs-records-syntactic)
  (files record-syntactic-check))

(define-structure r6rs-records-test (export r6rs-records-tests)
  (open scheme test-suites
	r6rs-records-procedural-test
	r6rs-records-syntactic-test)
  (begin
    (define-test-suite r6rs-records-tests
      (r6rs-records-procedural-tests r6rs-records-syntactic-tests))))

(define-structure r6rs-enums-test (export r6rs-enums-tests)
  (open scheme test-suites
	r6rs-enums)
  (files enum-check))

(define-structure r6rs-lists-test (export r6rs-lists-tests)
  (open scheme test-suites
	r6rs-lists)
  (files list-check))

(define-structure r6rs-reader-test (export r6rs-reader-tests)
  (open scheme test-suites
	srfi-74 ; blobs
	(subset i/o-internal (eof-object))
	exceptions
	extended-ports
	r6rs-reader)
  (files reader-check))

(define-structure r6rs-comparison-test (export r6rs-comparison-tests)
  (open test-suites
        (subset scheme-level-1 (integer? exact? negative? not zero? + - cons
                                vector-length vector-ref append map length
                                define cond let let* if lambda and list quote
                                apply vector string-append string integer->char))
        (with-prefix scheme-level-1 prim:)
        (with-prefix srfi-1 srfi-1:)
        exceptions
        r6rs-lists
        r6rs-base-comparisons
        r6rs-unicode)
  (files comparison-check))

(define-structure r6rs-bytevectors-test (export r6rs-bytevectors-tests 
						ieee-bytevectors-tests  
						string-bytevectors-tests)
  (open scheme test-suites matchers
	(subset srfi-13 (string-contains))
	r6rs-bytevectors)
	(files bytevector-check 
	       bytevector-string-check 
	       bytevector-ieee-check))

(define-structure r6rs-test (export r6rs-tests)
  (open scheme test-suites
	r6rs-records-test r6rs-lists-test r6rs-enums-test r6rs-reader-test
        r6rs-comparison-test r6rs-bytevectors-test)
  (begin
    (define-test-suite r6rs-tests
      (r6rs-records-tests r6rs-lists-tests r6rs-enums-tests r6rs-reader-tests
       r6rs-comparison-tests r6rs-bytevectors-tests))))

