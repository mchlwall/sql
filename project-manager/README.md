# project-manager

Practice SQL against real data from the [project-manager](https://github.com/mchlwall/project-manager) app.

The app stores its data in a single SQLite file. You add data through the app's API (the seed script does this for you), then query that file with any SQL client.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) or Rancher Desktop, running
- `curl` and `jq` (`brew install jq` on macOS)
- `sqlite3` (preinstalled on macOS) or a graphical SQL client
- The app repo cloned next to this one:

```
Github/
├── project-manager/   # the app
└── sql/               # this repo
```

## 1. Start the app

From the `project-manager` app repo:

```bash
docker compose up --build -d --wait
curl localhost:8080/health     # should reply {"status":"ok"}
```

## 2. Seed the data

From this repo's root:

```bash
./project-manager/scripts/seed.sh
```

This creates 5 projects and 19 tasks. To seed an app running somewhere else, use `BASE_URL=http://host:port ./project-manager/scripts/seed.sh`.

The script is safe to re-run. It deletes and recreates its own projects (and their tasks) each time, so the data always starts from the same state. Projects you created yourself are left alone.

Due dates are set relative to the day you run the script, so some tasks are always overdue and some are upcoming.

## 3. Query the data

The database file is `project-manager/data/project-manager.db` in the app repo. From this repo's root:

```bash
sqlite3 -readonly -header -column ../project-manager/data/project-manager.db
```

`-readonly` stops you locking the file while the app is using it. `-header -column` prints results as a readable table. Exit with `.quit`.

To use a graphical client instead ([DB Browser for SQLite](https://sqlitebrowser.org/), [TablePlus](https://tableplus.com/), [DBeaver](https://dbeaver.io/)), open the `.db` file. There's no host, port or password. Avoid editing data from the client: the app uses a single connection, so open writes can block it.

Changes you make through the app (its web page at <http://localhost:8080> or its API) show up in the file straight away.

## The tables

| Table | Columns |
| --- | --- |
| `projects` | `id`, `name` (unique), `description`, `created_at`, `updated_at` |
| `tasks` | `id`, `project_id` → `projects.id`, `title`, `description`, `status`, `priority`, `due_date`, `created_at`, `updated_at` |

- `status` is one of `TODO`, `IN_PROGRESS`, `DONE`.
- `priority` is one of `LOW`, `MEDIUM`, `HIGH`.
- Dates and timestamps are stored as text (`due_date` as `yyyy-MM-dd`), so SQLite's `date()` functions work on them.
- Deleting a project deletes its tasks.

What's in the seed data that's useful for practice:

- Every status and priority is used.
- Some tasks have no due date or description (NULLs).
- "Q4 Budget" has only finished tasks.
- "Reading List" has no tasks, so it only shows up with a `LEFT JOIN`.
- Some rows were edited after creation, so `updated_at > created_at`.

## Example queries

```sql
.tables                 -- list tables
.schema tasks           -- show column definitions

-- Tasks per project, including projects with none
SELECT p.name, COUNT(t.id) AS tasks
FROM projects p LEFT JOIN tasks t ON t.project_id = p.id
GROUP BY p.id;

-- Overdue tasks that aren't done
SELECT title, status, due_date FROM tasks
WHERE due_date < date('now') AND status <> 'DONE';

-- Completion percentage per project
SELECT p.name, ROUND(100.0 * SUM(t.status = 'DONE') / COUNT(t.id)) AS pct_done
FROM projects p JOIN tasks t ON t.project_id = p.id
GROUP BY p.id;

-- Rows changed after they were created
SELECT title, created_at, updated_at FROM tasks WHERE updated_at > created_at;
```

## Stopping and resetting

```bash
docker compose down     # stop the app; data is kept
```

To start from an empty database, stop the app and delete the app repo's `data/` folder, then start the app and seed again.
