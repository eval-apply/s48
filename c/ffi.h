/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/* Modelled on Jim Blandy's foreign function interface that he put in
   his Scheme implementation called Minor. */

#ifndef _H_FFI
#define _H_FFI

/* internal interface */
s48_call_t s48_first_call (void);
s48_call_t s48_get_current_call (void);
s48_call_t s48_push_call (s48_call_t call);
void       s48_pop_to (s48_call_t call);
void       s48_initialize_ffi (void);

/* gc interface */
void        s48_trace_external_calls (void);

#ifdef DEBUG_FFI
void init_debug_ffi (void);
static size_t count_calls(), count_local_refs(), count_global_refs();
#endif

#endif /* _H_FFI */
