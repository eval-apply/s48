
extern long s48_initialize(int *argc, char ** argv);

int
main(int argc, char *argv[])
{
  long return_value;

  return_value = s48_initialize(&argc, argv);

  if (return_value != 0)
    return return_value;
  else
    return s48_call_startup_procedure(argv, argc);
}
