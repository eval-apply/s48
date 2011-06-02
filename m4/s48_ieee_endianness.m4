### s48_ieee_endianness.m4 --- S48_IEEE_ENDIANNESS macro  -*- Autoconf -*-
# serial 1
dnl
AC_DEFUN([S48_IEEE_ENDIANNESS], [dnl
build_universal="$1"
AC_MSG_CHECKING([IEEE floating-point endianness])
if test "$build_universal" = "1";
then 
  AC_MSG_RESULT([building Universal Binary; using compiler defined macros instead])
else
AC_TRY_RUN([#include <stdio.h>
#include <inttypes.h>

typedef uint32_t word32_t;

typedef union { double d; word32_t word[2]; } double_overlay;

#define DOUBLE_WORD0(x) ((double_overlay*)&(x))->word[0]
#define DOUBLE_WORD1(x) ((double_overlay*)&(x))->word[1]


int
main(void)
{
  double n = 0.3;
	
  /* least significant byte first */
  if ((DOUBLE_WORD0(n) == 0x33333333) && (DOUBLE_WORD1(n) == 0x3fd33333))
    return 0;
  /* most significant byte first */
  else if ((DOUBLE_WORD1(n) == 0x33333333) && (DOUBLE_WORD0(n) == 0x3fd33333))
    return 1;
  else {
    fprintf(stderr, "WARNING: unknown IEEE format; assuming IEEE with least significant byte first\n");
    return 0;
  }
}], ieee_endianness="least first", ieee_endianness="most first", ieee_endianness="least first")
AC_MSG_RESULT([$ieee_endianness])
if test "$ieee_endianness" = "most first"; then
  AC_DEFINE([IEEE_MOST_FIRST], 1, [Define if IEEE doubles are stored with most-significant byte first.])
fi
fi
])dnl
### s48_ieee_endianness.m4 ends here
