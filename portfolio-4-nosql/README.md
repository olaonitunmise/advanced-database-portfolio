# Portfolio 4: NoSQL and Advanced Data Models

## 1. Objective

To model part of the CityLight Public Library data as documents in MongoDB, load and query it in a cloud-hosted cluster, index it, and explain why a document model suits this data (and which parts of the system it does not suit).

This portfolio uses the same case study as Portfolios 1 to 3. See the [root README](../README.md).

## 2. Files

| File | Description |
|---|---|
| `model-design.md` | The document model: example document, embed-or-reference decisions, trade-offs |
| `export-books.sql` | PostgreSQL query that exports the catalogue as one JSON array |
| `books.json` | The 12 sample books exported from PostgreSQL |
| `extra-books.json` | 3 additional titles with different fields, to show the flexible schema |
| `queries.js` | The find queries (N1 to N6) and aggregation pipelines (A1 to A3) |
| `indexes.js` | The two indexes created |
| `screenshots/` | Evidence for each step |

## 3. How to run

**Platform:** MongoDB Atlas, free M0 tier. Cluster `citylight-cluster`, provider and region: [fill in from your cluster overview]. Everything was done in the browser using Atlas Data Explorer, so nothing was installed locally. Database `citylight_library`, collection `books`.

1. Create the free cluster, a database user, and the empty `books` collection. (Credentials and connection strings are deliberately not in this repository.)
2. Run `export-books.sql` in pgAdmin on the Portfolio 1 database. It returns one cell containing a JSON array of 12 documents. Save it as `books.json`.
3. Save `extra-books.json` (hand-written).
4. In Data Explorer, choose **ADD DATA → Insert document**, switch to the JSON view, and paste the contents of each file. The collection should then show **15 documents**. (The menu on my account offered only *Insert document* and *Generate mock data script*, with no file import.)
5. Run the queries in `queries.js`: find queries in the **Documents** tab, pipelines in the **Aggregations** tab (TEXT view).
6. Create the indexes in `indexes.js` from the **Indexes** tab and compare the **Explain** output before and after.

## 4. The document model

I used the **document model**: one collection, `books`, with one document per title.

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

### Embed or reference

| Data | Decision | Reason |
|---|---|---|
| Authors | Embedded array | A book has only a few, and they are always read with the book. This removes the `book_authors` junction table and two joins. |
| Category | Embedded as a name | Few categories, rarely renamed. The cost is that a rename means updating many documents. |
| Copies | Embedded array | A title has a small, bounded number of copies, so availability can be answered from one document. |
| Reviews | Embedded array, on some titles only | Shows a field that only some documents have |
| Loans, fines, members | Not in MongoDB | See section 8 |

### Flexible schema

Documents in the same collection have different fields on purpose:

- *Learning NoSQL Databases* has `edition`, `tags` and `reviews`.
- *The Tortoise and the River* has `ageRange`, `illustrated` and `reviews`.
- *Notes on Modern Lagos* has `tags` and `language`.

In PostgreSQL, each of these would need an `ALTER TABLE` or a column that is NULL for most rows. The three extra titles and their reviews are **synthetic** and do not exist in the PostgreSQL database.

## 5. Implementation

| Evidence | What it shows |
|---|---|
| `atlas-cluster.png` | The M0 cluster, provider and region |
| `export-query.png` | The PostgreSQL query that produced the JSON |
| `import-result.png` | The `books` collection with **15 documents** (12 exported + 3 extra) |
| `doc-database-system-concepts.png` | A document with 3 embedded authors and 3 embedded copies |
| `doc-tortoise.png` | A document with different fields (`ageRange`, `illustrated`, `reviews`) |

Each document received an automatic `_id` (an ObjectId) that I did not supply. Dates arrived as text strings (for example `"2025-01-20"`), not date values, because they passed through JSON. I left them as strings, but in a real system I would convert them to dates.

## 6. Queries and aggregations

### Find queries

