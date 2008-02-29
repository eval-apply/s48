# generated automatically by aclocal 1.7.9 -*- Autoconf -*-

# Copyright (C) 1996, 1997, 1998, 1999, 2000, 2001, 2002
# Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

# serial 1
dnl
dnl
dnl On AIX, we need xlc_r or cc_r if not explicitly set
AC_DEFUN([S48_CC], [dnl
  case "$target" in
    *-*-aix*) dnl
	if test -z "$CC" ; then
	  AC_CHECK_PROGS(CC,cc_r xlc_r cc)
	fi
    ;;
esac
])

# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_PICK_GC], [dnl
AC_ARG_ENABLE([gc],
[AC_HELP_STRING([--enable-gc=GC],
                [choose garbage collector (twospace, bibop), default is twospace])],
              [dnl
                case $enableval in
                  twospace )
			AC_DEFINE([S48_GC_TWOSPACE], 1, [Define if building with two-space GC.])
			GC_OBJS='${GC_TWOSPACE_OBJS}' ;;
                  bibop )
			AC_DEFINE([S48_GC_BIBOP], 1, [Define if building with BIBOP GC.])
			GC_OBJS='${GC_BIBOP_OBJS}' ;;
                  * ) AC_MSG_ERROR([Invalid argument to --enable-gc]) ;;
		esac
	      ],
	      [AC_DEFINE([S48_GC_TWOSPACE], 1, [Define if building with two-space GC.])
	       GC_OBJS='${GC_TWOSPACE_OBJS}'])dnl
])dnl
])

# serial 1
dnl
dnl
dnl Force to use 32bit implementation.
AC_DEFUN([S48_ENABLE_FORCE_32BIT], [dnl
AC_MSG_CHECKING([whether we must build a 32bit binary])
dnl
AC_ARG_ENABLE([force-32bit],
[AC_HELP_STRING([--enable-force-32bit],
		[Build a 32bit binary on architectures where this is not the default])],
	[dnl 
         S48_FORCE_32_P="1"
	 BIT_SUFFIX="32"
	 dnl For now only a Linux/AMD x86_64 version:
	 case "$host" in
		x86_64-*-linux-gnu )
	         CFLAGS="${CFLAGS} -m32";
		 LDFLAGS="${LDFLAGS} -m32";
		 dnl This is needed if 'gcc' resp. 'ld' is used to link a dynamic external below
		 GCC_LDFLAGS="${GCC_LDFLAGS} -m32";
		 LD_LDFLAGS="${LD_LDFLAGS} -melf_i386";
		;;
                *darwin* ) dnl AC_MSG_RESULT([Found Darwin, will check later.])
                ;;
		* ) AC_MSG_ERROR([Don't know how to build a 32bit binary on this architecture])
		;;
	 esac
	 AC_DEFINE([BUILD_32BIT], 1,
		   [Define if we are building a 32bit binary on architectures where this is not the default.])
	 AC_MSG_RESULT(yes)],
   	[dnl
         S48_FORCE_32_P="0"
	 AC_MSG_RESULT(no)])])

# serial 1
dnl
dnl
dnl Determines the number of bits per byte
AC_DEFUN([S48_DETERMINE_BITS_PER_BYTE], [dnl
AC_MSG_CHECKING(bits per byte)
AC_CACHE_VAL(ac_cv_sizeof_void_p,
	[AC_TRY_RUN([#include <stdio.h>
		#include <stdlib.h>
		main()
		{
		  unsigned char c = 1;
		  int i = 0;
		  FILE *f=fopen("conftestval", "w");
		  if (!f) exit(1);
		  while (c != 0) {
		    i++;
		    c = c << 1;
		  }
		  fprintf(f, "%d\n", i);
		  exit(0);
		}],
	    ac_cv_bits_per_byte=`cat conftestval`,
	    ac_cv_bits_per_byte=0,
	    AC_MSG_ERROR(failed to compile test program))])
     if test "$ac_cv_bits_per_byte" = "0" -o "$ac_cv_bits_per_byte" = ""; then
       AC_MSG_ERROR([Unable to determine bits per byte, see config.log for details.]);
     fi
     AC_MSG_RESULT($ac_cv_bits_per_byte)
     AC_DEFINE_UNQUOTED(BITS_PER_BYTE, [$ac_cv_bits_per_byte], [Check for the number of bits per byte])
])

