/* Copyright (c) 1993-2008 by Richard Kelsey and Jonathan Rees.
   See file COPYING. */

/*
 * Scheme 48/POSIX process environment interface
 */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "c-mods.h"
#include "scheme48.h"
#include "scheme48vm.h"
#include "event.h"
#include "posix.h"
#include "unix.h"

extern void		s48_init_posix_proc(void),
			s48_uninit_posix_proc(void);
static s48_ref_t	posix_fork(s48_call_t call),
			posix_exec(s48_call_t call, s48_ref_t program, s48_ref_t lookup_p,
				   s48_ref_t env, s48_ref_t args),
  			posix_enter_pid(s48_call_t call, s48_ref_t pid),
  			posix_waitpid(s48_call_t call),
			posix_integer_to_signal(s48_call_t call, s48_ref_t sig_int),
			posix_initialize_named_signals(s48_call_t call),
			posix_request_interrupts(s48_call_t call, s48_ref_t int_number),  
			posix_cancel_interrupt_request(s48_call_t call, s48_ref_t sch_signal),
  			posix_kill(s48_call_t call, s48_ref_t sch_pid, s48_ref_t sch_signal);

static s48_ref_t	enter_signal(s48_call_t call, int signal);
static int		extract_signal(s48_call_t call, s48_ref_t sch_signal);
static void		signal_map_init(void);
static void		signal_map_uninit(void);
static void		cancel_interrupt_requests(void);

static char		**enter_byte_vector_array(s48_call_t call, s48_ref_t strings),
			*add_dot_slash(char *name);

/*
 * Two lists, one with all the child process ids and the other with all the
 * unnamed signals.  Each CAR is a weak pointer to the actual object.
 *
 * We also have a handy procedure for lookup up values in the lists.
 *
 * These are in C instead of Scheme to prevent them from being written out in
 * images.
 */

static s48_ref_t child_pids;
static s48_ref_t unnamed_signals;

s48_ref_t s48_lookup_record(s48_call_t call, s48_ref_t *list_loc, int offset, s48_ref_t key);

/*
 * Record types imported from Scheme.
 */

static s48_ref_t 	posix_process_id_type_binding;
static s48_ref_t	posix_named_signal_type_binding;
static s48_ref_t	posix_unnamed_signal_type_binding;

/*
 * Vector of Scheme signal objects imported from Scheme, and a marker that
 * is put in unnamed signals.
 */

static s48_ref_t	posix_signals_vector_binding;
static s48_ref_t	posix_unnamed_signal_marker_binding;

/*
 * Queue of received interrupts that need to be passed on to Scheme.
 * Kept in a finite array to avoid consing.
 */

/*
 * Install all exported functions in Scheme48.
 */
void
s48_init_posix_proc(void)
{
  S48_EXPORT_FUNCTION(posix_fork);
  S48_EXPORT_FUNCTION(posix_exec);
  S48_EXPORT_FUNCTION(posix_enter_pid);
  S48_EXPORT_FUNCTION(posix_waitpid);
  S48_EXPORT_FUNCTION(posix_integer_to_signal);
  S48_EXPORT_FUNCTION(posix_initialize_named_signals);
  S48_EXPORT_FUNCTION(posix_request_interrupts);
  S48_EXPORT_FUNCTION(posix_cancel_interrupt_request);
  S48_EXPORT_FUNCTION(posix_kill);

  posix_process_id_type_binding =
    s48_get_imported_binding_2("posix-process-id-type");

  posix_named_signal_type_binding =
    s48_get_imported_binding_2("posix-named-signal-type");

  posix_unnamed_signal_type_binding =
    s48_get_imported_binding_2("posix-unnamed-signal-type");

  posix_signals_vector_binding =
    s48_get_imported_binding_2("posix-signals-vector");

  posix_unnamed_signal_marker_binding =
    s48_get_imported_binding_2("posix-unnamed-signal-marker");

  child_pids = s48_make_global_ref(_s48_value_null);
  unnamed_signals = s48_make_global_ref(_s48_value_null);

  signal_map_init();
}

void
s48_uninit_posix_proc(void)
{
  /* this will lose our signal handlers without reinstalling them; too bad */
  cancel_interrupt_requests();
  signal_map_uninit();
}

/*
 * Box a process id in a Scheme record.
 */

