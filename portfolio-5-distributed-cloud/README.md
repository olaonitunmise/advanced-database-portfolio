# Portfolio 5: Distributed and Cloud Database Exercise

## 1. Objective

To show how the CityLight Public Library database would be deployed and scaled across several nodes, using a MongoDB Atlas replica set as practical evidence and a written design for what the free tier does not allow (sharding and failover testing).

This portfolio uses the same case study as Portfolios 1 to 4. See the [root README](../README.md).

## 2. Files

| File | Description |
|---|---|
| `deployment-notes.md` | The Atlas deployment (provider, region, topology, limits, security observations) |
| `distributed-design.md` | Replication, availability, consistency, a sharding design, PostgreSQL scaling and cloud trade-offs |
| `architecture-diagram.png` | How PostgreSQL and the Atlas replica set fit together |
| `screenshots/` | Evidence from the Atlas console |

## 3. What I did

1. Used the Atlas cluster from Portfolio 4 (free tier, `citylight-cluster`) and recorded its deployment details from the overview page.
2. Captured the three-node replica set and its roles.
3. Reviewed the free-tier limits in the Atlas documentation, which showed that sharding and failover tests are not possible on this tier. I therefore wrote those parts as a design, and say so clearly.
4. Wrote the replication, availability, consistency and sharding analysis, tied to the queries and the double-booking problem from Portfolios 2 and 3.

## 4. Deployment evidence

| Item | Value |
|---|---|
| Provider and region | AWS, Ireland (eu-west-1) |
| Tier | Free |
| MongoDB version | 8.0.37 |
| Topology | Replica set, 3 nodes: 1 primary, 2 secondaries |
| Data | 15 documents, about 80 KB of the 512 MB limit |

| Screenshot | What it shows |
|---|---|
| `atlas-cluster.png` | Cluster card with tier, version, region and "Replica Set - 3 nodes" |
| `replica-set-nodes.png` | The primary and two secondary nodes |
| `import-result.png` | The catalogue stored on the cluster (15 documents) |
| `security.png` | The database user list (username blurred) |

## 5. Summary of the design

- **Replication:** one primary takes writes and two secondaries copy them. A majority (2 of 3) is needed to elect a primary, so the cluster survives the loss of one node. I could not test failover on a free cluster, so the failure table in `distributed-design.md` describes expected behaviour and is not an observed result.
- **Availability:** one-node failure is tolerated, but all three nodes are in one region, so a regional outage would stop the MongoDB side.
- **Consistency:** reads from the primary give the latest data, while reads from a secondary can be slightly stale. Borrowing needs the latest data (and in Portfolio 3 it used row locking), while catalogue browsing can tolerate stale reads. The catalogue in MongoDB is a snapshot of PostgreSQL, so the real availability check happens at borrowing time.
- **Sharding (design only):** I compared `member_id`, `copy_id` and `loan_date` as shard keys for the loans data against my Portfolio 2 queries and the Portfolio 3 double-booking rule. I chose a hashed `copy_id`, because the borrow operation touches a copy and its loan together. The cost is that a member's history becomes a query across all shards.
- **PostgreSQL:** I discuss read replicas for the heaviest reporting queries and date partitioning for `loans`, but did not implement them.

## 6. Limitations

- No failover or outage test was possible on the free tier.
- No sharded cluster was possible on the free tier, so sharding is a design discussion.
- The three nodes share one region.
- I did not change read preference or write concern.
- The MongoDB data is a snapshot, with no synchronisation from PostgreSQL.

## 7. Challenges and lessons

*(Edit this section so it matches what happened to you. These points are supported by my screenshots and notes.)*

**Challenges**
- **Planning around the free tier.** I had planned to demonstrate failover and sharding, but the Atlas documentation shows the free tier doesn't support them. I changed the approach to a clearly labelled design discussion and did not claim results I could not obtain.
- **Finding the right screen.** My first cluster screenshot showed an empty collection and not the cluster overview, so I retook it from the cluster list and the overview page.
- **Security findings.** My database user turned out to have the broad `atlasAdmin` role, which I recorded as a least-privilege weakness.

**Lessons**
- Replication gives availability and read scaling, but it is not a backup and it creates a consistency choice.
- Sharding decisions come from the queries: the same shard key that makes one query fast can make another touch every shard.
- A cloud service shifts operating work to the provider but limits control, and its free tier has hard limits.
- Being honest about what was not tested matters as much as the evidence that was.

## 8. Sources and AI use

- MongoDB Atlas free-tier limits: https://www.mongodb.com/docs/atlas/reference/free-shared-limitations/
- MongoDB Atlas: https://www.mongodb.com/atlas
- MongoDB documentation: https://www.mongodb.com/docs/manual/
- Tools: MongoDB Atlas (Free tier) and PostgreSQL with pgAdmin. Cluster credentials and connection strings are intentionally not included in this repository.
- AI use is described in the AI Use Declaration in the final documentation (tool used, what it was used for, and how I reviewed and tested the output).