# serial 1
dnl
dnl
dnl Determines the size of a pointer.
AC_DEFUN([S48_DETERMINE_POINTER_SIZE], [dnl
dnl Our own version of AC_CHECK_SIZEOF([void *])
AC_MSG_CHECKING(size of void *)
AC_CACHE_VAL(ac_cv_sizeof_void_p,
	[AC_TRY_RUN([#include <stdio.h>
		#include <stdlib.h>
		main()
		{
		  FILE *f=fopen("conftestval", "w");
		  if (!f) exit(1);
		  fprintf(f, "%d\n", (int)sizeof(void *));
		  exit(0);
		}],
	    ac_cv_sizeof_void_p=`cat conftestval`,
	    ac_cv_sizeof_void_p=0,
	    AC_MSG_ERROR(failed to compile test program))])
     if test "$ac_cv_sizeof_void_p" = "0" -o "$ac_cv_sizeof_void_p" = ""; then
       AC_MSG_ERROR([Unable to determine sizeof (void *), see config.log for details.]);
     fi
     AC_MSG_RESULT($ac_cv_sizeof_void_p)
     AC_DEFINE_UNQUOTED(SIZEOF_VOID_P, [$ac_cv_sizeof_void_p], [Check for sizeof (void *)])
])

# serial 1
dnl
dnl
dnl Determines the number of bits of desired build.
AC_DEFUN([S48_DETERMINE_BIT_SUFFIX], [dnl
     AC_MSG_CHECKING([for BIT_SUFFIX])
     if test $BIT_SUFFIX; then
       AC_MSG_RESULT([You forced BIT_SUFFIX to be $BIT_SUFFIX.])
     else
       BIT_SUFFIX=`expr $ac_cv_sizeof_void_p \* $ac_cv_bits_per_byte`
       AC_MSG_RESULT($BIT_SUFFIX)
     fi
     AC_DEFINE_UNQUOTED(WORDSIZE, [$BIT_SUFFIX], [Check for number of bits in a word])
])

# serial 1
dnl
dnl
dnl Option to build an universal binary on MacOSX.
AC_DEFUN([S48_ENABLE_UNIVERSAL_BINARY], [dnl
AC_MSG_CHECKING([whether we are building a Universal Binary])
dnl
AC_ARG_ENABLE([universal-binary],
[AC_HELP_STRING([--enable-universal-binary],
		[Build MacOS X Universal Binary])],
	[dnl
	 case $host in
           *darwin* ) S48_BUILD_UNIVERSAL_P="1"
	     AC_DEFINE([BUILD_UNIVERSAL_BINARY], 1,
		       [Define if we are building an OS X Universal Binary.])
	     AC_MSG_RESULT(yes)
           ;;
           * ) AC_MSG_ERROR([--enable-universal-binary only works on Mac OS X])
           ;;
         esac
           ],
   	[dnl
	 S48_BUILD_UNIVERSAL_P="0"
	 AC_MSG_RESULT(no)])])

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