static s48_ref_t
make_pid(s48_call_t call, pid_t c_pid)
{
  s48_ref_t weak, temp;
  s48_ref_t sch_pid = s48_make_record_2(call, posix_process_id_type_binding);

  s48_unsafe_record_set_2(call, sch_pid, 0, s48_enter_long_2(call, c_pid));
  s48_unsafe_record_set_2(call, sch_pid, 1, s48_false_2(call));	/* return status */
  s48_unsafe_record_set_2(call, sch_pid, 2, s48_false_2(call));	/* terminating signal */
  s48_unsafe_record_set_2(call, sch_pid, 3, s48_false_2(call));	/* placeholder for waiting threads */

  weak = s48_make_weak_pointer_2(call, sch_pid);

  temp = child_pids;

  child_pids = s48_local_to_global_ref(s48_cons_2(call, weak, child_pids));

  s48_free_global_ref(temp);

  return sch_pid;
}

/*
 * Lookup a pid in the list of same.  We clear out any dropped weak pointers
 * on the way.
 */

static s48_ref_t
lookup_pid(s48_call_t call, pid_t c_pid)
{
  return s48_lookup_record(call, &child_pids, 0, s48_enter_long_2(call, c_pid));
}

/*
 * Lookup a record on a list of weak pointers to same.  We get a value and
 * the record offset at which to look for the value.  Any dropped pointers
 * are cleared out along the way.  If any have been seen we walk the entire
 * list to clear them all out.
 *
 * This is too much C code!  It should all be done in Scheme.
 */

s48_ref_t
s48_lookup_record(s48_call_t call, s48_ref_t *the_list_loc, int offset, s48_ref_t key)
{
  int		cleanup_p = 0;
  s48_ref_t	the_list = *the_list_loc;

  /* Clear out initial dropped weaks */
  while (!s48_null_p_2(call, the_list) &&
	 s48_false_p_2(call,
		       s48_unsafe_weak_pointer_ref_2(call, s48_unsafe_car_2(call, the_list))))
    the_list = s48_unsafe_cdr_2(call, the_list);

  if (the_list != *the_list_loc) {
    s48_free_global_ref(*the_list_loc);
    the_list = s48_local_to_global_ref(the_list);
    *the_list_loc = the_list;
    cleanup_p = 1; }

  if (s48_null_p_2(call, the_list))
    return s48_false_2(call);			/* Nothing */

  {
    s48_ref_t first = s48_unsafe_weak_pointer_ref_2(call, s48_unsafe_car_2(call, the_list));

    if (s48_eq_p_2(call, key, s48_unsafe_record_ref_2(call, first, offset)))
      /* Found it first thing.  We skip the cleanup, but so what. */
      return first;

    {
      /* Loop down. */
      s48_ref_t	found = s48_false_2(call);
      s48_ref_t prev = the_list;
      s48_ref_t next = s48_unsafe_cdr_2(call, prev);
      for(; !s48_null_p_2(call, next) && s48_false_p_2(call, found);
	  next = s48_unsafe_cdr_2(call, prev)) {
	s48_ref_t first = s48_unsafe_weak_pointer_ref_2(call, s48_unsafe_car_2(call, next));
	if (s48_false_p_2(call, first)) {
	  s48_unsafe_set_cdr_2(call, prev, s48_unsafe_cdr_2(call, next));
	  cleanup_p = 1; }
	else if (s48_eq_p_2(call, key, s48_unsafe_record_ref_2(call, first, offset)))
	  found = first;
	else
	  prev = next; }
    
      /* If we found any empty weaks we check the entire list for them. */
    
      if (cleanup_p) {
	
	for(; !s48_null_p_2(call, next); next = s48_unsafe_cdr_2(call, next)) {
	  s48_ref_t first = s48_unsafe_weak_pointer_ref_2(call, s48_unsafe_car_2(call, next));
	  if (s48_false_p_2(call, first))
	    s48_unsafe_set_cdr_2(call, prev, s48_unsafe_cdr_2(call, next)); } }
      
      return found; } }
}

/*
 * If we already have this process, return it, else make a new one.
 */

s48_ref_t
s48_enter_pid(s48_call_t call, pid_t c_pid)
{
  s48_ref_t sch_pid = lookup_pid(call, c_pid);
  return s48_false_p_2(call, sch_pid) ? make_pid(call, c_pid) : sch_pid;
}

/*
 * Version of above for calling from Scheme.
 */

static s48_ref_t
posix_enter_pid(s48_call_t call, s48_ref_t sch_pid)
{
  return s48_enter_pid(call, s48_extract_long_2(call, sch_pid));
}

/*
 * Waiting for children.  We get finished pid's until we reach one for which
 * there is a Scheme pid record.  The exit status or terminating signal is
 * saved in the record which is then returned.
 *
 * This does not looked for stopped children, only terminated ones.
 */

