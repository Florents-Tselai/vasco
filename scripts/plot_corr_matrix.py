#!/usr/bin/env python3

import pandas as pd
import seaborn as sns
from sys import argv
from sqlalchemy import create_engine
import matplotlib.pyplot as plt


def main():
    try:
        schema_name, table_name = argv[1].split('.')
    except IndexError:
        raise ValueError("Input table should be provided in the format <schema>.<table>")

    engine = create_engine('postgresql+psycopg2://')
    df = pd.read_sql_table(table_name, engine, schema_name, index_col='col')
    df.sort_index(level=0, axis=0, ascending=True, inplace=True)
    df.sort_index(level=0, axis=1, ascending=True, inplace=True)

    heatmap_plot = sns.heatmap(df, annot=False, cmap="YlOrBr")
    heatmap_plot.set_title(f"{schema_name}.{table_name}")
    fig = heatmap_plot.get_figure()

    plt.tight_layout()
    out_fname = f"{schema_name}.{table_name}_heatmap.png"

    fig.savefig(out_fname, dpi=800)
    print(f"Heatmap saved under {out_fname}")


if __name__ == '__main__':
    main()
