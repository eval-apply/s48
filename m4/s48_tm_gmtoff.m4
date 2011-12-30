### s48_tm_gmtoff.m4 --- S48_TM_GMTOFF macro  -*- Autoconf -*-
# serial 1
AC_DEFUN([S48_TM_GMTOFF], [dnl
AC_CHECK_MEMBER(struct tm.tm_gmtoff,
  AC_DEFINE(HAVE_TM_GMTOFF, 1, [Define to 1 if struct tm has field tm_gmtoff]),[],
  [[#include <time.h>]])
])dnl
### s48_tm_gmtoff.m4 ends here