static s48_ref_t
posix_waitpid(s48_call_t call)
{
  while(1==1) {
    int stat;
    pid_t c_pid = waitpid(-1, &stat, WNOHANG);
    if (c_pid == -1) {
      if (errno == ECHILD)		/* no one left to wait for */
	return s48_false_2(call);
      else if (errno != EINTR)
	s48_os_error_2(call, "posix_waitpid", errno, 0);
    }
    else {
      s48_ref_t sch_pid = lookup_pid(call, c_pid);
      s48_ref_t temp = s48_unspecific_2(call);

      if (!s48_false_p_2(call, sch_pid)) {
	if (WIFEXITED(stat))
	  s48_unsafe_record_set_2(call, sch_pid, 1, s48_enter_long_2(call, WEXITSTATUS(stat)));
	else {
	  temp = enter_signal(call, WTERMSIG(stat));
	  s48_unsafe_record_set_2(call, sch_pid, 2, temp);
	}

	return sch_pid;
      }
    }
  }
}

/*
 * Fork and exec.
 */

static s48_ref_t
posix_fork(s48_call_t call)
{
  pid_t child_pid = fork();

  if (child_pid < 0)
    s48_os_error_2(call, "posix_fork", errno, 0);

  if (child_pid == 0)
    return s48_false_2(call);
  else
    return make_pid(call, child_pid);
}

/*
 * The environment is an array of strings of the form "name=value", where
 * `name' cannot contain `='.
 *
 * It is a nuisance that given three binary choices (arguments explicit or
 * in a vector, path lookup or not, explicit or implicit environment) Posix
 * only gives six functions.  The two calls that have an explict environment
 * both do path lookup.  We work around this by adding `./' to the beginning
 * of the program, if it does not already contain a `/'.
 */

static s48_ref_t
posix_exec(s48_call_t call, s48_ref_t program, s48_ref_t lookup_p,
	   s48_ref_t env, s48_ref_t args)
{
  char **c_args = enter_byte_vector_array(call, args);
  char *c_program, *real_c_program;
  int status;

  c_program = s48_extract_byte_vector_2(call, program);

  s48_stop_alarm_interrupts();

  if (s48_false_p_2(call, env))
    if (s48_false_p_2(call, lookup_p))
      status = execv(c_program, c_args);
    else {
      status = execvp(c_program, c_args);
    }
  else {
    char **c_env = enter_byte_vector_array(call, env);
    
    if (NULL == strchr(c_program, '/'))
      real_c_program = add_dot_slash(c_program);
    else
      real_c_program = c_program;

    status = execve(c_program, c_args, c_env);

    free(c_env);
    if (real_c_program != c_program)
      free(real_c_program); }

  /* If we get here, then something has gone wrong. */

  free(c_args);
  s48_start_alarm_interrupts();
  s48_os_error_2(call, "posix_exec", errno, 0);

  /* appease gcc -Wall */
  return s48_false_2(call);
}

/*
 * Convert a list of byte vectors into an array of char pointers.
 */

static char **
enter_byte_vector_array(s48_call_t call, s48_ref_t vectors)
{
  int length = s48_unsafe_extract_long_2(call, s48_length_2(call, vectors));
  char **result = (char **)malloc((length + 1) * sizeof(char *));
  int i;

  if (result == NULL)
    s48_out_of_memory_error();
  
  for(i = 0; i < length; i++, vectors = s48_unsafe_cdr_2(call, vectors)) {
    s48_ref_t vector = s48_unsafe_car_2(call, vectors);
    if (! s48_byte_vector_p_2(call, vector)) {
      free(result);
      s48_assertion_violation_2(call, NULL, "not a byte vector", 1, vector); }
    result[i] = s48_unsafe_extract_byte_vector_2(call, vector); }
  result[length] = NULL;

  return result;
}
  
/*
 * Add `./' to the beginning of `name'.
 */

static char *
add_dot_slash(char *name)
{
  int len = strlen(name);
  char *new_name = (char *)malloc((len + 1) * sizeof(char));
  
  if (new_name == NULL)
    s48_out_of_memory_error();
  
  new_name[0] = '.';
  new_name[1] = '/';
  strcpy(new_name + 2, name);

  return new_name;
}

/*
 * Signals
 */

/*
 * Simple front for kill().  We have to retry if interrupted.
 */

