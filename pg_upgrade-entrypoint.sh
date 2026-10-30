#!/usr/bin/env sh

set -e

test -n "${PGTARGET}" || {
  echo "PGTARGET is not defined. Aborting."
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

test -f "${source_dir}/PG_VERSION" || {
  echo "${source_dir}/PG_VERSION not found. Aborting."
  exit 2
}
source_version=$(cat "${source_dir}/PG_VERSION")
echo "Detected source version ${source_version} in ${source_dir}"

target_version=${PGTARGET%%.*}

if [ "${target_version}" = "${source_version}" ]; then
  echo "Source (${source_version}) and target versions (${target_version}) are identical. Dismiss pg_upgrade."
  exit 0
fi

pgdata_base=${PGDATA_BASE:-/var/lib/postgresql}

if [ -n "${PGDATA_NEW}" ]; then
  target_dir=${PGDATA_NEW}
else
  target_dir="${pgdata_base}/${target_version}/docker"
fi

if [ "${CLEAN_NEW}" = "1" ]; then
  echo Deleting ${target_dir}
  rm -rf "${target_dir}"
fi

echo "Upgrading from ${source_dir} to ${target_dir}..."

mkdir -p "${target_dir}"
source_bin_dir="/usr/local-pg${source_version}/bin"
target_bin_dir="/usr/local-pg${target_version}/bin"
pg_user="${PGUSER:-postgres}"

mkdir -m 700 -p /tmp/pg-upgrade-sockets
cd /tmp

set -x

whoami

chmod 700 "${source_dir}"
ls -lahF "${pgdata_base}"

if [ "${target_version}" -ge 18 ]; then
  initdb_args="--no-data-checksum"
fi

eval "${target_bin_dir}/initdb \
  -U '${pg_user}' \
  -D '${target_dir}' \
  ${initdb_args}"

eval "${target_bin_dir}/pg_upgrade \
  -U '${pg_user}' \
  ${PGUPGRADE_OPTIONS} \
  -b '${source_bin_dir}' \
  -B '${target_bin_dir}' \
  -d '${source_dir}' \
  -D '${target_dir}' \
  --socketdir /tmp/pg-upgrade-sockets" || {
  cat ${target_dir}/pg_upgrade_output.d/*/log/pg_upgrade_server.log || true
  exit 1
}

if [ "${target_version}" -ge 18 ]; then
  ${target_bin_dir}/pg_checksums --enable -D "${target_dir}"
fi
