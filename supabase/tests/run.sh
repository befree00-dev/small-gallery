#!/usr/bin/env bash
# Runs the migrations and the RLS tests against a throwaway local PostgreSQL.
# Needs PostgreSQL 15+ server binaries (initdb, pg_ctl) on PATH or in PG_BIN.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
pg_bin="${PG_BIN:-$(dirname "$(command -v initdb 2>/dev/null || ls /usr/lib/postgresql/*/bin/initdb | tail -1)")}"
data="$(mktemp -d)"
port="${PGPORT_TEST:-54329}"

if [ "$(id -u)" = "0" ]; then
  chown -R postgres "$data"
  run() { su postgres -c "$*"; }
else
  run() { bash -c "$*"; }
fi

cleanup() { run "'$pg_bin/pg_ctl' -D '$data' -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$data"; }
trap cleanup EXIT

run "'$pg_bin/initdb' -D '$data' -U postgres -A trust >/dev/null"
run "'$pg_bin/pg_ctl' -D '$data' -o '-p $port -k /tmp -c listen_addresses=' -l '$data/log' start >/dev/null"
sleep 1

psql_cmd=(psql -h /tmp -p "$port" -U postgres -v ON_ERROR_STOP=1 -q)

# Run once like an older Supabase project (broad default grants) and once like
# a newer one (no default grants), so the migrations work on both.
for mode in default_grants no_default_grants; do
  db="sg_$mode"
  "${psql_cmd[@]}" -c "create database $db" >/dev/null
  "${psql_cmd[@]}" -d "$db" -f "$here/supabase_shim.sql" >/dev/null
  if [ "$mode" = default_grants ]; then
    "${psql_cmd[@]}" -d "$db" -f "$here/supabase_default_grants.sql" >/dev/null
  fi
  for f in "$root"/migrations/*.sql; do
    "${psql_cmd[@]}" -d "$db" -f "$f" >/dev/null
  done
  echo "== $mode =="
  "${psql_cmd[@]}" -d "$db" -f "$here/rls_test.sql"
done
