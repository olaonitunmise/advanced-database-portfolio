# Portfolio 2: Query Processing and Optimisation

## 1. Objective

To write realistic SQL queries against the CityLight Public Library database, analyse how PostgreSQL executes them using `EXPLAIN (ANALYZE, BUFFERS)`, improve performance with indexing, and evaluate the results with measured evidence.

This portfolio uses the same case study and database as Portfolio 1. See the [root README](../README.md).

## 2. Files

| File / folder | Description |
|---|---|
| `generate-large-data.sql` | Creates synthetic bulk data so that timings and plans are meaningful |
| `queries.sql` | The eight business queries (Q1 to Q8), each with a comment header |
| `explain-plans.sql` | The same queries wrapped in `EXPLAIN (ANALYZE, BUFFERS)` |
| `indexes.sql` | The six indexes created for optimisation |
| `performance-analysis.md` | Before/after results table and written analysis |
| `execution-plans/` | Full plan output as text: `q1-before.txt` to `q8-before.txt` and `q1-after.txt` to `q8-after.txt` |
| `screenshots/` | Result screenshots, check queries, index lists, index and table sizes, graphical plans |

## 3. How to run

**Tools:** PostgreSQL 17 with pgAdmin. All plans were captured on the same server.

1. Complete Portfolio 1 first (`schema.sql`, then `sample-data.sql`).
2. Run `generate-large-data.sql` **once**. It adds about 20,000 members, 20,000 books, 60,000 copies, 300,000 loans and about 82,000 fines, and ends with `ANALYZE`.
3. Run the queries in `queries.sql`.
4. Run the statements in `explain-plans.sql` **before** `indexes.sql`, one at a time, and save each plan as `qN-before.txt`.
5. Run `indexes.sql`, then run the same `explain-plans.sql` statements again and save each plan as `qN-after.txt`.

To repeat the experiment, drop the six `idx_...` indexes and run `ANALYZE` before step 4.

**Notes on the data:**
- The bulk data is **synthetic**. Names, emails and titles are generated, and loans are spread evenly, so every bulk title was borrowed exactly 15 times. This means the Q5 and Q7 rankings are ties and not realistic popularity data, but they still test the cost of the queries properly.
- Because the schema has no rule against it (this is dealt with in Portfolio 3), the same copy can have overlapping loan dates in the generated data. This does not affect the performance tests.
- Q3 uses `CURRENT_DATE`, so its `days_overdue` and `fine_so_far` values depend on the day it is run. My screenshots were taken on 3 November 2026.

## 4. The queries

| Query | Purpose | SQL features | Result |
|---|---|---|---|
| **Q1** | Catalogue search by title prefix, with authors and category | 4-table JOIN, `LIKE` prefix search, `string_agg()`, `GROUP BY` | 1,111 rows |
| **Q2** | One member's loan history, newest first | 3-table JOIN, foreign key filter, `ORDER BY ... DESC` | 21 rows (member 5000) |
| **Q3** | Currently overdue loans with fine accrued so far (50 per day) | 4-table JOIN, `IS NULL`, date arithmetic with `CURRENT_DATE`, calculated columns | 4 rows |
| **Q4** | Members owing more than 500 in unpaid fines (top 20) | JOINs, `GROUP BY`, `COUNT` and `SUM`, `HAVING`, `LIMIT` | 20 rows, highest 1,900.00 |
| **Q5** | Ten most borrowed titles | JOINs, `GROUP BY`, `COUNT`, tie-breaker in `ORDER BY`, `LIMIT` | 10 rows, all tied at 15 |
| **Q6** | Members who have never borrowed | Correlated subquery with `NOT EXISTS` (anti-join) | 1 row (member 8) |
| **Q7** | Top 3 titles in each category | CTE, JOINs, window function `ROW_NUMBER() OVER (PARTITION BY ...)`, filter on window result via subquery | 15 rows (5 categories x 3) |
| **Q8** | Availability of a title by ISBN | JOIN, UNIQUE-column lookup, `COUNT(*) FILTER (WHERE ...)` | 1 row: 3 copies, 1 available |

Every result was checked with a separate query (for example a `COUNT(*)` for Q1, Q2, Q3 and Q6, the boundary case of exactly 500 for Q4, and two checks for Q5).

Two design points worth noting:
- **`WHERE` vs `HAVING` (Q4):** `WHERE` removes individual rows before grouping, `HAVING` removes whole groups after the totals are calculated.
- **`ROW_NUMBER()` instead of `RANK()` (Q7):** many titles tie on loan count, so `RANK()` would give them all rank 1 and `rn <= 3` would return about 20,000 rows. `ROW_NUMBER()` with a title tie-breaker returns exactly three per category.

