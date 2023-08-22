/*
 * This code is written by Florents Tselai <florents@tselai.com>.
 *
 * Copyright (C) 2023 Florents Tselai
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "vasco.h"

PG_MODULE_MAGIC;

/* GUC variables */

/* MINE params */

#define MINE_DEFAULT_ALPHA 0.6
#define MINE_DEFAULT_C 15
#define MINE_DEFAULT_MCN_EPS 0.
#define MINE_DEFAULT_TIC_NORM TRUE
#define MINE_DEFAULT_GMIC_P 0.

static double guc_mine_c = MINE_DEFAULT_C;
static double guc_mine_alpha = MINE_DEFAULT_ALPHA;
static int guc_mine_estimator = EST_MIC_APPROX;
static double guc_mine_mcn_eps = MINE_DEFAULT_MCN_EPS;
static bool guc_mine_tic_norm = MINE_DEFAULT_TIC_NORM;
static double guc_mine_gmic_p = MINE_DEFAULT_GMIC_P;


static const struct config_enum_entry mic_estimator_options[] = {
        {"ApproxMIC", EST_MIC_APPROX, false},
        {"MIC_e",     EST_MIC_E,      false}
};

/* Startup */
void _PG_init(void) {

    /*
     * TODO: check params with hooks instead of letting them slip into mine_check_parameter
     */

    DefineCustomRealVariable("vasco.mine_c",
                             "MINE c variable",
                             NULL,
                             &guc_mine_c,
                             MINE_DEFAULT_C,
                             0.0,
                             INFINITY,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL
    );

    DefineCustomRealVariable("vasco.mine_alpha",
                             "MINE alpha variable",
                             NULL,
                             &guc_mine_alpha,
                             MINE_DEFAULT_ALPHA,
                             0.0,
                             INFINITY,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL
    );

    DefineCustomEnumVariable("vasco.mic_estimator",
                             "Algo to use for the estimator. Available are: ApproxMIC or MIC_e",
                             NULL,
                             &guc_mine_estimator,
                             EST_MIC_APPROX,
                             mic_estimator_options,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL
    );

    DefineCustomRealVariable("vasco.mine_mcn_eps",
                             "MINE eps used for mcn",
                             NULL,
                             &guc_mine_mcn_eps,
                             MINE_DEFAULT_MCN_EPS,
                             0.0,
                             INFINITY,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL
    );

    DefineCustomBoolVariable("vasco.mine_tic_norm",
                             "MINE normalize for TIC",
                             NULL,
                             &guc_mine_tic_norm,
                             MINE_DEFAULT_TIC_NORM,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL);

    DefineCustomRealVariable("vasco.mine_gmic_p",
                             "MINE p used for gmic",
                             NULL,
                             &guc_mine_gmic_p,
                             MINE_DEFAULT_GMIC_P,
                             0.0,
                             INFINITY,
                             PGC_SUSET,
                             0,
                             NULL,
                             NULL,
                             NULL
    );

}

/* Tear-down */
void _PG_fini(void) {
    elog(NOTICE, "Goodbye from vasco %s", VASCO_VERSION);
}

void build_str_characteristic_matrix(mine_score *score, StringInfo *str) {
    /* print the characteristic matrix M */

    int i, j;
    appendStringInfoString(*str, "\n=== BEGIN Characteristic Matrix ===\n\n");
    for (i = 0; i < score->n; i++) {
        for (j = 0; j < score->m[i]; j++)
            appendStringInfo(*str, "%.3lf ", score->M[i][j]);
        appendStringInfoString(*str, "\n");
    }
    appendStringInfoString(*str, "\n=== END Characteristic Matrix ===\n");

}

static void build_mine_problem(ArrayType *arg0,
                               bool null_arg0,
                               ArrayType *arg1,
                               bool null_arg1,
                               mine_problem *ret_prob) {
    ArrayIterator iter0, iter1;
    int i;
    Datum x_value, y_value;

    ret_prob->n = ArrayGetNItems(ARR_NDIM(arg0), ARR_DIMS(arg0));
    //TODO: check that both arrays are of the same size
    ret_prob->x = (double *) palloc(ret_prob->n * sizeof(double));
    ret_prob->y = (double *) palloc(ret_prob->n * sizeof(double));

    /* populate prob.x and prob.y arrays */
    iter0 = array_create_iterator(arg0, 0, NULL);
    i = 0;
    while (array_iterate(iter0, &x_value, &null_arg0)) {
        ret_prob->x[i] = DatumGetFloat8(x_value);
        i++;
    }
    array_free_iterator(iter0);

    iter1 = array_create_iterator(arg1, 0, NULL);
    i = 0;
    while (array_iterate(iter1, &y_value, &null_arg1)) {
        ret_prob->y[i] = DatumGetFloat8(y_value);
        i++;
    }
    array_free_iterator(iter1);
}


