; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-interface r6rs-base-comparisons-interface
  (export symbol=? boolean=?
	  char=? char<? char>? char<=? char>=?
	  string=? string<? string>? string<=? string>=?))

(define-structure r6rs-base-comparisons r6rs-base-comparisons-interface
  (open (modify scheme (hide char=? char<? char>? char<=? char>=?
			     string=? string<? string>? string<=? string>=?))
	(modify scheme (prefix prim:))
	exceptions
	r6rs-n-ary-comparisons)
  (files base-comparison))
			     
(define-interface r6rs-records-procedural-interface
  (export make-record-type-descriptor
	  record-type-descriptor?
	  make-record-constructor-descriptor
	  record-constructor record-predicate
	  record-accessor record-mutator))

(define-interface r6rs-records-inspection-interface
  (export record-type-name
	  record-type-parent
	  record-type-sealed?
	  record-type-uid
	  record-type-generative?
	  record-type-field-names
	  record-type-opaque?
	  record-field-mutable?

	  record? record-rtd))

(define-interface r6rs-records-internal-interface
  (export retrofit-record-type!
	  nongenerative-record-types
	  delete-nongenerative-record-type))

(define-structures ((r6rs-records-procedural r6rs-records-procedural-interface)
		    (r6rs-records-inspection r6rs-records-inspection-interface)
		    (r6rs-records-internal r6rs-records-internal-interface))
  (open scheme
	(subset util (unspecific))
	(subset features (make-immutable!))
	(modify record-types (hide record-accessor))
	define-record-types
	(modify records (prefix primitive:))
	r6rs-lists
	exceptions
	tables
	(subset command-state (user-context-accessor user-context-modifier))
	locks)
  (optimize auto-integrate)
  (files record-procedural))

(define-structure r6rs-records-commands (export)
  (open scheme
	r6rs-records-procedural r6rs-records-inspection r6rs-records-internal
	(subset command-processor (define-user-command-syntax
				    user-command-environment))
	(subset command-state (command-output))
	(subset environments (environment-define!)))
  (files record-command))

(define-interface r6rs-records-syntactic-interface
  (export ((define-record-type record-type-descriptor record-constructor-descriptor)
	   :syntax)))

(define-interface r6rs-records-syntactic-internal-interface
  (export (define-retrofitted-record-type :syntax)))

(define-structures ((r6rs-records-syntactic r6rs-records-syntactic-interface)
		    (r6rs-records-syntactic-internal r6rs-records-syntactic-internal-interface))
  (open scheme
	(subset primitives (checked-record-ref checked-record-set! record))
	r6rs-records-procedural
	r6rs-records-internal
	loopholes types)
  (for-syntax (open scheme exceptions))
  (files record-syntactic))

(define-interface r6rs-conditions-interface
  (export condition
	  condition?
	  simple-conditions
	  condition-predicate
	  condition-accessor
	  define-condition-type
	  (&condition :syntax)
	  (&message :syntax)
	  make-message-condition
	  message-condition?
	  condition-message
	  (&warning :syntax)
	  make-warning
	  warning?
	  (&serious :syntax)
	  make-serious-condition
	  serious-condition?
	  (&error :syntax)
	  make-error
	  error?
	  (&violation :syntax)
	  make-violation
	  violation?
	  (&non-continuable :syntax)
	  make-noncontinuable-violation
	  non-continuable-violation?
	  (&implementation-restriction :syntax)
	  make-implementation-restriction-violation
	  implementation-restriction-violation?
	  (&lexical :syntax)
	  make-lexical-violation
	  lexical-violation?
	  (&syntax :syntax)
	  make-syntax-violation
	  syntax-violation?
	  (&undefined :syntax)
	  make-undefined-violation
	  undefined-violation?
	  (&assertion :syntax)
	  make-assertion-violation
	  assertion-violation?
	  (&irritants :syntax)
	  make-irritants-condition
	  irritants-condition?
	  condition-irritants
	  (&who :syntax)
	  make-who-condition
	  who-condition?
	  condition-who))

(define-structure r6rs-conditions r6rs-conditions-interface
  (open scheme
	r6rs-records-syntactic
	r6rs-records-syntactic-internal
	(subset record-types (define-record-discloser))
	(modify conditions (prefix rts:))
	(subset conditions (condition
			    condition?
			    simple-conditions
			    condition-predicate
			    condition-accessor
			    make-message-condition
			    message-condition?
			    condition-message
			    make-warning
			    warning?
			    make-serious-condition
			    serious-condition?
			    make-error
			    error?
			    make-violation
			    violation?
			    make-noncontinuable-violation
			    non-continuable-violation?
			    make-implementation-restriction-violation
			    implementation-restriction-violation?
			    make-lexical-violation
			    lexical-violation?
			    make-syntax-violation
			    syntax-violation?
			    make-undefined-violation
			    undefined-violation?
			    make-assertion-violation
			    assertion-violation?
			    make-irritants-condition
			    irritants-condition?
			    condition-irritants
			    make-who-condition
			    who-condition?
			    condition-who)))
  (files condition))

