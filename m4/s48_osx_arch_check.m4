### s48_osx_arch_check.m4 --- S48_OSX_ARCH_CHECK macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Tests if it can compile and link with "-arch"-Flag on MacOSX,
dnl keeps the "-arch"-Flag in the CFLAGS and LDFLAGS if test is
dnl successfull.
AC_DEFUN([S48_OSX_ARCH_CHECK], [dnl
AC_MSG_CHECKING([for gcc argument $1])
save_CFLAGS="$CFLAGS"
save_LDFLAGS="$LDFLAGS"
CFLAGS="$CFLAGS -arch $1"
LDFLAGS="$LDFLAGS -arch $1"
compiles=0
links=0
AC_TRY_COMPILE([],[],compiles=1, compiles=0)
AC_TRY_LINK([],[],links=1, links=0)
if test "$links" = "1" -a "$compiles" = "1"; then
  AC_MSG_RESULT([OK])
else
  CFLAGS="$save_CFLAGS"
  LDFLAGS="$save_LDFLAGS"
  AC_MSG_RESULT([failed])
fi
])
### s48_osx_arch_check.m4 ends here
