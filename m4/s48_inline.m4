### s48_inline.m4 --- S48_INLINE macro  -*- Autoconf -*-
# serial 1
dnl
AC_DEFUN([S48_INLINE], [dnl
AC_MSG_CHECKING([for inline keyword])
AC_COMPILE_IFELSE([#include <stdio.h>

inline void f(void)
{
  printf("inlined");
}], [AC_MSG_RESULT([yes])
     AC_DEFINE([HAVE_INLINE], [1], [Define if the C compiler supports the inline keyword])],
    [AC_MSG_RESULT([no])])
])
### s48_inline.m4 ends here
