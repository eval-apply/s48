/* Part of Scheme 48 1.9.  See file COPYING for notices and license.
 *
 * Authors: Mike Sperber, Robert Ransom, Marcus Crestani
 */

/* 
 * For building and linking DLLs on Windows, we need to mark functions
 * the DLL calls in Scheme 48 and vice versa explicitly---and differently
 * depending on whether we're compiling the DLL or Scheme 48 itself.
 *
 * Therefore, on Windows, we assume that __COMPILING_SCHEME48_ITSELF__
 * is defined when Scheme 48 itself is being compiled, and not when
 * we're compiling something external against it.
 */

#if defined(__CYGWIN__) || defined(_WIN32)
#  ifdef __COMPILING_SCHEME48_ITSELF__
#    define S48_EXTERN_ADD_ONS __declspec(dllexport)
#  else
#    define S48_EXTERN_ADD_ONS __declspec(dllimport)
#  endif
#endif

#ifndef S48_EXTERN_ADD_ONS
#  define S48_EXTERN_ADD_ONS
#endif

#define S48_EXTERN extern S48_EXTERN_ADD_ONS

/*
 * We repeat this so we won't have to install sysdep.h.
 */

/* Check for sizeof (void *) */
#define SIZEOF_VOID_P 4

/* Check for the number of bits per byte */
#define BITS_PER_BYTE 8

/* Define if building with BIBOP GC. */
#define S48_GC_BIBOP 1

/* Define if building with two-space GC. */
/* #undef S48_GC_TWOSPACE */

/* Define to 1 if you have the <stdint.h> header file. */
#undef HAVE_STDINT_H

/* Define to 1 if you have the <sys/types.h> header file. */
#undef HAVE_SYS_TYPES_H

typedef unsigned _int16 uint16_t;
typedef unsigned _int32 uint32_t;

#include <stdio.h> /* size_t */