# serial 1
dnl
dnl
dnl Tests if it can compile and link with "-arch"-Flag on MacOSX,
dnl keeps the "-arch"-Flag in the CFLAGS and LDFLAGS if test is
dnl successfull.
AC_DEFUN([S48_OSX_ARCH_CHECK], [dnl
AC_MSG_CHECKING([for gcc argument $1])
save_CFLAGS="$CFLAGS"
save_LDFLAGS="$LDFLAGS"
CFLAGS="$CFLAGS -arch $1"
LDFLAGS="$LDFLAGS -arch $1"
compiles=0
links=0
AC_TRY_COMPILE([],[],compiles=1, compiles=0)
AC_TRY_LINK([],[],links=1, links=0)
if test "$links" = "1" -a "$compiles" = "1"; then
  AC_MSG_RESULT([OK])
else
  CFLAGS="$save_CFLAGS"
  LDFLAGS="$save_LDFLAGS"
  AC_MSG_RESULT([failed])
fi
])

# serial 1
dnl
dnl
dnl Determine the name of compiler option for generating position
dnl independent code.
AC_DEFUN([S48_PIC_OPTION_NAME], [dnl
	AC_MSG_CHECKING([how to compile position independent code])
	case "$host_os" in
		solaris* )
		   if test "$GCC" = "yes"; then
			PIC="-fPIC"
		   else
			# for SUN's compiler
			PIC="-KPIC"
		   fi
		;;
		darwin*|macosx* )
		   # Code on this platform is PIC by default
		   PIC=""
		;;
		*)
 	           PIC="-fPIC"
		;;
	esac
	if test "$PIC" = ""; then
	   AC_MSG_RESULT(no extra option necessary)
  	else
	   AC_MSG_RESULT($PIC)
	fi
])dnl

# serial 1
dnl
AC_DEFUN([S48_CREATE_BUILD_DIRS], [dnl
        mkdir -p c/bibop
        mkdir -p c/unix
	mkdir -p c/net
        mkdir -p c/posix
        mkdir -p c/fake
])dnl

# serial 1
dnl
dnl
dnl
dnl -rdynamic is needed for loading external code
AC_DEFUN([S48_LDFLAGS], [dnl
	AC_MSG_CHECKING([-rdynamic])
	oldLDFLAGS="$LDFLAGS"
	LDFLAGS="$LDFLAGS -rdynamic"
	AC_TRY_RUN([int main() { return 0;}],
		[AC_MSG_RESULT(yes)],
		[AC_MSG_RESULT(no)
			LDFLAGS="$oldLDFLAGS"],
		[AC_MSG_RESULT(no)
			LDFLAGS="$oldLDFLAGS"])
	AC_MSG_CHECKING([LDFLAGS_VM])
	case "$host_os" in
		aix* )
 			if test "$GCC" = "yes"; then
				LDFLAGS_VM="-Xlinker -brtl -Xlinker -bE:$srcdir/c/scheme48.exp"
			else
				LDFLAGS_VM="-brtl -bE:$srcdir/c/scheme48.exp"
			fi
		;;
		* )
			LDFLAGS_VM=
		;;
	esac
 	AC_MSG_RESULT([$LDFLAGS_VM])
])dnl

# serial 1
dnl
AC_DEFUN([S48_INLINE], [dnl
AC_MSG_CHECKING([for inline keyword])
AC_COMPILE_IFELSE([#include <stdio.h>

inline void f(void)
{
  printf("inlined");
}], [AC_MSG_RESULT([yes])
     AC_DEFINE([HAVE_INLINE], [1], [Define if the C compiler supports the inline keyword])],
    [AC_MSG_RESULT([no])])
])

# serial 1
AC_DEFUN([S48_POSIX_LIBC], [dnl
echo checking for RISC/OS POSIX library lossage
if test -f /usr/posix/usr/lib/libc.a; then
  LIBS="${LIBS} /usr/posix/usr/lib/libc.a"
fi
])dnl

# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_GLIB], [dnl
AC_ARG_ENABLE([glib],
[AC_HELP_STRING([--enable-glib],
                [Use the glib event loop])],
	[dnl Check for glib-2.0
  	 PKG_CHECK_MODULES(GLIB, glib-2.0, AC_DEFINE(HAVE_GLIB), AC_MSG_WARN(glib-2.0 not found))
	 dnl Set GLIB flags
         LIBS="$LIBS $GLIB_LIBS"
         CFLAGS="$CFLAGS $GLIB_CFLAGS"
         dnl Check if we still are able to compile, link, and run with glib's build options
	 AC_MSG_CHECKING([whether the GLIB flags work])
	 AC_TRY_RUN([int main() { return 0;}], [AC_MSG_RESULT([yes])], [AC_MSG_ERROR(Failed to compile with GLIB flags.)], [])
	])
       ])

