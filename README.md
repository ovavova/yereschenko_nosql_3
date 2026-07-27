# yereschenko_nosql_3

# Завдання 3. Граф знань для рекомендаційної системи

Хід роботи:

Завантажити та розпакувати датасет MovieLens 1M, конвертувати .datфайли у CSV.
Розгорнути Neo4j через Docker або зареєструватися в AuraDB.
Спроєктувати схему графа та обґрунтувати рішення — вузли, ребра, властивості.
Завантажити дані: створити індекси, завантажити вузли та ребра батчами.
Написати 6 Cypher-запитів зростаючої складності — від простих фільтрацій до рекомендацій і пошуку шляхів.
Знайти супервузли та пояснити їхній вплив на продуктивність.
Запустити три алгоритми GDS: PageRank, Louvain і Dijkstra — та змістовно інтерпретувати результати.
Порівняти графовий підхід з реляційним і зробити висновки.


Структура репозиторію

.
├── docker-compose.yml          # локальний запуск Neo4j
├── convert.py                  # конвертація .dat → .csv
├── import/                     # CSV-файли для завантаження (не комітьте самі .dat)
│   ├── movies.csv
│   ├── users.csv
│   └── ratings.csv
├── queries/
│   ├── part2_load.cypher       # створення індексів і завантаження даних
│   ├── part3.cypher            # всі запити частини 3
│   ├── part4_supernodes.cypher
│   └── part5_gds.cypher
└── README.md                   # відповіді на всі питання + скриншоти


# Neo4j - noSQL - Граф знань для рекомендаційної системи - Домашнє завдання

## 🔹 Частина 1 — проєктування схеми

Загальна ідея моделі

Метою графа є побудова рекомендаційної системи фільмів. 
Використуємо Query-first design: спрощення запитів про вподобання користувачів, популярність фільмів, схожість користувачів і жанрові рекомендації.

Датасет MovieLens 1M містить дані про користувачів, фільми та понад один мільйон записів. Кожна оцінка це оцінка користувача до фільмому і додатково містить значення рейтингу та час коли створена оцінка.

Для графа обираємо три типи вузлів:

**User** — користувач рекомендаційної системи;
**Movie** — фільм;
**Genre** — жанр фільму.

Між ними використовуються зв’язки:

**RATED** — користувач оцінив фільм;

**HAS_GENRE** — фільм належить до жанру.
```
(User { userId, gender, age, occupation, zipCode })
(Movie { movieId, title, year })
(Genre { name })

(User)-[:RATED { rating, timestamp }]->(:Movie)
(Movie)-[:HAS_GENRE]->(:Genre)
```

## Завантаження вузлів



## індекси:
```
CREATE CONSTRAINT user_id_unique IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE; 
CREATE CONSTRAINT movie_id_unique IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE; 
CREATE CONSTRAINT genre_name_unique IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;
```

## Завантаження ребер (оцінок)

Завантаження ребер RATED

Оцінки у ratings.csv: userId,movieId,rating,timestamp

Зв’язок: (:User)-[:RATED {rating, timestamp}]->(:Movie)

як зазначено в завданні для великої кількості оцінок використовуємо apoc.periodic.iterate - див part2_load.cypher


Два Cypher-запити:
дані:
LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
RETURN row
та передаєм кожен рядок з них у другий запит для обробки оцінок:

MATCH (u:User {userId: toInteger(row.userId)})
MATCH (m:Movie {movieId: toInteger(row.movieId)})
MERGE (u)-[r:RATED]->(m)
SET
    r.rating = toInteger(row.rating),
    r.timestamp = toInteger(row.timestamp)

використовуємо MATCH що знаходить вже створені вузли користувача та фільму по ID.

**parallel: false** означає, що батчі виконуються послідовно для того щоб безпечно додавати без блокування: паралельні транзакції можуть одночасно блокувати популярні фільми чи користувачів - більша стабільність і це є безпечним режимом за замовчуванням. 