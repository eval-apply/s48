### s48_glib.m4 --- S48_GLIB macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_GLIB], [dnl
AC_ARG_ENABLE([glib],
[AC_HELP_STRING([--enable-glib],
                [Use the glib event loop])],
    [if test "$enable_glib" != no; then
	 dnl Check for glib-2.0
  	 PKG_CHECK_MODULES(GLIB, glib-2.0, AC_DEFINE(HAVE_GLIB), AC_MSG_WARN(glib-2.0 not found))
	 dnl Set GLIB flags
         LIBS="$LIBS $GLIB_LIBS"
         CFLAGS="$CFLAGS $GLIB_CFLAGS"
         dnl Check if we still are able to compile, link, and run with glib's build options
	 AC_MSG_CHECKING([whether the GLIB flags work])
	 AC_TRY_RUN([int main() { return 0;}], [AC_MSG_RESULT([yes])], [AC_MSG_ERROR(Failed to compile with GLIB flags.)], [])
    fi])
  ])
### s48_glib.m4 ends here
