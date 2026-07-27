// Частина 3 — Запити різної складності

// Базові запити

// Запит 1 — Thriller із рейтингом вище 4.0

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


// Запит 2 — користувачі з понад 50 оцінками 5

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
