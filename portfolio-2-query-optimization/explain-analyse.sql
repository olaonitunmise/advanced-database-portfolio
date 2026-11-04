-- Confirming baseline

SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Q1 AFTER-INDEX PLAN
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.book_id,
    b.title,
    string_agg(a.first_name || ' ' || a.last_name, ', ') AS authors,
    c.name AS category
FROM books b
JOIN categories c    ON c.category_id = b.category_id
JOIN book_authors ba ON ba.book_id = b.book_id
JOIN authors a       ON a.author_id = ba.author_id
WHERE b.title LIKE 'Bulk Title 12%'
GROUP BY b.book_id, b.title, c.name
ORDER BY b.title;


-- Q2 AFTER-INDEX PLAN: one member's loan history
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    l.loan_id,
    b.title,
    l.loan_date,
    l.due_date,
    l.return_date
FROM loans l
JOIN book_copies c ON c.copy_id = l.copy_id
JOIN books b       ON b.book_id = c.book_id
WHERE l.member_id = 5000
ORDER BY l.loan_date DESC;


-- Q3 AFTER-INDEX PLAN: currently overdue loans
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    l.loan_id,
    m.first_name,
    m.last_name,
    b.title,
    l.due_date,
    (CURRENT_DATE - l.due_date)      AS days_overdue,
    (CURRENT_DATE - l.due_date) * 50 AS fine_so_far
FROM loans l
JOIN members m     ON m.member_id = l.member_id
JOIN book_copies c ON c.copy_id   = l.copy_id
JOIN books b       ON b.book_id   = c.book_id
WHERE l.return_date IS NULL
  AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;


-- Q4 AFTER-INDEX PLAN: members owing more than 500 in unpaid fines
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    COUNT(*)      AS unpaid_fines,
    SUM(f.amount) AS total_owed
FROM fines f
JOIN loans l   ON l.loan_id   = f.loan_id
JOIN members m ON m.member_id = l.member_id
WHERE f.paid = FALSE
GROUP BY m.member_id, m.first_name, m.last_name
HAVING SUM(f.amount) > 500
ORDER BY total_owed DESC
LIMIT 20;


-- Q5 AFTER-INDEX PLAN: ten most borrowed titles
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    b.title,
    COUNT(*) AS times_borrowed
FROM loans l
JOIN book_copies c ON c.copy_id = l.copy_id
JOIN books b       ON b.book_id = c.book_id
GROUP BY b.book_id, b.title
ORDER BY times_borrowed DESC, b.title
LIMIT 10; 


-- Q6 AFTER-INDEX PLAN: members who have never borrowed
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.member_id, m.first_name, m.last_name, m.status
FROM members m
WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.member_id = m.member_id)
ORDER BY m.member_id;



-- Q7 AFTER-INDEX PLAN: top 3 most borrowed titles per category
EXPLAIN (ANALYZE, BUFFERS)
WITH title_loans AS (
    SELECT
        cat.name AS category,
        b.title,
        COUNT(*) AS loan_count
    FROM loans l JOIN book_copies bc 
	ON bc.copy_id = l.copy_id
    JOIN books b
	ON b.book_id = bc.book_id
    JOIN categories cat 
	ON cat.category_id = b.category_id
    GROUP BY cat.name, b.book_id, b.title
)
SELECT category, title, loan_count, rn
FROM (
    SELECT
        category, title, loan_count,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY loan_count DESC, title
        ) AS rn
    FROM title_loans
) ranked
WHERE rn <= 3
ORDER BY category, rn;





-- Q8 AFTER-INDEX PLAN: availability of a title by ISBN
EXPLAIN (ANALYZE, BUFFERS)
SELECT b.title,
       COUNT(*) AS total_copies,
       COUNT(*) FILTER (WHERE c.status = 'available') AS available_copies
FROM books b
JOIN book_copies c ON c.book_id = b.book_id
WHERE b.isbn = '9780000000009'
GROUP BY b.book_id, b.title;




















