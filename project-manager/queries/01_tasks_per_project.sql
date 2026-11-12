-- Number of tasks in each project, including projects with no tasks.
SELECT
    p.name,
    COUNT(t.id) AS task_count
FROM projects AS p
LEFT JOIN tasks AS t ON p.id = t.project_id
GROUP BY p.id, p.name
ORDER BY p.name;
