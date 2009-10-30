/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

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

#include <stdio.h> /* size_t */
