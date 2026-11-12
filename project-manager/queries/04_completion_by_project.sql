-- Percentage of each project's tasks that are done.
-- Projects with no tasks are excluded.
SELECT
    p.name,
    COUNT(t.id) AS task_count,
    SUM(CASE WHEN t.status = 'DONE' THEN 1 ELSE 0 END) AS done_count,
    ROUND(
        100.0 * SUM(CASE WHEN t.status = 'DONE' THEN 1 ELSE 0 END) / COUNT(t.id)
    ) AS pct_done
FROM projects AS p
INNER JOIN tasks AS t ON p.id = t.project_id
GROUP BY p.id, p.name
ORDER BY pct_done DESC, p.name ASC;