## 5. Indexes created

```sql
CREATE INDEX idx_loans_member_id ON loans (member_id);
CREATE INDEX idx_loans_copy_id   ON loans (copy_id);
CREATE INDEX idx_copies_book_id  ON book_copies (book_id);
CREATE INDEX idx_loans_open_due  ON loans (due_date) WHERE return_date IS NULL;   -- partial index
CREATE INDEX idx_books_title_prefix ON books (title text_pattern_ops);
CREATE INDEX idx_fines_paid      ON fines (paid);
```

PostgreSQL does not automatically index foreign key columns, which is why the first three were needed.

## 6. Results summary

| Query | Time before | Time after | Plan change |
|---|---|---|---|
| Q1 | 26.625 ms | 19.229 ms | Seq Scan to Bitmap Index Scan on `books` |
| Q2 | 73.081 ms | 0.314 ms | Parallel Seq Scan to Bitmap Index Scan on `loans` |
| Q3 | 190.352 ms | 0.298 ms | Parallel Seq Scan to Bitmap Index Scan (partial index) |
| Q4 | 338.914 ms | 383.866 ms | Identical plan |
| Q5 | 657.213 ms | 956.614 ms | Identical plan |
| Q6 | 358.878 ms | 40.139 ms | Hash Anti Join to Nested Loop Anti Join with Index Only Scan |
| Q7 | 1,735.121 ms | 3,498.008 ms | Identical plan (sorts spill to disk) |
| Q8 | 13.801 ms | 0.106 ms | Seq Scan to Index Scan on `book_copies` |

- **Large gains** (Q2, Q3, Q6, Q8) came from queries that need a small number of rows from a large table.
- **No plan change** (Q4, Q5, Q7): these queries read every row or a non-selective half of a table, so the indexes were not used. `idx_fines_paid` and `idx_loans_copy_id` were never used by any of the eight queries.
- The higher after-times for Q4, Q5 and Q7 occur with identical plans. I took a single run of each and did not repeat them, so I do not attribute the difference to the indexes.

Each time is the Execution Time of a single warm-cache run. The full analysis, index sizes (8,216 kB in total) and limitations are in [`performance-analysis.md`](performance-analysis.md).

## 7. Evidence

| Screenshot | What it shows |
|---|---|
| `data-row-counts.png` | Row counts after the bulk load |
| `q1-result.png` to `q8-result.png` | Result of each query |
| `q5-check-count.png`, `q5-check-max.png`, `q6-check-count.png`, `q7-check.png`, `q8-check.png` and others | Independent check queries confirming the results |
| `baseline-indexes.png` | Only primary key and UNIQUE indexes before optimisation (15 indexes) |
| `indexes-after.png` | 21 indexes after `indexes.sql`, including the six new ones |
| `index-sizes.png`, `table-sizes.png` | Storage cost of the new indexes and size of the affected tables |
| `q2-before-plan.png`, `q2-after-plan.png` (and others) | Graphical execution plans from pgAdmin |

## 8. Testing

- Every query was run and its result checked against a separate verification query or an expected value worked out from the data design.
- Baseline indexes were listed before any plan was captured, to show that the "before" plans had no help from new indexes.
- Each plan was captured with `EXPLAIN (ANALYZE, BUFFERS)`. `ANALYZE` was run after loading the data and after creating the indexes.
- The same `explain-plans.sql` statements were used before and after, so the comparison uses identical SQL.

## 9. Challenges and lessons

*(Write this section in your own words from what actually happened to you. Below are points that your files support; keep only the ones that are true for you and add the problems you really hit, with the error messages.)*

- Several indexes made no difference. I expected `idx_fines_paid` to help Q4, but the plan shows PostgreSQL ignoring it because about half of the fines are unpaid.
- Q1 improved less than expected because the title scan was only part of the cost.
- Q6 became faster even though it touches many more buffers after indexing. [Add what you made of this.]
- I had to correct Q7: my first version used `RANK()`, which would have returned about 20,000 rows because of ties.

Lessons: indexes pay off when a query keeps a small fraction of a table; foreign keys are not indexed automatically in PostgreSQL; read the plan, not just the time; an unused index is pure cost; a single timing on a laptop should not be over-interpreted.

## 10. Sources and AI use

- Tools: PostgreSQL 17 and pgAdmin. All data is synthetic.
- AI use is described in the AI Use Declaration in the final documentation (tool used, what it was used for, and how I reviewed and tested the output).
