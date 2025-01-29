-- Q1.1: View A
CREATE VIEW V_POPULAR_GENRES AS
SELECT W.genre, COUNT(*) AS total_events
FROM Events E
JOIN Items I ON E.item_id = I.item_id
JOIN Works W ON I.isbn = W.isbn
WHERE E.event_type IN ('Loan', 'Hold')
GROUP BY W.genre
ORDER BY total_events DESC
LIMIT 5;

-- Q1.1: View B
CREATE VIEW V_COSTS_INCURRED AS
WITH ChargeableEvents AS (
    SELECT 
        E.patron_id, 
        E.charge, 
        E.time_stamp
    FROM 
        EVENTS E
    WHERE 
        E.charge > 0
        AND E.event_type = 'Loss'
        AND E.time_stamp BETWEEN '2024-01-01 00:00:00' AND '2024-06-30 23:59:59'
),
RankedCharges AS (
    SELECT 
        C.patron_id, 
        SUM(C.charge) AS total_charges,
        ROW_NUMBER() OVER (ORDER BY SUM(C.charge) DESC) AS rank
    FROM 
        ChargeableEvents C
    GROUP BY 
        C.patron_id
)
SELECT 
    patron_id, 
    total_charges
FROM 
    RankedCharges
WHERE 
    rank <= 5;


-- Q1.3: Materialised view
CREATE MATERIALIZED VIEW MV_COSTS_INCURRED AS
WITH ChargeableEvents AS (
    SELECT E.patron_id, E.charge, E.time_stamp
    FROM EVENTS E
    WHERE E.charge > 0
    AND E.event_type = 'Loss'
    AND E.time_stamp BETWEEN '2024-01-01 00:00:00' AND '2024-06-30 12:59:59'
)
SELECT C.patron_id, SUM(C.charge) AS total_charges
FROM ChargeableEvents C
GROUP BY C.patron_id
ORDER BY total_charges DESC
LIMIT 5;

-- Q2.1 Basic index 
EXPLAIN SELECT * FROM V_POPULAR_GENRES;
CREATE INDEX IDX_EVENT_ITEM ON EVENTS (event_type, item_id);
EXPLAIN SELECT * FROM V_POPULAR_GENRES;

-- Q2.2 Function-based index
CREATE OR REPLACE FUNCTION get_surname(author_name TEXT) 
RETURNS TEXT AS $$
BEGIN
    RETURN (regexp_split_to_array(author_name, ' '))[array_length(regexp_split_to_array(author_name, ' '), 1)];
END;
$$ LANGUAGE plpgsql;

-- 1
WITH name_parts AS (
    SELECT 
        author,
        get_surname(author) AS surname
    FROM 
        WORKS
)
SELECT 
    author,
    surname
FROM 
    name_parts;


-- 2 
EXPLAIN WITH name_parts AS (
    SELECT 
        author,
        get_surname(author) AS surname
    FROM 
        WORKS
)
SELECT 
    author,
    surname
FROM 
    name_parts;


-- 3
CREATE INDEX idx_author_surname ON WORKS (regexp_split_to_array(author, ' ')[array_length(regexp_split_to_array(author, ' '), 1)]);

-- 4
EXPLAIN WITH name_parts AS (
    SELECT 
        author,
        regexp_split_to_array(author, ' ') AS parts
    FROM 
        WORKS
)
SELECT 
    author,
    parts,
    parts[array_length(parts, 1)] AS surname
FROM 
    name_parts;

-- Q3 Indexes and query planning
SET enable_seqscan = ON;
SET enable_indexscan = ON;

EXPLAIN SELECT * FROM Events WHERE event_id < 100;
EXPLAIN SELECT * FROM Events WHERE event_id >= 100;

SET enable_seqscan = OFF;
SET enable_indexscan = ON;

EXPLAIN SELECT * FROM Events WHERE event_id < 100;
EXPLAIN SELECT * FROM Events WHERE event_id >= 100;

SET enable_seqscan = ON;
SET enable_indexscan = OFF;

EXPLAIN SELECT * FROM Events WHERE event_id < 100;
EXPLAIN SELECT * FROM Events WHERE event_id >= 100;

-- Q4 Transactions
-- 1
BEGIN;
SELECT * FROM items WHERE status = 'available' LIMIT 1;

-- 2
BEGIN;
UPDATE items SET status = 'on_hold', hold_patron_id = 123, hold_until = now() + interval '14 days'
WHERE item_id = 1;
COMMIT;

-- 3
UPDATE items SET status = 'on_loan', loan_patron_id = 456, loan_date = now()
WHERE item_id = 1;
COMMIT;

