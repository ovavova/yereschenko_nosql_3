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

# 🔹 Частина 1 — проєктування схеми

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

![image alt](https://github.com/ovavova/yereschenko_nosql_3/blob/main/screenshots4readme/load_movies.png)

![image alt](https://github.com/ovavova/yereschenko_nosql_3/blob/main/screenshots4readme/load_ratings.png)

![image alt](https://github.com/ovavova/yereschenko_nosql_3/blob/main/screenshots4readme/load_users.png)
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


#Частина 3 — Запити різної складності




## Що означає довжина шляху?

Один хоп — це один перехід по ребру RATED. RATED з’єднує User і Movie, шлях між двома користувачами завжди має парну довжину.

Шлях довжини 2
User 1 → Movie ← User 2 Це означає, що обидва користувачі оцінили один і той самий фільм. Це - найближчй зв’язком між двома користувачами в нашій моделі.

Шлях довжини 4
User 1 → Movie A ← User 3 → Movie B ← User 2

користувачі User 1 і User 3 оцінили Movie A;
користувачі User 3 і User 2 оцінили Movie B.

User 3 виступає проміжним користувачем, який пов’язує початкових користувачів через два фільми.

Шлях довжини 6
User 1 → Movie A ← User 3
       → Movie B ← User 4
       → Movie C ← User 2

Тут три фільми, два користувачі та шість ребер RATED.

# Частина 4 — Виявлення супервузлів

## Результат 5.1
```
movieId, title, pageRank
2858, "American Beauty (1999)", 9.702536
260, "Star Wars: Episode IV - A New Hope (1977)", 9.138237
1196, "Star Wars: Episode V - The Empire Strikes Back (1980)", 9.10252
1198, "Raiders of the Lost Ark (1981)", 7.940092
608, "Fargo (1996)", 7.031726
593, "Silence of the Lambs, The (1991)", 6.714389
858, "Godfather, The (1972)", 6.314397
318, "Shawshank Redemption, The (1994)", 6.294661
2571, "Matrix, The (1999)", 6.286031
2762, "Sixth Sense, The (1999)", 6.245582
2028, "Saving Private Ryan (1998)", 6.025807
1270, "Back to the Future (1985)", 5.802377
1210, "Star Wars: Episode VI - Return of the Jedi (1983)", 5.601634
527, "Schindler's List (1993)", 5.578541
1197, "Princess Bride, The (1987)", 5.464214
589, "Terminator 2: Judgment Day (1991)", 5.45045
1617, "L.A. Confidential (1997)", 5.410687
296, "Pulp Fiction (1994)", 5.403263
110, "Braveheart (1995)", 4.961585
1240, "Terminator, The (1984)", 4.841094
```

**Що означає високий PageRank для фільму в цьому графі? Це просто “популярний фільм” чи щось інше?**
Перші фільми співпали з supernodes, оскільки популярні фільми зазвичай мають багато зв’язків. Але списки - різні: google page rank оцінює важливість кожної сторінки на основі кількості та якості зовнішніх посилань, що на неї ведуть.
За результатами найбільш центральним фільмом став American Beauty (1999), за ним розташувалися дві частини Star Wars. Це означає, що вони пов’язані з великою кількістю інших фільмів через спільну аудиторію з високими оцінками.

### 5.2 Louvain 

communityId, usersCount, topGenres
5099, 238, [{genre: "Drama", highRatings: 26375}, {genre: "Comedy", highRatings: 18136}, {genre: "Action", highRatings: 11846}]
5681, 200, [{genre: "Comedy", highRatings: 22244}, {genre: "Drama", highRatings: 20130}, {genre: "Action", highRatings: 17682}]
4168, 132, [{genre: "Drama", highRatings: 19528}, {genre: "Comedy", highRatings: 14120}, {genre: "Romance", highRatings: 6529}]
1697, 83, [{genre: "Drama", highRatings: 13794}, {genre: "Comedy", highRatings: 11489}, {genre: "Action", highRatings: 6563}]
2, 1, [{genre: "Adventure", highRatings: 21}, {genre: "Comedy", highRatings: 19}, {genre: "Action", highRatings: 18}]
4, 1, [{genre: "Drama", highRatings: 42}, {genre: "Comedy", highRatings: 29}, {genre: "Thriller", highRatings: 13}]
5, 1, [{genre: "Romance", highRatings: 25}, {genre: "Comedy", highRatings: 21}, {genre: "Musical", highRatings: 16}]
6, 1, [{genre: "Action", highRatings: 24}, {genre: "Thriller", highRatings: 14}, {genre: "Sci-Fi", highRatings: 9}]
7, 1, [{genre: "Drama", highRatings: 62}, {genre: "Action", highRatings: 23}, {genre: "Romance", highRatings: 22}]
8, 1, [{genre: "Drama", highRatings: 36}, {genre: "Comedy", highRatings: 19}, {genre: "Thriller", highRatings: 18}]

**Чи відповідають отримані кластери інтуїтивним групам (наприклад, «любителі бойовиків», «цінителі арт-хаусу»)?**
так - найбільші групи любителів драми, комедій, action бойовиків


**Як ви це перевірили?**
Для кожного communityId підраховувалася кількість високих оцінок для кожного жанру.
Після цього жанрові профілі спільнот порівнювалися між собою. Наприклад:

спільнота 5681 має більшу орієнтацію на Comedy та Action;
спільнота 4168 відрізняється появою Romance;
спільноти 5099 і 1697 мають схожий профіль Drama–Comedy–Action.
### 5.3

graphName, nodeCount, relationshipCount
"userGraph", 6040, 20000

**Наскільки «тісний світ» у цьому датасеті? Спробуйте кілька пар користувачів.**

**Яка середня довжина шляху? Чи підтверджується гіпотеза «шести рукостискань»**


# 🔹 Частина 6 — Аналіз і висновки


## 1. Граф vs SQL. Які із запитів частини 3 було б складно або неможливо написати в SQL? Чому? Наведіть конкретний приклад — покажіть, як виглядав би еквівалентний SQL-запит (або поясніть, чому його не існує).

Усі запити з частини мабуть теоретично можна реалізувати в реляційній базі даних. 
Складні і багатокрокові рекомендації та пошук шляхів у SQL можуть стати найскладнішими, такі як найкоротший шлях та користувачі зі схожими смаками з великою кількісттю join таблиць.

## 2. Де граф програє? Для яких задач із цим датасетом реляційна модель підійшла б краще? Наприклад: агрегація по всіх користувачах, звіти, експорт даних.

Реляційна модель краще підходила б для задач, у яких запити використовують повні сканування агрегації та звітність, як середній рейтинг, кількість оцінок за кожним значенням - гістограма, звіти по часовим періодам, тощо

Neo4j — для рекомендацій, шляхів, схожості та графових алгоритмів;
реляційна база або data warehouse — для агрегацій, звітності й експорту.

## 3. Покращення схеми. Які зміни в схемі прискорили б конкретні запити з частини 3? Розгляньте хоча б два запити.

Запит 1 обчислює середній рейтинг для кожного фільму жанру Thriller: Genre ← Movie ← RATED

Проходить кожен раз по всім оцінкам фільмів і повторно виконує avg() і count().

Для прискорення можна денормалізувати і додати  avg() і count() у вузлі Movie:

(:Movie {
    averageRating,
    ratingsCount
})

Це суттєво прискорює часті запити, але потребує оновлення агрегатів після зміни оцінок.

**Покращення запиту 4**

Запит 4 кожного разу проходить: Genre ← Movie ← User
і повторно обчислює:

кількість фільмів;
кількість оцінок;
середній рейтинг.

Для популярних жанрів це означає обхід великої кількості ребер.

Можна зберегти ці дані безпосередньо у  Genre:

(:Genre {
    movieCount,
    ratingCount,
    averageRating
})