# pkg.m4 - Macros to locate and utilise pkg-config.            -*- Autoconf -*-
# 
# Copyright © 2004 Scott James Remnant <scott@netsplit.com>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# As a special exception to the GNU General Public License, if you
# distribute this file as part of a program that contains a
# configuration script generated by Autoconf, you may include it under
# the same distribution terms that you use for the rest of that program.

# PKG_PROG_PKG_CONFIG([MIN-VERSION])
# ----------------------------------
AC_DEFUN([PKG_PROG_PKG_CONFIG],
[m4_pattern_forbid([^_?PKG_[A-Z_]+$])
m4_pattern_allow([^PKG_CONFIG(_PATH)?$])
AC_ARG_VAR([PKG_CONFIG], [path to pkg-config utility])dnl
if test "x$ac_cv_env_PKG_CONFIG_set" != "xset"; then
	AC_PATH_TOOL([PKG_CONFIG], [pkg-config])
fi
if test -n "$PKG_CONFIG"; then
	_pkg_min_version=m4_default([$1], [0.9.0])
	AC_MSG_CHECKING([pkg-config is at least version $_pkg_min_version])
	if $PKG_CONFIG --atleast-pkgconfig-version $_pkg_min_version; then
		AC_MSG_RESULT([yes])
	else
		AC_MSG_RESULT([no])
		PKG_CONFIG=""
	fi
		
fi[]dnl
])# PKG_PROG_PKG_CONFIG

# PKG_CHECK_EXISTS(MODULES, [ACTION-IF-FOUND], [ACTION-IF-NOT-FOUND])
#
# Check to see whether a particular set of modules exists.  Similar
# to PKG_CHECK_MODULES(), but does not set variables or print errors.
#
#
# Similar to PKG_CHECK_MODULES, make sure that the first instance of
# this or PKG_CHECK_MODULES is called, or make sure to call
# PKG_CHECK_EXISTS manually
# --------------------------------------------------------------
AC_DEFUN([PKG_CHECK_EXISTS],
[AC_REQUIRE([PKG_PROG_PKG_CONFIG])dnl
if test -n "$PKG_CONFIG" && \
    AC_RUN_LOG([$PKG_CONFIG --exists --print-errors "$1"]); then
  m4_ifval([$2], [$2], [:])
m4_ifvaln([$3], [else
  $3])dnl
fi])


# _PKG_CONFIG([VARIABLE], [COMMAND], [MODULES])
# ---------------------------------------------
m4_define([_PKG_CONFIG],
[if test -n "$PKG_CONFIG"; then
    if test -n "$$1"; then
        pkg_cv_[]$1="$$1"
    else
        PKG_CHECK_EXISTS([$3],
                         [pkg_cv_[]$1=`$PKG_CONFIG --[]$2 "$3" 2>/dev/null`],
			 [pkg_failed=yes])
    fi
else
	pkg_failed=untried
fi[]dnl
])# _PKG_CONFIG

# _PKG_SHORT_ERRORS_SUPPORTED
# -----------------------------
AC_DEFUN([_PKG_SHORT_ERRORS_SUPPORTED],
[AC_REQUIRE([PKG_PROG_PKG_CONFIG])
if $PKG_CONFIG --atleast-pkgconfig-version 0.20; then
        _pkg_short_errors_supported=yes
else
        _pkg_short_errors_supported=no
fi[]dnl
])# _PKG_SHORT_ERRORS_SUPPORTED


