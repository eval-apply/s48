### s48_native_code.m4 --- S48_NATIVE_CODE macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_NATIVE_CODE], [dnl
dnl assumes that S48_PICK_GC already ran
AC_MSG_CHECKING([native-code compiler support])
AC_ARG_ENABLE([native-code],
[AC_HELP_STRING([--enable-native code],
		[Include support for native-code compiler])],
	[dnl 
         case $GC_OBJS in
	   '${GC_TWOSPACE_OBJS}' )
		 case `uname -m` in
		   i?86 )
			 AC_MSG_RESULT([x86])
			 ASM_OBJECTS='${X86_ASM_OBJECTS}'
			 AC_CHECK_FUNCS(sigaltstack, HAVE_SIGALTSTACK=1, HAVE_SIGALTSTACK=0)
			 if test "$HAVE_SIGALTSTACK" = 0; then
				 AC_MSG_ERROR([Your system lacks sigaltstack])
			 fi
			 AC_MSG_CHECKING([assembler style])
			 case `uname` in
			   Darwin )
			     AC_MSG_RESULT([Darwin])
			     ASM_STYLE='darwin' ;;
			   * )
			     AC_MSG_RESULT([GNU(hopefully)])
			     ASM_STYLE='gnu' ;;
			 esac ;;
		   * )
		     AC_MSG_RESULT([no])
		     ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
		 esac;;
	   * )
	     AC_MSG_RESULT([no (picked GC not compatible)])
	     ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
	 esac],
   	[dnl
	 AC_MSG_RESULT([no])
	 ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
        ]
)
AC_SUBST(ASM_OBJECTS)
AC_SUBST(ASM_STYLE)
])dnl
### s48_native_code.m4 ends here
