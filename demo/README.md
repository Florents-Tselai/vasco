# vasco: Discover Hidden Patterns in Postgres Data

In the world of data analysis, 
uncovering hidden patterns and relationships 
in your data can provide invaluable insights. 
Whether you're working with financial data, user behavior, or any other dataset,
understanding the underlying correlations can help in making informed decisions.

Imagine you're an analyst working with stock market data, specifically the S&P 500.
You want to understand how different stocks are correlated with each other to make better investment decisions.

While traditional methods like the Pearson correlation can give you some insight, 
they might miss more complex non-linear relationships.
This is where **vasco** comes into play—a powerful Postgres extension designed to help you 
discover hidden correlations in your data using advanced statistical methods.

## What is Vasco?

**Vasco** is a Postgres
extension that leverages the [Maximal Information Coefficient (MIC)](https://en.wikipedia.org/wiki/Maximal_information_coefficient) 
and other MINE statistics to uncover hidden patterns in your data. 
These statistics are designed to capture a wide range of functional and non-functional relationships between variables, 
making it easier to identify significant correlations that traditional methods might miss.

**Key Features of Vasco:**

- Detects complex relationships between variables using MIC.
- Provides a suite of MINE statistics for deeper analysis.
- Supports pgvector for computing statistics on vector types.
- Simple installation and configuration.

## Installation

Getting started with Vasco is straightforward. Here’s how you can install it:

```sh
cd /tmp
git clone git@github.com:Florents-Tselai/vasco.git
cd vasco
make all # WITH_PGVECTOR=1 to enable pgvector support
make install # may need sudo
```

Then, in a PostgreSQL session, run:

```sql
CREATE EXTENSION vasco;
```

## Example: Exploring Stock Correlations

Let’s dive into a practical example using stock price data from the S&P 500.

### Setting Up the Data

First, let's populate your PostgreSQL database with some stock price data. 
For this example, we'll use daily closing prices for several S&P 500 companies.
You can find a Postgres dump in the vasco repo and load it like this.

```sh
psql -f demo/stocks.sql postgres
```

Among other tables, 
this also creates a `v_sample` view containing daily closing prices 
for FAANG stocks (Facebook, Apple, Amazon, Netflix, Google) and a few other tickers.

### Calculating Correlations

With Vasco, you can easily compute the MIC for pairs of stocks to understand their correlation strength.

```sql
SELECT mic(aapl, nflx)  AS aapl_nflx,
       mic(aapl, googl) AS aapl_googl,
       mic(aapl, ba)    AS aapl_ba,
       mic(ba, pg)      AS ba_pg,
       mic(pg, gm)      AS pg_gm
FROM v_sample;
```

| aapl_nflx | aapl_googl | aapl_ba | ba_pg | pg_gm |
|:----------|:-----------|:--------|:------|:------|
| 0.51      | 0.80       | 0.55    | 0.48  | 0.32  |

From this, we can see that Apple's stock price has a strong correlation with Google's, 
while the correlation with Netflix is moderate. 
Procter & Gamble (PG) correlates weaker with Boeing (BA).

### Exploring All Stock Pairs

To exhaustively explore the correlations between all stock pairs in a relation, 
Vasco provides an easy way to do this in one go:

```sql
SELECT vasco_corr_matrix('v_faang', 'mic_v_faang');
```

This query computes the MIC for all column pairs in the `v_faang` 
relation (view in this case)
and stores the result in a new table `mic_v_faang`
(the appropriate table columns are fetched dynamically).

This table looks like a correlation matrix, normalized in [0,1].

| col   | aapl | meta | amzn | googl | nflx |
|-------|------|------|------|-------|------|
| aapl  | 1.00 | 0.63 | 0.51 | 0.81  | 0.52 |
| meta  | 0.63 | 1.00 | 0.72 | 0.64  | 0.80 |
| amzn  | 0.51 | 0.72 | 1.00 | 0.58  | 0.80 |
| googl | 0.81 | 0.64 | 0.58 | 1.00  | 0.47 |
| nflx  | 0.52 | 0.80 | 0.80 | 0.47  | 1.00 |

### Visualizing Correlations

Visualizing a correlation matrix with a heatmap can provide a clearer understanding. 
Here’s a plot of the correlation matrix as a heatmap,
with a `coolwarm` colormap.
The interpretation is:
The darker red a box is, the warmer / stronger the correlation between the pair is.
The darker blue a box is, the cooler / less strong the correlation between these stocks is.

Here's the heatmap for the above FAANG correlation matrix.

We can immediately spot, for example that NFLX is mostly correlated with META and AMZN,
rather with GOOGL.

![image](demo/img/faang_corr.png)

Here's the time series plot for these symbols:
Indeed, we can see that NFLX, META, and AMZN follow 
a similar pattern of spikes (remember the pandemic?),
while GOOGL is more stable.

![image](demo/img/nflx_meta_amz_googl.png)

### Additional Metrics

No algorithm can magically detect the function of the relationship
between two variables, but MINE statistics can shed some light on the
nature of that relationship.

| Metric                                          | SQL Function               | Interpretation                                                                                                                                                |
|-------------------------------------------------|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Maximum Asymmetry Score (MAS)                   | `SELECT mas(X, Y)`         | measures how much the relationship deviates from monotonicity                                                                                                 |
| Maximum Edge Value (MEV)                        | `SELECT mev(X, Y)`         | measures the degree to which the dataset appears to be sampled from a continuous function.                                                                    |
| Minimum Cell Number (MCN)                       | `SELECT mcn(X, Y`)         | measures the complexity of the association.                                                                                                                   |
| Minimum Cell Number General (MCNG)              | `SELECT mcn_general(X, Y)` | returns the MCN with `eps = 1 - MIC`                                                                                                                          |
| Total Information Coefficient (TIC)             | `SELECT tic(X, Y)`         | returns the total information coefficient                                                                                                                     |
| Generalized Mean Information Coefficient (GMIC) | `SELECT gmic(X, Y)`        | generalization of MIC, which incorporates a tuning parameter that can be used to modify the complexity of the association favored by the measure [Luedtke2013] |


### Exploring Energy Stocks

Let's explore stocks from the Energy sector.
This involves three steps.

First, we get the relevant list of symbols.

```sql
select string_agg(lower(symbol), ', ')
from sp500
where sector = 'Energy';
```

Second, we create a view for these stocks.

```sql
create view v_energy_stocks as
select apa, bkr, cvx, cop, ctra, dvn, fang, eog, eqt, xom, hal, hes, kmi, mro, mpc, oxy, oke, psx, slb, trgp, vlo, wmb
from close;
```

Third, we create the MIC-based correlation matrix using the `vasco_corr_matrix` function.

```sql
select vasco_corr_matrix('v_energy_stocks', 'corr_energy');
```

Here's the resulting heatmap. 

![image](demo/img/energy_corr.png)

A blue-ish row/column in the heatmap means that
the stock is generally not correlated with the others.

Looks like this is the case for tickers like 
KMI, OKE, and PSX seem to beat at their drum.

If we look at TRGP, we'll see that it's closely associated with
both DVN and EOG, but not with OKE and PSX.

## Conclusion

Vasco is a powerful tool for discovering hidden patterns in your data, especially when dealing with complex relationships that traditional methods might miss. By leveraging advanced statistical measures like MIC, Vasco provides a deeper insight into the correlations within your dataset, making it an invaluable addition to any data analyst's toolkit.

Stay tuned for more updates and features as Vasco continues to evolve. Try it out with your data and see what hidden patterns you can uncover!
