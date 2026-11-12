-- Rule: every task must belong to an existing project.
-- Returns the tasks that break the rule.
SELECT
    t.id,
    t.title,
    t.project_id
FROM tasks AS t
LEFT JOIN projects AS p ON t.project_id = p.id
WHERE p.id IS NULL;
