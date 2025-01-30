/*
* Libxicor core library.
 *
 * This code is written by Florents Tselai <florents.tselai@gmail.com> .
 *
 * Copyright (C) 2014 Florents Tselai.
 *
 * References:
 *   * Original xicor paper: DOI: https://doi.org/10.1080/01621459.2020.1758115;
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

#include "xicor.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "vasco.h"

char* libxicor_version = LIBXICOR_VERSION;

xicor_score* xicor_compute_score(xicor_problem* prob, xicor_parameter* param)
{
    if (!prob || !prob->x || !prob->y || prob->n <= 0)
    {
        fprintf(stderr, "Invalid input to xicor_compute_score\n");
        return NULL;
    }

    int n = prob->n;
    double* x = prob->x;
    double* y = prob->y;
    int ties = param->ties;

    /* Initialize the random seed */
    srand(param->seed);

    /* Get the sorted order of x using argsort */
    int* order = argsort(x, n);
    if (!order)
    {
        fprintf(stderr, "Memory allocation failed for order array\n");
        return NULL;
    }

    /* Compute the rank arrays l and r */
    int* l = (int*)malloc(n * sizeof(int));
    int* r = (int*)malloc(n * sizeof(int));
    if (!l || !r)
    {
        fprintf(stderr, "Memory allocation failed for rank arrays\n");
        free(order);
        return NULL;
    }

    for (int i = 0; i < n; i++)
    {
        l[i] = 0;
        for (int j = 0; j < n; j++)
        {
            if (y[order[j]] >= y[order[i]])
            {
                l[i]++;
            }
        }
        r[i] = l[i];
    }

    /* Handle ties if required */
    if (ties)
    {
        for (int i = 0; i < n; i++)
        {
            int tie_count = 0;
            for (int j = 0; j < n; j++)
            {
                if (r[j] == r[i]) tie_count++;
            }
            if (tie_count > 1)
            {
                int* tie_indices = (int*)malloc(tie_count * sizeof(int));
                if (!tie_indices)
                {
                    fprintf(stderr, "Memory allocation failed for tie indices\n");
                    free(order);
                    free(l);
                    free(r);
                    return NULL;
                }

                int k = 0;
                for (int j = 0; j < n; j++)
                {
                    if (r[j] == r[i])
                    {
                        tie_indices[k++] = j;
                    }
                }

                for (int k = 0; k < tie_count; k++)
                {
                    r[tie_indices[k]] = r[tie_indices[k]] - k;
                }

                free(tie_indices);
            }
        }
    }

    /* Compute the Xi correlation score */
    double sum_l = 0.0, sum_r_diff = 0.0;
    for (int i = 0; i < n; i++)
    {
        sum_l += l[i] * (n - l[i]);
    }
    for (int i = 1; i < n; i++)
    {
        sum_r_diff += abs(r[i] - r[i - 1]);
    }

    double score;
    if (ties)
    {
        score = 1.0 - (n * sum_r_diff) / (2.0 * sum_l);
    }
    else
    {
        score = 1.0 - (3.0 * sum_r_diff) / ((double)(n * n - 1));
    }

    /* Create the result structure */
    xicor_score* result = (xicor_score*)malloc(sizeof(xicor_score));
    if (!result)
    {
        fprintf(stderr, "Memory allocation failed for result\n");
        free(order);
        free(l);
        free(r);
        return NULL;
    }
    result->score = score;

    /* Free allocated memory */
    free(order);
    free(l);
    free(r);

    return result;
}
