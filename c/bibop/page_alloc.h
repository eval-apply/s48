/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

#ifndef __S48_PAGE_ALLOC_H
#define __S48_PAGE_ALLOC_H

#include "memory.h"

extern void s48_initialize_page_allocation();
extern unsigned long s48_allocate_pages(unsigned long minimum,
					unsigned long maximum,
					s48_address* start);
extern void s48_free_pagesB(s48_address start, unsigned long size);

#endif
