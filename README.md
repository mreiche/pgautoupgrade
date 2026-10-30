# pgautoupgrade-simple

This is a PostgreSQL Docker image to automatically upgrade
your database.

It is a much simpler and flexible implementation inspired/forked by [pgautoupgrade/docker-pgautoupgrade](https://github.com/pgautoupgrade/docker-pgautoupgrade)

Its whole purpose in life is to automatically detect the
version of PostgreSQL used in the existing PostgreSQL data
directory, then automatically upgrade it (if needed) to the
required version of PostgreSQL using `pg_upgrade`.

Note: It does not start a PostgreSQL server nor does it clean up the old cluster data.

## How to use this image

```shell
docker run \
    --rm \
    -e PGDATA="/var/lib/postgresql/data" \
    -v "/var/data/dir:/var/lib/postgresql" \
    mreiche/pgautoupgrade:18.6-alpine3.24
```

### As init container

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
      - name: PGUPGRADE_OPTIONS
        value: "-o '-c wal_level=logical'"
    volumeMounts:
      - name: pgdata
        mountPath: /var/lib/postgresql
```

### Environment variables
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

    ghcr.io/mreiche/pgautoupgrade:18.6-debian13.7

## Troubleshooting

### Symptom: FATAL: logical replication slot "xxx" exists, but wal_level < logical
* Reason: The old cluster was supporting a higher WAL level
* Solution: Pass `PGUPGRADE_OPTIONS="-o '-c wal_level=logical"'`
