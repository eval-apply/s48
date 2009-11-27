### s48_pthread_try_flags.m4 --- S48_PTHREAD_TRY_FLAGS macro  -*- Autoconf -*-
# serial 1
dnl
AC_DEFUN([S48_PTHREAD_TRY_FLAGS], [
	if test "$pthreads_done" = "no"; then
	  flags_result=""

	  oldCFLAGS="$CFLAGS"
	  CFLAGS="$CFLAGS $1"
	  AC_TRY_RUN([#include <pthread.h>
int
main(void)
{
  pthread_kill(pthread_self(), 0);
}],
	    [flags_result="$1 (compile)"],
	    [CFLAGS="$oldCFLAGS"])

	  oldLDFLAGS="$LDFLAGS"
	  LDFLAGS="$LDFLAGS $1"
	  AC_TRY_RUN([#include <pthread.h>
int
main(void)
{
  pthread_kill(pthread_self(), 0);
}],
		  [flags_result="$flags_result $1 (link)"
		   pthreads_done="yes"],
		  [LDFLAGS="$oldLDFLAGS"])
	if test -n "$flags_result"; then
		AC_MSG_RESULT($flags_result)
	fi
      fi
])
### s48_pthread_try_flags.m4 ends here