| Query | Filter | Result | Evidence |
|---|---|---|---|
| N1: look up a book by ISBN | `{ isbn: "9780000000009" }` | 1 document | `n1-isbn.png` |
| N2: Technology titles | `{ category: "Technology" }` | 3 documents | `n2-technology.png` |
| N3: search inside the embedded authors array | `{ "authors.lastName": "Achebe" }` | 2 documents | `n3-author.png` |
| N4: books with at least one copy available | `{ copies: { $elemMatch: { status: "available" } } }` | 14 documents | `n4-available.png` |
| N5: books with a copy on loan | `{ "copies.status": "on_loan" }` | 4 documents | `n5-on-loan.png` |
| N6: books that have reviews | `{ reviews: { $exists: true } }` | 2 documents | `n6-flexible.png` |

- **N1** returns a whole book, with authors and copies, from one read and no join. In PostgreSQL the same information needed a join across `books`, `book_authors`, `authors` and `book_copies`.
- **N3** queries a field inside an array of embedded objects, which in PostgreSQL goes through the `book_authors` junction table.
- **N4** returns 14 of 15 because the only copy of one title (*Death and the King's Horseman*) has status `lost`. `$elemMatch` makes the condition apply to a single copy.
- **N6** shows the flexible schema: only 2 documents have a `reviews` field, and the query needs no schema change.

### Aggregation pipelines

| Pipeline | Stages | Result | Evidence |
|---|---|---|---|
| A1: titles per category | `$group`, `$sort` | 5 rows: Fiction 4, Children's 3, History 3, Technology 3, Science 2 | `a1-category.png` |
| A2: total and available copies per title | `$project` with `$size` and `$filter`, `$sort` | 15 rows. For example *Clean Code* has 2 copies, 1 available. *Database System Concepts* has 3, 1 available, matching PostgreSQL Q8. | `a2-availability.png` |
| A3: average rating per title | `$unwind`, `$group` with `$avg`, `$sort` | 2 rows: *The Tortoise and the River* (3 reviews, about 4.67) and *Learning NoSQL Databases* (2 reviews, 4.5) | `a3-rating.png` |

A3 only returns titles with reviews, because `$unwind` discards documents with no array to expand. A2 counts available copies inside each document with `$filter`, replacing the `FILTER` clause and `GROUP BY` used in PostgreSQL.

## 7. Indexing and explain plans

### Before and after an index (query N3)

| | Before | After |
|---|---|---|
| Winning plan | `COLLSCAN` (collection scan) | `IXSCAN` then `FETCH` |
| Index used | none ("No index available for this query") | `idx_authors_lastname` on `authors.lastName` |
| Documents examined | **15** | **2** |
| Index keys examined | 0 | 2 |
| Documents returned | 2 | 2 |
| Execution time | 0 ms | 0 ms |

| Evidence | What it shows |
|---|---|
| `explain-n3-before.png` and `explain-n3-before-json.png` | `COLLSCAN`, 15 documents examined, no index |
| `explain-n3-after.png` and `explain-n3-after-json.png` | `IXSCAN`, 2 documents examined, 2 index keys, `isMultiKey: true` |

The change that matters is **documents examined falling from 15 to 2**, and the plan changing from a collection scan to an index scan. The execution times are both 0 ms because the collection has only 15 documents, so I draw no conclusion from them. The benefit would show on a large collection.

The index is on a field inside an array, so it is a **multikey index**: MongoDB keeps one index entry for each element of the `authors` array (the raw output shows `multiKeyPaths` of `authors.lastName` pointing at `authors`). As in PostgreSQL, an index costs storage and slows writes.

### Unique index

I created a unique index `uq_isbn` on `isbn`, the MongoDB counterpart of the `UNIQUE` constraint on `books.isbn` in PostgreSQL. To test it, I tried to insert a document with an ISBN that already exists:

```
E11000 duplicate key error collection: citylight_library.books index: uq_isbn dup key: { isbn: "9780000000001" }
```

The insert was rejected (`duplicate-key-error.png`). Without that index, MongoDB would have accepted the duplicate. This is a key difference from PostgreSQL: **MongoDB enforces only what you ask it to**. It also has no foreign keys, so referential integrity between collections is the application's job.

## 8. Why a document model suits (and does not suit) this data

### Why it suits the catalogue

- **One read returns a whole book.** A title page needs the book, its authors and its copies, and the embedded design returns them together with no joins (N1).
- **Flexible schema.** Different kinds of titles carry different attributes, and new fields need no schema migration (N6).
- **Natural array queries.** Searching within authors, filtering copies by status, and unwinding reviews are all direct operations (N3, N4, A2, A3).
- **Read-heavy workload.** A catalogue is searched far more often than it is changed, which is where denormalisation pays off.

### Why loans, fines and members stay in PostgreSQL

- They need **foreign keys and CHECK constraints** (Portfolio 1) and **multi-row transactions with concurrency control** (Portfolio 3). MongoDB does not enforce these unless the application does.
- They **grow without limit**. Embedding a member's whole loan history in one document would make it larger and larger.
- They are queried **across entities** (members with fines, overdue loans per member), which is what relational joins are for.

The design is therefore **polyglot**: MongoDB for searching and browsing the catalogue, PostgreSQL as the system of record for borrowing. In Portfolio 3, borrowing needed two writes (a new loan and a status change) to be atomic and protected against double-booking. An update to a single MongoDB document is atomic, but an operation that spans a loan record and a copy's status in two systems would need extra care.

### Relational versus document design for this data

| | PostgreSQL (Portfolios 1 to 3) | MongoDB (this portfolio) |
|---|---|---|
| Book with authors and copies | 4 tables, joined | 1 document |
| Many-to-many (books and authors) | Junction table | Embedded array |
| Adding a new attribute | `ALTER TABLE` or NULL columns | Just add the field |
| Data duplication | Minimal (normalised to 3NF) | Author and category data repeated across documents |
| Integrity | Foreign keys, CHECK, UNIQUE enforced | Only what is added (e.g. unique index) |
| Multi-step operations | ACID transactions with isolation levels | Single-document atomicity |

### Other NoSQL models (discussion only, not implemented)

A **key-value** store could cache each copy's availability for very fast lookups, and a **graph** database could answer "members who borrowed this also borrowed" recommendations. Neither is needed for the catalogue here.

## 9. Testing and limitations

- Each query's result count was checked against what the data predicts (for example, 14 for N4 because one title's only copy is `lost`).
- The extra aggregation A2 agrees with the PostgreSQL availability query (Q8) for the same title.
- The duplicate-key test confirmed the unique index works.

