;;; "loadfn.scm" --- Capture the name of the file being loaded  -*- Scheme -*-
;; Ivan Shmakov, 2008
;; This code is in public domain

(define $load-filename (make-fluid (make-cell #f)))

(define (with-load-filename filename thunk)
  (let-fluid $load-filename (make-cell filename)
	     thunk))

(define (current-load-filename)
  (fluid-cell-ref $load-filename))

;;; loadfn.scm ends here
