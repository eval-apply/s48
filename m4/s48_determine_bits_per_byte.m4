### s48_determine_bits_per_byte.m4 --- S48_DETERMINE_BITS_PER_BYTE macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Determines the number of bits per byte
AC_DEFUN([S48_DETERMINE_BITS_PER_BYTE], [dnl
AC_MSG_CHECKING(bits per byte)
AC_CACHE_VAL(ac_cv_sizeof_void_p,
	[AC_TRY_RUN([#include <stdio.h>
		#include <stdlib.h>
		main()
		{
		  unsigned char c = 1;
		  int i = 0;
		  FILE *f=fopen("conftestval", "w");
		  if (!f) exit(1);
		  while (c != 0) {
		    i++;
		    c = c << 1;
		  }
		  fprintf(f, "%d\n", i);
		  exit(0);
		}],
	    ac_cv_bits_per_byte=`cat conftestval`,
	    ac_cv_bits_per_byte=0,
	    AC_MSG_ERROR(failed to compile test program))])
     if test "$ac_cv_bits_per_byte" = "0" -o "$ac_cv_bits_per_byte" = ""; then
       AC_MSG_ERROR([Unable to determine bits per byte, see config.log for details.]);
     fi
     AC_MSG_RESULT($ac_cv_bits_per_byte)
     AC_DEFINE_UNQUOTED(BITS_PER_BYTE, [$ac_cv_bits_per_byte], [Check for the number of bits per byte])
])
### s48_determine_bits_per_byte.m4 ends here