**Limitations:**
- The collection has only 15 documents, so the performance comparison shows the plan changing, not meaningful timings.
- The data is a **snapshot** taken from PostgreSQL at export time. Nothing keeps the two databases in sync, so copy statuses in MongoDB will drift from PostgreSQL as books are borrowed. A real system would need a synchronisation process.
- Three titles and all reviews are synthetic and exist only in MongoDB.
- Dates are stored as strings.
- The M0 free tier does not support sharding, which is covered as a design discussion in Portfolio 5.

## 10. Challenges and lessons

*(Edit this section so it matches what happened to you. These points are supported by my screenshots.)*

**Challenges**

- **Finding the import option.** The guide I followed mentioned importing a JSON file, but the ADD DATA menu on my account showed only *Insert document* and *Generate mock data script*. I used the Insert document dialog in JSON view instead.
- **Running an aggregation in the wrong place.** My first attempts at the aggregation pipelines were entered in the Documents tab's query bar, which gave the error `Query filter must be a plain object or ObjectId`. That bar accepts only a filter. The pipelines belong in the **Aggregations** tab, where the TEXT view lets me paste a whole pipeline.
- **Atlas's interface differs from guides.** Menus and labels were different from the tutorials I read, so I had to work out where each feature was.

**Lessons**

- Document design starts from the **queries**: what is read together should be stored together. Embedding authors and copies made the catalogue queries simple.
- Embedding has limits. Data that grows without bound or needs strict integrity (loans, fines) is better kept relational.
- Flexibility has a cost. MongoDB did not stop a duplicate ISBN until I added a unique index, whereas PostgreSQL had that rule from the start.
- `explain` shows how a query ran, not just how fast. The change from `COLLSCAN` to `IXSCAN`, and documents examined falling from 15 to 2, is the evidence, not the 0 ms timings.
- Two databases holding the same facts need a plan for keeping them consistent.

## 11. Sources and AI use

- Tools: MongoDB Atlas (free M0 tier, Data Explorer) and PostgreSQL with pgAdmin. The sample data comes from the Portfolio 1 database; the extra titles and reviews are fictional.
- AI use is described in the AI Use Declaration in the final documentation (tool used, what it was used for, and how I reviewed and tested the output).
