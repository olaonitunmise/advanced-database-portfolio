# Portfolio 2: Performance Analysis

## 1. Test setup

- **Database:** PostgreSQL 17, queried through pgAdmin on a laptop ([CPU and RAM: fill in]).
- **Data:** synthetic bulk data added on top of the Portfolio 1 sample data: about 20,000 members, 20,012 books, 60,020 copies, 300,009 loans and 82,371 fines. The bulk data is evenly spread, so it does not give a realistic popularity pattern, but it is large enough to show real differences between plans.
- **Method:** each query was run with `EXPLAIN (ANALYZE, BUFFERS)` before any extra indexes existed (only primary key and UNIQUE indexes, see `screenshots/baseline-indexes.png`), then again after running `indexes.sql`. `ANALYZE` was run after loading the data and after creating the indexes, so the planner's statistics were current.
- **Timing:** each figure is the Execution Time of one run (the third run of the query), so it reflects a warm cache. Every plan reports shared hits and no disk reads. Each figure is a single measurement, not an average.

## 2. Results

| Query | Plan before | Time before | Index | Plan after | Time after | Change |
|---|---|---|---|---|---|---|
| Q1 title prefix search | Seq Scan on `books` | 26.625 ms | `idx_books_title_prefix` | Bitmap Index Scan | 19.229 ms | about 28% faster |
| Q2 member loan history | Parallel Seq Scan on `loans` | 73.081 ms | `idx_loans_member_id` | Bitmap Index Scan | 0.314 ms | about 233x faster |
| Q3 overdue loans | Parallel Seq Scan on `loans` | 190.352 ms | `idx_loans_open_due` (partial) | Bitmap Index Scan | 0.298 ms | about 640x faster |
| Q4 unpaid fines | Seq Scans, Hash Joins | 338.914 ms | `idx_fines_paid` (not used) | Identical plan | 383.866 ms | plan unchanged |
| Q5 most borrowed titles | Seq Scans, Hash Joins | 657.213 ms | none helpful | Identical plan | 956.614 ms | plan unchanged |
| Q6 members who never borrowed | Hash Right Anti Join, Seq Scan on `loans` | 358.878 ms | `idx_loans_member_id` | Nested Loop Anti Join, Index Only Scan | 40.139 ms | about 9x faster |
| Q7 top 3 titles per category | Seq Scans, Hash Joins, disk sort | 1,735.121 ms | none helpful | Identical plan | 3,498.008 ms | plan unchanged |
| Q8 title availability by ISBN | Seq Scan on `book_copies` | 13.801 ms | `idx_copies_book_id` | Index Scan | 0.106 ms | about 130x faster |

Buffers touched (pages read from memory) tell the same story: Q2 fell from 2,340 to 149, Q3 from 2,242 to 38, Q8 from 504 to 6 and Q1 from 298 to 115. Q6 rose from 2,472 to 60,291, which is discussed below.

## 3. Analysis

### 3.1 Queries where an index changed the plan

**Q2 and Q3.** Both look for a handful of rows in a 300,009-row table. Before indexing, PostgreSQL read the whole `loans` table to find them (`Rows Removed by Filter` was about 300,000 in each). Q2 keeps 21 rows and Q3 keeps 4, which is a tiny fraction of the table, and that is the situation where an index pays off most.

In Q2 the plan after indexing used a Bitmap Index Scan with `Heap Blocks: exact=20`. The 21 loans of member 5000 sit in 20 different table pages because the synthetic loans were generated in random order, so a bitmap scan, which visits each page once, was a sensible choice. The before plan also launched a parallel worker, and the Gather Merge node finished much later than the Sort below it, so a large part of the 73 ms was probably parallel startup overhead rather than scanning. The after plan needs no parallelism at all.

In Q3, the partial index `idx_loans_open_due` contains only rows where `return_date IS NULL`, so it holds just the 4 open loans and is 16 kB. The plan's recheck condition lists both `due_date < CURRENT_DATE` and `return_date IS NULL` because the second condition is built into the index definition. After indexing, planning time (1.383 ms) is larger than execution time (0.298 ms).

**Q8.** Even before indexing, the planner found the book through the UNIQUE index on `isbn`, but it then had to scan all 60,020 rows of `book_copies` to find that book's 3 copies, because PostgreSQL does not automatically index foreign key columns. The number of matching rows does not matter when there is no index, since the whole table must still be read. `idx_copies_book_id` removes that scan.

**Q6.** Before, PostgreSQL scanned all of `loans` and hashed `members` for an anti join. After, it scans `members` once and, for each of the 20,008 members, asks `idx_loans_member_id` whether a loan exists. This is an Index Only Scan with `Heap Fetches: 0`, so the table itself is never read. The after plan touched far more buffers (60,291) than the before plan (2,472) because it performs 20,008 separate index lookups, yet it was still about 9x faster. That is a warm-cache measurement: I did not test a cold cache, so I cannot say whether the result would hold if the data were not already in memory. Most of the before time sits in the join node above the scan, which I cannot explain from the plan alone, so I treat the 9x figure with some caution.

