-- CityLight Public Library: schema (PostgreSQL)


-- DROP TABLE IF EXISTS fines, loans, book_copies, book_authors,
--                      books, staff, members, authors, categories CASCADE;

-- 1. Lookup / independent tables --------------------------------

CREATE TABLE categories (
    category_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE authors (
    author_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL
);

CREATE TABLE members (
    member_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL UNIQUE,
    phone        VARCHAR(30),
    join_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    status       VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT chk_member_status CHECK (status IN ('active', 'suspended'))
);

CREATE TABLE staff (
    staff_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR(100) NOT NULL,
    last_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL UNIQUE,
    role         VARCHAR(50) NOT NULL
);

-- 2. Catalogue --------------------------------------------------

CREATE TABLE books (
    book_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    isbn              VARCHAR(20) NOT NULL UNIQUE,
    title             VARCHAR(255) NOT NULL,
    publisher         VARCHAR(150),
    publication_year  INT,
    category_id       INT NOT NULL,
    CONSTRAINT chk_publication_year
        CHECK (publication_year BETWEEN 1450 AND 2100),
    CONSTRAINT fk_books_category
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Junction table: books <-> authors (many-to-many)
CREATE TABLE book_authors (
    book_id    INT NOT NULL,
    author_id  INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    CONSTRAINT fk_ba_book
        FOREIGN KEY (book_id) REFERENCES books (book_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ba_author
        FOREIGN KEY (author_id) REFERENCES authors (author_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Physical copies of a title
CREATE TABLE book_copies (
    copy_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id        INT NOT NULL,
    barcode        VARCHAR(30) NOT NULL UNIQUE,
    status         VARCHAR(20) NOT NULL DEFAULT 'available',
    acquired_date  DATE,
    CONSTRAINT chk_copy_status
        CHECK (status IN ('available', 'on_loan', 'lost')),
    CONSTRAINT fk_copies_book
        FOREIGN KEY (book_id) REFERENCES books (book_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 3. Borrowing --------------------------------------------------

CREATE TABLE loans (
    loan_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    copy_id      INT NOT NULL,
    member_id    INT NOT NULL,
    staff_id     INT NOT NULL,
    loan_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date     DATE NOT NULL,
    return_date  DATE,          -- NULL = still on loan
    CONSTRAINT chk_due_after_loan   CHECK (due_date > loan_date),
    CONSTRAINT chk_return_after_loan
        CHECK (return_date IS NULL OR return_date >= loan_date),
    CONSTRAINT fk_loans_copy
        FOREIGN KEY (copy_id) REFERENCES book_copies (copy_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_loans_member
        FOREIGN KEY (member_id) REFERENCES members (member_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_loans_staff
        FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- At most one fine per loan (UNIQUE on loan_id)
CREATE TABLE fines (
    fine_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id    INT NOT NULL UNIQUE,
    amount     NUMERIC(8,2) NOT NULL,
    fine_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    paid       BOOLEAN NOT NULL DEFAULT FALSE,
    paid_date  DATE,
    CONSTRAINT chk_fine_amount CHECK (amount > 0),
    CONSTRAINT chk_fine_paid_consistency
        CHECK ((paid = FALSE AND paid_date IS NULL)
            OR (paid = TRUE  AND paid_date IS NOT NULL)),
    CONSTRAINT fk_fines_loan
        FOREIGN KEY (loan_id) REFERENCES loans (loan_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);



-- Checking to see the tables after creation

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;








