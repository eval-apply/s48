### s48_osx_arch_flags.m4 --- S48_OSX_ARCH_FLAGS macro  -*- Autoconf -*-
# serial 1
dnl
dnl
dnl Checks for valid "-arch"-Flags on MacOSX depending on the
dnl parameters build_universal (see S48_ENABLE_UNIVERSAL_BINARY)
dnl and force_32 (see S48_ENABLE_FORCE_32BIT).
AC_DEFUN([S48_OSX_ARCH_FLAGS], [dnl
build_universal="$1"
force_32="$2"
if test "$build_universal" = 1 -a "$force_32" = 1; then 
  S48_OSX_ARCH_CHECK(i386,32)
  S48_OSX_ARCH_CHECK(ppc,32)
elif test "$build_universal" = 1 -a "$force_32" = 0; then
  if test "$BIT_SUFFIX" = 32; then
    S48_OSX_ARCH_CHECK(i386,32)
    S48_OSX_ARCH_CHECK(ppc,32)
  elif test "$BIT_SUFFIX" = 64; then
    S48_OSX_ARCH_CHECK(x86_64,64)
    S48_OSX_ARCH_CHECK(ppc64,64)
  fi
fi
])
### s48_osx_arch_flags.m4 ends here
