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
    mreiche/pgautoupgrade:18.6-alpine3.24
```

## As init container

```yaml
initContainers:
  - name: postgres-upgrade
    image: ghcr.io/mreiche/pgautoupgrade:18.6-alpine3.24
    securityContext: {}  # Pass your security context here
    env:
      - name: PGDATA
        value: /var/lib/postgresql/pgdata
      - name: CLEAN_NEW
        value: "1"
      - name: OPTIONS
        value: "--link -o '-c wal_level=logical'"
    volumeMounts:
      - name: pgdata
        mountPath: /var/lib/postgresql
```

Environment variables:
```shell
PGDATA=""             # Old PostgreSQL data
PGUSER="postgres"     # PostgreSQL superuser to use (optional)
PGDATA_NEW=""         # New PostgreSQL data directory (optional)
PGDATA_BASE="/var/lib/postgresql"  # PostgreSQL data mount point used for auto-detection when PGDATA_NEW is not set (optional)
PGUPGRADE_OPTIONS=""  # Additional options for pg_upgrade (optional)
CLEAN_NEW="0"         # Deletes the new PostgreSQL data (optional)
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
