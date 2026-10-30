#!/usr/bin/env sh

set -eu

pg_user="${PGUSER:-postgres}"

if [ "${CLEAN_NEW:-0}" = "1" ]; then
  echo "Deleting ${target_dir}"
  rm -rf "${target_dir}"
fi

mkdir -p "${target_dir}" || {
  echo "Failed creating ${target_dir}"
  ls -lahF "${pgdata_base}" || true
  echo whoami: $(id -u)
}

if [ "${target_version}" -ge 18 ]; then
  initdb_args="--no-data-checksum"
fi

set -x

eval "${target_bin_dir}/initdb \
  -U '${pg_user}' \
  -D '${target_dir}' \
  ${initdb_args:-}"

eval "${target_bin_dir}/pg_upgrade \
  -U '${pg_user}' \
  ${PGUPGRADE_OPTIONS:-} \
  -b '${source_bin_dir}' \
  -B '${target_bin_dir}' \
  -d '${source_dir}' \
  -D '${target_dir}' \
  --socketdir /tmp/pg-upgrade-sockets" || {
  cat ${target_dir}/pg_upgrade_output.d/*/log/pg_upgrade_server.log || true
  exit 1
}

if [ "${target_version}" -ge 18 ]; then
  eval "${target_bin_dir}/pg_checksums --enable -D '${target_dir}'"
fi
