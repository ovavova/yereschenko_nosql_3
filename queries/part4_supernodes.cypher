
// Частина 4 — Виявлення супервузлів

MATCH (n)
WITH n, COUNT { (n)--() } AS degree
WHERE degree > 100
RETURN
    labels(n) AS labels,
    coalesce(n.name, n.title, toString(n.userId)) AS node,
    degree
ORDER BY degree DESC
LIMIT 20;


// Топ-20 вузлів за кількістю зв'язків.

MATCH (n)
WITH n, COUNT { (n)--() } AS degree
RETURN
    labels(n) AS labels,
    coalesce(n.name, n.title, toString(n.userId)) AS node,
    degree
ORDER BY degree DESC
LIMIT 20;

