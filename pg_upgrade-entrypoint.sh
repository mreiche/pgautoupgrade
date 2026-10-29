#!/usr/bin/env sh

set -e

test -n "${PGTARGET}" || {
  echo "CRITICAL: PGTARGET is not defined. This variable is usually provided by the image itself. You may run an incompatible or invalid image. Aborting."
  exit 2
}

test -n "${PGDATA}" || {
  echo "PGDATA is not defined. Aborting."
  exit 2
}

source_dir="${PGDATA}"

test -d "${source_dir}" || {
  echo "Data dir ${source_dir} not found. Aborting."
  exit 2
}

pidfile="${source_dir}/postmaster.pid"
if [ -f "${pidfile}" ]; then
  echo "Pidfile found: ${pidfile}. Source server was not gracefully shut down. Aborting."
  exit 2
fi

test -f "${source_dir}/PG_VERSION" || {
  echo "${source_dir}/PG_VERSION not found. Aborting."
  exit 2
}
source_version=$(cat "${source_dir}/PG_VERSION")

echo "Detected source version ${source_version} in ${source_dir}"

target_version=${PGTARGET%%.*}

if [ "${target_version}" == "${source_version}" ]; then
  echo "Source (${source_version}) and target versions (${target_version}) are identical. Dismiss pg_upgrade."
  exit 0
fi

if [ -n "${PGDATA_TO}" ]; then
  target_dir=${PGDATA_TO}
else
  target_dir="${PGDATA_BASE:-/var/lib/postgresql}/${target_version}/docker"
fi

echo "Upgrading from ${source_dir} to ${target_dir}..."

mkdir -p "${target_dir}"
source_bin_dir="/usr/local-pg${source_version}/bin"
psql_bin=$(which psql)
target_bin_dir=$(dirname ${psql_bin})

set -x

initdb -D "${target_dir}" --no-data-checksums

cd "${PGDATA_BASE}"
mkdir -m 700 /tmp/pg-upgrade-sockets

pg_upgrade \
  --link \
  -b "${source_bin_dir}" \
  -B "${target_bin_dir}" \
  -d "${source_dir}" \
  -D "${target_dir}" \
  --socketdir /tmp/pg-upgrade-sockets

pg_checksums --enable -D "${target_dir}"
