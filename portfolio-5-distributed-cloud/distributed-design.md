# Portfolio 5: Distributed and cloud design for CityLight Public Library

## 1. What is deployed

- **MongoDB Atlas (cloud):** the catalogue (`books` collection, 15 documents) from Portfolio 4, on a Free-tier 3-node replica set in AWS Ireland (eu-west-1).
- **PostgreSQL (local):** loans, fines, members and copies, which remain the system of record (Portfolios 1 to 3).
- The two databases are linked only by the one-off JSON export from Portfolio 4. See `architecture-diagram.png`.

## 2. Replication

A replica set keeps copies of the same data on several nodes. One node, the **primary**, accepts all writes and records them in an operation log. The **secondaries** apply that log and so hold copies of the data. My cluster's overview page shows three nodes: one primary and two secondaries (`replica-set-nodes.png`).

A failover test isn't available on a Free cluster, so I did not run one. The table below is the behaviour I expect from how replica sets work, not something I observed.

| Event | Expected behaviour | Effect on the library |
|---|---|---|
| One secondary fails | The primary and the other secondary are still a majority (2 of 3), so writes continue | None visible |
| The primary fails | The two remaining nodes hold an election and one becomes primary. Writes pause briefly, and drivers can retry a failed write once the new primary is elected. | A short interruption to catalogue updates |
| Two nodes fail | No majority, so no primary can be elected. The surviving node can serve reads only if reads from secondaries are allowed. | Browsing may continue, but updates stop |
| The whole region fails | All three nodes are in Ireland, so the whole cluster is unavailable | Full outage of the MongoDB side |

Spreading nodes over several regions would reduce that last risk, but as far as I know that needs a paid tier, which I did not use.

## 3. Availability

- **What I gained:** the cluster tolerates the loss of one node, and Atlas runs and monitors the nodes for me.
- **What I did not get:** all three nodes sit in one region, the free tier has fixed resources, and idle free clusters may be deactivated.
- **Recovery:** bbackups were not enabled
- **PostgreSQL:** my PostgreSQL server is a single instance on a laptop, which is a single point of failure. In production I would add a standby server using streaming replication with automatic failover. I did not implement this.

## 4. Consistency

Replication creates a choice: read the latest data (from the primary) or read from a secondary, which can lag behind the primary and return older data. The settings that control this are the **read preference** (where reads go) and the **write concern** (how many nodes must acknowledge a write). Writing with majority acknowledgement protects a write from being lost if the primary fails straight afterwards. I used Atlas's default settings through Data Explorer and did not change them.

| Library operation | Where | Needs | Why |
|---|---|---|---|
| Borrow a book (check availability, create the loan) | PostgreSQL | Latest data, with locking (`FOR UPDATE` from Portfolio 3) | A stale read here is exactly how the double-booking in Portfolio 3 happened |
| Search and browse the catalogue | MongoDB, secondary reads acceptable | Slightly stale data is fine | Speed and spreading load matter more than being up to the second |
| Show "available" on a catalogue page | MongoDB | May be out of date | It is a copy exported from PostgreSQL, so the real check has to happen at borrowing time |
| Add or edit a book | MongoDB, majority acknowledgement | A durable write | An edit should not vanish after a failover |

In terms of the CAP trade-off, a replica set leans towards **consistency**: if the network splits, the side without a majority cannot elect a primary and stops accepting writes. Reads from secondaries are **eventually consistent**.

**Keeping the two databases in step.** In Portfolio 4, MongoDB received a snapshot, so its copy statuses drift as books are borrowed. A real system would stream changes from PostgreSQL to MongoDB (change data capture, or an "outbox" table), which makes the catalogue eventually consistent with the system of record. I did not build that.

## 5. Sharding (design only)

**Why I did not shard.** The catalogue is about 80 KB, and the Free tier can't be sharded. Sharding splits one collection across several servers, each holding part of the data. It would only be worth it if a single server could no longer hold or serve the data. In my project the table that would outgrow a server first is `loans` (300,009 rows in my tests, and it grows with every borrow).

**Choosing a shard key for `loans`.** I compared three candidates against the queries and rules from Portfolios 2 and 3:

| Shard key | Q2: one member's history | Q3: overdue loans | Borrowing and "one open loan per copy" | Write spread |
|---|---|---|---|---|
| `member_id` (hashed) | One shard | All shards | A copy's loans are spread over shards, so the rule cannot be enforced by a local unique index and needs coordination between shards | Even |
| `copy_id` (hashed) | All shards | All shards | The copy and all its loans sit together on one shard, so the rule can be enforced locally | Even |
| `loan_date` (ranged) | All shards | Mostly the newest ranges | Same problem as `member_id` | Poor: every new loan lands in the newest range, creating a hotspot |

**My choice:** `copy_id`, hashed. Borrowing is the operation that must be correct, and it touches a copy and its loan together. Keeping them on one shard keeps that operation within a single shard, and it lets the "one open loan per copy" rule (the optional index idea from Portfolio 3) be enforced locally. The price is that Q2 (a member's history) has to ask every shard. I would cover that with a second copy of the loan data keyed by member for reads. This is reasoning from my own queries, not something I tested.

A `loan_date` key would be a poor choice because it is monotonically increasing, so all new writes go to the same shard.

**Illustration only, not run:**
```javascript
sh.shardCollection("citylight_library.loans", { copy_id: "hashed" })
```

**The `books` catalogue** doesn't need sharding. If it ever did, `isbn` would be a natural key, since it is unique and used for lookups.

## 6. Scaling the PostgreSQL side (discussion only)

- **Read replicas.** The heaviest queries in Portfolio 2 (Q4, Q5 and Q7, which read every loan) could run against a replica, leaving the primary free for borrowing.
- **Partitioning `loans` by date.** Old loans can be archived by dropping a partition, and queries on recent loans touch less data.
- I did not implement either.

## 7. Cloud trade-offs

| Benefit | Risk or limit |
|---|---|
| Atlas runs and monitors the replica set, so I did not have to build or patch it | Little control: the free tier fixes the node count and the MongoDB version |
| Scales up by moving to a paid tier | Free tier: 512 MB, shared resources, possible deactivation when idle |
| Reachable from anywhere | The region is Ireland. For users in Lagos that adds latency, and personal data about members stored abroad would need to be checked against data protection rules |
| Credentials and an access list protect the cluster | My database user has the broad `atlasAdmin` role, and the access list needs to be kept tight |
| No hardware to buy | Ongoing cost on paid tiers, and some lock-in to the provider's tools |

## 8. Limitations

- I did not test failover or simulate any failure, because the free tier doesn't allow it.
- Sharding is a design only.
- I did not change read preference or write concern; the consistency section explains what they do.
- The MongoDB data is a snapshot and is not synchronised with PostgreSQL.
- The Free tier's three nodes share one region.
