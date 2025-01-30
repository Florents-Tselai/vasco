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

#ifndef VASCO_H

#define VASCO_VERSION "0.1.0"

#define VASCO_H

#include "postgres.h"
#include "fmgr.h"
#include "utils/array.h"
#include "utils/arrayaccess.h"
#include "utils/guc.h"
#include "funcapi.h"
#include "mine.h"

#include "limits.h"

void _PG_init(void);

void _PG_fini(void);

void mine_free_prob(mine_problem *prob);

void build_str_characteristic_matrix(mine_score *score, StringInfo *str);

static void build_mine_problem(ArrayType *arg0,
                               bool null_arg0,
                               ArrayType *arg1,
                               bool null_arg1,
                               mine_problem *ret_prob);

static void build_mine_param(mine_parameter *param);

int *argsort(double *a, int n);

#endif