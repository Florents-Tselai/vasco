/*

These is the explore API.
It provides function exposing "bulk exploration" between tables (or relations in general).

Here's how the process works
     Given a regclass $1:
     Filter the column types we support / are interested in
     and store them in an array.

     Iterate over all possible pairs of columns and
     compute the statistics; possible cache them too

*/


-- Returns 2-pairs from array (with no repetition)

CREATE OR REPLACE FUNCTION vasco_array_pairs(anyarray, OUT p1 anyelement, OUT p2 anyelement)
    RETURNS setof record
    LANGUAGE sql AS
$$
WITH d AS (SELECT ROW_NUMBER() OVER () AS row, e AS v
           FROM UNNEST($1) e)
SELECT d1.v AS p1, d2.v AS p2
FROM d d1
         CROSS JOIN d d2
WHERE d1.row >= d2.row;
$$;


/*
 Given an input table, explores all the column pairs for their MINE statistics.
 Returns a table describing those results.
 Ideally the returned table should have fixed schema / columns but dunno it yet.
 */
CREATE OR REPLACE FUNCTION vasco_explore(regclass)
    RETURNS table
            (
                table_schema  text,
                table_name    text,
                column_name_1 text,
                column_name_2 text,
                mine_prob     mine_problem,
                mine_stats    mine_statistics,
                solved_in     interval
            )
    LANGUAGE plpgsql
    VOLATILE
    PARALLEL SAFE
AS
$$

DECLARE
    cols            text[];
    col_types       text[];
    tabname ALIAS FOR $1;
    var_pair        record;
    mine_prob_n     int;
    mine_prob_x     float8[];
    mine_prob_y     float8[];
    prob_size_limit int DEFAULT NULL; /* maybe at some point we'll want to limit prob_n or sample randomly */
    time_start      timestamp;
    relnamespace    text;
    relname         text;
    i               int;
    num_cols        int;
    num_pairs       int;
BEGIN

    --TODO: make this a param ?
    col_types := ARRAY ['int2', 'int4', 'int8', 'float4', 'float8', 'numeric'];

    --TODO: merge these two queries
    EXECUTE 'SELECT relnamespace::regnamespace::text, relname::text
        FROM pg_class
        WHERE oid = $1' INTO relnamespace, relname USING tabname;

    RAISE NOTICE 'relnamespace is % \t relname is %', relnamespace, relname;


    EXECUTE FORMAT('SELECT ARRAY_AGG(attname)
                 FROM pg_attribute a
                          JOIN pg_type t ON a.atttypid = t.oid
                 WHERE attrelid = $1
                   AND attnum > 0
                   AND NOT attisdropped
                   AND t.typname = ANY ($2) limit 2')
        INTO cols USING tabname, col_types;

    num_cols = ARRAY_LENGTH(cols, 1);
    num_pairs = (num_cols * (num_cols - 1)) / 2; /* n*(n-1)/2 */

    RAISE NOTICE 'vasco is about to explore % variable pairs', num_pairs;

    i = 0;
    FOR var_pair IN
        SELECT * FROM vasco_array_pairs(cols)
        LOOP
            i = i + 1;
            RAISE NOTICE 'exploring pair % out of %', i, num_pairs;

            /* Build a mine problem for this var pair,
               by aggregating their values in a float8[] array.
            */
            EXECUTE FORMAT('SELECT array_agg(%I), array_agg(%I) FROM %I.%I',
                           var_pair.p1,
                           var_pair.p2,
                           relnamespace,
                           relname
                ) INTO mine_prob_x, mine_prob_y;

            mine_prob_n := ARRAY_LENGTH(mine_prob_x, 1);
            mine_prob := ROW (mine_prob_n, mine_prob_x, mine_prob_y)::mine_problem;

            /* Solve the problem */
            time_start := CLOCK_TIMESTAMP();

            mine_stats = compute_mine_statistics(mine_prob);

            solved_in = CLOCK_TIMESTAMP() - time_start;

            table_schema = relnamespace::text;
            table_name = relname::text;
            column_name_1 = var_pair.p1;
            column_name_2 = var_pair.p2;

            RETURN NEXT;

        END LOOP;
    RETURN;
END;
$$;


CREATE FUNCTION vasco_corr_matrix(regclass, text) RETURNS void
    LANGUAGE plpgsql AS
$$
DECLARE
    r record;
    out_table_name ALIAS FOR $2;
BEGIN


    EXECUTE FORMAT('CREATE TABLE %I
        (
            col text primary key
        )', out_table_name);

    FOR r IN SELECT *
             FROM vasco_explore($1)
             ORDER BY column_name_1, column_name_2
        LOOP
            /* That's a lot of ALTER / INSERT / UPDATE to execute in separate queries.
               Will need to refactor by putting everything in a single query.
               Keep it cleaner for now though.
               */
            EXECUTE FORMAT('ALTER TABLE %I ADD COLUMN IF NOT EXISTS %I float8', out_table_name, r.column_name_1);
            EXECUTE FORMAT('ALTER TABLE %I ADD COLUMN IF NOT EXISTS %I float8', out_table_name, r.column_name_2);

            EXECUTE FORMAT('INSERT INTO %I(col) VALUES (%L) ON CONFLICT DO NOTHING;', out_table_name,
                           r.column_name_1);
            EXECUTE FORMAT('INSERT INTO %I(col) VALUES (%L) ON CONFLICT DO NOTHING;', out_table_name,
                           r.column_name_2);

            EXECUTE FORMAT('UPDATE %I SET %I = %L WHERE col=%L ;', out_table_name, r.column_name_1,
                           (r.mine_stats).mic, r.column_name_2);

            EXECUTE FORMAT('ALTER TABLE %I ADD COLUMN IF NOT EXISTS %I float8', out_table_name, r.column_name_2);

            EXECUTE FORMAT('UPDATE %I SET %I = %L WHERE col=%L ;', out_table_name, r.column_name_2,
                           (r.mine_stats).mic, r.column_name_1);

        END LOOP;
END

$$;

