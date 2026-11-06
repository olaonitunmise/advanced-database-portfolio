BEGIN;

-- check the copy is available
SELECT copy_id, barcode, status 
FROM book_copies 
WHERE barcode = 'CL-0014';

-- Creating the loan
INSERT INTO loans (copy_id, member_id, staff_id, loan_date, due_date)
SELECT c.copy_id, m.member_id, s.staff_id, CURRENT_DATE, CURRENT_DATE + 14
FROM book_copies c, members m, staff s
WHERE c.barcode = 'CL-0017'
  AND m.email   = 'funmi.adeyemi@example.com'
  AND s.email   = 'grace.ade@citylight.example';


-- marking the copy as on_loan
UPDATE book_copies SET status = 'on_loan' 
WHERE barcode = 'CL-0017';

-- Inspecting the result inside the transaction
SELECT l.loan_id, c.barcode, 
	   c.status, l.loan_date, 
	   l.due_date, l.return_date
FROM loans l JOIN book_copies c ON c.copy_id = l.copy_id
WHERE c.barcode = 'CL-0017' AND l.return_date IS NULL;

COMMIT;

-- Confirming that the change is permanent
SELECT l.loan_id, c.barcode, 
	   c.status, l.loan_date, 
	   l.due_date, l.return_date
FROM loans l JOIN book_copies c 
ON c.copy_id = l.copy_id
WHERE c.barcode = 'CL-0017' AND l.return_date IS NULL;







