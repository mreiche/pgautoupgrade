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
data_uid=$(stat -c '%u' "${source_dir}")
echo "Detected source version ${source_version} in ${source_dir} owned by uid: ${data_uid}"

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

my_uid=$(id -u)
echo "whoami: ${my_uid}"

export source_bin_dir="/usr/local-pg${source_version}/bin"
export target_bin_dir="/usr/local-pg${target_version}/bin"

# Create world writable socket dir
mkdir -m 777 -p /tmp/pg-upgrade-sockets
cd /tmp

chmod 700 "${source_dir}"

# If the data uid differs from the current uid
if [ "${data_uid}" != "${my_uid}" ]; then
  # Create a user with that uid
  echo "Create user postgres with uid: ${data_uid}"
  useradd -u "${data_uid}" -M -s /bin/sh postgres
  # And run the migration as this user
  su -m postgres /usr/local/bin/pg_upgrade.sh
else
  /usr/local/bin/pg_upgrade.sh
fi
