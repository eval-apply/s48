; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Really poor man's version

(define (debug-message . stuff)
  (for-each (lambda (thing)
	      (write thing))
	    stuff)
  (newline))
