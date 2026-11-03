/* Q1: Catalogue search by title prefix
	Business question: A member asks the librarian to find
	every book whose title starts with "Bulk Title 12",
	showing the authors and the category.
	SQL features: multi-table JOIN (4 tables), LIKE prefix
	search, string_agg(), GROUP BY, ORDER BY */

SELECT
    b.book_id,
    b.title,
    -- Combine multiple authors of one book into a single cell
    string_agg(a.first_name || ' ' || a.last_name, ', ') AS authors,
    c.name AS category
FROM books b
JOIN categories c    ON c.category_id = b.category_id   -- book: its category
JOIN book_authors ba ON ba.book_id = b.book_id          -- book: junction table
JOIN authors a       ON a.author_id = ba.author_id      -- junction: author
WHERE b.title LIKE 'Bulk Title 12%'                     -- prefix search
GROUP BY b.book_id, b.title, c.name                     -- one row per book
ORDER BY b.title;

SELECT COUNT(*) FROM books WHERE title LIKE 'Bulk Title 12%';


/* Q2: One member's loan history
-- Business question: Show every book member 5000 has
--   borrowed, newest first, with due and return dates.
-- SQL features: 3-table JOIN, filter on a foreign key,
--   ORDER BY ... DESC
-- (A NULL return_date would mean the book is still out.) */
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

SELECT COUNT(*) FROM loans WHERE member_id = 5000;

-- Q3: Currently overdue loans
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


-- Q4: Members with large unpaid loans

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

-- Q5: Ten most borrowed titles
SELECT
    b.title,
    COUNT(*) AS times_borrowed              
FROM loans l
JOIN book_copies c ON c.copy_id = l.copy_id 
JOIN books b       ON b.book_id = c.book_id 
GROUP BY b.book_id, b.title                 
ORDER BY times_borrowed DESC, b.title       
LIMIT 10;

-- Confirmation for Q5; checking the count of one title independently
SELECT COUNT(*) AS times_borrowed
FROM loans l
JOIN book_copies c ON c.copy_id = l.copy_id
JOIN books b       ON b.book_id = c.book_id
WHERE b.title = 'Bulk Title 1';

-- Q5 CHECK
SELECT MAX(cnt) AS most_borrowed
FROM (
    SELECT COUNT(*) AS cnt
    FROM loans l
    JOIN book_copies c ON c.copy_id = l.copy_id
    GROUP BY c.book_id
) t;



-- Q6: Members who never borrowed
SELECT
    m.member_id,
    m.first_name,
    m.last_name,
    m.status
FROM members m
WHERE NOT EXISTS (
    SELECT 1
    FROM loans l
    WHERE l.member_id = m.member_id   
)                                     
ORDER BY m.member_id;


-- Q6: Check count
SELECT COUNT(*) AS loans_for_member_8 
FROM loans WHERE member_id = 8;


/* Q7: Top 3 titles per category
 Business question: Within each category, which three titles are borrowed most often? */
 WITH title_loans AS (                      
    SELECT
        cat.name AS category,
        b.title,
        COUNT(*) AS loan_count
    FROM loans l
    JOIN book_copies bc ON bc.copy_id      = l.copy_id
    JOIN books b        ON b.book_id       = bc.book_id
    JOIN categories cat ON cat.category_id = b.category_id
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


-- Q7: Check
SELECT cat.name AS category, COUNT(*) AS loan_count
FROM loans l
JOIN book_copies bc ON bc.copy_id      = l.copy_id
JOIN books b        ON b.book_id       = bc.book_id
JOIN categories cat ON cat.category_id = b.category_id
WHERE b.title = 'Bulk Title 10004'
GROUP BY cat.name;



/* Q8: Availability of a title by ISBN
-- Business question: How many copies of a given book does the library own, and how many are on the shelf now?*/
SELECT
    b.title,
    COUNT(*) AS total_copies,                                        -- all copies of this title
    COUNT(*) FILTER (WHERE c.status = 'available') AS available_copies  -- only those on the shelf
FROM books b
JOIN book_copies c ON c.book_id = b.book_id      
WHERE b.isbn = '9780000000009'                   
GROUP BY b.book_id, b.title;

-- Check
SELECT barcode, status
FROM book_copies
WHERE barcode IN ('CL-0013', 'CL-0014', 'CL-0015')
ORDER BY barcode;