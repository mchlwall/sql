#!/usr/bin/env bash
# Seeds the project-manager app through its REST API so the resulting SQLite
# database can be explored from a SQL client.
#
# Usage:   ./seed.sh                      (defaults to http://localhost:8080)
#          BASE_URL=http://host:port ./seed.sh
#
# Re-runnable: any existing project with a seed name is deleted first (its tasks
# cascade), then recreated, so the seed data is always in a known state.
# Projects not created by this script are left untouched.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"

for cmd in curl jq; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd is required" >&2; exit 1; }
done

# api METHOD PATH [JSON_BODY] -> prints response body; exits on non-2xx.
api() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" -w $'\n%{http_code}' "$BASE_URL$path")
  [[ -n "$body" ]] && args+=(-H 'Content-Type: application/json' -d "$body")

  local response status
  response="$(curl "${args[@]}")"
  status="${response##*$'\n'}"
  response="${response%$'\n'*}"

  if [[ "$status" != 2* ]]; then
    echo "error: $method $path -> HTTP $status: $response" >&2
    exit 1
  fi
  printf '%s' "$response"
}

# create_project NAME [DESCRIPTION] -> prints new project id
create_project() {
  local name="$1" description="${2:-}"
  local existing_id
  existing_id="$(api GET /api/projects | jq -r --arg n "$name" \
    '.[] | select((.name | ascii_downcase) == ($n | ascii_downcase)) | .id')"
  if [[ -n "$existing_id" ]]; then
    api DELETE "/api/projects/$existing_id" >/dev/null
  fi

  local body
  if [[ -n "$description" ]]; then
    body="$(jq -nc --arg n "$name" --arg d "$description" '{name: $n, description: $d}')"
  else
    body="$(jq -nc --arg n "$name" '{name: $n}')"
  fi
  api POST /api/projects "$body" | jq -r '.id'
}

# create_task PROJECT_ID TITLE STATUS PRIORITY [DUE_DATE] [DESCRIPTION] -> prints new task id
create_task() {
  local project_id="$1" title="$2" status="$3" priority="$4" due="${5:-}" description="${6:-}"
  local body
  body="$(jq -nc \
    --arg t "$title" --arg s "$status" --arg p "$priority" --arg due "$due" --arg d "$description" \
    '{title: $t, status: $s, priority: $p}
     + (if $due == "" then {} else {dueDate: $due} end)
     + (if $d == "" then {} else {description: $d} end)')"
  api POST "/api/projects/$project_id/tasks" "$body" | jq -r '.id'
}

# Date offset from today in yyyy-MM-dd (works with BSD/macOS and GNU date).
days_from_now() {
  local n="$1"
  if date -v+0d +%F >/dev/null 2>&1; then
    date -v"${n}d" +%F
  else
    date -d "$n days" +%F
  fi
}

api GET /health >/dev/null || { echo "error: app not reachable at $BASE_URL" >&2; exit 1; }
echo "Seeding $BASE_URL ..."

# --- Website Redesign: mixed statuses, some overdue ---------------------------
p="$(create_project "Website Redesign" "Refresh the marketing site with the new brand")"
create_task "$p" "Audit current pages"        DONE        LOW    "$(days_from_now -20)" "List every page and its traffic" >/dev/null
create_task "$p" "Create wireframes"          DONE        HIGH   "$(days_from_now -10)" >/dev/null
create_task "$p" "Design homepage mockup"     IN_PROGRESS HIGH   "$(days_from_now -2)"  "Overdue: waiting on brand assets" >/dev/null
create_task "$p" "Build component library"    IN_PROGRESS MEDIUM "$(days_from_now +7)" >/dev/null
create_task "$p" "Write new copy"             TODO        MEDIUM "$(days_from_now +14)" >/dev/null
create_task "$p" "Set up redirects"           TODO        LOW >/dev/null
seo_task="$(create_task "$p" "SEO review" TODO MEDIUM "$(days_from_now +21)")"

# --- Mobile App Launch: high priority heavy -----------------------------------
p="$(create_project "Mobile App Launch" "Ship v1 of the iOS and Android apps")"
create_task "$p" "Finalise app store listing" TODO        HIGH   "$(days_from_now +3)" >/dev/null
create_task "$p" "Fix login crash on Android" IN_PROGRESS HIGH   "$(days_from_now -1)" "Repro on Pixel 6 only" >/dev/null
create_task "$p" "Push notification setup"    IN_PROGRESS MEDIUM "$(days_from_now +5)" >/dev/null
create_task "$p" "Beta tester feedback round" DONE        HIGH   "$(days_from_now -7)" >/dev/null
create_task "$p" "Accessibility pass"         TODO        HIGH   "$(days_from_now +10)" >/dev/null
create_task "$p" "Analytics events"           TODO        LOW >/dev/null

# --- Q4 Budget: all done ------------------------------------------------------
p="$(create_project "Q4 Budget" "Quarterly budget planning")"
create_task "$p" "Collect team requests"      DONE        MEDIUM "$(days_from_now -30)" >/dev/null
create_task "$p" "Draft budget spreadsheet"   DONE        HIGH   "$(days_from_now -25)" >/dev/null
create_task "$p" "Finance sign-off"           DONE        HIGH   "$(days_from_now -15)" >/dev/null

# --- Home Renovation: no description, no due dates ----------------------------
p="$(create_project "Home Renovation")"
create_task "$p" "Get plumber quotes"         TODO        MEDIUM >/dev/null
create_task "$p" "Pick paint colours"         TODO        LOW >/dev/null
create_task "$p" "Order kitchen tiles"        IN_PROGRESS MEDIUM >/dev/null

# --- Reading List: a project with no tasks (useful for LEFT JOINs) ------------
create_project "Reading List" "Books to get through this year" >/dev/null

# --- Updates, so some rows have updated_at > created_at -----------------------
api PATCH "/api/tasks/$seo_task" '{"status":"IN_PROGRESS","priority":"HIGH"}' >/dev/null
reading_id="$(api GET /api/projects | jq -r '.[] | select(.name == "Reading List") | .id')"
api PATCH "/api/projects/$reading_id" '{"description":"Books and long-form articles to get through this year"}' >/dev/null

projects="$(api GET /api/projects | jq 'length')"
echo "Done. $projects projects in the database."
