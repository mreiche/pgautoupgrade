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

export source_dir="${PGDATA}"

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

export target_version=${PGTARGET%%.*}

if [ "${target_version}" = "${source_version}" ]; then
  echo "Source (${source_version}) and target versions (${target_version}) are identical. Dismiss pg_upgrade."
  exit 0
fi

pgdata_base=${PGDATA_BASE:-/var/lib/postgresql}

if [ -n "${PGDATA_NEW}" ]; then
  export target_dir=${PGDATA_NEW}
else
  export target_dir="${pgdata_base}/${target_version}/docker"
fi

echo "Upgrading from ${source_dir} to ${target_dir}..."

myuid=$(id -u)
echo "whoami: ${myuid}"

export source_bin_dir="/usr/local-pg${source_version}/bin"
export target_bin_dir="/usr/local-pg${target_version}/bin"

# Create world writable socket dir
mkdir -m 777 -p /tmp/pg-upgrade-sockets
cd /tmp

chmod 700 "${source_dir}"

# If the container runs as root and a PGUID is given
# We need to change the uid of the pre-existing user "postgres" to this uid
if [ -n "${PGUID}" ]; then
  echo "Create user postgres with uid: ${PGUID}"
  useradd -u "${PGUID}" -M -s /bin/sh postgres
  su -m postgres /usr/local/bin/pg_upgrade.sh
else
  /usr/local/bin/pg_upgrade.sh
fi
