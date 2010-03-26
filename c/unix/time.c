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
  S48_EXPORT_FUNCTION(s48_time_to_string);
  S48_EXPORT_FUNCTION(s48_get_current_time);
  S48_EXPORT_FUNCTION(s48_get_timezone);

  time_type_binding =
    s48_get_imported_binding_2("os-time-type");
}

/* ************************************************************ */

/*
 * Convert a Scheme time record into a timeval.
 */
void
extract_time(s48_call_t call, s48_ref_t *sch_time, struct timeval *time)
{
  s48_check_record_type_2(call, *sch_time, time_type_binding);

  time->tv_sec =
    s48_extract_long_2(call, s48_unsafe_record_ref_2(call, *sch_time, 0));
  time->tv_usec =
    s48_extract_long_2(call, s48_unsafe_record_ref_2(call, *sch_time, 1));
}

/*
 * The posix ctime() procedure, which converts a time_t into a string, using
 * the local time zone.
 *
 * ENTER_STRING does a copy, which gets us out of ctime()'s static buffer.
 */
s48_ref_t
s48_time_to_string(s48_call_t call, s48_ref_t sch_time)
{
  struct timeval time;
  s48_check_record_type_2(call, sch_time, time_type_binding);

  extract_time(call, &sch_time, &time) ;

  return s48_enter_byte_string_2(call, ctime(&time.tv_sec));
}


/*
 * Convert a timeval into a Scheme time record.
 */
s48_ref_t
s48_enter_time(s48_call_t call, struct timeval *now)
{
  s48_ref_t	sch_time;
  s48_ref_t	seconds;
  s48_ref_t	useconds;

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
  struct tm *broken_time;

  if ((helper_time = time(NULL)) == -1)
    s48_assertion_violation_2(call, "os_time", "unknown error calling time()", 0);

  broken_time = localtime(&helper_time);

  return s48_enter_long_2(call, broken_time->tm_gmtoff);
}
