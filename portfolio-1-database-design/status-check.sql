-- Copies marked on_loan with no open loan
SELECT barcode FROM book_copies WHERE status = 'on_loan'
EXCEPT
SELECT c.barcode FROM loans l JOIN book_copies c ON c.copy_id = l.copy_id WHERE l.return_date IS NULL;


-- Open loans whose copy is not marked on_loan
SELECT c.barcode FROM loans l JOIN book_copies c ON c.copy_id = l.copy_id WHERE l.return_date IS NULL
EXCEPT
SELECT barcode FROM book_copies WHERE status = 'on_loan';







