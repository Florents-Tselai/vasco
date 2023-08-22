CREATE FUNCTION vectors_to_mine_problem(vector, vector) RETURNS mine_problem AS
'SELECT arrays_to_mine_problem($1::real[]::float8[], $1::real[]::float8[])'
    LANGUAGE sql IMMUTABLE
                 STRICT
                 PARALLEL SAFE;


/*
 * f(vector, vector) functions
 */

CREATE FUNCTION mic(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).mic' LANGUAGE sql IMMUTABLE
                                                                                     STRICT
                                                                                     PARALLEL SAFE;

CREATE FUNCTION mas(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).mas' LANGUAGE sql IMMUTABLE
                                                                                     STRICT
                                                                                     PARALLEL SAFE;
CREATE FUNCTION mev(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).mev' LANGUAGE sql IMMUTABLE
                                                                                     STRICT
                                                                                     PARALLEL SAFE;

CREATE FUNCTION mcn(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).mcn' LANGUAGE sql IMMUTABLE
                                                                                     STRICT
                                                                                     PARALLEL SAFE;

CREATE FUNCTION mcn_general(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).mcn_general' LANGUAGE sql IMMUTABLE
                                                                                             STRICT
                                                                                             PARALLEL SAFE;

CREATE FUNCTION tic(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).tic' LANGUAGE sql IMMUTABLE
                                                                                     STRICT
                                                                                     PARALLEL SAFE;

CREATE FUNCTION gmic(vector, vector) RETURNS float8 AS
'SELECT (compute_mine_statistics(vectors_to_mine_problem($1, $2))).gmic' LANGUAGE sql IMMUTABLE
                                                                                      STRICT
                                                                                      PARALLEL SAFE;