s48_ref_t
posix_kill(s48_call_t call, s48_ref_t sch_pid, s48_ref_t sch_signal)
{
  int status;

  s48_check_record_type_2(call, sch_pid, posix_process_id_type_binding);

  RETRY_OR_RAISE_NEG(status,
		     kill(s48_extract_long_2(call, s48_unsafe_record_ref_2(call, sch_pid, 0)),
			  extract_signal(call, sch_signal)));

  return s48_unspecific_2(call);
}

/*
 * This is an array that maps our `canonical' signal numbers to the local
 * OS's numbers.  The initialization is done via an include file written
 * by a Scheme program.  The include file first calls signal_count_is()
 * with the number of named signals and then adds the named signals supported
 * by the current os to `signal_map'.
 */

static int	*signal_map, signal_map_size;

static void
signal_count_is(int count)
{  
  int i;

  signal_map_size = count;
  signal_map = (int *) malloc(count * sizeof(int));

  if (signal_map == NULL) {
    fprintf(stderr, "ran out of memory during initialization\n");
    exit(1); }

  for (i = 0; i < count; i++)
    signal_map[i] = -1;
}
    
static void
signal_map_init()
{
#include "s48_signals.h"
}

static void
signal_map_uninit(void)
{
  free(signal_map);
}

/*
 * Converts from an OS signal to a canonical signal number.
 * We return -1 if there is no matching named signal.
 */

static int
lookup_signal(int c_signal) {
  int i = 0;

  for (i = 0; i < signal_map_size; i++)
    if (signal_map[i] == c_signal)
      return i;

  return -1;
}

/*
 * Use the signal map to set the os-number slot in each named signal to
 * its value in the current OS.
 */

static s48_ref_t
posix_initialize_named_signals(s48_call_t call)
{
  int i, length;
  s48_ref_t named_signals;

  s48_shared_binding_check_2(call, posix_signals_vector_binding);

  named_signals = s48_shared_binding_ref_2(call, posix_signals_vector_binding);

  if(! s48_vector_p_2(call, named_signals))
    s48_assertion_violation_2(call, 
			      "posix_initialize_named_signals", "not a vector", 1,
			      named_signals);
    
  length = s48_unsafe_vector_length_2(call, named_signals);

  for(i = 0; i < length; i++) {
    s48_ref_t signal = s48_unsafe_vector_ref_2(call, named_signals, i);
    int canonical = s48_extract_long_2(call, s48_unsafe_record_ref_2(call, signal, 1));
    int c_signal = signal_map[canonical];
    s48_ref_t scm_signal = (c_signal == -1) ?
                           s48_false_2(call) :
                           s48_enter_long_2(call, c_signal);
    
    s48_unsafe_record_set_2(call, signal, 2, scm_signal); }

  return s48_unspecific_2(call);
}

/*
 * Make a new unnamed signal containing `fx_signal' and add it to the weak
 * list of unnamed signals.
 */

static s48_ref_t
make_unnamed_signal(s48_call_t call, s48_ref_t fx_signal)
{
  s48_ref_t weak, temp;
  s48_ref_t unnamed = s48_make_record_2(call, posix_unnamed_signal_type_binding);

  s48_unsafe_record_set_2(call,
			  unnamed,
			  0,
			  s48_unsafe_shared_binding_ref_2(call,
			      posix_unnamed_signal_marker_binding));
  s48_unsafe_record_set_2(call, unnamed, 1, fx_signal);
  s48_unsafe_record_set_2(call, unnamed, 2, s48_null_2(call));	/* No queues */

  weak = s48_make_weak_pointer_2(call, unnamed);

  temp = unnamed_signals;

  unnamed_signals = s48_local_to_global_ref(s48_cons_2(call, weak, unnamed_signals));

  s48_free_global_ref(temp);

  return unnamed;
}

/*
 * Returns a signal record for `signal'.  Unnamed signals are looked up in
 * the weak list of same; if none is found we make one.  Scheme records for
 * named signals are retrieved from a vector sent down by the Scheme code.
 */

static s48_ref_t
enter_signal(s48_call_t call, int c_signal)
{
  int canonical = lookup_signal(c_signal);

  if (canonical == -1) {
    s48_ref_t fx_signal = s48_enter_long_2(call, c_signal);
    s48_ref_t unnamed = s48_lookup_record(call, &unnamed_signals, 1, fx_signal);
    
    if (!s48_false_p_2(call, unnamed))
      return unnamed;
    else
      return make_unnamed_signal(call, fx_signal); }
  else
    return s48_vector_ref_2(call,
			    s48_shared_binding_ref_2(call, posix_signals_vector_binding),
			    canonical);
}

