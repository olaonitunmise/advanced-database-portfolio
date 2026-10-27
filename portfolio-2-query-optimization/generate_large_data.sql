-- =====================================================
-- Bulk synthetic data for performance testing
-- Run once, after sample-data.sql
-- =====================================================

-- 20,000 members
INSERT INTO members (first_name, last_name, email, phone, join_date, status)
SELECT 'First' || g, 'Last' || g,
       'member' || g || '@bulk.example.com',
       '0805' || lpad(g::text, 7, '0'),
       DATE '2023-01-01' + (random() * 1000)::int,
       'active'
FROM generate_series(1, 20000) g;

-- 20,000 books, spread across the existing categories
WITH cats AS (SELECT array_agg(category_id ORDER BY category_id) AS ids FROM categories)
INSERT INTO books (isbn, title, publisher, publication_year, category_id)
SELECT '979' || lpad(g::text, 10, '0'),
       'Bulk Title ' || g,
       'Bulk Press',
       1990 + (g % 35),
       cats.ids[1 + (g % array_length(cats.ids, 1))]
FROM generate_series(1, 20000) g
CROSS JOIN cats;

-- One author per bulk book
WITH a AS (SELECT array_agg(author_id ORDER BY author_id) AS ids FROM authors)
INSERT INTO book_authors (book_id, author_id)
SELECT b.book_id, a.ids[1 + (b.book_id % array_length(a.ids, 1))]
FROM books b CROSS JOIN a
WHERE b.isbn LIKE '979%';

-- 3 copies per bulk book = 60,000 copies
INSERT INTO book_copies (book_id, barcode, status, acquired_date)
SELECT b.book_id,
       'BK-' || lpad(b.book_id::text, 6, '0') || '-' || c,
       'available',
       DATE '2020-01-01' + ((b.book_id * 7 + c) % 1500)
FROM books b CROSS JOIN generate_series(1, 3) c
WHERE b.isbn LIKE '979%';

-- 300,000 returned loans (returned 0-20 days after loan, due after 14 days)
WITH cp  AS (SELECT array_agg(copy_id)   AS ids FROM book_copies WHERE barcode LIKE 'BK-%'),
     mb  AS (SELECT array_agg(member_id) AS ids FROM members WHERE email LIKE '%@bulk.example.com'),
     st  AS (SELECT array_agg(staff_id)  AS ids FROM staff),
     gen AS MATERIALIZED (
         SELECT g,
                DATE '2024-01-01' + (random() * 900)::int AS loan_date,
                (random() * 20)::int                      AS days_kept
         FROM generate_series(1, 300000) g
     )
INSERT INTO loans (copy_id, member_id, staff_id, loan_date, due_date, return_date)
SELECT cp.ids[1 + (g % array_length(cp.ids, 1))],
       mb.ids[1 + floor(random() * array_length(mb.ids, 1))::int],
       st.ids[1 + (g % array_length(st.ids, 1))],
       loan_date,
       loan_date + 14,
       loan_date + days_kept
FROM gen CROSS JOIN cp CROSS JOIN mb CROSS JOIN st;

-- A fine for every late return, at 50 per overdue day
INSERT INTO fines (loan_id, amount, fine_date, paid, paid_date)
SELECT l.loan_id,
       (l.return_date - l.due_date) * 50,
       l.return_date,
       (l.loan_id % 2 = 0),
       CASE WHEN l.loan_id % 2 = 0 THEN l.return_date + 1 END
FROM loans l
WHERE l.return_date > l.due_date
  AND NOT EXISTS (SELECT 1 FROM fines f WHERE f.loan_id = l.loan_id);

-- Refresh planner statistics (important before measuring anything)
ANALYZE;