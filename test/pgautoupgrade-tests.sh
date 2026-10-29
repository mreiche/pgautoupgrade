#!/usr/bin/env bats

retry() {
	local command="$@"
	local max_wait="${2:-60}"
	local elapsed=0

	while ! ${command}; do

	  echo $command failed

		if (( elapsed >= max_wait )); then
			return 1
		fi

		sleep 1
		((elapsed++))
	done

	return 0
}

setup() {
  echo "Ignore"
}

@test "From 9.5 to 18" {
  from="9.5-alpine"
  save_from=${from//-/_}

  base_data_dir="pgdata"
  data_dir="${base_data_dir}/${save_from}"
  rm -rf ${base_data_dir} || true
  mkdir -p "${data_dir}"

  name="postgres_${save_from}"

  docker stop "${name}" || true

  docker run \
    --rm \
    --detach \
    -e POSTGRES_PASSWORD=secret \
    --name "${name}" \
    -v "$(pwd)/${data_dir}:/var/lib/postgresql/data" \
    "postgres:${from}"

  retry "docker exec ${name} pg_isready"

  rand_int=$((RANDOM % 1000))
  docker exec "${name}" psql -U postgres -c "CREATE TABLE test(id int4); INSERT INTO test VALUES(${rand_int});"
  sleep 2
  docker exec -u postgres "${name}" sh -exc 'pg_ctl -D "$PGDATA" -m fast stop' || true
  sleep 2

  upgrade_name="${name}_pgautoupgrade"
  docker run \
    --rm \
    -e PGDATA="/var/lib/postgresql/${save_from}" \
    -e PGDATA_BASE="/var/lib/postgresql" \
    --name "${upgrade_name}" \
    -v "$(pwd)/${base_data_dir}:/var/lib/postgresql" \
    "localhost/pgautoupgrade:latest"
}

teardown() {
  # rm -rf ./pgdata
  echo "ignore"
}