# PKG_CHECK_MODULES(VARIABLE-PREFIX, MODULES, [ACTION-IF-FOUND],
# [ACTION-IF-NOT-FOUND])
#
#
# Note that if there is a possibility the first call to
# PKG_CHECK_MODULES might not happen, you should be sure to include an
# explicit call to PKG_PROG_PKG_CONFIG in your configure.ac
#
#
# --------------------------------------------------------------
AC_DEFUN([PKG_CHECK_MODULES],
[AC_REQUIRE([PKG_PROG_PKG_CONFIG])dnl
AC_ARG_VAR([$1][_CFLAGS], [C compiler flags for $1, overriding pkg-config])dnl
AC_ARG_VAR([$1][_LIBS], [linker flags for $1, overriding pkg-config])dnl

pkg_failed=no
AC_MSG_CHECKING([for $1])

_PKG_CONFIG([$1][_CFLAGS], [cflags], [$2])
_PKG_CONFIG([$1][_LIBS], [libs], [$2])

m4_define([_PKG_TEXT], [Alternatively, you may set the environment variables $1[]_CFLAGS
and $1[]_LIBS to avoid the need to call pkg-config.
See the pkg-config man page for more details.])

if test $pkg_failed = yes; then
        _PKG_SHORT_ERRORS_SUPPORTED
        if test $_pkg_short_errors_supported = yes; then
	        $1[]_PKG_ERRORS=`$PKG_CONFIG --short-errors --errors-to-stdout --print-errors "$2"`
        else 
	        $1[]_PKG_ERRORS=`$PKG_CONFIG --errors-to-stdout --print-errors "$2"`
        fi
	# Put the nasty error message in config.log where it belongs
	echo "$$1[]_PKG_ERRORS" >&AS_MESSAGE_LOG_FD

	ifelse([$4], , [AC_MSG_ERROR(dnl
[Package requirements ($2) were not met:

$$1_PKG_ERRORS

Consider adjusting the PKG_CONFIG_PATH environment variable if you
installed software in a non-standard prefix.

_PKG_TEXT
])],
		[AC_MSG_RESULT([no])
                $4])
elif test $pkg_failed = untried; then
	ifelse([$4], , [AC_MSG_FAILURE(dnl
[The pkg-config script could not be found or is too old.  Make sure it
is in your PATH or set the PKG_CONFIG environment variable to the full
path to pkg-config.

_PKG_TEXT

To get pkg-config, see <http://www.freedesktop.org/software/pkgconfig>.])],
		[$4])
else
	$1[]_CFLAGS=$pkg_cv_[]$1[]_CFLAGS
	$1[]_LIBS=$pkg_cv_[]$1[]_LIBS
        AC_MSG_RESULT([yes])
	ifelse([$3], , :, [$3])
fi[]dnl
])# PKG_CHECK_MODULES

# serial 1
dnl
AC_DEFUN([S48_IEEE_ENDIANNESS], [dnl
build_universal="$1"
AC_MSG_CHECKING([IEEE floating-point endianness])
if test "$build_universal" = "1";
then 
  AC_MSG_RESULT([building Universal Binary; using compiler defined macros instead])
else
AC_TRY_RUN([#include <stdio.h>
#include <inttypes.h>

typedef uint32_t word32_t;

typedef union { double d; word32_t word[2]; } double_overlay;

#define DOUBLE_WORD0(x) ((double_overlay*)&(x))->word[0]
#define DOUBLE_WORD1(x) ((double_overlay*)&(x))->word[1]


int
main(void)
{
  double n = 0.3;
	
  /* least significant byte first */
  if ((DOUBLE_WORD0(n) == 0x33333333) && (DOUBLE_WORD1(n) == 0x3fd33333))
    return 0;
  /* most significant byte first */
  else if ((DOUBLE_WORD1(n) == 0x33333333) && (DOUBLE_WORD0(n) == 0x3fd33333))
    return 1;
  else {
    fprintf(stderr, "WARNING: unknown IEEE format; assuming IEEE with least significant byte first\n");
    return 0;
  }
}], ieee_endianness="least first", ieee_endianness="most first", ieee_endianness="least first")
AC_MSG_RESULT([$ieee_endianness])
if test "$ieee_endianness" = "most first"; then
  AC_DEFINE([IEEE_MOST_FIRST], 1, [Define if IEEE doubles are stored with most-significant byte first.])
fi
fi
])dnl

# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_NATIVE_CODE], [dnl
dnl assumes that S48_PICK_GC already ran
AC_MSG_CHECKING([native-code compiler support])
AC_ARG_ENABLE([native-code],
[AC_HELP_STRING([--enable-native code],
		[Include support for native-code compiler])],
	[dnl 
         case $GC_OBJS in
	   '${GC_TWOSPACE_OBJS}' )
		 case `uname -m` in
		   i?86 )
			 AC_MSG_RESULT([x86])
			 ASM_OBJECTS='${X86_ASM_OBJECTS}'
			 AC_CHECK_FUNCS(sigaltstack, HAVE_SIGALTSTACK=1, HAVE_SIGALTSTACK=0)
			 if test "$HAVE_SIGALTSTACK" = 0; then
				 AC_MSG_ERROR([Your system lacks sigaltstack])
			 fi
			 AC_MSG_CHECKING([assembler style])
			 case `uname` in
			   Darwin )
			     AC_MSG_RESULT([Darwin])
			     ASM_STYLE='darwin' ;;
			   * )
			     AC_MSG_RESULT([GNU(hopefully)])
			     ASM_STYLE='gnu' ;;
			 esac ;;
		   * )
		     AC_MSG_RESULT([no])
		     ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
		 esac;;
	   * )
	     AC_MSG_RESULT([no (picked GC not compatible)])
	     ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
	 esac],
   	[dnl
	 AC_MSG_RESULT([no])
	 ASM_OBJECTS='${FAKE_ASM_OBJECTS}'
        ]
)])dnl