static void build_mine_param(mine_parameter *param) {
    char *check_ret;

    param->alpha = guc_mine_alpha;
    param->c = guc_mine_c;
    param->est = guc_mine_estimator;

    /* check the parameters */
    check_ret = mine_check_parameter(param);
    if (check_ret)
        elog(ERROR, "ERROR: not valid MINE params %s\n\n", check_ret);
}

void mine_free_prob(mine_problem *prob) {
    pfree(prob->x);
    pfree(prob->y);
}

PG_FUNCTION_INFO_V1(arrays_to_mine_problem);

Datum
arrays_to_mine_problem(PG_FUNCTION_ARGS) {

    /* Input */
    ArrayType *arg0 = PG_GETARG_ARRAYTYPE_P(0);
    ArrayType *arg1 = PG_GETARG_ARRAYTYPE_P(1);

    int n0;
    int n1;

    n0 = ArrayGetNItems(ARR_NDIM(arg0), ARR_DIMS(arg0));
    n1 = ArrayGetNItems(ARR_NDIM(arg1), ARR_DIMS(arg1));

    if (n0 != n1)
        ereport(ERROR,
                (errcode(ERRCODE_DATA_EXCEPTION),
                        errmsg("different number of elements in arrays %d and %d", n0, n1)));


    /* Output */
    TupleDesc resultTupleDesc;
    HeapTuple resultTuple;
    Datum result;
    Datum result_values[3];
    bool result_is_null[3];

    result_values[0] = n0;
    result_values[1] = PG_GETARG_DATUM(0);
    result_values[2] = PG_GETARG_DATUM(1);

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        result_is_null[0] = TRUE;
    else
        result_is_null[0] = FALSE;

    result_is_null[1] = PG_ARGISNULL(0);
    result_is_null[2] = PG_ARGISNULL(1);

    /* Build result tuple */
    get_call_result_type(fcinfo, NULL, &resultTupleDesc);
    BlessTupleDesc(resultTupleDesc);

    resultTuple = heap_form_tuple(resultTupleDesc, result_values, result_is_null);

    result = HeapTupleGetDatum(resultTuple);

    PG_RETURN_DATUM(result);
}

PG_FUNCTION_INFO_V1(compute_mine_statistics);

Datum
compute_mine_statistics(PG_FUNCTION_ARGS) {

    /* Input */
    HeapTupleHeader problem = PG_GETARG_HEAPTUPLEHEADER(0);
    Datum n, x, y;
    bool n_isnull, x_isnull, y_isnull;

    /* Computation */
    mine_problem prob;
    mine_parameter param;
    mine_score *score;

    /* Characteristic Matrix print */
    StringInfo str_char_matrix;

    /* Output */
    TupleDesc resultTupleDesc;
    HeapTuple resultTuple;
    Datum result;
    Datum result_values[7];
    bool result_is_null[7];



    n = GetAttributeByName(problem, "n", &n_isnull);
    x = GetAttributeByName(problem, "x", &x_isnull);
    y = GetAttributeByName(problem, "y", &y_isnull);

    /* set the parameters */
    build_mine_param(&param);

    /* build the problem */
    build_mine_problem(DatumGetArrayTypeP(x), x_isnull, DatumGetArrayTypeP(y), y_isnull, &prob);

    /* compute_score */
    score = mine_compute_score(&prob, &param);

    if (score == NULL) {
        elog(ERROR, "ERROR: mine_compute_score()\n");
        PG_RETURN_NULL();
    }

    /* Log characteristic matrix */
    str_char_matrix = makeStringInfo();
    build_str_characteristic_matrix(score, &str_char_matrix);

    /* Build result tuple */
    get_call_result_type(fcinfo, NULL, &resultTupleDesc);
    BlessTupleDesc(resultTupleDesc);

    result_values[0] = Float8GetDatum(mine_mic(score));
    result_values[1] = Float8GetDatum(mine_mas(score));
    result_values[2] = Float8GetDatum(mine_mev(score));
    result_values[3] = Float8GetDatum(mine_mcn(score, guc_mine_mcn_eps));
    result_values[4] = Float8GetDatum(mine_mcn_general(score));
    result_values[5] = Float8GetDatum(mine_tic(score, guc_mine_tic_norm));
    result_values[6] = Float8GetDatum(mine_gmic(score, guc_mine_gmic_p));

    /* TODO: maybe really check these ? */
    result_is_null[0] = false;
    result_is_null[1] = false;
    result_is_null[2] = false;
    result_is_null[3] = false;
    result_is_null[4] = false;
    result_is_null[5] = false;
    result_is_null[6] = false;

    resultTuple = heap_form_tuple(resultTupleDesc, result_values, result_is_null);

    result = HeapTupleGetDatum(resultTuple);

    /* free score */
    mine_free_score(&score);
    /* free problem */
    mine_free_prob(&prob);

    /* free char matrix text */
    pfree(str_char_matrix->data);

    PG_RETURN_DATUM(result);

}
