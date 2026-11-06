# Portfolio 3: Transactions and Concurrency

## 1. Objective

To show that the "borrow a book" operation in the CityLight Public Library database behaves correctly as a transaction (commit and rollback), to reproduce a real concurrency problem (two members borrowing the last available copy of a book), and to fix it using two different control mechanisms.

This portfolio uses the same case study and database as Portfolios 1 and 2. See the [root README](../README.md).

## 2. Files

| File | Description |
|---|---|
| `00-check-and-reset.sql` | Pre-flight check, reset statements used between demos, and the final clean-state check |
| `01-commit-transaction.sql` | Part A: a successful borrow, committed |
| `02-rollback-transaction.sql` | Part B: a deliberate rollback (B1) and a rollback after an error half-way through (B2) |
| `03-concurrency-problem.sql` | Part C: two sessions double-booking the last copy under READ COMMITTED |
| `04-fix-select-for-update.sql` | Part D: the fix using a row lock (`SELECT ... FOR UPDATE`) |
| `05-fix-repeatable-read.sql` | Part E: the fix using the `REPEATABLE READ` isolation level |
| `screenshots/` | Evidence for each part |

## 3. How to run

**Tools:** PostgreSQL 17 with pgAdmin. Every script was run **one statement at a time** (highlight the statement, then F5), not as a whole file, because pgAdmin shows only the last result of a multi-statement run and because a transaction must be controlled step by step.

**Sessions:** each pgAdmin Query Tool tab has its own database connection, so two tabs behave as two users. Parts C, D and E use two tabs (Session A and Session B). Part D also uses a third tab to watch `pg_stat_activity`.

**Demo data (from Portfolio 1):**
- Copy `CL-0017` (*Clean Code*) is used for Parts A and B.
- Copy `CL-0014` is the **last available copy** of *Database System Concepts* (its other two copies are on loan). It is used for Parts C to E.
- Members: Funmi Adeyemi (Parts A and B), Adaeze Okafor (Session A) and Aisha Bello (Session B). Staff: Grace Ade.

**Between demos:** I ran the two reset statements in `00-check-and-reset.sql`, which delete open loans on the two demo copies and set both copies back to `available`, then checked the state. After the last demo I confirmed the database was back to its Portfolio 2 state: 300,009 loans in total and 4 open loans.

**Note on loan IDs:** loan IDs in the screenshots (300010 to 300026) are not consecutive per demo, because identity values are not reused after a delete or rollback. This does not affect the results.

## 4. The borrow operation

Borrowing a copy takes two writes that describe the same event:

1. insert a row into `loans`, and
2. change the copy's `status` in `book_copies` to `on_loan`.

If only one of them happens, the database becomes inconsistent: either a loan exists for a copy that still says `available`, or a copy says `on_loan` with no loan. Both writes therefore need to succeed or fail together, which is what a transaction provides.

## 5. Transaction control

### Part A: commit

Inside `BEGIN ... COMMIT` I checked that `CL-0017` was available, inserted the loan for Funmi Adeyemi (due 14 days after the loan date), and set the copy to `on_loan`.

| Evidence | What it shows |
|---|---|
| `a1-before-commit.png` | Inside the transaction: 1 open loan (loan 300010) and the copy `on_loan` |
| `a2-after-commit.png` | After `COMMIT`: the same row, now permanent |

`COMMIT` made both changes permanent together (atomicity and durability).

### Part B1: deliberate rollback

I began a transaction and inserted the loan. The count of open loans for the copy was **1 inside the transaction** and **0 after `ROLLBACK`**.

| Evidence | What it shows |
|---|---|
| `b1-inside-txn.png` | Count 1 inside the transaction |
| `b1-after-rollback.png` | Count 0 after `ROLLBACK` |

Work inside a transaction is provisional. `ROLLBACK` discards all of it and leaves the database as it was before `BEGIN`.

### Part B2: rollback after an error half-way through

Inside a transaction, the loan insert **succeeded**, and then an update to the copy's status failed because `'borrowed'` is not an allowed value:

