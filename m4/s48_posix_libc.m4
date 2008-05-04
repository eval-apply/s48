### s48_posix_libc.m4 --- S48_POSIX_LIBC macro  -*- Autoconf -*-
# serial 1
AC_DEFUN([S48_POSIX_LIBC], [dnl
echo checking for RISC/OS POSIX library lossage
if test -f /usr/posix/usr/lib/libc.a; then
  LIBS="${LIBS} /usr/posix/usr/lib/libc.a"
fi
])dnl
### s48_posix_libc.m4 ends here
