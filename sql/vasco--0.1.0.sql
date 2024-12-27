-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION vasco" to load this file. \quitCREATE SCHEMA IF NOT EXISTS _vasco_internal;

/*
 * BASIC TYPES
 */
CREATE TYPE mine_problem AS
(
    n int,
    x float8[],
    y float8[]
);

/*
 This is not used yet,
 but going forward should be stored and used to compute the MINE statistics.
 */
CREATE TYPE mine_score AS
(
    n  int,
    m  int[],
    cm float8[][] -- the characteristic matrix
);

/*
 Convenience type to pack a set of relevant statistics.
 Going forward each one of these should be computed
 from a mine_score object.
 */
CREATE TYPE mine_statistics AS
(
    mic         float8,
    mas         float8,
    mev         float8,
    mcn         float8,
    mcn_general float8,
    tic         float8,
    gmic        float8
);

/*
 * Probably redundant
 * libmine uses this as a struct,
 * but in a PG context,
 * configuration is done through GUC variables.
 */
CREATE TYPE mine_parameter AS
(
    alpha float8,
    c     float8,
    est   int
);


/*
 * There are three ways to build a mine_problem:
 * from a (float8[], float8[]) tuple,
 * from a (vector, vector) tuple
 * from a (column, column) tuple (hence building a mine_problem incrementally and compute an aggregate function at the end)
 */
CREATE FUNCTION arrays_to_mine_problem(float8[], float8[]) RETURNS mine_problem AS
'MODULE_PATHNAME' LANGUAGE C IMMUTABLE
                             STRICT
                             PARALLEL SAFE;


CREATE FUNCTION compute_mine_statistics(mine_problem) RETURNS mine_statistics AS
'MODULE_PATHNAME' LANGUAGE C IMMUTABLE
                             STRICT
                             PARALLEL SAFE;


/*
 * f(float8[], float8[]) functions
 */

CREATE FUNCTION mic(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).mic' LANGUAGE sql IMMUTABLE
                STRICT
                PARALLEL SAFE;

CREATE FUNCTION mas(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).mas' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;
CREATE FUNCTION mev(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).mev' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;

CREATE FUNCTION mcn(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).mcn' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;

CREATE FUNCTION mcn_general(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).mcn_general' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;

CREATE FUNCTION tic(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).tic' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;

CREATE FUNCTION gmic(float8[], float8[]) RETURNS float8 AS
'SELECT (compute_mine_statistics(arrays_to_mine_problem($1, $2))).gmic' LANGUAGE sql IMMUTABLE
                                                                                    STRICT
                                                                                    PARALLEL SAFE;



/*
 * Aggregate functions
 */

CREATE FUNCTION _compute_mine_statistics_f8_f8(float8[], float8[])
    RETURNS mine_statistics
AS
$$
SELECT compute_mine_statistics((ARRAY_LENGTH($1, 0), $1, $2));
$$
    LANGUAGE sql
    IMMUTABLE
    STRICT
    PARALLEL SAFE;

CREATE FUNCTION _agg_compute_mine_score_trans(p mine_problem, x_i float8, y_i float8)
    RETURNS mine_problem AS
$$
-- Not sure if this makes a performance difference because it's in SQL instaed of C; Should investigate
SELECT (p.n + 1, ARRAY_APPEND(p.x, x_i), ARRAY_APPEND(p.y, y_i))::mine_problem
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE FUNCTION _agg_compute_mine_score_final(p mine_problem)
    RETURNS mine_statistics AS
$$
SELECT _compute_mine_statistics_f8_f8(p.x, p.y)
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE agg_compute_mine_statistics (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mine_score_final
    );


CREATE FUNCTION _agg_compute_mic_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).mic
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE mic (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mic_final
    );

CREATE FUNCTION _agg_compute_mas_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).mas
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE mas (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mas_final
    );

CREATE FUNCTION _agg_compute_mev_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).mev
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE mev (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mev_final
    );

CREATE FUNCTION _agg_compute_mcn_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).mcn
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE mcn (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mcn_final
    );

CREATE FUNCTION _agg_compute_mcn_general_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).mcn_general
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE mcn_general (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_mcn_general_final
    );

CREATE FUNCTION _agg_compute_tic_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).tic
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE tic (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_tic_final
    );

CREATE FUNCTION _agg_compute_gmic_final(p mine_problem)
    RETURNS float8 AS
$$
SELECT (_compute_mine_statistics_f8_f8(p.x, p.y)).gmic
$$
    LANGUAGE sql
    IMMUTABLE
    PARALLEL SAFE;

CREATE AGGREGATE gmic (float8, float8)(
    SFUNC = _agg_compute_mine_score_trans,
    STYPE = mine_problem,
    INITCOND = '(0, {}, {})',
    FINALFUNC = _agg_compute_gmic_final
    );
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

