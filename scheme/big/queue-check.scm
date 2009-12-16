
(define-test-suite queues-tests)

(define-syntax with-queue
  (syntax-rules ()
    ((with-queue (?var) . ?body)
     (let ((?var (make-queue))) . ?body))))

;;; TODO? - move to utility package?
(define-syntax list*
  (syntax-rules (skip)
    ((list* (skip ?expr) . ?rest)
     (begin ?expr
            (list* . ?rest)))
    ((list* ?expr . ?rest)
     (let ((x ?expr))
       (cons x (list* . ?rest))))
    ((list*)
     '())))

(define (stuff-queue! q xs)
  (for-each (lambda (x) (enqueue! q x)) xs))

(define (devour-queue! q)
  (let loop ((acc '()))
    (if (queue-empty? q) ; race condition doesn't matter here
        (reverse acc)
        (loop (cons (dequeue! q) acc)))))

(define (suck-queue! q n)
  (let loop ((acc '())
             (n n))
    (if (or (queue-empty? q)
            (<= n 0))
        (reverse acc)
        (loop (cons (dequeue! q) acc)
              (- n 1)))))

(define-test-case basics queues-tests
  (check (with-queue (q)
                     (enqueue! q 'a)
                     (dequeue! q))
         => 'a)
  (check (with-queue (q)
                     (stuff-queue! q '(a b c a b c))
                     (devour-queue! q))
         => '(a b c a b c))
  (check (with-queue (q)
                     (stuff-queue! q '(a b c a b c))
                     (list* (suck-queue! q 3)
                            (skip (stuff-queue! q '(d e f)))
                            (devour-queue! q)))
         => '((a b c) (a b c d e f)))
  (check (with-queue (q)
                     (stuff-queue! q '(a b c a b c))
                     (list* (devour-queue! q)
                            (maybe-dequeue! q)
                            (skip (stuff-queue! q '(d e f)))
                            (maybe-dequeue! q)
                            (devour-queue! q)))
         => '((a b c a b c)
              #f
              d
              (e f))))

(define-test-case queue-head queues-tests
  (check-exception (with-queue (q) (queue-head q)))
  (check (with-queue (q)
                     (stuff-queue! q '(a b c))
                     (queue-head q))
         => 'a))

(define-test-case queue-length queues-tests
  (for-each
   (lambda (n)
     (check (with-queue (q)
                        (stuff-queue! q (srfi-1:iota n))
                        (queue-length q))
            => n))
   '(0 1 2 3 4 5 6 7 8 9 10)))

(define-test-case delete-from-queue! queues-tests
  (for-each
   (lambda (x)
     (check (with-queue (q)
                        (stuff-queue! q '(a b c a b c))
                        (list* x
                               (delete-from-queue! q x)
                               (devour-queue! q)))
            => (list x
                     (x->boolean (memq x '(a b c)))
                     (append (delq x '(a b c))
                             '(a b c)))))
   '(a b c d))
  (for-each
   (lambda (x)
     (check (with-queue (q)
                        (stuff-queue! q '(a b c a b c))
                        (list* x
                               (delete-from-queue! q x)
                               (skip (stuff-queue! q '(d e f)))
                               (devour-queue! q)))
            => (list x
                     (x->boolean (memq x '(a b c)))
                     (append (delq x '(a b c))
                             '(a b c d e f)))))
   '(a b c d)))

(define-test-case on-queue? queues-tests
  (check
   (map (lambda (x)
          (with-queue (q)
                      (stuff-queue! q '(a b c))
                      (on-queue? q x)))
        '(a b c d))
   => '(#t #t #t #f))
  (check
   (map (lambda (x)
          (with-queue (q)
                      (on-queue? q x)))
        '(a b c d))
   => '(#f #f #f #f)))

(define-test-case queue->list queues-tests
  (check (with-queue (q)
                     (stuff-queue! q '(a b c d e f))
                     (list* (queue->list q)
                            (suck-queue! q 2)
                            (skip (stuff-queue! q '(g h)))
                            (queue->list q)
                            (devour-queue! q)))
         => '((a b c d e f)
              (a b)
              (c d e f g h)
              (c d e f g h))))

(define-test-case list->queue queues-tests
  (check (let ((q (list->queue '(a b c d))))
           (list* (suck-queue! q 2)
                  (skip (stuff-queue! q '(e f g)))
                  (devour-queue! q)))
         => '((a b)
              (c d e f g))))
