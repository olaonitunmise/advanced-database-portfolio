-- CityLight Public Library: sample data

INSERT INTO categories (name) VALUES
 ('Fiction'), ('Science'), ('History'), ('Technology'), ('Children''s');

INSERT INTO authors (first_name, last_name) VALUES
 ('Chinua', 'Achebe'),
 ('Chimamanda Ngozi', 'Adichie'),
 ('Wole', 'Soyinka'),
 ('Yuval Noah', 'Harari'),
 ('Stephen', 'Hawking'),
 ('Carl', 'Sagan'),
 ('Abraham', 'Silberschatz'),
 ('Henry', 'Korth'),
 ('S.', 'Sudarshan'),
 ('Robert C.', 'Martin'),
 ('Roald', 'Dahl');

INSERT INTO staff (first_name, last_name, email, role) VALUES
 ('Grace', 'Ade',   'grace.ade@citylight.example',   'Head Librarian'),
 ('Samuel', 'Okon', 'samuel.okon@citylight.example', 'Circulation Librarian'),
 ('Bisi', 'Lawal',  'bisi.lawal@citylight.example',  'Assistant Librarian');

INSERT INTO members (first_name, last_name, email, phone, join_date, status) VALUES
 ('Adaeze',  'Okafor',  'adaeze.okafor@example.com',  '08030000001', '2025-01-10', 'active'),
 ('Tunde',   'Balogun', 'tunde.balogun@example.com',  '08030000002', '2025-02-14', 'active'),
 ('Ngozi',   'Eze',     'ngozi.eze@example.com',      '08030000003', '2025-03-03', 'active'),
 ('Ibrahim', 'Musa',    'ibrahim.musa@example.com',   '08030000004', '2025-05-21', 'active'),
 ('Funmi',   'Adeyemi', 'funmi.adeyemi@example.com',  '08030000005', '2025-06-30', 'active'),
 ('Chinedu', 'Obi',     'chinedu.obi@example.com',    '08030000006', '2025-08-12', 'active'),
 ('Aisha',   'Bello',   'aisha.bello@example.com',    '08030000007', '2026-01-05', 'active'),
 ('Emeka',   'Nwosu',   'emeka.nwosu@example.com',    '08030000008', '2026-02-18', 'suspended');

INSERT INTO books (isbn, title, publisher, publication_year, category_id)
SELECT v.isbn, v.title, v.publisher, v.yr, c.category_id
FROM (VALUES
 ('9780000000001', 'Things Fall Apart',               'Heinemann',        1958, 'Fiction'),
 ('9780000000002', 'Arrow of God',                    'Heinemann',        1964, 'Fiction'),
 ('9780000000003', 'Half of a Yellow Sun',            'Fourth Estate',    2006, 'Fiction'),
 ('9780000000004', 'Death and the King''s Horseman',  'Methuen',          1975, 'Fiction'),
 ('9780000000005', 'Sapiens',                         'Harvill Secker',   2014, 'History'),
 ('9780000000006', 'Homo Deus',                       'Harvill Secker',   2016, 'History'),
 ('9780000000007', 'A Brief History of Time',         'Bantam',           1988, 'Science'),
 ('9780000000008', 'Cosmos',                          'Random House',     1980, 'Science'),
 ('9780000000009', 'Database System Concepts',        'McGraw-Hill',      2019, 'Technology'),
 ('9780000000010', 'Clean Code',                      'Prentice Hall',    2008, 'Technology'),
 ('9780000000011', 'Matilda',                         'Jonathan Cape',    1988, 'Children''s'),
 ('9780000000012', 'The Twits',                       'Jonathan Cape',    1980, 'Children''s')
) AS v(isbn, title, publisher, yr, cat)
JOIN categories c ON c.name = v.cat;

-- Many-to-many: Database System Concepts has three authors
INSERT INTO book_authors (book_id, author_id)
SELECT b.book_id, a.author_id
FROM (VALUES
 ('9780000000001', 'Achebe'),
 ('9780000000002', 'Achebe'),
 ('9780000000003', 'Adichie'),
 ('9780000000004', 'Soyinka'),
 ('9780000000005', 'Harari'),
 ('9780000000006', 'Harari'),
 ('9780000000007', 'Hawking'),
 ('9780000000008', 'Sagan'),
 ('9780000000009', 'Silberschatz'),
 ('9780000000009', 'Korth'),
 ('9780000000009', 'Sudarshan'),
 ('9780000000010', 'Martin'),
 ('9780000000011', 'Dahl'),
 ('9780000000012', 'Dahl')
) AS v(isbn, last_name)
JOIN books b   ON b.isbn = v.isbn
JOIN authors a ON a.last_name = v.last_name;

