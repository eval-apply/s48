

(define-record-type pair :pair
  (cons car cdr)
  (car int32 car)
  (cdr pair cdr set-cdr!))

(define null (unspecific))

(define (null? x)
  (eq? x null))

(define (init)
  (set! null (cons 0 null)))

(define (member? list x)
  (let loop ((list list))
    (cond ((null? list)
	   #f)
	  ((= x (car list))
	   #t)
	  (else
	   (loop (cdr list))))))

(define (reverse! list)
  (if (or (null? list)
	  (null? (cdr list)))
      list
      (let loop ((list list) (prev null))
	(let ((next (cdr list)))
	  (set-cdr! list prev)
	  (if (null? next)
	      list
	      (loop next list))))))


