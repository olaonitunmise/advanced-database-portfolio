SELECT barcode, status 





FROM book_copies 
WHERE barcode IN ('CL-0014', 'CL-0017') 
ORDER BY barcode;





BEGIN;

-- check availability
SELECT barcode, status 
FROM book_copies 
WHERE barcode = 'CL-0014';

-- borrow it
INSERT INTO loans (copy_id, member_id, staff_id, loan_date, due_date)
SELECT c.copy_id, m.member_id, s.staff_id, CURRENT_DATE, CURRENT_DATE + 14
FROM book_copies c, members m, staff s
WHERE c.barcode = 'CL-0014'
  AND m.email   = 'adaeze.okafor@example.com'
  AND s.email   = 'grace.ade@citylight.example';


UPDATE book_copies 
SET status = 'on_loan' 
WHERE barcode = 'CL-0014';


COMMIT;

-- verification
SELECT l.loan_id, m.email, l.loan_date, l.return_date
FROM loans l
JOIN members m ON m.member_id = l.member_id
WHERE l.copy_id = (SELECT copy_id FROM book_copies WHERE barcode = 'CL-0014')
  AND l.return_date IS NULL;

ROLLBACK;

DELETE FROM loans
WHERE return_date IS NULL
  AND copy_id IN (SELECT copy_id FROM book_copies WHERE barcode IN ('CL-0014', 'CL-0017'));


UPDATE book_copies 
SET status = 'available' 
WHERE barcode IN ('CL-0014', 'CL-0017');

SELECT barcode, status 
FROM book_copies 
WHERE barcode IN ('CL-0014', 'CL-0017') 
ORDER BY barcode;

