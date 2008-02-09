### s48_ldflags.m4 --- S48_LDFLAGS macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl
dnl -rdynamic is needed for loading external code
AC_DEFUN([S48_LDFLAGS], [dnl
	AC_MSG_CHECKING([-rdynamic])
	oldLDFLAGS="$LDFLAGS"
	LDFLAGS="$LDFLAGS -rdynamic"
	AC_TRY_RUN([int main() { return 0;}],
		[AC_MSG_RESULT(yes)],
		[AC_MSG_RESULT(no)
			LDFLAGS="$oldLDFLAGS"],
		[AC_MSG_RESULT(no)
			LDFLAGS="$oldLDFLAGS"])
	AC_MSG_CHECKING([LDFLAGS_VM])
	case "$host_os" in
		aix* )
 			if test "$GCC" = "yes"; then
				LDFLAGS_VM="-Xlinker -brtl -Xlinker -bE:$srcdir/c/scheme48.exp"
			else
				LDFLAGS_VM="-brtl -bE:$srcdir/c/scheme48.exp"
			fi
		;;
		* )
			LDFLAGS_VM=
		;;
	esac
 	AC_MSG_RESULT([$LDFLAGS_VM])
])dnl
### s48_ldflags.m4 ends here
