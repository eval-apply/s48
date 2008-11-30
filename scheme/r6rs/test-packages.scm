; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

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

(define-structure r6rs-test (export r6rs-tests)
  (open scheme test-suites
	r6rs-lists-test r6rs-enums-test r6rs-reader-test)
  (begin
    (define-test-suite r6rs-tests
      (r6rs-lists-tests r6rs-enums-tests r6rs-reader-tests))))

