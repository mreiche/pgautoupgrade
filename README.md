# pgautoupgrade-simple

This is a PostgreSQL Docker image to automatically upgrade
your database.

This is a much simpler implementation inspired/forked by [pgautoupgrade/docker-pgautoupgrade](https://github.com/pgautoupgrade/docker-pgautoupgrade)

Its whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, then automatically upgrade it (if needed) to the
required version of PostgreSQL using `pg_upgrade` with the `--link` option.

After this, the PostgreSQL server starts and runs as per
normal. The old cluster data will be removed.

The reason this Docker image is needed, is because the
official Docker PostgreSQL image has no ability to handle
version upgrades, which leaves people to figure it out
manually (not great): <https://github.com/docker-library/postgres/issues/37>

> [!WARNING]
> Backup your data!
> This Docker image does an in-place upgrade of the database
> data, so if something goes wrong you are expected to already
> have backups you can restore from.

> [!IMPORTANT]
> Also, remove any healthchecks.
> Due to how we perform the update process, we had to implement our own healthcheck.
> So no extra healthcheck is needed.

## How to use this image

```shell
docker run \
    --rm \
    -e PGDATA="/var/lib/postgresql/data" \
    -v "/var/data/dir:/var/lib/postgresql" \
    "mreiche/pgautoupgrade:latest"
```

Environment variables:
```shell
PGDATA=""             # Old PostgreSQL data
PGDATA_TO=""          # Target PostgreSQL data (optional)
PGDATA_BASE="/var/lib/postgresql"  # PostgreSQL data mount point (optional)
CLEAN_TARGET="0"      # Deletes the target PostgreSQL data (optional)
OLD_OPTIONS=""        # Inject options for the old PostgreSQL data (optional)
NEW_OPTIONS=""        # Inject options for the new PostgreSQL data (optional)
SLEEP_ON_ERROR="10"   # Sleep after pg_upgrade failed (optional)
```

## Debian vs Alpine based images

The default official Docker PostgreSQL image is Debian Linux
based, and upgrading from that to one of our Alpine Linux
based images doesn't always work out well.

To solve that problem, we have Debian based images available as well.

To use either of those, choose the version of PostgreSQL you'd
like to upgrade to, then change your docker image to match:

    pgautoupgrade/pgautoupgrade:18-trixie

## Troubleshooting

### Symptom: FATAL: logical replication slot "xxx" exists, but wal_level < logical
* Solution: Pass `NEW_OPTIONS="-c wal_level=logical"`
