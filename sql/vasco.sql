-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION vasco" to load this file. \quit

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
