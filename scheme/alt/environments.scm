; Part of Scheme 48 1.9.  See file COPYING for notices and license.


(define (*structure-ref struct name)
  (eval name (interaction-environment)))

