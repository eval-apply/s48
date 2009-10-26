
(define-syntax when
  (syntax-rules ()
    ((when expr body ...)
     (if expr (begin body ...)))))

(define-syntax unless
  (syntax-rules ()
    ((unless expr body ...)
     (if (not expr) (begin body ...)))))
