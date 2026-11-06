BEGIN ISOLATION LEVEL REPEATABLE READ;

SELECT barcode, status 
FROM book_copies 
WHERE barcode = 'CL-0014';


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