(define-interface r6rs-unicode-interface
  (compound-interface unicode-normalizations-interface
		      (export char-titlecase
			      char-title-case?
			      char-foldcase
			      string-upcase string-downcase
			      string-foldcase
			      string-titlecase)
		      (export char-ci=? char-ci<? char-ci>? char-ci<=? char-ci>=?
			      string-ci=? string-ci<? string-ci>? string-ci<=? string-ci>=?)
		      (export char-general-category)))

(define-structure r6rs-unicode r6rs-unicode-interface
  (open (modify scheme (hide char-ci<=? char-ci<? char-ci=? char-ci>=? char-ci>?
			     string-ci<=? string-ci<? string-ci=? string-ci>=? string-ci>?))
	(modify scheme (prefix prim:))
	unicode-normalizations
	(subset unicode-char-maps (char-titlecase
				   char-title-case?
				   char-foldcase
				   string-upcase string-downcase
				   string-foldcase
				   string-titlecase

				   general-category-symbol))
	(modify unicode-char-maps
		(rename (char-general-category s48:char-general-category))
		(expose char-general-category))
	r6rs-n-ary-comparisons)
  (files unicode-comparison)
  (begin
    ;; R6RS uses a symbol instead of an enumeration
    (define (char-general-category c)
      (general-category-symbol (s48:char-general-category c)))))

(define-interface r6rs-lists-interface
  (export find
	  for-all exists
	  filter partition
	  fold-left fold-right
	  remp remove remv remq
	  memp member memv memq
	  assp assoc assv assq
	  cons*))

(define-structure r6rs-lists r6rs-lists-interface
  (open scheme
	exceptions)
  (files list))

(define-interface r6rs-enums-interface
  (export make-enumeration
	  enum-set-universe
	  enum-set-indexer
	  enum-set-constructor
	  enum-set->list
	  enum-set-member?
	  enum-set=?
	  enum-set-subset?
	  enum-set-union
	  enum-set-intersection
	  enum-set-difference
	  enum-set-complement
	  enum-set-projection
	  (define-enumeration :syntax)))

(define-structure r6rs-enums r6rs-enums-interface
  (open scheme
	big-util
	(modify enum-sets (prefix big:))
	(modify enum-sets-internal (prefix big:))
	constant-tables
	(subset tables (symbol-hash))
	(subset names (desyntaxify))
	code-quotation)
  (files enum))

(define-interface r6rs-sorting-interface
  (export list-sort
	  vector-sort
	  vector-sort!))

(define-structure r6rs-sorting r6rs-sorting-interface
  (open scheme
	(modify sorting (prefix olin:)))
  (begin
    (define list-sort olin:list-stable-sort)
    (define vector-sort olin:vector-stable-sort)
    (define vector-sort! olin:vector-sort!)))

(define-structures ((r6rs-reader (export get-datum))
		    (r6rs-reader-internals (export define-sharp-macro 
						   reading-error)))
  (open (modify scheme (hide read))
	conditions exceptions
	byte-vectors
	unicode-char-maps
	(subset primitives (make-immutable!))
	(subset silly (reverse-list->string)))
  (files reader)
  (optimize auto-integrate))

(define-structure r6rs-reader-command (export read-form)
  (open (modify scheme (hide read))
	r6rs-reader
	r6rs-reader-internals
	conditions exceptions
	(subset command-processor (with-sharp-sharp current-sharp-sharp))
	nodes command-state)
  (files reader-command)
  (optimize auto-integrate))

(define-structure r6rs-equal (export equal?)
  (open (modify scheme-level-1 (hide equal?))
        byte-vectors)
  (files equal)
  (optimize auto-integrate))

(define-structure r6rs-control (export when unless case-lambda)
  (open scheme-level-2
        srfi-16)
  (files control))

; Utilities

(define-interface r6rs-n-ary-comparisons-interface
  (export compare-n-ary define-n-ary-comparison))

(define-structure r6rs-n-ary-comparisons r6rs-n-ary-comparisons-interface
  (open scheme
	r6rs-lists
	exceptions)
  (files n-ary-comparison))
