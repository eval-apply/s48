; Copyright (c) 1993-2000 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Generate filenames.make from *-packages.scm.

; Define DEFINE-STRUCTURE and friends
(for-each load
	  '("scheme/bcomp/module-language.scm"
	    "scheme/alt/dummy-interface.scm"
	    "scheme/alt/config.scm"
	    "scheme/env/flatload.scm"))

; The following bogus structures are required in order to load
; scheme/more-interfaces.scm.
(define ascii      (structure (make-simple-interface 'ascii      '())))
(define bitwise    (structure (make-simple-interface 'bitwise    '())))
(define vm-data    (structure (make-simple-interface 'vm-data    '())))
(define enumerated (structure (make-simple-interface 'enumerated '())))
(define tables     (structure (make-simple-interface 'tables     '())))
(define cells      (structure (make-simple-interface 'cells      '())))

; The following loads are unnecessary; they only serve to suppress
; annoying "undefined" warnings for interfaces.
(for-each load
	  '("scheme/interfaces.scm"
	    "scheme/vm/shared-interfaces.scm"
	    "scheme/more-interfaces.scm"))

(load-configuration "scheme/packages.scm")

; The following defines are unnecessary; they only serve to suppress
; annoying "undefined" warnings for some forward references.
(define methods 0) 
(define tables 0) 

(flatload linker-structures)

(define q-f (all-file-names link-config)) 

; (display "Initial structures") (newline)
(flatload initial-structures)

(define scheme (make-scheme environments evaluation))

(define initial-system
  (structure (export)
    (open ;; Cf. initial.scm
	  (make-initial-system scheme (make-mini-command scheme))
	  module-system
	  ensures-loaded
	  for-reification))) ;foo...

(define i-f (all-file-names initial-system))

; (display "Usual structures") (newline)
(flatload usual-structures)

(define u-f (all-file-names usual-features initial-system))

(write-file-names "build/filenames.make"      
		  'initial-files i-f
		  'usual-files u-f
		  'linker-files q-f)

