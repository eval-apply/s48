; Part of Scheme 48 1.9.  See file COPYING for notices and license.


; Platform-specific constants

(define-structure platform platform-interface
  ;; don't open anything---this is loaded before even SCHEME-LEVEL-0 is available
  (define-all-operators)
  (usual-transforms and cond do let let* or)
  (files ((vm data) platform-64)))
