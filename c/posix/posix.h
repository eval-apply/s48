
extern mode_t		s48_extract_mode(s48_call_t call, s48_ref_t sch_mode);
extern int		s48_extract_file_options(s48_call_t call, s48_ref_t sch_file_options);

extern s48_ref_t	s48_enter_uid(s48_call_t call, uid_t uid);
extern uid_t		s48_extract_uid(s48_call_t call, s48_ref_t uid);

extern s48_ref_t	s48_enter_gid(s48_call_t call, gid_t gid);
extern gid_t		s48_extract_gid(s48_call_t call, s48_ref_t gid);

extern s48_ref_t	s48_enter_pid(s48_call_t call, pid_t c_pid);
