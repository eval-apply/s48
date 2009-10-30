; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-n-ary-comparison char-ci=? char? char-foldcase prim:char=?)
(define-n-ary-comparison char-ci<? char? char-foldcase prim:char<?)
(define-n-ary-comparison char-ci>? char? char-foldcase prim:char>?)
(define-n-ary-comparison char-ci<=? char? char-foldcase prim:char<=?)
(define-n-ary-comparison char-ci>=? char? char-foldcase prim:char>=?)

(define-n-ary-comparison string-ci=? string? string-foldcase prim:string=?)
(define-n-ary-comparison string-ci<? string? string-foldcase prim:string<?)
(define-n-ary-comparison string-ci>? string? string-foldcase prim:string>?)
(define-n-ary-comparison string-ci<=? string? string-foldcase prim:string<=?)
(define-n-ary-comparison string-ci>=? string? string-foldcase prim:string>=?)
