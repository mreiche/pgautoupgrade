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

    save_from=${from//-/_}

    base_data_dir="pgdata"
    data_dir="${base_data_dir}/${save_from}"

    if [ -e "${base_data_dir}" ]; then
      if [ "${CI:-}" = "true" ]; then
        echo "CI: Delete ${base_data_dir}"
        sudo rm -rf "${base_data_dir}"
      else
        rm -rf "${base_data_dir}"
      fi
    fi

    mkdir -p "${data_dir}"

    name="postgres_${save_from}"
    migration_name="${name}_migrated"

    docker stop "${name}" || true
    docker stop "${migration_name}" || true

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

    postgres_uid=$(docker exec "${name}" id -u postgres)

    if [ "${CI:-}" = "true" ]; then
      echo "CI: Change owner to ${postgres_uid}"
    	sudo chown -R "${postgres_uid}" "${base_data_dir}"
    fi

    rand_int=$((RANDOM % 1000))
    docker exec "${name}" psql -U postgres -c "CREATE TABLE test(id int4); INSERT INTO test VALUES(${rand_int});"
    docker exec -u postgres "${name}" sh -exc 'pg_ctl -D "$PGDATA" -m fast stop' || true
    while docker inspect -f '{{.State.Running}}' "${name}" ; do
      sleep 1
    done

    pg_target=${to%%[^0-9]*}

    # Run the migration
    upgrade_name="${name}_pgautoupgrade"
    docker run \
      --user "${postgres_uid}" \
      --rm \
      -e PGTARGET="${pg_target}" \
      -e PGDATA="/var/lib/postgresql/${save_from}" \
      -e PGDATA_BASE="/var/lib/postgresql" \
      --name "${upgrade_name}" \
      -v "$(pwd)/${base_data_dir}:/var/lib/postgresql" \
      "${image}"

    # Test the migration
    docker run \
      --rm \
      --detach \
      -e PGDATA="/var/lib/postgresql/${pg_target}/docker" \
      -e POSTGRES_PASSWORD=secret \
      --name "${migration_name}" \
      -v "$(pwd)/${base_data_dir}:/var/lib/postgresql" \
      "postgres:${to}"

    retry "docker exec ${migration_name} pg_isready"

    get_int=$(docker exec "${migration_name}" psql -U postgres -t -A -c "SELECT id FROM test LIMIT 1;")
    test "${get_int}" -eq "${rand_int}"

    docker stop "${migration_name}"
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