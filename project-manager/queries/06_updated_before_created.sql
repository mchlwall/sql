-- Rule: a row can't be updated before it was created.
-- Returns the projects and tasks that break the rule.
SELECT
    'project' AS row_type,
    id,
    created_at,
    updated_at
FROM projects
WHERE updated_at < created_at
UNION ALL
SELECT
    'task' AS row_type,
    id,
    created_at,
    updated_at
FROM tasks
WHERE updated_at < created_at;
