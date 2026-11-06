BEGIN;

--Insert the loan
INSERT INTO loans (copy_id, member_id, staff_id, loan_date, due_date)
SELECT c.copy_id, m.member_id, s.staff_id, CURRENT_DATE, CURRENT_DATE + 14
FROM book_copies c, members m, staff s
WHERE c.barcode = 'CL-0017'
  AND m.email   = 'funmi.adeyemi@example.com'
  AND s.email   = 'grace.ade@citylight.example';


-- Count inside the transaction
SELECT COUNT(*) AS open_loans_inside_txn
FROM loans l JOIN book_copies c ON c.copy_id = l.copy_id
WHERE c.barcode = 'CL-0017' AND l.return_date IS NULL;

ROLLBACK;

SELECT COUNT(*) AS open_loans_after_rollback
FROM loans l JOIN book_copies c ON c.copy_id = l.copy_id
WHERE c.barcode = 'CL-0017' AND l.return_date IS NULL;