- The update was rejected with `violates check constraint "chk_copy_status"` (SQLSTATE 23514).
- The next statement, `SELECT 1`, was also refused: `current transaction is aborted, commands ignored until end of transaction block` (SQLSTATE 25P02).
- After `ROLLBACK`, there were **0 open loans** for the copy and its status was still `available`.

| Evidence | What it shows |
|---|---|
| `b2-constraint-error.png` | The check constraint violation (23514) |
| `b2-aborted-transaction.png` | The aborted-transaction message (25P02) |
| `b2-after-rollback1.png` | 0 open loans after the rollback |
| `b2-after-rollback2.png` | The copy still `available` |

This demonstrates **atomicity**. The loan insert had worked, but because it shared a transaction with the failing update, it was undone too. Without a transaction, the database would have held a loan for a copy that still said `available`. It also shows that after an error, PostgreSQL does not let the session carry on until the transaction is ended.

## 6. Concurrency

### Part C: the problem (READ COMMITTED, the default)

`CL-0014` is the last available copy. Adaeze (Session A) and Aisha (Session B) both try to borrow it at the same time:

1. Both sessions began a transaction and **both read `available`**.
2. Session A inserted its loan, marked the copy `on_loan` and committed.
3. Session B, still acting on what it had read earlier, inserted its loan, marked the copy `on_loan` and committed. Nothing blocked and nothing failed.

**Result:** two open loans (300023 for Adaeze and 300024 for Aisha) on one physical copy.

| Evidence | What it shows |
|---|---|
| `c1-a-sees-available.png` | Session A sees `available` |
| `c2-b-sees-available.png` | Session B sees `available` at the same time |
| `c3-double-booking.png` | Two open loans on the same copy |

**Why it happens:** this is a check-then-act race condition. Each session decided from an earlier read, and the other session's commit then made that read out of date. Under READ COMMITTED each statement sees the latest committed data, but a decision made from an earlier `SELECT` is not protected. Nothing in the schema forbids two open loans on one copy (I left that rule out of Portfolio 1 on purpose, so this problem could be shown), so the database accepted both.

### Part D: fix 1, a row lock (`SELECT ... FOR UPDATE`)

Both sessions now check availability with `SELECT ... FOR UPDATE`, which takes a row-level lock:

1. Session A locked the row and saw `available`.
2. Session B ran the same query and **did not return**: it was waiting.
3. While B waited, `pg_stat_activity` showed Session B as `active` with `wait_event_type` = `Lock` and `wait_event` = `transactionid`, and Session A as `idle in transaction`.
4. Session A inserted its loan, marked the copy `on_loan` and committed.
5. Session B's query then returned **`on_loan`**. B did not borrow, and rolled back.

**Result:** one open loan (300025, Adaeze).

| Evidence | What it shows |
|---|---|
| `d1-a-holds-lock.png` | Session A takes the lock |
| `d2-b-waiting.png` | Session B's query still running (blocked) |
| `d3-pg-stat-activity.png` | B waiting on a lock, A idle in transaction |
| `d4-b-sees-on-loan.png` | B's query returns `on_loan` after A commits |
| `d5-one-open-loan.png` | One open loan on the copy |

**Why it works:** the check and the update are protected together. B cannot lock the row until A finishes, and when it can, PostgreSQL returns the updated row, so B sees the committed state. This is **pessimistic** concurrency control: lock first, then decide. The cost is that B has to wait, which is fine for a short transaction but would slow other sessions down if a transaction held locks for a long time.

### Part E: fix 2, a stricter isolation level (`REPEATABLE READ`)

Both sessions began with `BEGIN ISOLATION LEVEL REPEATABLE READ`:

1. Both read `available`.
2. Session A inserted its loan, marked the copy `on_loan` and committed.
3. Session B tried to update the same row and failed with `ERROR: could not serialize access due to concurrent update` (SQLSTATE 40001). In my run the error appeared on the `UPDATE`.
4. Session B ran `ROLLBACK`, which also undid its loan insert.

**Result:** one open loan (300026, Adaeze).

| Evidence | What it shows |
|---|---|
| `e1-a-sees-available.png` | Session A's snapshot sees `available` |
| `e2-b-sees-available.png` | Session B's snapshot sees `available` |
| `e3-serialization-error.png` | The serialization failure (40001) in Session B |
| `e4-one-open-loan.png` | One open loan on the copy |

