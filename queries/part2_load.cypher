// 4. Зв'язки RATED

CALL apoc.periodic.iterate(
    "
    LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
    RETURN row
    ",
    "
    MATCH (u:User {userId: toInteger(row.userId)})
    MATCH (m:Movie {movieId: toInteger(row.movieId)})
    MERGE (u)-[r:RATED]->(m)
    SET
        r.rating = toInteger(row.rating),
        r.timestamp = toInteger(row.timestamp)
    ",
    {
        batchSize: 10000,
        parallel: false,
        retries: 2
    }
)
YIELD
    batches,
    total,
    timeTaken,
    failedBatches,
    errorMessages
RETURN
    batches,
    total,
    timeTaken,
    failedBatches,
    errorMessages;