-- 20 physical copies. on_loan copies match the open loans below.
INSERT INTO book_copies (book_id, barcode, status, acquired_date)
SELECT b.book_id, v.barcode, v.status, v.acq
FROM (VALUES
 ('9780000000001', 'CL-0001', 'available', '2024-01-15'::date),
 ('9780000000001', 'CL-0002', 'available', '2024-01-15'),
 ('9780000000002', 'CL-0003', 'available', '2024-02-10'),
 ('9780000000003', 'CL-0004', 'available', '2024-03-05'),
 ('9780000000003', 'CL-0005', 'available', '2024-03-05'),
 ('9780000000004', 'CL-0006', 'lost',      '2024-03-20'),
 ('9780000000005', 'CL-0007', 'available', '2024-05-01'),
 ('9780000000005', 'CL-0008', 'available', '2024-05-01'),
 ('9780000000006', 'CL-0009', 'available', '2024-06-12'),
 ('9780000000007', 'CL-0010', 'available', '2024-07-08'),
 ('9780000000008', 'CL-0011', 'available', '2024-07-08'),
 ('9780000000008', 'CL-0012', 'available', '2024-07-08'),
 ('9780000000009', 'CL-0013', 'on_loan',   '2025-01-20'),
 ('9780000000009', 'CL-0014', 'available', '2025-01-20'),
 ('9780000000009', 'CL-0015', 'on_loan',   '2025-01-20'),
 ('9780000000010', 'CL-0016', 'on_loan',   '2025-02-02'),
 ('9780000000010', 'CL-0017', 'available', '2025-02-02'),
 ('9780000000011', 'CL-0018', 'on_loan',   '2025-04-17'),
 ('9780000000011', 'CL-0019', 'available', '2025-04-17'),
 ('9780000000012', 'CL-0020', 'available', '2025-04-17')
) AS v(isbn, barcode, status, acq)
JOIN books b ON b.isbn = v.isbn;

-- 9 loans (4 still open, 2 returned late)
INSERT INTO loans (copy_id, member_id, staff_id, loan_date, due_date, return_date)
SELECT c.copy_id, m.member_id, s.staff_id, v.loan_date, v.due_date, v.return_date
FROM (VALUES
 ('CL-0001', 'adaeze.okafor@example.com', 'grace.ade@citylight.example',   '2026-10-01'::date, '2026-10-15'::date, '2026-10-12'::date),
 ('CL-0004', 'tunde.balogun@example.com', 'grace.ade@citylight.example',   '2026-09-20', '2026-10-04', '2026-10-14'),
 ('CL-0013', 'ngozi.eze@example.com',     'samuel.okon@citylight.example', '2026-10-10', '2026-10-24', NULL),
 ('CL-0016', 'ibrahim.musa@example.com',  'samuel.okon@citylight.example', '2026-09-28', '2026-10-12', NULL),
 ('CL-0007', 'funmi.adeyemi@example.com', 'bisi.lawal@citylight.example',  '2026-10-05', '2026-10-19', '2026-10-18'),
 ('CL-0018', 'chinedu.obi@example.com',   'grace.ade@citylight.example',   '2026-10-18', '2026-11-01', NULL),
 ('CL-0011', 'adaeze.okafor@example.com', 'bisi.lawal@citylight.example',  '2026-08-30', '2026-09-13', '2026-09-30'),
 ('CL-0014', 'aisha.bello@example.com',   'samuel.okon@citylight.example', '2026-10-02', '2026-10-16', '2026-10-16'),
 ('CL-0015', 'ngozi.eze@example.com',     'grace.ade@citylight.example',   '2026-10-15', '2026-10-29', NULL)
) AS v(barcode, member_email, staff_email, loan_date, due_date, return_date)
JOIN book_copies c ON c.barcode = v.barcode
JOIN members m     ON m.email   = v.member_email
JOIN staff s       ON s.email   = v.staff_email;

-- Two fines at 50 per overdue day: 10 days = 500, 17 days = 850
INSERT INTO fines (loan_id, amount, fine_date, paid, paid_date)
SELECT l.loan_id, v.amount, v.fine_date, v.paid, v.paid_date
FROM (VALUES
 ('CL-0004', '2026-09-20'::date, 500.00, '2026-10-14'::date, FALSE, NULL::date),
 ('CL-0011', '2026-08-30'::date, 850.00, '2026-09-30'::date, TRUE,  '2026-10-01'::date)
) AS v(barcode, loan_date, amount, fine_date, paid, paid_date)
JOIN book_copies c ON c.barcode = v.barcode
JOIN loans l       ON l.copy_id = c.copy_id AND l.loan_date = v.loan_date;