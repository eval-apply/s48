/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/* Modelled on Jim Blandy's foreign function interface that he put in
   his Scheme implementation called Minor. */

#ifndef _H_ECALL
#define _H_ECALL

#include <stdlib.h>

#include "scheme48.h"


struct ref_group;

struct s48_ref_t
{
  s48_value obj;
  struct ref_group *group;
};


/* local refs */
s48_ref_t  s48_make_local_ref (s48_call_t call, s48_value obj);
s48_ref_t  s48_copy_local_ref (s48_call_t call, s48_ref_t ref);
void       s48_free_local_ref (s48_call_t call, s48_ref_t ref);
void       s48_free_local_ref_array (s48_call_t call, s48_ref_t *refs, size_t len);

/* global refs */
s48_ref_t  s48_make_global_ref (s48_value obj);
void       s48_free_global_ref (s48_ref_t ref);


/* subcalls */
s48_call_t s48_make_subcall (s48_call_t call);
void       s48_free_subcall (s48_call_t subcall);
s48_ref_t  s48_finish_subcall (s48_call_t call, s48_call_t subcall, s48_ref_t ref);


/* internal interface */
s48_call_t s48_first_call (void);
s48_call_t s48_get_current_call (void);
s48_call_t s48_push_call (s48_call_t call);
void       s48_pop_to (s48_call_t call);
void       s48_init_ffi (void);


/* gc interface */
extern void        s48_trace_external_calls (void);


#ifdef DEBUG_FFI
void init_debug_ffi (void);
size_t count_calls(), count_local_refs(), count_global_refs();
#endif

#endif /* _H_ECALL */
