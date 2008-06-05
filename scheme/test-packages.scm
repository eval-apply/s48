; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Package definitions for various test suites.

(define-structure base-test (export base-tests)
  (open scheme test-suites
	fluids)
  (files (debug base-check)))

; Random tests, mostly for stuff in scheme/big

(define-structure misc-big-test (export misc-big-tests)
  (open scheme test-suites matchers
	;assembler
	byte-vectors
	ports
	queues
	random
	sort
	big-scheme
	arrays
	dump/restore
	search-trees
	threads
	placeholders
	locks
	interrupts
	mask-types
	masks
	finite-types
	(subset i/o (read-byte))
	(subset i/o-internal (open-input-port? eof-object)))
  (files (big check)))

(define-structure inversion-lists-test (export inversion-lists-tests)
  (open scheme test-suites matchers
	inversion-lists)
  (files (big inversion-list-check)))

(define-structure constant-tables-test (export constant-tables-tests)
  (open scheme test-suites matchers
	constant-tables
	(subset tables (symbol-hash)))
  (files (big constant-table-check)))

(define-structure matchers-test (export matchers-tests)
  (open scheme test-suites matchers)
  (files (big matcher-check)))

(define-structure big-test (export big-tests)
  (open scheme test-suites
	misc-big-test inversion-lists-test constant-tables-test matchers-test)
  (begin
    (define-test-suite big-tests
      (misc-big-tests
       inversion-lists-tests
       constant-tables-tests
       matchers-tests))))

(define-structure sockets-test (export tcp-sockets-tests
				       udp-sockets-tests)
  (open scheme test-suites matchers
	byte-vectors threads
	sockets udp-sockets)
  (files (net socket-check)))

(define-structure tconc-queue-test
  (export tconc-queue-tests)
  (open scheme test-suites matchers tconc-queue
	srfi-34 srfi-42 conditions)
  (files (big tconc-queue-check)))

(define-structure transport-link-cell-test
  (export transport-link-cell-tests)
  (open scheme test-suites matchers primitives
	tconc-queue srfi-42)
  (files (big transport-link-cell-check)))

(define-structure package-mutation-test (export package-mutation-tests)
  (open scheme test-suites
	packages compiler built-in-structures handle conditions
	interfaces defpackage package-mutation)
  (files (env package-mutation-check)))

(define-structure env-test (export env-tests)
  (open scheme test-suites
	package-mutation-test)
  (begin
    (define-test-suite env-tests
      (package-mutation-tests))))