# serial 1
dnl
dnl
dnl
AC_DEFUN([S48_DYNAMIC_EXTERNALS], [dnl
	dnl
	AC_CHECK_PROGS([LD], [ld cc gcc])
	AC_MSG_CHECKING([compile and link flags for dynamic externals])
	DYNAMIC_EXTERNALS_LDFLAGS_IN_PLACE=""
	case "$host_os" in
		hpux* )
			dnl +z means position-independent code
			DYNAMIC_EXTERNALS_CFLAGS='+z -D_HPUX_SOURCE'
			DYNAMIC_EXTERNALS_LDFLAGS='-b'
		;;
		aix* )
			DYNAMIC_EXTERNALS_CFLAGS=''
			dnl -bM:SRE means shared object
			dnl -brtl means run-time linking is enabled
			dnl -bnoentry means no default entry point
			DYNAMIC_EXTERNALS_LDFLAGS='-bM:SRE -brtl -bI:\$(incdir)/scheme48.exp -bnoentry -bE:\$(incdir)/scheme48-external.exp -lc'
			DYNAMIC_EXTERNALS_LDFLAGS_IN_PLACE='-bM:SRE -brtl -bI:\$(srcdir)/c/scheme48.exp -bnoentry -bE:\$(srcdir)/c/scheme48-external.exp -lc'
		;;
		darwin*|macosx* )
			DYNAMIC_EXTERNALS_CFLAGS='-fno-common'
			DYNAMIC_EXTERNALS_LDFLAGS="$CFLAGS $LDFLAGS -bundle -flat_namespace -undefined suppress"
			dnl linker workaround for MacOSX
			LD="$CC"
		;;
		solaris* )
			DYNAMIC_EXTERNALS_CFLAGS="$PIC"
			dnl -G means shared object
			DYNAMIC_EXTERNALS_LDFLAGS="$LDFLAGS -G"
			LD="$CC"
		;;
		linux* )
			DYNAMIC_EXTERNALS_CFLAGS="$PIC"
			if test "$LD" = "ld"; then
				DYNAMIC_EXTERNALS_LDFLAGS="-shared $LD_LDFLAGS"
			else
				DYNAMIC_EXTERNALS_LDFLAGS="-shared $GCC_LDFLAGS"
			fi
		;;
		cygwin* )
			LD="$CC"
			DYNAMIC_EXTERNALS_CFLAGS=""
			DYNAMIC_EXTERNALS_LDFLAGS='-shared $(bindir)/scheme48vm.a'
			DYNAMIC_EXTERNALS_LDFLAGS_IN_PLACE='-shared $(srcdir)/scheme48vm.a'
		;;
		* )
			DYNAMIC_EXTERNALS_CFLAGS="$PIC"
			DYNAMIC_EXTERNALS_LDFLAGS='-shared'
		;;
	esac
	if test -z "$DYNAMIC_EXTERNALS_LDFLAGS_IN_PLACE"; then
		DYNAMIC_EXTERNALS_LDFLAGS_IN_PLACE="$DYNAMIC_EXTERNALS_LDFLAGS"
	fi
	AC_MSG_RESULT([$DYNAMIC_EXTERNALS_CFLAGS, $DYNAMIC_EXTERNALS_LDFLAGS])
])dnl

