
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mongoplyr - Use {dplyr} verbs with a MongoDB database or construct MongoDB JSON queries from {dplyr} verbs <a href="https://www.sciviews.org/mongoplyr"><img src="man/figures/logo.png" alt="mongoplyr website" align="right" height="139"/></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/SciViews/mongoplyr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SciViews/mongoplyr/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/SciViews/mongoplyr/branch/main/graph/badge.svg)](https://app.codecov.io/gh/SciViews/mongoplyr?branch=main)
[![CRAN
status](https://www.r-pkg.org/badges/version/mongoplyr)](https://CRAN.R-project.org/package=mongoplyr)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

## Overview

Use {dplyr} verbs to query a MongoDB database. This uses {dbplyr} to
create SQL queries, and then converts them into MongoDB JSON aggregating
queries with “mongotranslate” from the MongoDB BI Connector (to be
installed). One can also recover the JSON query to use it directly into
{mongolite}. This way, {mongoplyr} serves as a translator from {dplyr}
code to MongoDB JSON queries only during the prototyping phase.

**Note: this is highly experimental. Do not expect to obtain running
queries in MongoDB JSON for any and all {dplyr} pipelines!** However,
the code obtained could be a base to be edited later on. This is an
additional argument to use {mongoplyr} only for prototyping your MongoDB
JSON queries.

## Installation

You can install the development version of {mongoplyr} from
[GitHub](https://github.com/SciViews/mongoplyr) with:

``` r
# install.packages("remotes")
remotes::install_github("SciViews/mongoplyr")
```

You also need “mongotranslate” and “mongodrdl” external binaries that
are provided by MongoDB BI Connector (note: “mongotranslate” is **not**
provided under Windows, see here under).

- For Linux and MacOS, download the MongoDB BI Connector and follow
  instructions from here:
  <https://www.mongodb.com/docs/bi-connector/current/installation/>.
  Also note that you must register and you need a premise MongoDB
  subscription to be allowed to use these binaries, … or you can use
  them for testing or prototyping purpose only (which is what we are
  going to do). In R, you can check accessibility to these programs by
  using `system("mongotranslate")`.

- For Windows, install WSL2 (see
  <https://learn.microsoft.com/en-us/windows/wsl/install>) and a Linux
  distribution for WSL (Ubuntu 22.04 for instance). Then, install
  MongoDB BI Connector in your WSL Linux as explained here above. Then,
  you should be able to access “mongotranslate”/“mongodrdl” through a
  command like `wsl mongotranslate`. Test it under R by issuing
  `system("wsl mongotranslate")`.

If you made “mongotranslate” and “mongodrdl” accessible from the path
(that is, these programs run in a terminal without specifying their
complete path), you are done. If you prefer to isolate these programs in
a directory, say in `/my/directory/to/mongodb_bi`, then {mongoplyr} will
be able to access these programs if you indicate the path like this:

``` r
options(mongotranslate.path = "/my/directory/to/mongodb_bi")
# Test it with:
#system(file.path(getOption("mongotranslate.path"), "mongostranslate"))
```

## Example

Here is a basic example using the five main {dplyr} verbs `select()`,
`filter()`, `mutate()`, `group_by()` and `summarise()` (+ `arrange()`).
We do not set up our own MongoDB server, but just reuse the example
server provided by Jeroen Ooms, the author of the {mongolite} package
that {mongoplyr} uses to connect to MongoDB.

``` r
library(mongoplyr)
library(dplyr)
#> 
#> Attachement du package : 'dplyr'
#> Les objets suivants sont masqués depuis 'package:stats':
#> 
#>     filter, lag
#> Les objets suivants sont masqués depuis 'package:base':
#> 
#>     intersect, setdiff, setequal, union
database <- "test"
collection <- "mtcars"
mongodb_url <- "mongodb+srv://readwrite:test@cluster0-84vdt.mongodb.net"

# Connect and make sure the collection contains the mtcars dataset
mcon <- mongolite::mongo(collection, database, mongodb_url)
mcon$drop()
mcon$insert(mtcars)
#> List of 5
#>  $ nInserted  : num 32
#>  $ nMatched   : num 0
#>  $ nRemoved   : num 0
#>  $ nUpserted  : num 0
#>  $ writeErrors: list()
```

Now, we create a **tbl_mongo** object that lazily matches a
**data.frame** to this connection and allows to use {dplyr} verbs to
query it.

``` r
tbl <- tbl_mongo(mongo = mcon)
query <- tbl |>
  filter(mpg < 30 & wt >= 2) |>
  select(cyl, wt, mpg, hp) |>
  mutate(log_hp = log(hp), wt2 = wt^2) |>
  group_by(cyl) |>
  summarise(
    max_mpg     = max(mpg, na.rm = TRUE),
    min_wt2     = min(wt2, na.rm = TRUE),
    mean_log_hp = mean(log_hp, na.rm = TRUE)) |>
  arrange(cyl)
  
# Here is the equivalent MongoDB JSON query
collapse(query)
#> <mongo_query>
#> [
#>   {"$match": {"$and": [{"wt": {"$gte": {"$numberDecimal": "2"}}},{"mpg": {"$lt": {"$numberDecimal": "30"}}}]}},
#>   {"$project": {"test__mtcars__cyl": "$cyl","test__mtcars__mpg": "$mpg","ln(test__mtcars__hp)": {"$cond": {"if": {"$gt": ["$hp",{"$literal": {"$numberInt": "0"}}]},"then": {"$ln": ["$hp"]},"else": {"$literal": null}}},"power(test__mtcars__wt,2)": {"$pow": ["$wt",{"$literal": {"$numberDecimal": "2"}}]}}},
#>   {"$group": {"_id": "$test__mtcars__cyl","max(test__q01__mpg)": {"$max": "$test__mtcars__mpg"},"min(test__q01__wt2)": {"$min": "$power(test__mtcars__wt,2)"},"avg(test__q01__log_hp)": {"$avg": "$ln(test__mtcars__hp)"}}},
#>   {"$addFields": {"_id": {"group_key_0": "$_id"}}},
#>   {"$sort": {"_id.group_key_0": {"$numberInt": "1"}}},
#>   {"$project": {"cyl": "$_id.group_key_0","max_mpg": "$max(test__q01__mpg)","min_wt2": "$min(test__q01__wt2)","mean_log_hp": "$avg(test__q01__log_hp)","_id": {"$numberInt": "0"}}}
#> ]
```

Use `collect()` to get the resulting **data.frame**:

``` r
collect(query)
#>   cyl max_mpg min_wt2 mean_log_hp
#> 1   4    26.0  4.5796    4.498422
#> 2   6    21.4  6.8644    4.792079
#> 3   8    19.2 10.0489    5.318145
```

The query is just a character string (obtained with `collapse()`) and it
can be used as such directly in an `$aggregate()` method of a **mongo**
object (the string is entered using the raw character syntax by
embedding it in `r"{...}"`). Since it is pretty unreadable by anyone not
used to the MongoDB aggregating language (and even by those who
understand it, probably!) we copy and paste also the corresponding
{dplyr} pipeline in comments above to better document it. In case you
would need to refine this query later on, you know you can start from
that {dplyr} pipeline in the comments. This way, you do not need
{mongoplyr} any more, nor the external programs “mongotranslate” and
“mongodrdl” to run that query on your database. So, you have just used
{mongoplyr} for prototyping your query.

``` r
# The next query is equivalent to (created with {mongoplyr}):
#tbl |>
#  filter(mpg < 30 & wt >= 2) |>
#  select(cyl, wt, mpg, hp) |>
#  mutate(log_hp = log(hp), wt2 = wt^2) |>
#  group_by(cyl) |>
#  summarise(
#    max_mpg     = max(mpg, na.rm = TRUE),
#    min_wt2     = min(wt2, na.rm = TRUE),
#    mean_log_hp = mean(log_hp, na.rm = TRUE)) |>
#  arrange(cyl)
mcon$aggregate(r"{[
  {"$match": {"$and": [{"wt": {"$gte": {"$numberDecimal": "2"}}},{"mpg": {"$lt": {"$numberDecimal": "30"}}}]}},
  {"$project": {"test__mtcars__cyl": "$cyl","test__mtcars__mpg": "$mpg","ln(test__mtcars__hp)": {"$cond": {"if": {"$gt": ["$hp",{"$literal": {"$numberInt": "0"}}]},"then": {"$ln": ["$hp"]},"else": {"$literal": null}}},"power(test__mtcars__wt,2)": {"$pow": ["$wt",{"$literal": {"$numberDecimal": "2"}}]}}},
  {"$group": {"_id": "$test__mtcars__cyl","max(test__q01__mpg)": {"$max": "$test__mtcars__mpg"},"min(test__q01__wt2)": {"$min": "$power(test__mtcars__wt,2)"},"avg(test__q01__log_hp)": {"$avg": "$ln(test__mtcars__hp)"}}},
  {"$addFields": {"_id": {"group_key_0": "$_id"}}},
  {"$sort": {"_id.group_key_0": {"$numberInt": "1"}}},
  {"$project": {"cyl": "$_id.group_key_0","max_mpg": "$max(test__q01__mpg)","min_wt2": "$min(test__q01__wt2)","mean_log_hp": "$avg(test__q01__log_hp)","_id": {"$numberInt": "0"}}}
]}")
#>   cyl max_mpg min_wt2 mean_log_hp
#> 1   4    26.0  4.5796    4.498422
#> 2   6    21.4  6.8644    4.792079
#> 3   8    19.2 10.0489    5.318145
```

Compare this with a direct manipulation of `mtcars` as a **data.frame**
using regular {dplyr} code:

``` r
mtcars |>
  filter(mpg < 30 & wt >= 2) |>
  select(cyl, wt, mpg, hp) |>
  mutate(log_hp = log(hp), wt2 = wt^2) |>
  group_by(cyl) |>
  summarise(
    max_mpg     = max(mpg, na.rm = TRUE),
    min_wt2     = min(wt2, na.rm = TRUE),
    mean_log_hp = mean(log_hp, na.rm = TRUE)) |>
  arrange(cyl)
#> # A tibble: 3 × 4
#>     cyl max_mpg min_wt2 mean_log_hp
#>   <dbl>   <dbl>   <dbl>       <dbl>
#> 1     4    26      4.58        4.50
#> 2     6    21.4    6.86        4.79
#> 3     8    19.2   10.0         5.32
```

## Getting help

Help is accessible as usual by one of these instructions:

``` r
library(help = "mongoplyr")
help("mongoplyr-package")
vignette("mongoplyr") # Note: no vignette is installed with install_github()
```

For further instructions, please, refer to the Web site at
<https://www.sciviews.org/mongoplyr/>.

------------------------------------------------------------------------

Please note that the {mongoplyr} package is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
