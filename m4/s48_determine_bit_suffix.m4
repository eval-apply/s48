### s48_determine_bit_suffix.m4 --- S48_DETERMINE_BIT_SUFFIX macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Determines the number of bits of desired build.
AC_DEFUN([S48_DETERMINE_BIT_SUFFIX], [dnl
     AC_MSG_CHECKING([for BIT_SUFFIX])
     if test $BIT_SUFFIX; then
       AC_MSG_RESULT([You forced BIT_SUFFIX to be $BIT_SUFFIX.])
     else
       BIT_SUFFIX=`expr $ac_cv_sizeof_void_p \* $ac_cv_bits_per_byte`
       AC_MSG_RESULT($BIT_SUFFIX)
     fi
     AC_DEFINE_UNQUOTED(WORDSIZE, [$BIT_SUFFIX], [Check for number of bits in a word])
])
### s48_determine_bit_suffix.m4 ends here
