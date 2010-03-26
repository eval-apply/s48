; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.


(import-lambda-definition-2 current-utc-time () "s48_get_current_time")
(import-lambda-definition-2 timezone-offset () "s48_get_timezone")
(import-lambda-definition-2 export-time->string (time) "s48_time_to_string")

(define-record-type time :time
  (make-time seconds microseconds)
  time?
  (seconds time-seconds)
  (microseconds time-microseconds))

(define-record-discloser :time
  (lambda (time)
    (let ((string (time->string time)))
      (list 'time (substring string 0 (- (string-length string) 1))))))

(define-exported-binding "os-time-type" :time)

(define (time=? time1 time2)
  (and 
   (= (time-seconds time1)
      (time-seconds time2))
   (= (time-microseconds time1)
      (time-microseconds time2))))

(define (time<? time1 time2)
  (if (< (time-seconds time1)
         (time-seconds time2))
      (< (time-microseconds time1)
         (time-microseconds time2))))

(define (time<=? time1 time2)
  (not (time<? time2 time1)))
      
(define (time>? time1 time2)
  (time<? time2 time1))

(define (time>=? time1 time2)
  (not (time<? time1 time2)))

(define (time->string t)
  (os-string->string
   (byte-vector->os-string
    (export-time->string t))))