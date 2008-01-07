; Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees. See file COPYING.


; Platform-specific constants

(define-structure platform platform-interface
  ;; don't open anything---this is loaded before even SCHEME-LEVEL-0 is available
  (define-all-operators)
  (usual-transforms and cond do let let* or)
  (files ((vm data) platform-64)))
