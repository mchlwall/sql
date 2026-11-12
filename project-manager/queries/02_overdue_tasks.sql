-- Unfinished tasks that were overdue on 2026-11-12, the day the fixture
-- was seeded. Uses a fixed date rather than date('now') so the result
-- doesn't change over time.
SELECT
    p.name AS project,
    t.title,
    t.status,
    t.due_date
FROM tasks AS t
INNER JOIN projects AS p ON t.project_id = p.id
WHERE
    t.due_date < '2026-11-12'
    AND t.status != 'DONE'
ORDER BY t.due_date;
