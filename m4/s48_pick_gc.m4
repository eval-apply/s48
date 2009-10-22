### s48_pick_gc.m4 --- S48_PICK_GC macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_PICK_GC], [dnl
AC_ARG_ENABLE([gc],
[AC_HELP_STRING([--enable-gc=GC],
                [choose garbage collector (twospace, bibop), default is twospace])],
              [dnl
                case $enableval in
                  twospace )
			AC_DEFINE([S48_GC_TWOSPACE], 1, [Define if building with two-space GC.])
			GC_OBJS='${GC_TWOSPACE_OBJS}' ;;
                  bibop )
			AC_DEFINE([S48_GC_BIBOP], 1, [Define if building with BIBOP GC.])
			GC_OBJS='${GC_BIBOP_OBJS}' ;;
                  * ) AC_MSG_ERROR([Invalid argument to --enable-gc]) ;;
		esac
	      ],
	      [AC_DEFINE([S48_GC_BIBOP], 1, [Define if building with BIBOP GC.])
	       GC_OBJS='${GC_BIBOP_OBJS}'])dnl
])dnl
AC_SUBST(S48_GC_TWOSPACE)
AC_SUBST(S48_GC_BIBOP)
])
### s48_pick_gc.m4 ends here
