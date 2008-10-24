### s48_misaligned_doubles.m4 --- S48_MISALIGNED_DOUBLES macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl must run after S48_DYNAMIC_EXTERNALS
AC_DEFUN([S48_MISALIGNED_DOUBLES], [dnl
	if test "$GCC" = "yes"; then
		AC_MSG_CHECKING([-munaligned-doubles])
		oldCFLAGS="$CFLAGS"
		CFLAGS="$CFLAGS -munaligned-doubles"
		AC_TRY_RUN([int main() { return 0;}],
			[AC_MSG_RESULT(yes)
				DYNAMIC_EXTERNALS_CFLAGS="$DYNAMIC_EXTERNALS_CFLAGS -munaligned-doubles"],
			[AC_MSG_RESULT(no)
				CFLAGS="$oldCFLAGS"],
			[AC_MSG_RESULT(no)
				CFLAGS="$oldCFLAGS"])
	fi
])dnl
### s48_misaligned_doubles.m4 ends here
