/* Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/*
 * Users and groups
 *
 * This provides Scheme access to the following: getgrgid(), getgrnam(),
 * getpwuid(), and getpwnam().
 *
 * The only externally visible bindings are s48_posix_init_user() and
 * s48_{enter|extract}_{u|g}id
 */

#include <stdio.h>
#include "scheme48.h"
#include <sys/types.h>
#include <stdio.h>
#include <errno.h>
#include <pwd.h>
#include <grp.h>
#include "posix.h"
#include "unix.h"

extern void		s48_posix_init_user(void);
static s48_value	posix_getpwuid(s48_value uid),
			posix_getpwnam(s48_value user_name),
			posix_getgrgid(s48_value gid),
			posix_getgrnam(s48_value group_name);

/*
 * Record types imported from Scheme.
 */
static s48_value	posix_user_id_type_binding = S48_FALSE,
			posix_group_id_type_binding = S48_FALSE;

/*
 * Install all exported functions in Scheme48 and import and protect the
 * required record types.
 */
void
s48_init_posix_user(void)
{
  S48_EXPORT_FUNCTION(posix_getpwuid);
  S48_EXPORT_FUNCTION(posix_getpwnam);
  S48_EXPORT_FUNCTION(posix_getgrgid);
  S48_EXPORT_FUNCTION(posix_getgrnam);

  S48_GC_PROTECT_GLOBAL(posix_user_id_type_binding);
  posix_user_id_type_binding = s48_get_imported_binding("posix-user-id-type");
    
  S48_GC_PROTECT_GLOBAL(posix_group_id_type_binding);
  posix_group_id_type_binding = s48_get_imported_binding("posix-group-id-type");
}

/* ****************************************************************
 * Converting uids and gids back and forth between C and Scheme.
 */

/*
 * Convert a uid into a Scheme uid record.
 */
s48_value
s48_enter_uid(uid_t uid)
{
  s48_value	sch_uid;

  sch_uid = s48_make_record(posix_user_id_type_binding);
  S48_UNSAFE_RECORD_SET(sch_uid, 0, s48_enter_fixnum(uid));

  return sch_uid;
}


/*
 * Convert a Scheme uid record into a uid_t.
 */
uid_t
s48_extract_uid(s48_value uid)
{
  s48_check_record_type(uid, posix_user_id_type_binding);

  return s48_extract_fixnum(S48_UNSAFE_RECORD_REF(uid, 0));
}

/*
 * Convert a gid into a Scheme gid record.
 */
s48_value
s48_enter_gid(gid_t gid)
{
  s48_value	sch_gid;

  sch_gid = s48_make_record(posix_group_id_type_binding);
  S48_UNSAFE_RECORD_SET(sch_gid, 0, s48_enter_fixnum(gid));

  return sch_gid;
}

/*
 * Convert a Scheme gid record into a gid_t.
 */
gid_t
s48_extract_gid(s48_value gid)
{
  s48_check_record_type(gid, posix_group_id_type_binding);

  return s48_extract_fixnum(S48_UNSAFE_RECORD_REF(gid, 0));
}

/* ****************************************************************
 * Getting user and group information.
 */

static s48_value enter_user_data(struct passwd *data);

static s48_value
posix_getpwuid(s48_value uid)
{
  struct passwd *data;
  
  RETRY_OR_RAISE_NULL(data, getpwuid(s48_extract_uid(uid)));

  return enter_user_data(data);
}

static s48_value
posix_getpwnam(s48_value name)
{
  struct passwd *data;
  
  RETRY_OR_RAISE_NULL(data, getpwnam(S48_UNSAFE_EXTRACT_BYTE_VECTOR(name)));

  return enter_user_data(data);
}

/*
 * returns a list of components
 */

static s48_value
enter_user_data(struct passwd *data)
{
  s48_value sch_data = S48_FALSE;
  s48_value temp = S48_UNSPECIFIC;
  S48_DECLARE_GC_PROTECT(2);

  S48_GC_PROTECT_2(sch_data, temp);

  sch_data = S48_NULL;
  temp = s48_enter_byte_string(data->pw_shell);
  sch_data = s48_cons(temp, sch_data);
  temp = s48_enter_byte_string(data->pw_dir);
  sch_data = s48_cons(temp, sch_data);
  temp = s48_enter_gid(data->pw_gid);
  sch_data = s48_cons(temp, sch_data);
  temp = s48_enter_uid(data->pw_uid);
  sch_data = s48_cons(temp, sch_data);
  temp = s48_enter_byte_string(data->pw_name);
  sch_data = s48_cons(temp, sch_data);
  
  S48_GC_UNPROTECT();
  
  return sch_data;
}

static s48_value
enter_group_data(struct group *data)
{
  s48_value sch_data = S48_FALSE;
  s48_value members = S48_FALSE;
  s48_value temp = S48_UNSPECIFIC;
  S48_DECLARE_GC_PROTECT(3);
  int length;
  char **names;

  S48_GC_PROTECT_3(sch_data, members, temp);

  for(length = 0, names = data->gr_mem; *names != NULL; length++, names++);
  members = s48_make_vector(length, S48_FALSE);
  for(length = 0, names = data->gr_mem; *names != NULL; length++, names++) {
    temp = s48_enter_byte_string(*names);
    S48_UNSAFE_VECTOR_SET(members, length, temp);
  }

  sch_data = S48_NULL;
  sch_data = s48_cons(members, sch_data);
  temp = s48_enter_gid(data->gr_gid);
  sch_data = s48_cons(temp, sch_data);
  temp = s48_enter_byte_string(data->gr_name);
  sch_data = s48_cons(temp, sch_data);
  
  S48_GC_UNPROTECT();
  
  return sch_data;
}

static s48_value
posix_getgrgid(s48_value gid)
{
  struct group *data;
  
  RETRY_OR_RAISE_NULL(data, getgrgid(s48_extract_gid(gid)));

  return enter_group_data(data);
}

static s48_value
posix_getgrnam(s48_value name)
{
  struct group *data;
  
  RETRY_OR_RAISE_NULL(data, getgrnam(S48_UNSAFE_EXTRACT_BYTE_VECTOR(name)));

  return enter_group_data(data);
}