# serial 1
dnl
dnl
dnl must run after S48_DYNAMIC_EXTERNALS
AC_DEFUN([S48_PTHREADS], [dnl
       AC_CHECK_HEADERS([pthread.h],[dnl
         pthreads_done="no"
         AC_MSG_CHECKING([Pthreads support])
	 S48_PTHREAD_TRY_FLAGS([-mt])
	 S48_PTHREAD_TRY_FLAGS([-pthread])
	 S48_PTHREAD_TRY_FLAGS([-pthreads])
	 S48_PTHREAD_TRY_FLAGS([-mthreads])
	 S48_PTHREAD_TRY_FLAGS([-thread])
 	])
       ])

# serial 1
dnl
AC_DEFUN([S48_PTHREAD_TRY_FLAGS], [
	if test "$pthreads_done" = "no"; then
	  flags_result=""

	  oldCFLAGS="$CFLAGS"
	  CFLAGS="$CFLAGS $1"
	  AC_TRY_RUN([#include <pthread.h>
int
main(void)
{
  pthread_kill(pthread_self(), 0);
}],
	    [flags_result="$1 (compile)"],
	    [CFLAGS="$oldCFLAGS"])

	  oldLDFLAGS="$LDFLAGS"
	  LDFLAGS="$LDFLAGS $1"
	  AC_TRY_RUN([#include <pthread.h>
int
main(void)
{
  pthread_kill(pthread_self(), 0);
}],
		  [flags_result="$flags_result $1 (link)"
		   pthreads_done="yes"],
		  [LDFLAGS="$oldLDFLAGS"])
	if test -n "$flags_result"; then
		AC_MSG_RESULT($flags_result)
	fi
      fi
])

# serial 1
dnl
dnl
dnl must run after S48_DYNAMIC_EXTERNALS
AC_DEFUN([S48_MISALIGNED_DOUBLES], [dnl
	if test "$GCC" = "yes"; then
		AC_MSG_CHECKING([-munaligned-doubles])
		oldCFLAGS="$CFLAGS"
		CFLAGS="$CFLAGS -munaligned-doubles"
		AC_TRY_RUN([int main() { return 0;}],
			[AC_MSG_RESULT(yes)
				DYNAMIC_EXTERNALS_CFLAGS="$DYNAMIC_EXTERNALS_CFLAGS -munaligned-doubles"],
			[AC_MSG_RESULT(no)
				CFLAGS="$oldCFLAGS"],
			[AC_MSG_RESULT(no)
				CFLAGS="$oldCFLAGS"])
	fi
])dnl

