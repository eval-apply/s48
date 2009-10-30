; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define (symbol=?/2 a b)
  (if (or (not (symbol? a))
	  (not (symbol? b)))
      (assertion-violation symbol=? "non-symbol argument" a b))
  (eq? a b))

(define (boolean=?/2 a b)
  (if (or (not (boolean? a))
	  (not (boolean? b)))
      (assertion-violation boolean=? "non-boolean argument" a b))
  (eq? a b))

(define-n-ary-comparison symbol=? symbol=?/2)
(define-n-ary-comparison boolean=? boolean=?/2)

(define-n-ary-comparison char=? prim:char=?)
(define-n-ary-comparison char<? prim:char<?)
(define-n-ary-comparison char>? prim:char>?)
(define-n-ary-comparison char<=? prim:char<=?)
(define-n-ary-comparison char>=? prim:char>=?)
(define-n-ary-comparison string=? prim:string=?)
(define-n-ary-comparison string<? prim:string<?)
(define-n-ary-comparison string>? prim:string>?)
(define-n-ary-comparison string<=? prim:string<=?)
(define-n-ary-comparison string>=? prim:string>=?)

