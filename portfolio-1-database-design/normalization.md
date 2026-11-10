# Normalization: CityLight Public Library

## 1. Approach

To justify my design, I started from the kind of single flat record a small library might keep for each loan, identified the problems with it, and normalised it step by step to Third Normal Form (3NF). I then checked the final tables against Boyce-Codd Normal Form (BCNF) and recorded the one place where I deliberately kept some redundancy.

## 2. Unnormalized starting point

Each row describes one loan and repeats everything related to it:

| loan_id | member_name | member_email | member_phone | book_title | isbn | authors | category | copy_barcode | copy_status | staff_name | staff_role | loan_date | due_date | return_date | fine_amount | fine_paid |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | Ngozi Eze | ngozi.eze@example.com | 08030000003 | Database System Concepts | 9780000000009 | Silberschatz, Korth, Sudarshan | Technology | CL-0013 | on_loan | Samuel Okon | Circulation Librarian | 2026-10-10 | 2026-10-24 | NULL | NULL | NULL |

This table has three kinds of anomaly:

- **Update anomaly:** a member's email is repeated on every loan they make. Changing it means editing many rows, and missing one leaves inconsistent data.
- **Insertion anomaly:** a new book cannot be added to the catalogue until someone borrows it, because every row is a loan.
- **Deletion anomaly:** deleting a member's only loan also deletes the only record of the book, copy or staff member in that row.

## 3. First Normal Form (1NF)

1NF requires atomic values and no repeating groups. The `authors` column breaks this, since one cell holds three names. I fixed it by giving each author their own row, so the key becomes **(loan_id, author_name)**.

This is now in 1NF, but it is worse in other ways, because every loan detail is repeated once per author.

## 4. Second Normal Form (2NF)

2NF requires that every non-key attribute depends on the *whole* composite key, not only part of it.

Looking at the functional dependencies:

- `loan_id → member, book, copy, staff, dates, fine` (everything except the author depends on the loan alone)
- `author_name` determines nothing else here

So all the loan columns depend on only part of the key (`loan_id`). I removed the partial dependency by splitting the table into:

- **LOAN_DETAILS**(loan_id, member_name, member_email, member_phone, book_title, isbn, category, copy_barcode, copy_status, staff_name, staff_role, loan_date, due_date, return_date, fine_amount, fine_paid)
- **LOAN_AUTHOR**(loan_id, author_name)

While doing this I noticed that authors really belong to the *book*, not the loan, because the same book has the same authors however many times it is borrowed. I corrected this in the next step.

## 5. Third Normal Form (3NF)

3NF requires that non-key attributes depend only on the key and not on other non-key attributes (no transitive dependencies). `LOAN_DETAILS` contains several chains of this kind:

| Transitive dependency | What it means | Fix |
|---|---|---|
| loan_id → member_email → member_name, member_phone | Member details depend on the member, not the loan | **members** table |
| loan_id → staff_email → staff_name, staff_role | Staff details depend on the staff member | **staff** table |
| loan_id → copy_barcode → copy_status, book | Copy details depend on the physical copy | **book_copies** table |
| copy → isbn → book_title, category | Title and category depend on the book, not the copy | **books** table |
| category → category name | Category is a separate entity with its own identity | **categories** table |
| isbn → authors | Authors are determined by the book, and a book can have many authors and an author many books (many-to-many) | **authors** and **book_authors** junction table |
| loan_id → fine details | A fine belongs to a loan, but most loans have none; keeping it in `loans` would leave many NULLs | **fines** table, with a UNIQUE `loan_id` so a loan has at most one fine |

The many-to-many relationship between books and authors is why `LOAN_AUTHOR` from the 2NF step moved to `book_authors(book_id, author_id)` with a composite primary key.

## 6. Final design

The result is nine tables:

| Table | Primary key | Key dependency |
|---|---|---|
| categories | category_id | category_id → name |
| authors | author_id | author_id → first_name, last_name |
| books | book_id | book_id → isbn, title, publisher, publication_year, category_id |
| book_authors | (book_id, author_id) | link table only, no other attributes |
| book_copies | copy_id | copy_id → book_id, barcode, status, acquired_date |
| members | member_id | member_id → name, email, phone, join_date, status |
| staff | staff_id | staff_id → name, email, role |
| loans | loan_id | loan_id → copy_id, member_id, staff_id, loan_date, due_date, return_date |
| fines | fine_id | fine_id → loan_id, amount, fine_date, paid, paid_date |

Every non-key attribute depends on "the key, the whole key, and nothing but the key", so the design is in 3NF.

## 7. BCNF check

BCNF requires every determinant to be a candidate key. In my tables, the only determinants are primary keys and the natural identifiers I enforced with UNIQUE constraints (`email`, `isbn`, `barcode`, and `loan_id` in `fines`). Each of these is a candidate key, so the tables also satisfy BCNF.

I used generated integer keys (`GENERATED ALWAYS AS IDENTITY`) as primary keys, because they are compact and stable, while keeping the natural identifiers UNIQUE so duplicates are still prevented.

## 8. Deliberate trade-offs

I did not follow normalization rules blindly. Two decisions are intentional:

1. **`book_copies.status`** can be derived from `loans`, since a copy is on loan when it has a loan with no `return_date`. A strict reading would remove it. I kept it because it makes the "is this copy available?" check a single-row lookup, and because it lets me demonstrate a concurrency problem in Portfolio 3 (two sessions reading "available" at the same time). The cost is that the two sources could disagree. I wrote verification queries to detect mismatches, and transactions in Portfolio 3 are what keep them consistent.

2. **`fines.amount`** could be calculated from the due date, return date and a daily rate. I stored it as a record of what was actually charged, so that a later change to the fine rate does not alter past charges. This is a controlled denormalization for historical accuracy.

## 9. Summary

Normalizing removed the update, insertion and deletion anomalies of the flat record and gave a clean design in which each fact is stored once. The two exceptions above are conscious choices for performance and for demonstrating the later portfolios, and I can explain the reasoning behind them.
