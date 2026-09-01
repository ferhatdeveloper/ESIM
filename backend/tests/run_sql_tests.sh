#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"
psql -h "${POSTGRES_HOST:-127.0.0.1}" -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-esim}" \
  -v ON_ERROR_STOP=1 -f "$ROOT/tests/test_business_rules.sql"
