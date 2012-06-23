#!/bin/sh -e

# Part of Scheme 48 1.9.  See file COPYING for notices and license.
#
# Authors: Martin Gasbichler, Marcus Crestani, Robert Ransom
#

# Ensure that $MAKE is set.
echo "${MAKE:=make}" >/dev/null

echo "This script requires an installed scheme48 executable in the path."
echo "The executable should be Scheme 48 1.6 or later."
sleep 3
ACLOCAL="aclocal -I m4" autoreconf -v -i
./configure
rm -rf autom4te.cache
rm -f scheme48.image build/initial.image-32 build/initial.image-64 c/scheme48.h
>build/filenames.make
touch -t 197001010101 build/filenames.make
${MAKE} ./build/filenames.make
${MAKE} i-know-what-i-am-doing
${MAKE} c/scheme48.h
${MAKE} ./build/initial.image-32 ./build/initial.image-64
${MAKE} distclean
