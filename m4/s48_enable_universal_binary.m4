### s48_enable_universal_binary.m4 --- S48_ENABLE_UNIVERSAL_BINARY macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Option to build an universal binary on MacOSX.
AC_DEFUN([S48_ENABLE_UNIVERSAL_BINARY], [dnl
AC_MSG_CHECKING([whether we are building a Universal Binary])
dnl
AC_ARG_ENABLE([universal-binary],
[AC_HELP_STRING([--enable-universal-binary],
		[Build MacOS X Universal Binary])],
	[dnl
	 case $host in
           *darwin* ) S48_BUILD_UNIVERSAL_P="1"
	     AC_DEFINE([BUILD_UNIVERSAL_BINARY], 1,
		       [Define if we are building an OS X Universal Binary.])
	     AC_MSG_RESULT(yes)
           ;;
           * ) AC_MSG_ERROR([--enable-universal-binary only works on Mac OS X])
           ;;
         esac
           ],
   	[dnl
	 S48_BUILD_UNIVERSAL_P="0"
	 AC_MSG_RESULT(no)])])
### s48_enable_universal_binary.m4 ends here
