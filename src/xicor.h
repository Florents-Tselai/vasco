#ifndef _LIBXICOR_H
#define _LIBXICOR_H

#include "mine.h"

#define LIBXICOR_VERSION "1.0.0"

extern char *libxicor_version;

typedef struct xicor_problem
{
    int n;
    double *x;
    double *y;
} xicor_problem;

typedef struct xicor_parameter {
  int seed;
  int ties; /* bool */
} xicor_parameter;

typedef struct xicor_score
{
    double score;
} xicor_score;

xicor_score *xicor_compute_score(xicor_problem *prob, xicor_parameter *param);

#endif