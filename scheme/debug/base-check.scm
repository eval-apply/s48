; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Tests for stuff in the base language.

(define-test-suite base-tests)

; adapted from the R6RS document
(define-test-case quasiquote base-tests
  (check `(list ,(+ 1 2) 4) => '(list 3 4))
  (check (let ((name 'a)) `(list ,name ',name)) 
	 => '(list a (quote a)))
  (check `(a ,(+ 1 2) ,@(map abs '(4 -5 6)) b)
	 =>  '(a 3 4 5 6 b))
  (check `((foo ,(- 10 3)) ,@(cdr '(c)) . ,(car '(cons)))
	 => '((foo 7) . cons))
  (check `#(10 5 ,(even? 4) ,@(map even? '(2 3 5 7)) 8)
	 => '#(10 5 #t #t #f #f #f 8))
  (check (let ((name 'foo))
	   `((unquote name name name)))
	 => '(foo foo foo))
  (check (let ((name '(foo)))
	   `((unquote-splicing name name name)))
	 => '(foo foo foo))
  (check (let ((q '((append x y) (even? 9))))
	   ``(foo ,,@q)) 
	 => '`(foo (unquote (append x y) (even? 9))))
  (check (let ((x '(2 3))
	       (y '(4 5)))
	   `(foo (unquote (append x y) (even? 9))))
	 => '(foo (2 3 4 5) #f))

  (check `(a `(b ,(+ 1 2) ,(foo ,(+ 1 3) d) e) f)
	 => '(a `(b ,(+ 1 2) ,(foo 4 d) e) f))
  (check (let ((name1 'x)
	       (name2 'y))
	   `(a `(b ,,name1 ,',name2 d) e))
	 => '(a `(b ,x ,'y d) e)))

