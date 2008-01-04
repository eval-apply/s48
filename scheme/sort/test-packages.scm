(define-structure sort-test (export sort-tests)
  (open scheme test-suites matchers
	srfi-27
	vector-heap-sort list-merge-sort vector-merge-sort vector-insertion-sort
	sorted)
  (files check))
