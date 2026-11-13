#!/usr/bin/env bats

@test "Missing PGTARGET" {
  run env \
    "./pg_upgrade-entrypoint.sh"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "PGTARGET is not defined" ]]
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
    "./pg_upgrade-entrypoint.sh"
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
    "./pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/data to lib/postgresql/17/docker" ]]
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
    "./pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/15/data to lib/postgresql/18/docker" ]]
}

@test "PGDATA_NEW with SKIP_NEW upgrades" {
  pgdata="lib/postgresql/from"
  mkdir -p "${pgdata}"
  echo "17" > "${pgdata}/PG_VERSION"

  run env \
    PGDATA="${pgdata}" \
    PGDATA_NEW="lib/postgresql/to" \
    SKIP_NEW="1" \
    PGTARGET="18" \
    "./pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "Upgrading from lib/postgresql/from to lib/postgresql/to" ]]
}

@test "SKIP_NEW dismisses upgrade" {
  pgdata_from="lib/postgresql/from"
  pgdata_to="lib/postgresql/to"
  mkdir -p "${pgdata_from}"
  mkdir -p "${pgdata_to}"
  echo "17" > "${pgdata_from}/PG_VERSION"
  echo "18" > "${pgdata_to}/PG_VERSION"

  run env \
    PGDATA="${pgdata_from}" \
    PGDATA_NEW="${pgdata_to}" \
    SKIP_NEW="1" \
    PGTARGET="18" \
    "./pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "already exists. Dismiss pg_upgrade." ]]
}

@test "Same version dismisses upgrade" {
  pgdata_from="lib/postgresql/from"
  pgdata_to="lib/postgresql/to"
  mkdir -p "${pgdata_from}"
  mkdir -p "${pgdata_to}"
  echo "18" > "${pgdata_from}/PG_VERSION"
  echo "18" > "${pgdata_to}/PG_VERSION"

  run env \
    PGDATA="${pgdata_from}" \
    PGDATA_NEW="${pgdata_to}" \
    PGTARGET="18" \
    "./pg_upgrade-entrypoint.sh"
  [[ "$output" =~ "are identical. Dismiss pg_upgrade." ]]
}

teardown() {
  rm -rf ./lib
}