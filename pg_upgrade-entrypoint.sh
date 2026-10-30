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

#pidfile="${source_dir}/postmaster.pid"
#if [ -f "${pidfile}" ]; then
#  echo "Pidfile found: ${pidfile}. Source server was not gracefully shut down. Aborting."
#  exit 2
#fi

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

pgdata_base=${PGDATA_BASE:-/var/lib/postgresql}

if [ -n "${PGDATA_TO}" ]; then
  target_dir=${PGDATA_TO}
else
  target_dir="${pgdata_base}/${target_version}/docker"
fi

if [ "${CLEAN_TARGET}" == "1" ]; then
  echo Deleting ${target_dir}
  rm -rf "${target_dir}"
fi

echo "Upgrading from ${source_dir} to ${target_dir}..."

mkdir -p "${target_dir}"
source_bin_dir="/usr/local-pg${source_version}/bin"
psql_bin=$(which psql)

binary_version=$(psql --version | awk '{print $3}' | cut -d. -f1)
if [ "${binary_version}" == "${target_version}" ]; then
  target_bin_dir=$(dirname ${psql_bin})
else
  target_bin_dir="/usr/local-pg${target_version}/bin"
fi

set -x

initdb -D "${target_dir}" --no-data-checksums
chmod 700 "${source_dir}"
ls -lahF "${pgdata_base}"

mkdir -m 700 -p /tmp/pg-upgrade-sockets
cd /tmp

pg_upgrade \
  --link \
  -o "${OLD_OPTIONS}" \
  -O "${NEW_OPTIONS}" \
  -b "${source_bin_dir}" \
  -B "${target_bin_dir}" \
  -d "${source_dir}" \
  -D "${target_dir}" \
  --socketdir /tmp/pg-upgrade-sockets || {
  cat ${target_dir}/pg_upgrade_output.d/*/log/pg_upgrade_server.log || true
  sleep ${SLEEP_ON_ERROR:-10}
  exit 1
}

pg_checksums --enable -D "${target_dir}"
