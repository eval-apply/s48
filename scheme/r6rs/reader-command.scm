; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; R6RS Scheme reader with ##

; ## should evaluate to the last REPL result.

(define-sharp-macro #\#
  (lambda (c port)
    (read-char port)
    ((current-sharp-sharp) port)))

; Read a single form, allowing ## as a way to refer to last command
; output.
(define (read-form port)
  (with-sharp-sharp (make-node (get-operator 'quote)
			       (list 'quote (focus-object)))
    (lambda () (get-datum port))))
