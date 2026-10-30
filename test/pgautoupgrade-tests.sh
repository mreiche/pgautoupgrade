#!/usr/bin/env bats

export flavor=${FLAVOR:-alpine}

retry() {
	local command="$@"
	local max_wait="${2:-60}"
	local elapsed=0

	while ! ${command}; do

	  echo $command failed

		if [ "${elapsed}" -ge "${max_wait}" ]; then
		  echo "Failed after ${elapsed} seconds"
			return 1
		fi

		sleep 1
		elapsed=$((elapsed + 1))
	done

	return 0
}

setup() {
  echo "Ignore"
}

test_migration() {
    from=$1
    to=$2
    image=${3:-pgautoupgrade-${flavor}:latest}

    name="from_${from//-/_}_to_${to//-/_}"
    pg_target=${to%%[^0-9]*}
    test_name="${name}_test"

    base_data_dir="pgdata"
    data_dir="${base_data_dir}/${name}"

    if [ -e "${base_data_dir}" ]; then
      if [ "${CI:-}" = "true" ]; then
        echo "CI: Delete ${base_data_dir}"
        sudo rm -rf "${base_data_dir}"
      else
        rm -rf "${base_data_dir}"
      fi
    fi

    mkdir -p "${data_dir}"

    docker stop "${name}" || true
    docker stop "${test_name}" || true

    # Pre pull the image
    docker pull "postgres:${from}"

    # Initial data
    docker run \
      --rm \
      --detach \
      -e POSTGRES_PASSWORD=secret \
      --name "${name}" \
      -v "$(pwd)/${data_dir}:/var/lib/postgresql/data" \
      "postgres:${from}"

    retry "docker exec ${name} pg_isready"

    if [ "${CI:-}" = "true" ]; then
      postgres_uid=$(docker exec "${name}" id -u postgres)
    else
      postgres_uid=$(id -u)
    fi

    rand_int=$((RANDOM % 1000))
    docker exec "${name}" psql -U postgres -c "CREATE TABLE test(id int4); INSERT INTO test VALUES(${rand_int});"
    docker exec -u postgres "${name}" sh -exc 'pg_ctl -D "$PGDATA" -m fast stop' || true
    while docker inspect -f '{{.State.Running}}' "${name}" ; do
      sleep 1
    done


    echo "Run migration as: ${postgres_uid}"

    if [ "${CI:-}" = "true" ]; then
      echo "CI: Change owner of ${base_data_dir} to: ${postgres_uid}"
      sudo chown -R "${postgres_uid}" "${base_data_dir}"
    fi

    # Run the migration
    upgrade_name="${name}_pgautoupgrade"
    docker run \
      --rm \
      -e PGUID="${postgres_uid}" \
      -e PGTARGET="${pg_target}" \
      -e PGDATA="/var/lib/postgresql/${name}" \
      -e PGDATA_BASE="/var/lib/postgresql" \
      -e PGUPGRADE_OPTIONS="-o '-c wal_level=logical'" \
      --name "${upgrade_name}" \
      -v "$(pwd)/${base_data_dir}:/var/lib/postgresql" \
      "${image}"

    # Test the migration
    docker run \
      --rm \
      --detach \
      -e PGDATA="/var/lib/postgresql/${pg_target}/docker" \
      -e POSTGRES_PASSWORD=secret \
      --name "${test_name}" \
      -v "$(pwd)/${base_data_dir}:/var/lib/postgresql" \
      "postgres:${to}"

    retry "docker exec ${test_name} pg_isready"

    get_int=$(docker exec "${test_name}" psql -U postgres -t -A -c "SELECT id FROM test LIMIT 1;")
    test "${get_int}" -eq "${rand_int}"

    docker stop "${test_name}"
}

@test "From 14 to 18 (${flavor})" {
  test_migration "14-alpine" "18-alpine"
}

@test "From 14 to 17 (${flavor})" {
  test_migration "14-alpine" "17-alpine"
}

teardown() {
  # rm -rf ./pgdata
  echo "ignore"
}