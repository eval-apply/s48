/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

extern void s48_init_ieee_bytevect(void);

void s48_on_load(void)
{
  s48_init_ieee_bytevect();
}