**Q1.** The improvement was smaller (about 28%). The `books` scan itself went from about 6.7 ms to about 0.7 ms and its buffers from 207 to 24. The index uses `text_pattern_ops` so that the prefix `LIKE 'Bulk Title 12%'` becomes a range condition. But the rest of the query (a scan of 20,014 `book_authors` rows, three hash joins and two sorts) did not change and dominates the total. The query keeps about 5.5% of the books, so the index is useful but not dramatic.

One index, `idx_loans_member_id`, serves both Q2 and Q6.

### 3.2 Queries the indexes did not help

Q4, Q5 and Q7 have identical plans before and after (same nodes, same cost estimates), so none of the new indexes changed how they run.

- **Q4** filters on `paid = FALSE`, which matches about 50% of fines (41,314 of 82,371 rows). Reading half a table through an index costs more than scanning it sequentially, so PostgreSQL correctly ignored `idx_fines_paid`. Its joins already use primary keys, and the query never filters `loans` by `member_id`.
- **Q5** counts every loan to rank titles, so every row is needed and an index cannot skip any. The table scans take under 50 ms of the 657 ms; most of the time goes into two hash joins and the aggregation.
- **Q7** also reads every loan, and it spills to disk: the sort reports `external merge Disk: 5632kB` (and 6136kB for the worker) before indexing and 4376kB and 7400kB after. The planner estimated 100,060 groups when only 20,007 existed, which is exactly 5 x 20,012, so it appears to have treated the two grouping columns as independent. That probably pushed it to a sort-based aggregate instead of a hash aggregate. The problem is memory and estimation, not missing indexes, and I did not test a larger `work_mem`.

The execution times for Q4, Q5 and Q7 are higher in the after runs (by 13%, 46% and 102%), but the plans are identical, so I do not attribute the difference to the indexes. I took one run of each and did not repeat them, so I cannot say how much of the difference is ordinary run-to-run variation on a laptop. As an example of that variation, the same Seq Scan on `loans` took about 65 ms in the Q4 before plan and about 46 ms in the Q4 after plan.

## 4. Reading the plans

- **Seq Scan:** reads every row of a table. Cheap for small tables, expensive when only a few rows of a large table are needed.
- **Index Scan and Bitmap Index Scan:** use an index to find matching rows. A bitmap scan collects the matching page locations first and then visits each page once, which suits queries that match a moderate number of rows spread over many pages.
- **Index Only Scan:** answers from the index alone. With `Heap Fetches: 0` the table is not read at all.
- **Hash Join:** builds a hash table from one input and probes it with the other. **Nested Loop:** looks up matching rows for each row of the outer input, efficient when the outer side is small and the inner side is indexed.
- **Estimated vs actual rows:** the estimates were close for most scans (Q1: 1,011 estimated, 1,111 actual) but off for some (Q2: about 9 vs 21; Q3: 1 vs 4; Q7's group count 5x too high). The estimates influence which plan is chosen.

## 5. Cost of the indexes

| Index | Size | Used by my eight queries? |
|---|---|---|
| `idx_loans_copy_id` | 3,440 kB | No |
| `idx_loans_member_id` | 2,488 kB | Yes (Q2, Q6) |
| `idx_copies_book_id` | 976 kB | Yes (Q8) |
| `idx_books_title_prefix` | 720 kB | Yes (Q1) |
| `idx_fines_paid` | 576 kB | No |
| `idx_loans_open_due` | 16 kB | Yes (Q3) |

The six indexes take 8,216 kB in total. Measured with `pg_total_relation_size` (which includes all indexes), the four affected tables are `loans` 30 MB, `book_copies` 8,832 kB, `fines` 8,776 kB and `books` 3,496 kB, about 51 MB in all, so the new indexes are roughly 16% of that. On `loans` alone, the three new indexes add about 5.9 MB.

Two of the six, `idx_loans_copy_id` and `idx_fines_paid`, were not used by any of my queries and account for about 49% of the new index storage. The partial index `idx_loans_open_due` is only 16 kB yet gave the largest speed-up (about 640x on Q3), which is the argument for partial indexes.

Every index also has a write cost: each INSERT into `loans` must update `idx_loans_member_id` and `idx_loans_copy_id` as well as the table, and returning a book sets `return_date`, which removes the row from the partial index. I did not measure the write overhead, so I am describing it from how indexes work, not from my own test.

`idx_loans_copy_id` is not necessarily wasteful in a real system: it would serve a "loan history of this copy" query and speed up the foreign key check when a copy is deleted. `idx_fines_paid` is the weaker case, because a boolean column with two roughly equal values will rarely be selective enough to be used.

## 6. Limitations

- Each timing is a single run on a laptop with a warm cache. Small differences should not be over-interpreted; the large improvements (Q2, Q3, Q6, Q8) are 9x to 640x and each has a clear plan change behind it.
- The data is synthetic and evenly distributed, so the Q5 and Q7 rankings are ties and not realistic popularity data.
- I did not test a cold cache, write performance, or different `work_mem` settings, so the Q7 disk spill is unresolved.

## 7. Conclusion

Indexes gave large gains where a query needed a small fraction of a big table (Q2, Q3, Q8) and a moderate gain where the saved scan was only part of the work (Q1, Q6). They made no difference where every row was needed (Q4, Q5, Q7), and two of the six indexes were never used. The main lesson is that an index must match the query's filter and be selective enough for the planner to choose it, and that its storage and write costs mean it should be created for a known workload, not by default.
