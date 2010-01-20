; Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees. See file COPYING.

(define-user-command-syntax 'profile "<command>" "profile execution"
  '(command))

(environment-define! (user-command-environment)
		     'profile
		     profile)
