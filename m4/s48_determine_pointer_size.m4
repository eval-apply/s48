### s48_determine_pointer_size.m4 --- S48_DETERMINE_POINTER_SIZE macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Determines the size of a pointer.
AC_DEFUN([S48_DETERMINE_POINTER_SIZE], [dnl
dnl Our own version of AC_CHECK_SIZEOF([void *])
AC_MSG_CHECKING(size of void *)
AC_CACHE_VAL(ac_cv_sizeof_void_p,
	[AC_TRY_RUN([#include <stdio.h>
		#include <stdlib.h>
		main()
		{
		  FILE *f=fopen("conftestval", "w");
		  if (!f) exit(1);
		  fprintf(f, "%d\n", (int)sizeof(void *));
		  exit(0);
		}],
	    ac_cv_sizeof_void_p=`cat conftestval`,
	    ac_cv_sizeof_void_p=0,
	    AC_MSG_ERROR(failed to compile test program))])
     if test "$ac_cv_sizeof_void_p" = "0" -o "$ac_cv_sizeof_void_p" = ""; then
       AC_MSG_ERROR([Unable to determine sizeof (void *), see config.log for details.]);
     fi
     AC_MSG_RESULT($ac_cv_sizeof_void_p)
     AC_DEFINE_UNQUOTED(SIZEOF_VOID_P, [$ac_cv_sizeof_void_p], [Check for sizeof (void *)])
])
### s48_determine_pointer_size.m4 ends here
