#!/bin/bash
set -e

PGBOUNCER_HOST="pg_bouncer"
PGBOUNCER_PORT="6432"
PGBOUNCER_USER="app1"
PGBOUNCER_DB="postgres"
PG_PASSWORD="postgres"

if PGPASSWORD=$PG_PASSWORD psql -h $PGBOUNCER_HOST -p $PGBOUNCER_PORT -U $PGBOUNCER_USER -d $PGBOUNCER_DB -c "SELECT 1;" > /dev/null 2>&1; then
    echo "PgBouncer is healthy." >&2
    exit 0
else
    echo "PgBouncer is not responding." >&2
    exit 1
fi