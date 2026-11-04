-- Foreign key columns are NOT indexed automatically in PostgreSQL
CREATE INDEX idx_loans_member_id ON loans (member_id);
CREATE INDEX idx_loans_copy_id   ON loans (copy_id);
CREATE INDEX idx_copies_book_id  ON book_copies (book_id);

-- Partial index: only the (few) open loans, for the overdue report
CREATE INDEX idx_loans_open_due ON loans (due_date) WHERE return_date IS NULL;

-- Prefix search on title (text_pattern_ops makes LIKE 'abc%' index-friendly)
CREATE INDEX idx_books_title_prefix ON books (title text_pattern_ops);

-- Deliberately low-selectivity: about half of all fines are unpaid
CREATE INDEX idx_fines_paid ON fines (paid);

ANALYZE;

-- Index sizes
SELECT indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
ORDER BY indexname;

-- Table sizes
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size_with_indexes
FROM pg_catalog.pg_statio_user_tables
WHERE relname IN ('loans', 'book_copies', 'books', 'fines')
ORDER BY relname;

--Indexes after
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;













