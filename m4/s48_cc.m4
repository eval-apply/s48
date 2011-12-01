### s48_cc.m4 --- S48_CC macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl On AIX, we need xlc_r or cc_r if not explicitly set
AC_DEFUN([S48_CC], [dnl
  case "$target" in
    *-*-aix*) dnl
	if test -z "$CC" ; then
	  AC_CHECK_PROGS(CC,cc_r xlc_r cc)
	fi
    ;;
esac
])
### s48_cc.m4 ends here
