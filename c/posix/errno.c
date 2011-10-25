/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/*
 * Scheme 48/POSIX errno mapping
 * (largely copied & renamed from the signal mapping in proc.c)
 */

#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include "scheme48.h"

/*
 * Mapping from our `canonical' errno numbers to the local OS's
 * numbers. To avoid having to manually keep the values here in sync
 * with the NAMED-ERRNOS finite record type, we generate the values
 * using a Scheme program.
 */
static int errno_map[] = {
#include "s48_errno.h"
};

extern void s48_init_posix_errno(void);
static s48_ref_t posix_integer_to_errno(s48_call_t call, s48_ref_t sig_int);
static s48_ref_t posix_initialize_named_errnos(s48_call_t call);

static s48_ref_t enter_errno(s48_call_t call, int c_errno);
static int extract_errno(s48_call_t call, s48_ref_t sch_errno);

static s48_ref_t unnamed_errnos;

/* kludge in proc.c; needs to go away at some point anyway */
extern s48_ref_t s48_lookup_record(s48_call_t call, s48_ref_t *list_loc, int offset, s48_ref_t key);

/*
 * Record types imported from Scheme.
 */

static s48_ref_t posix_named_errno_type_binding;
static s48_ref_t posix_unnamed_errno_type_binding;

/*
 * Vector of Scheme errno objects imported from Scheme, and a marker that
 * is put in unnamed errnos.
 */

static s48_ref_t posix_errnos_vector_binding;
static s48_ref_t posix_unnamed_errno_marker_binding;

/*
 * Install all exported functions in Scheme48.
 */
void
s48_init_posix_errno(void)
{
  S48_EXPORT_FUNCTION(posix_integer_to_errno);
  S48_EXPORT_FUNCTION(posix_initialize_named_errnos);

  posix_named_errno_type_binding =
    s48_get_imported_binding_2("posix-named-errno-type");

  posix_unnamed_errno_type_binding =
    s48_get_imported_binding_2("posix-unnamed-errno-type");

  posix_errnos_vector_binding =
    s48_get_imported_binding_2("posix-errnos-vector");

  posix_unnamed_errno_marker_binding =
    s48_get_imported_binding_2("posix-unnamed-errno-marker");

  unnamed_errnos = s48_make_global_ref(_s48_value_null);
}

/*
 * Converts from an OS errno to a canonical errno number.
 * We return -1 if there is no matching named errno.
 */

static int
lookup_errno(int c_errno) {
  int i = 0;

  for (i = 0; i < (sizeof errno_map/sizeof(int)); i++)
    if (errno_map[i] == c_errno)
      return i;

  return -1;
}

/*
 * Use the errno map to set the os-number slot in each named errno to
 * its value in the current OS.
 */

static s48_ref_t
posix_initialize_named_errnos(s48_call_t call)
{
  int i, length;
  s48_ref_t named_errnos;

  s48_shared_binding_check_2(call, posix_errnos_vector_binding);

  named_errnos = s48_shared_binding_ref_2(call, posix_errnos_vector_binding);

  if(! s48_vector_p_2(call, named_errnos))
    s48_assertion_violation_2(call, 
			      "posix_initialize_named_errnos", "not a vector", 1,
			      named_errnos);
    
  length = s48_unsafe_vector_length_2(call, named_errnos);

  for(i = 0; i < length; i++) {
    s48_ref_t named_errno = s48_unsafe_vector_ref_2(call, named_errnos, i);
    int canonical = s48_extract_long_2(call, s48_unsafe_record_ref_2(call, named_errno, 1));
    int c_errno = errno_map[canonical];
    s48_ref_t scm_errno = (c_errno == -1) ?
                           s48_false_2(call) :
                           s48_enter_long_2(call, c_errno);
    
    s48_unsafe_record_set_2(call, named_errno, 2, scm_errno); }

  return s48_unspecific_2(call);
}

/*
 * Make a new unnamed errno containing `fx_errno' and add it to the weak
 * list of unnamed errnos.
 */

static s48_ref_t
make_unnamed_errno(s48_call_t call, s48_ref_t fx_errno)
{
  s48_ref_t weak, temp;
  s48_ref_t unnamed = s48_make_record_2(call, posix_unnamed_errno_type_binding);

  s48_unsafe_record_set_2(call,
			  unnamed,
			  0,
			  s48_unsafe_shared_binding_ref_2(call,
			      posix_unnamed_errno_marker_binding));
  s48_unsafe_record_set_2(call, unnamed, 1, fx_errno);
  s48_unsafe_record_set_2(call, unnamed, 2, s48_null_2(call));	/* No queues */

  weak = s48_make_weak_pointer_2(call, unnamed);

  temp = unnamed_errnos;

  unnamed_errnos = s48_local_to_global_ref(s48_cons_2(call, weak, unnamed_errnos));

  s48_free_global_ref(temp);

  return unnamed;
}
/*
 * Returns a errno record for `errno'.  Unnamed errnos are looked up in
 * the weak list of same; if none is found we make one.  Scheme records for
 * named errnos are retrieved from a vector sent down by the Scheme code.
 */

static s48_ref_t
enter_errno(s48_call_t call, int c_errno)
{
  int canonical = lookup_errno(c_errno);

  if (canonical == -1) {
    s48_ref_t fx_errno = s48_enter_long_2(call, c_errno);
    s48_ref_t unnamed = s48_lookup_record(call, &unnamed_errnos, 1, fx_errno);
    
    if (!s48_false_p_2(call, unnamed))
      return unnamed;
    else
      return make_unnamed_errno(call, fx_errno); }
  else
    return s48_vector_ref_2(call,
			    s48_shared_binding_ref_2(call, posix_errnos_vector_binding),
			    canonical);
}

/*
 * Wrapper for enter_errno() for calling from Scheme.
 */

static s48_ref_t
posix_integer_to_errno(s48_call_t call, s48_ref_t errno_int)
{
  if (s48_fixnum_p_2(call, errno_int))
    return enter_errno(call, s48_extract_long_2(call, errno_int));
  else
    /* really should do an integer? test here */
    return s48_false_2(call);
}

/*
 * Go from a errno back to the local integer.  For named errnos we extract
 * the canonical errno to use as an index into the errno map.  Unnamed errnos
 * contain the local errno already.
 */

static int
extract_errno(s48_call_t call, s48_ref_t sch_errno)
{
  s48_ref_t type;

  if (! s48_record_p_2(call, sch_errno))
    s48_assertion_violation_2(call, NULL, "not a record", 1, sch_errno);

  type = s48_unsafe_record_type_2(call, sch_errno);

  if (s48_eq_p_2(call, type, s48_unsafe_shared_binding_ref_2(call, posix_named_errno_type_binding))) {
    int canonical = s48_extract_long_2(call, s48_unsafe_record_ref_2(call, sch_errno, 1));
    if ((0 <= canonical) && (canonical < (sizeof errno_map/sizeof(int)))
	&& errno_map[canonical] != -1)
      return errno_map[canonical];
    else
      s48_assertion_violation_2(call, NULL, "not a valid errno index", 1, sch_errno); }

  else if (s48_eq_p_2(call, type,
		      s48_unsafe_shared_binding_ref_2(call, posix_unnamed_errno_type_binding)))
    return s48_extract_long_2(call, s48_unsafe_record_ref_2(call, sch_errno, 1));

  else
    s48_assertion_violation_2(call, NULL, "not a errno", 1, sch_errno);
}
