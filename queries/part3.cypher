
// Частина 3 Запити

// (:User)-[:RATED {rating, timestamp}]->(:Movie)
// (:Movie)-[:HAS_GENRE]->(:Genre)



// Запит 1. Знайти всі фільми жанру «Thriller» із середнім рейтингом вище 4.0:

MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (m)<-[r:RATED]-(:User)
WITH
    m,
    avg(r.rating) AS averageRating,
    count(r) AS ratingsCount
WHERE averageRating > 4.0
RETURN
    m.movieId AS movieId,
    m.title AS title,
    round(averageRating, 2) AS averageRating,
    ratingsCount
ORDER BY averageRating DESC, ratingsCount DESC, title;

// Запит 2. Знайти користувачів, які поставили оцінку 5 більш ніж 50 фільмам:


MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH
    u,
    count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN
    u.userId AS userId,
    u.gender AS gender,
    u.age AS age,
    u.occupation AS occupation,
    fiveStarRatings
ORDER BY fiveStarRatings DESC, userId;


// Запит 3. Знайти фільми, які обидва користувачі (наприклад, userId=1 і userId=2) оцінили високо (рейтинг ≥ 4):

MATCH
    (user1:User {userId: 1})-[rating1:RATED]->(movie:Movie)
    <-[rating2:RATED]-(user2:User {userId: 2})
WHERE rating1.rating >= 4
  AND rating2.rating >= 4
RETURN
    movie.movieId AS movieId,
    movie.title AS title,
    rating1.rating AS user1Rating,
    rating2.rating AS user2Rating
ORDER BY
    user1Rating + user2Rating DESC,
    title;


// Запит 4. Знайти жанри, чиї фільми стабільно отримують високі оцінки — середній рейтинг і кількість оцінок:
//
// критерії:
// середній рейтинг >= 3.5;
// > 1000 оцінок.


WITH
    3.5 AS minAverageRating,
    1000 AS minRatings
MATCH (genre:Genre)<-[:HAS_GENRE]-(movie:Movie)<-[rating:RATED]-(:User)
WITH
    genre,
    minAverageRating,
    minRatings,
    count(DISTINCT movie) AS moviesCount,
    count(rating) AS ratingsCount,
    avg(rating.rating) AS averageRating
WHERE averageRating >= minAverageRating
  AND ratingsCount >= minRatings
RETURN
    genre.name AS genre,
    moviesCount,
    ratingsCount,
    round(averageRating, 3) AS averageRating
ORDER BY averageRating DESC, ratingsCount DESC, genre;


// Запит 5. Рекомендація «користувачі зі схожими смаками також дивилися»: для заданого користувача знайти фільми, які він ще не дивився, але високо оцінили користувачі з подібними смаками:

WITH 1 AS targetUserId
MATCH (target:User {userId: targetUserId})
MATCH
    (target)-[targetRating:RATED]->(commonMovie:Movie)
    <-[similarRating:RATED]-(similarUser:User)
WHERE targetRating.rating >= 4
  AND similarRating.rating >= 4
  AND similarUser <> target
WITH
    target,
    similarUser,
    count(DISTINCT commonMovie) AS commonLikedMovies
WHERE commonLikedMovies >= 3
MATCH (similarUser)-[candidateRating:RATED]->(candidate:Movie)
WHERE candidateRating.rating >= 4
  AND NOT EXISTS {
      MATCH (target)-[:RATED]->(candidate)
  }
WITH
    candidate,
    count(DISTINCT similarUser) AS supportingUsers,
    avg(candidateRating.rating) AS averageRating,
    sum(commonLikedMovies) AS recommendationScore
RETURN
    candidate.movieId AS movieId,
    candidate.title AS title,
    supportingUsers,
    round(averageRating, 2) AS averageRating,
    recommendationScore
ORDER BY
    recommendationScore DESC,
    supportingUsers DESC,
    averageRating DESC,
    title
LIMIT 20;


// Запит 6. Знайти найкоротший ланцюжок зв’язку між двома користувачами через спільні фільми:

MATCH
    (user1:User {userId: 1}),
    (user2:User {userId: 2})
MATCH path = shortestPath(
    (user1)-[:RATED*..6]-(user2)
)
RETURN
    length(path) AS pathLength,
    path,
    [
        node IN nodes(path) |
        CASE
            WHEN node:User THEN 'User ' + toString(node.userId)
            ELSE node.title
        END
    ] AS chain;
