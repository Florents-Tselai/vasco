SET extra_float_digits = 0;

CREATE TABLE vasco_data
AS (SELECT RANDOM()                          AS rand_x,
           RANDOM()                          AS rand_y,
           x                                 AS x,
           x                                 AS ident,
           4 * pow(x, 3) + pow(x, 2) - 4 * x AS cubic,
           COS(12 * PI() + x * (1 + x))      AS periodic
    FROM GENERATE_SERIES(0, 1, 0.001) x);

select mic(x, ident) from vasco_data;