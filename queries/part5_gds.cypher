
// 5.1

// Крок 1: матеріалізуємо ребра фільм-фільм через спільних користувачів
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating = 5 AND r2.rating = 5 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 10000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: створюємо проєкцію на основі матеріалізованих ребер
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: запускаємо weighted PageRank
CALL gds.pageRank.stream(
  'movieGraph',
  {
    relationshipWeightProperty: 'weight',
    maxIterations: 20,
    dampingFactor: 0.85
  }
)
YIELD nodeId, score
WITH
  gds.util.asNode(nodeId) AS movie,
  score
RETURN
  movie.movieId AS movieId,
  movie.title AS title,
  round(score, 6) AS pageRank
ORDER BY pageRank DESC
LIMIT 20;

// Крок 4: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;



// 5.2 Louvain



// Крок 1: матеріалізуємо ребра користувач-користувач через спільні фільми
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5 AND r2.rating = 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 10000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: запускаємо Louvain і записуємо communityId у вузли User
CALL gds.louvain.write(
  'userSimilarity',
  {
    relationshipWeightProperty: 'weight',
    writeProperty: 'communityId',
    maxLevels: 10,
    maxIterations: 10
  }
)
YIELD
  communityCount,
  modularity,
  modularities,
  ranLevels
RETURN
  communityCount,
  round(modularity, 6) AS modularity,
  modularities,
  ranLevels;


// Крок 4.1: визначаємо 10 найбільших спільнот
MATCH (u:User)
WHERE u.communityId IS NOT NULL
RETURN
  u.communityId AS communityId,
  count(u) AS usersCount
ORDER BY usersCount DESC, communityId
LIMIT 10;


// Крок 4.2: визначаємо три найпопулярніші жанри
// для кожної з 10 найбільших спільнот
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH
  u.communityId AS communityId,
  count(u) AS usersCount
ORDER BY usersCount DESC
LIMIT 10

CALL {
  WITH communityId

  MATCH
    (member:User)-[rating:RATED]->(movie:Movie)
    -[:HAS_GENRE]->(genre:Genre)
  WHERE member.communityId = communityId
    AND rating.rating >= 4

  WITH
    genre.name AS genre,
    count(rating) AS highRatings

  ORDER BY highRatings DESC, genre
  LIMIT 3

  RETURN collect({
    genre: genre,
    highRatings: highRatings
  }) AS topGenres
}

RETURN
  communityId,
  usersCount,
  topGenres
ORDER BY usersCount DESC, communityId;



// 5.3

CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;



// Крок 3.1: визначаємо найбільшу зв'язну компоненту
// та знаходимо шлях між двома її користувачами

CALL gds.wcc.stream('userGraph')
YIELD nodeId, componentId
WITH
  componentId,
  collect(nodeId) AS componentNodes
ORDER BY size(componentNodes) DESC
LIMIT 1

WITH
  componentNodes,
  size(componentNodes) AS componentSize,
  gds.util.asNode(componentNodes[0]) AS source,
  gds.util.asNode(
    componentNodes[size(componentNodes) - 1]
  ) AS target

CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target
  }
)
YIELD totalCost, nodeIds, costs

RETURN
  componentSize,
  source.userId AS sourceUserId,
  target.userId AS targetUserId,
  toInteger(totalCost) AS pathLength,
  CASE
    WHEN size(nodeIds) >= 2
    THEN size(nodeIds) - 2
    ELSE 0
  END AS intermediateUsers,
  [
    nodeId IN nodeIds |
    gds.util.asNode(nodeId).userId
  ] AS userPath,
  costs;


// Крок 3.2: перевіряємо 10 пар користувачів
// із найбільшої зв'язної компоненти

CALL gds.wcc.stream('userGraph')
YIELD nodeId, componentId
WITH
  componentId,
  collect(nodeId) AS componentNodes
ORDER BY size(componentNodes) DESC
LIMIT 1

UNWIND range(
  0,
  CASE
    WHEN size(componentNodes) >= 20 THEN 9
    ELSE toInteger(floor(size(componentNodes) / 2.0)) - 1
  END
) AS pairIndex

WITH
  size(componentNodes) AS componentSize,
  gds.util.asNode(
    componentNodes[pairIndex]
  ) AS source,
  gds.util.asNode(
    componentNodes[size(componentNodes) - 1 - pairIndex]
  ) AS target

WHERE source <> target

CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target
  }
)
YIELD totalCost, nodeIds

RETURN
  componentSize,
  source.userId AS sourceUserId,
  target.userId AS targetUserId,
  toInteger(totalCost) AS pathLength,
  CASE
    WHEN size(nodeIds) >= 2
    THEN size(nodeIds) - 2
    ELSE 0
  END AS intermediateUsers,
  [
    nodeId IN nodeIds |
    gds.util.asNode(nodeId).userId
  ] AS userPath

ORDER BY
  pathLength,
  sourceUserId,
  targetUserId;


// Крок 3.3: розраховуємо середню довжину шляху
// для тих самих пар користувачів

CALL gds.wcc.stream('userGraph')
YIELD nodeId, componentId
WITH
  componentId,
  collect(nodeId) AS componentNodes
ORDER BY size(componentNodes) DESC
LIMIT 1

UNWIND range(
  0,
  CASE
    WHEN size(componentNodes) >= 20 THEN 9
    ELSE toInteger(floor(size(componentNodes) / 2.0)) - 1
  END
) AS pairIndex

WITH
  size(componentNodes) AS componentSize,
  gds.util.asNode(
    componentNodes[pairIndex]
  ) AS source,
  gds.util.asNode(
    componentNodes[size(componentNodes) - 1 - pairIndex]
  ) AS target

WHERE source <> target

CALL gds.shortestPath.dijkstra.stream(
  'userGraph',
  {
    sourceNode: source,
    targetNode: target
  }
)
YIELD totalCost

RETURN
  componentSize,
  count(*) AS connectedPairs,
  round(avg(totalCost), 2) AS averagePathLength,
  toInteger(min(totalCost)) AS minPathLength,
  toInteger(max(totalCost)) AS maxPathLength,
  sum(
    CASE
      WHEN totalCost <= 6 THEN 1
      ELSE 0
    END
  ) AS pathsWithinSixHops;

CALL gds.graph.drop('userGraph');