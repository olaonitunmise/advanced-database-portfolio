# Portfolio 4: Document model design

## Chosen model
I used the **document model** (MongoDB) for the library **catalogue**: one document per title in a `books` collection. The loans, fines and members stay in PostgreSQL (see "What I did not move").

## Example document
```json
{
  "isbn": "9780000000009",
  "title": "Database System Concepts",
  "publisher": "McGraw-Hill",
  "publicationYear": 2019,
  "category": "Technology",
  "authors": [
    { "firstName": "Abraham", "lastName": "Silberschatz" },
    { "firstName": "Henry", "lastName": "Korth" },
    { "firstName": "S.", "lastName": "Sudarshan" }
  ],
  "copies": [
    { "barcode": "CL-0013", "status": "on_loan",   "acquiredDate": "2025-01-20" },
    { "barcode": "CL-0014", "status": "available", "acquiredDate": "2025-01-20" },
    { "barcode": "CL-0015", "status": "on_loan",   "acquiredDate": "2025-01-20" }
  ]
}
```

## Embed or reference?

| Data | Decision | Reason |
|---|---|---|
| Authors | **Embedded** array | A book has only a few, they are always shown with the book, and this removes the `book_authors` junction table and two joins |
| Category | **Embedded** as a name | Few categories, rarely renamed. A rename would mean updating many documents, which is the trade-off. |
| Copies | **Embedded** array | A title has a small, bounded number of copies, and "is it available?" is answered from one document |
| Reviews (some titles) | **Embedded** array | Shows a field that only some documents have |
| Loans, fines, members | **Not in MongoDB** | See below |

## Flexible schema
Documents in the same collection can have different fields. A children's book can have `ageRange`, a technical book can have `edition` and `tags`, and some books have `reviews`. In PostgreSQL, each of these would need a schema change (`ALTER TABLE`) or many NULL columns.

## What I did not move to MongoDB
`loans`, `fines` and `members` stay in PostgreSQL. They need strict constraints and foreign keys (the `CHECK` rules and `ON DELETE RESTRICT` from Portfolio 1), multi-row transactions (Portfolio 3), and they grow without limit. Embedding an ever-growing loan history inside a member document would eventually make that document huge. So the design is **polyglot**: MongoDB for browsing and searching the catalogue, PostgreSQL as the system of record for borrowing.

## Trade-offs compared with the relational design
- **Gain:** one read returns a whole book, with no joins, and the schema is flexible.
- **Cost:** author and category data are duplicated across documents, so a change must be made in many places. MongoDB does not enforce foreign keys or CHECK constraints the way PostgreSQL does.
- **Atomicity:** an update to a single document is atomic, so changing one copy's status is safe in isolation. But an operation spanning several collections or systems (like borrowing, which also needs the loan record) would need transactions or care.
