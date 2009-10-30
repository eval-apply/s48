; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-n-ary-normalizing-comparison char-ci=? char-foldcase prim:char=?)
(define-n-ary-normalizing-comparison char-ci<? char-foldcase prim:char<?)
(define-n-ary-normalizing-comparison char-ci>? char-foldcase prim:char>?)
(define-n-ary-normalizing-comparison char-ci<=? char-foldcase prim:char<=?)
(define-n-ary-normalizing-comparison char-ci>=? char-foldcase prim:char>=?)

(define-n-ary-normalizing-comparison string-ci=? string-foldcase prim:string=?)
(define-n-ary-normalizing-comparison string-ci<? string-foldcase prim:string<?)
(define-n-ary-normalizing-comparison string-ci>? string-foldcase prim:string>?)
(define-n-ary-normalizing-comparison string-ci<=? string-foldcase prim:string<=?)
(define-n-ary-normalizing-comparison string-ci>=? string-foldcase prim:string>=?)
