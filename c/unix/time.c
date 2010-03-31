/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

#include <sys/time.h>
#include <time.h>
#include "scheme48.h"

static s48_ref_t time_type_binding;

/*
 * Install all exported functions in Scheme48.
 */
void
s48_init_time(void)
{
  S48_EXPORT_FUNCTION(s48_get_current_time);
  S48_EXPORT_FUNCTION(s48_get_timezone);

  time_type_binding =
    s48_get_imported_binding_2("os-time-type");
}

/* ************************************************************ */


/*
 * Convert a timeval into a Scheme time record.
 */
s48_ref_t
s48_enter_time(s48_call_t call, struct timeval *now)
{
  s48_ref_t	sch_time;

  sch_time = s48_make_record_2(call, time_type_binding);

  s48_unsafe_record_set_2(call, sch_time, 0, s48_enter_long_2(call, now->tv_sec));
  s48_unsafe_record_set_2(call, sch_time, 1, s48_enter_long_2(call, now->tv_usec));

  return sch_time;
}

/* returns a Scheme time record containing seconds since
 * midnight (00:00:00), January 1, 1970 (UTC) +
 * the fraction of a second in microseconds  
 */
s48_ref_t
s48_get_current_time(s48_call_t call)
{
  struct timeval now;
  gettimeofday(&now, NULL);

  return s48_enter_time(call, &now);
}

/* returns the difference in seconds between UTC and local time */
s48_ref_t
s48_get_timezone(s48_call_t call)
{
  time_t helper_time;
  struct tm broken_time;

  if ((helper_time = time(NULL)) == -1)
    s48_assertion_violation_2(call, "os_time", "unknown error calling time()", 0);

  localtime_r(&helper_time, &broken_time);

  return s48_enter_long_2(call, broken_time.tm_gmtoff);
}
