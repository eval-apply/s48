; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Author: Harald Glab-Plhak

;; test for the new ffi

(define-test-suite ffi-buf-tests)

(define-test-case ffi-local-bufs ffi-buf-tests
  (check (external-ffi-make-local-buf))
  (check (external-ffi-free-local-buf))
  (check (external-ffi-free-local-buf-1))
  (check (external-ffi-free-local-buf-2))
  (check (external-ffi-free-local-buf-3)))