**Why it works:** a `REPEATABLE READ` transaction works from a snapshot taken at its first query. B's snapshot was older than A's commit, so PostgreSQL refused to let B overwrite a row that had changed since. This is **optimistic** concurrency control: nothing waits, but the losing transaction has to retry.

### Comparing the two fixes

| | `FOR UPDATE` (Part D) | `REPEATABLE READ` (Part E) |
|---|---|---|
| Approach | Pessimistic: lock first | Optimistic: proceed, detect conflict |
| What the second session experiences | Waits, then sees `on_loan` | Proceeds, then fails with error 40001 |
| Application must | Check the status it reads back | Catch error 40001 and retry the transaction |
| Suits | Short transactions on contended rows, such as the last copy of a popular title | Mostly uncontended work, where conflicts are rare and waiting would be wasteful |

In a real application I would use `FOR UPDATE` for the borrow operation, because the check and update are short and the contention is on a single row. If I used `REPEATABLE READ`, the code would need a retry loop for error 40001, and on retry the second member would see `on_loan`.

One more option that I did **not** implement or test is a partial unique index on `loans (copy_id) WHERE return_date IS NULL`, which would make the database itself refuse a second open loan for a copy. This would act as a safety net underneath either fix. I mention it as a possible design improvement, not as a result.

## 7. Testing

- Before the demos I checked that the starting state was as expected (`CL-0014` and `CL-0017` available, the other three sample copies on loan; see `00-preflight-check.png`).
- I reset the data between demos and confirmed the state each time.
- After the last demo I confirmed that the database was back to its Portfolio 2 state: 300,009 loans in total and 4 open loans (`final-clean-state.png`), so none of the demo data was left behind.
- Each concurrency demo was confirmed with the same verification query (open loans on `CL-0014`): 2 rows in Part C, then 1 row in Parts D and E.

**Limitations:** I tested only two concurrent sessions, only the READ COMMITTED and REPEATABLE READ levels, and only one contended row. I did not test `SERIALIZABLE`, deadlocks, or behaviour under heavier load.

## 8. Challenges and lessons

*(Edit this section so it matches what happened to you. Below is what my screenshots and files support.)*

**Challenges**

- **Forgetting `BEGIN`.** pgAdmin auto-commits each statement, so statements run without `BEGIN` are saved immediately and `ROLLBACK` or `COMMIT` then warns that there is no transaction in progress. I had to check what had been saved, reset the data and redo the steps from `BEGIN`.
- **Closing a tab mid-demo.** Closing a Query Tool tab ended its session, and PostgreSQL rolled back the open transaction. When I reopened the tab and carried on from the middle, the earlier steps no longer counted. The two-session demos only work if both tabs stay open until the end.
- **Statements running more than once.** One run of Part C left six open loans on the copy (three for each member) instead of two. I believe pressing F5 without a highlighted statement ran extra statements, though I did not confirm this from the query history. I reset the data and repeated the demo, running one highlighted statement at a time and checking the Messages tab each time.
- **Blocked sessions look like a hang.** In Part D, Session B's query sat there without returning, which at first looks like a freeze. The `pg_stat_activity` query showed it was waiting on a lock, which was the expected behaviour.
- **Keeping the demo repeatable.** I had to reset the same two copies between demos and check the state each time, so every demo started from the same data.

**Lessons**

- Atomicity is what keeps multi-step operations consistent. The B2 error showed how one successful step is undone if a later step fails.
- A decision based on an earlier read is not safe under READ COMMITTED if the data can change in between. The default isolation level does not prevent this on its own.
- There are two different ways to prevent the problem: lock and wait, or detect the conflict and retry. Each has a different cost, and the application code differs between them.
- Reading the database's own view of what is happening (`pg_stat_activity`) is a useful way to understand blocking.
- Working carefully one statement at a time matters when demonstrating transactions, because it is easy to run steps in the wrong order or twice.

## 9. Sources and AI use

- Tools: PostgreSQL 17 and pgAdmin. All data is the fictional data from Portfolios 1 and 2.
- AI use is described in the AI Use Declaration in the final documentation (tool used, what it was used for, and how I reviewed and tested the output).
