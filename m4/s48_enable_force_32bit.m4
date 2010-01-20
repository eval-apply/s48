### s48_enable_force_32bit.m4 --- S48_ENABLE_FORCE_32BIT macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Force to use 32bit implementation.
AC_DEFUN([S48_ENABLE_FORCE_32BIT], [dnl
AC_MSG_CHECKING([whether we must build a 32bit binary])
dnl
AC_ARG_ENABLE([force-32bit],
[AC_HELP_STRING([--enable-force-32bit],
		[Build a 32bit binary on architectures where this is not the default])],
    [if test "$enable_force_32bit" != no; then
         S48_FORCE_32_P="1"
	 BIT_SUFFIX="32"
	 dnl For now only a Linux/AMD x86_64 version:
	 case "$host" in
		x86_64-*-linux-gnu )
	         CFLAGS="${CFLAGS} -m32";
		 LDFLAGS="${LDFLAGS} -m32";
		;;
                *darwin* ) dnl AC_MSG_RESULT([Found Darwin, will check later.])
                ;;
		* ) AC_MSG_ERROR([Don't know how to build a 32bit binary on this architecture])
		;;
	 esac
	 AC_DEFINE([BUILD_32BIT], 1,
		   [Define if we are building a 32bit binary on architectures where this is not the default.])
	 AC_MSG_RESULT(yes)
      else
         S48_FORCE_32_P="0"
	 AC_MSG_RESULT(no)
      fi],
   	[dnl
         S48_FORCE_32_P="0"
	 AC_MSG_RESULT(no)])])
### s48_enable_force_32bit.m4 ends here
