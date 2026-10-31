# pgautoupgrade

This is a PostgreSQL Docker image to automatically upgrade
your database by detecting the version of the PostgreSQL data directory, then automatically upgrades it (if needed) to the
given target version using `pg_upgrade`. More details here: [How it works](#how-it-works)

It is a much simpler and flexible implementation inspired/forked by [pgautoupgrade/docker-pgautoupgrade](https://github.com/pgautoupgrade/docker-pgautoupgrade)

## How to use this image

```shell
docker run \
  --rm \
  -e PGUID="70" \
  -e PGDATA="/var/lib/postgresql/data" \
  -v "/var/data/dir:/var/lib/postgresql" \
  mreiche/pgautoupgrade:14-18.alpine3.24
```

### As Kubernetes init container

```yaml
initContainers:
  - name: postgres-upgrade
    image: ghcr.io/mreiche/pgautoupgrade:14-18.alpine3.24
    securityContext:
      runAsUser: 70  # Pass your UID here
      fsGroup: 70  # Pass your UID here
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

### As Docker Compose
```yaml
services:
  postgres-upgrade:
    image: ghcr.io/mreiche/pgautoupgrade:14-18.alpine3.24
    environment:
      PGDATA: /var/lib/postgresql/pgdata
      PGUID: 70  # UID of the volume owner
    volumes:
      - pgdata:/var/lib/postgresql
  
  postgres:
    image: postgres:18-alpine
    depends_on:
      postgres-upgrade:
        condition: service_completed_successfully
    volumes:
      - pgdata:/var/lib/postgresql

volumes:
  pgdata:
```

### Environment variables
```shell
PGDATA=""             # Old PostgreSQL data (source)
PGUID=""              # UID of the volume owner, container must run as root if set (optional)
PGUSER="postgres"     # PostgreSQL superuser to use (optional)
PGDATA_NEW=""         # New PostgreSQL data directory (optional)
PGDATA_BASE="/var/lib/postgresql"  # PostgreSQL data mount point used for auto-detection when PGDATA_NEW is not set (optional)
PGUPGRADE_OPTIONS=""  # Additional options for pg_upgrade (optional)
CLEAN_NEW="0"         # Deletes the new PostgreSQL data (optional)
PGTARGET="18"         # Target PostgreSQL major version (optional)
```

### How it works

The `pg_upgrade` is pretty strict. It requires an existing user, which UID matches the process and source and target directories.
So either your container user must match the UID of the volume owner or run it as root and pass the `PGUID` with volume owner UID for an internal user switch.

Additional facts:
- It does not start a PostgreSQL server
- It does not manipulate the source data (unless `--link` is used)
- It always migrates the data to `$PGDATA_BASE/$PGTARGET/docker` unless `PGDATA_NEW` is set
- It does not clean up the old cluster data

### Supported PostgreSQL versions

The image tag `14-18.xxx` describes, which PostgreSQL versions are supported within the image.
By default, the migration is performed to the highest version (18). If you want to migrate to a lower version, set `PGTARGET="17"`.

I dropped support for PostgreSQL 13 and lower, since they are [end-of-life](https://endoflife.date/postgresql) for a while now. Please give feedback if you demand them.

For older versions (from 9.5), try the older images `18.6-alpine3.24` or `18.6-debian13.7`.

## Debian vs Alpine based images

The default official Docker PostgreSQL image is Debian-based, 
and upgrading from that to one of our Alpine-based images doesn't always work out well.

To solve that problem, we have Debian-based images available as well.

To use either of those, choose the version of PostgreSQL you'd
like to upgrade to, then change your docker image to match:

    ghcr.io/mreiche/pgautoupgrade:14-18.debian13.7

## Troubleshooting

### Symptom: FATAL: logical replication slot "xxx" exists, but wal_level < logical
* Reason: The old cluster was supporting a higher WAL level
* Solution: Pass `PGUPGRADE_OPTIONS="-o '-c wal_level=logical"'`