/*
 * Wrapper for enter_signal() for calling from Scheme.
 */

static s48_ref_t
posix_integer_to_signal(s48_call_t call, s48_ref_t signal_int)
{
  if (s48_fixnum_p_2(call, signal_int))
    return enter_signal(call, s48_extract_long_2(call, signal_int));
  else
    /* really should do an integer? test here */
    return s48_false_2(call);
}

/*
 * Go from a signal back to the local integer.  For named signals we extract
 * the canonical signal to use as an index into the signal map.  Unnamed signals
 * contain the local signal already.
 */

static int
extract_signal(s48_call_t call, s48_ref_t sch_signal)
{
  s48_ref_t type;

  if (! s48_record_p_2(call, sch_signal))
    s48_assertion_violation_2(call, NULL, "not a record", 1, sch_signal);

  type = s48_unsafe_record_type_2(call, sch_signal);

  if (s48_eq_p_2(call, type, s48_unsafe_shared_binding_ref_2(call, posix_named_signal_type_binding))) {
    int canonical = s48_extract_long_2(call, s48_unsafe_record_ref_2(call, sch_signal, 1));
    if ((0 <= canonical) && (canonical < signal_map_size)
	&& signal_map[canonical] != -1)
      return signal_map[canonical];
    else
      s48_assertion_violation_2(call, NULL, "not a valid signal index", 1, sch_signal); }

  else if (s48_eq_p_2(call, type,
		      s48_unsafe_shared_binding_ref_2(call, posix_unnamed_signal_type_binding)))
    return s48_extract_long_2(call, s48_unsafe_record_ref_2(call, sch_signal, 1));

  else
    s48_assertion_violation_2(call, NULL, "not a signal", 1, sch_signal);
}

/*
 * Queue the interrupt.  For SIGINT and SIGALRM we call the event-system's
 * handler as well.
 */

static void
generic_interrupt_catcher(int signum)
{
  extern void s48_add_os_signal(long);
  s48_add_os_signal(signum);

  switch (signum) {
  case SIGINT: {
    s48_when_keyboard_interrupt(0);
    break; }
  case SIGALRM: {
    s48_when_alarm_interrupt(0);
    break; }
  case SIG_EXTERNAL_EVENT: {
    s48_when_external_event_interrupt(0);
    break; }
  default:
    NOTE_EVENT; }
  
  return;
}

/*
 * Array of actions to be restored when we no longer listen for a signal.
 */

#define MAX_SIGNAL 1023			/* Just a guess. */

struct sigaction *saved_actions[MAX_SIGNAL + 1] = {NULL};

/*
 * If there is a saved action then our handler is already in place and
 * we need do nothing.  Otherwise we save the current action and install
 * our own.
 */

s48_ref_t
posix_request_interrupts(s48_call_t call, s48_ref_t sch_signum)
{
  int			signum = s48_extract_long_2(call, sch_signum);
  struct sigaction	sa;

  if (saved_actions[signum] == NULL) {
    struct sigaction *	old = (struct sigaction *)
                                malloc(sizeof(struct sigaction));
    
    if (old == NULL)
      s48_out_of_memory_error();

    sa.sa_handler = generic_interrupt_catcher;
    sigfillset(&sa.sa_mask);
    sa.sa_flags = 0;

    if (sigaction(signum, &sa, old) != 0) {
      free(old);
      s48_os_error_2(call, "posix_request_interrupts", errno, 1, sch_signum); }

    saved_actions[signum] = old; }
    
  return s48_unspecific_2(call);
}

/*
 * The reverse of the above.  If there is a saved action then we install it
 * and remove it from the saved_action array.
 */

static void
cancel_interrupt_request(int signum)
{
  struct sigaction *	old = saved_actions[signum];

  if (old != NULL)
    {
      
      if (sigaction(signum, old, (struct sigaction *) NULL) != 0)
	/* THIS IS STILL OLD FFI!  FIX THIS! */
	s48_os_error_2(NULL, NULL, errno, 1, s48_enter_fixnum(signum));
      
      free(old);
      saved_actions[signum] = NULL; 
    }
}

s48_ref_t
posix_cancel_interrupt_request(s48_call_t call, s48_ref_t sch_signum)
{
  cancel_interrupt_request(s48_extract_long_2(call, sch_signum));
  return s48_unspecific_2(call);
}

static void
cancel_interrupt_requests(void)
{
  int signum = 0;
  while (signum <= MAX_SIGNAL)
    {
      cancel_interrupt_request(signum);
      ++signum;
    }
}
