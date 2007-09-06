/* Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

#include "utils.h"
#include "gc_config.h"
#include <stdarg.h>
#include <stdlib.h>

void s48_gc_error(const char* message, ...) {
  va_list args;
  va_start(args, message);
  fprintf(stderr, "gc: ");
  vfprintf(stderr, message, args);
  fprintf(stderr, "\n");
  va_end(args);

  exit(-1);
}

#if (BIBOP_LOG)
void s48_bibop_log(const char* message, ...) {
  FILE* prot;
  va_list args;

  prot = fopen("BIBOP_LOG", "a");
  va_start(args, message);

  vfprintf(prot, message, args);
  fprintf(prot, "\n");

  va_end(args);

  fclose(prot);
}
#endif
