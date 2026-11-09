//n1 - Expect 1 document: Database System Concepts. No join was needed to get its authors and copies, because they’re embedded.
{ isbn: "9780000000009" }

//n2 - Expect 3 documents: Database System Concepts, Clean Code and Learning NoSQL Databases. 
{ category: "Technology" }

//n3 - Expect 2 documents: Things Fall Apart and Arrow of God. In PostgreSQL this took a join through book_authors.
{ "authors.lastName": "Achebe" }

//n4 - Expect 14 documents, every title except Death and the King’s Horseman (its only copy is lost)
{ copies: { $elemMatch: { status: "available" } } }

//n5 - Expect 4 documents: Database System Concepts, Clean Code, Matilda and Learning NoSQL Databases.
{ "copies.status": "on_loan" }

//n6 - Expect 2 documents (Learning NoSQL Databases and The Tortoise and the River).
{ reviews: { $exists: true } }


//Aggregations

//A1: titles per category
[
  { $group: { _id: "$category", titles: { $sum: 1 } } },
  { $sort: { titles: -1, _id: 1 } }
]

//A2: copies and availability per title
[
  { $project: {
      _id: 0,
      title: 1,
      totalCopies: { $size: "$copies" },
      availableCopies: {
        $size: { $filter: { input: "$copies", as: "c",
                            cond: { $eq: ["$$c.status", "available"] } } }
      }
  } },
  { $sort: { title: 1 } }
]

//A3: average rating per title
[
  { $unwind: "$reviews" },
  { $group: { _id: "$title", reviewCount: { $sum: 1 }, avgRating: { $avg: "$reviews.rating" } } },
  { $sort: { avgRating: -1 } }
]
