; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-interface r6rs-unicode-interface
  (compound-interface unicode-normalizations-interface
		      (export char-titlecase
			      char-title-case?
			      char-foldcase
			      string-upcase string-downcase
			      string-foldcase
			      string-titlecase)
		      (export char-general-category)))

(define-structure r6rs-unicode r6rs-unicode-interface
  (open scheme
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
		(expose char-general-category)))
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
	code-quote)
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

-