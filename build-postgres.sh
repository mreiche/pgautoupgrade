#!/usr/bin/env sh

set -exu

pgversion_major=${PGVERSION%%.*}

curl -fLo postgresql.tar.bz2 https://ftp.postgresql.org/pub/source/v${PGVERSION}/postgresql-${PGVERSION}.tar.bz2
tar -xf postgresql.tar.bz2
cd "postgresql-${PGVERSION}"

export CFLAGS="${CFLAGS:--Os}"

./configure --prefix="/usr/local-pg${pgversion_major}" --with-openssl=no --with-lz4 --without-readline --with-icu --with-system-tzdata=/usr/share/zoneinfo --enable-debug=no
make -j $(nproc) ${BUILD_TARGET}
make ${INSTALL_TARGET}
rm -rf "/usr/local-pg${pgversion_major}/include"
