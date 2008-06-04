; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-interface locks-interface
  (export lock?
	  make-lock
	  obtain-lock
	  maybe-obtain-lock
	  release-lock
	  with-lock
	  lock-owner))		;really should be internal

(define-structure locks locks-interface
  (open scheme-level-2 queues
	threads threads-internal
	interrupts
	proposals)
  (optimize auto-integrate)
  (files (big lock)))

(define-structure sort (export sort-list sort-list!)
  (open scheme-level-2
	vector-heap-sort list-merge-sort)
  (begin
    (define (sort-list l obj-<)
      (let ((v (list->vector l)))
	(vector-heap-sort! obj-< v)
	(vector->list v)))
    (define (sort-list! l obj-<)
      (list-merge-sort! obj-< l))))
