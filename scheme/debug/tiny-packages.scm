; Part of Scheme 48 1.9.  See file COPYING for notices and license.

; (link-simple-system '(debug tiny) 'start tiny-system)

(define-structure tiny-system (export start)
  (define-all-operators)
  (usual-transforms and cond do let let* or)
  (files tiny))
