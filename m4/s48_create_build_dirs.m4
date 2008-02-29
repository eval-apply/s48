### s48_create_build_dirs.m4 --- S48_CREATE_BUILD_DIRS macro  -*- Autoconf -*-
# serial 1
dnl
AC_DEFUN([S48_CREATE_BUILD_DIRS], [dnl
        mkdir -p c/bibop
        mkdir -p c/unix
	mkdir -p c/net
        mkdir -p c/posix
        mkdir -p c/fake
])dnl
### s48_create_build_dirs.m4 ends here
