-- Rule: every project should have at least one task.
-- Returns the projects that break the rule.
SELECT
    p.id,
    p.name
FROM projects AS p
WHERE
    NOT EXISTS (
        SELECT 1
        FROM tasks AS t
        WHERE t.project_id = p.id
    )
ORDER BY p.name;
