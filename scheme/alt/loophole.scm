; Part of Scheme 48 1.9.  See file COPYING for notices and license.


(define-syntax loophole
  (syntax-rules ()
    ((loophole ?type ?form)
     (begin (lambda () ?type)    ;Elicit unbound-variable warnings, etc.
	    ?form))))
    
