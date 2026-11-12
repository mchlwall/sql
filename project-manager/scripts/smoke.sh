#!/usr/bin/env bash
# Runs each query in ../queries against the committed fixture database and
# checks it returns the expected number of rows.
#
# Usage:   ./smoke.sh
#          DB=path/to/other.db ./smoke.sh
#
# The expected counts match fixtures/project-manager.db. If you regenerate the
# fixture or change a query, update EXPECTED below.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="${DB:-$ROOT/fixtures/project-manager.db}"

EXPECTED=(
  "01_tasks_per_project.sql 5"
  "02_overdue_tasks.sql 2"
  "03_projects_without_tasks.sql 1"
  "04_completion_by_project.sql 4"
  "05_orphaned_tasks.sql 0"
  "06_updated_before_created.sql 0"
)

command -v sqlite3 >/dev/null || { echo "error: sqlite3 is required" >&2; exit 1; }
[[ -f "$DB" ]] || { echo "error: database not found: $DB" >&2; exit 1; }

failures=0
for entry in "${EXPECTED[@]}"; do
  read -r file expected <<<"$entry"
  path="$ROOT/queries/$file"
  if [[ ! -f "$path" ]]; then
    echo "FAIL $file: query file not found"
    failures=$((failures + 1))
    continue
  fi

  rows="$(sqlite3 -readonly -batch -noheader -list "$DB" <"$path" | wc -l | tr -d ' ')"
  if [[ "$rows" == "$expected" ]]; then
    echo "ok   $file: $rows rows"
  else
    echo "FAIL $file: expected $expected rows, got $rows"
    failures=$((failures + 1))
  fi
done

untracked="$(comm -23 \
  <(find "$ROOT/queries" -name '*.sql' -exec basename {} \; | sort) \
  <(printf '%s\n' "${EXPECTED[@]}" | cut -d' ' -f1 | sort))"
if [[ -n "$untracked" ]]; then
  echo "FAIL queries with no expected row count in smoke.sh:"
  while read -r file; do echo "       $file"; done <<<"$untracked"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "All checks passed."
