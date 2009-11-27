### s48_pic_option_name.m4 --- S48_PIC_OPTION_NAME macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Determine the name of compiler option for generating position
dnl independent code.
AC_DEFUN([S48_PIC_OPTION_NAME], [dnl
	AC_MSG_CHECKING([how to compile position independent code])
	case "$host_os" in
		solaris* )
		   if test "$GCC" = "yes"; then
			PIC="-fPIC"
		   else
			# for SUN's compiler
			PIC="-KPIC"
		   fi
		;;
		darwin*|macosx* )
		   # Code on this platform is PIC by default
		   PIC=""
		;;
		*)
 	           PIC="-fPIC"
		;;
	esac
	if test "$PIC" = ""; then
	   AC_MSG_RESULT(no extra option necessary)
  	else
	   AC_MSG_RESULT($PIC)
	fi
])dnl
### s48_pic_option_name.m4 ends here
