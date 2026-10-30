#!/usr/bin/env bats

@test "Missing PGTARGET" {
  run env \
    "../pg_upgrade-entrypoint.sh"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "CRITICAL: PGTARGET is not defined" ]]
}

@test "14 to 18" {
  pgdata_base="lib/postgresql"
  pgdata="${pgdata_base}/data"
  mkdir -p "${pgdata}"
  echo "14" > "${pgdata}/PG_VERSION"

  run env \
    PGDATA="${pgdata}" \
    PGDATA_BASE="${pgdata_base}" \
    PGTARGET="18" \
    "../pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/data to lib/postgresql/18/docker" ]]
}

@test "14 to 17" {
  pgdata_base="lib/postgresql"
  pgdata="${pgdata_base}/data"
  mkdir -p "${pgdata}"
  echo "14" > "${pgdata}/PG_VERSION"

  run env \
    PGDATA="${pgdata}" \
    PGDATA_BASE="${pgdata_base}" \
    PGTARGET="17" \
    "../pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/data to lib/postgresql/17/docker" ]]
  [[ "$output" =~ "/usr/local-pg17/bin/initdb -U postgres -D lib/postgresql/17/docker" ]]
}

@test "15 to 18" {
  pgdata_base="lib/postgresql"
  pgdata="${pgdata_base}/15/data"
  mkdir -p "${pgdata}"
  echo "15" > "${pgdata}/PG_VERSION"

  run env \
    PGDATA="${pgdata}" \
    PGDATA_BASE="${pgdata_base}" \
    PGTARGET="18" \
    "../pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/15/data to lib/postgresql/18/docker" ]]
}

@test "PGDATA_FROM to PGDATA_TO" {
  pgdata="lib/postgresql/from"
  mkdir -p "${pgdata}"
  echo "17" > "${pgdata}/PG_VERSION"

  run env \
    PGDATA="${pgdata}" \
    PGDATA_NEW="lib/postgresql/to" \
    PGTARGET="18" \
    "../pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/from to lib/postgresql/to" ]]
}

teardown() {
  rm -rf ./lib
}