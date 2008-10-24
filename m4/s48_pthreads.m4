### s48_pthreads.m4 --- S48_PTHREADS macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl must run after S48_DYNAMIC_EXTERNALS
AC_DEFUN([S48_PTHREADS], [dnl
       AC_CHECK_HEADERS([pthread.h],[dnl
         pthreads_done="no"
         AC_MSG_CHECKING([Pthreads support])
	 S48_PTHREAD_TRY_FLAGS([-mt])
	 S48_PTHREAD_TRY_FLAGS([-pthread])
	 S48_PTHREAD_TRY_FLAGS([-pthreads])
	 S48_PTHREAD_TRY_FLAGS([-mthreads])
	 S48_PTHREAD_TRY_FLAGS([-thread])
 	])
       ])
### s48_pthreads.m4 ends here
