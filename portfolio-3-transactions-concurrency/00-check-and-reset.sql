-- CHECK: expected CL-0014 available, CL-0017 available
SELECT c.barcode, c.status, b.title
FROM book_copies c
JOIN books b ON b.book_id = c.book_id
WHERE c.barcode IN ('CL-0013', 'CL-0014', 'CL-0015', 'CL-0016', 'CL-0017')
ORDER BY c.barcode;


-- RESET: removes open loans on the two demo copies and puts them back on the shelf
DELETE FROM loans
WHERE return_date IS NULL
  AND copy_id IN (SELECT copy_id FROM book_copies WHERE barcode IN ('CL-0014', 'CL-0017'));


UPDATE book_copies SET status = 'available' WHERE barcode IN ('CL-0014', 'CL-0017');