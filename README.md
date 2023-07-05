# mongoplyr - Use {dplyr} verbs with a MongoDB database or construct MongoDB JSON queries from {dplyr} verbs

<!-- badges: start -->

[![R-CMD-check](https://github.com/SciViews/mongoplyr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SciViews/mongoplyr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Use {dplyr} verbs to query a MongoDB database. This uses {dbplyr} to create SQL queries, and then converts them into MongoDB JSON queries with "mongotranslate" from the MongoDB BI Connector (to be installed). One can also recover the JSON query to use it directly into {mongolite}. This way, {mongoplyr} serves as a translator from {dplyr} code to MongoDB JSON queries.

## Installation

You can install the development version of {mongoplyr} from [GitHub](https://github.com/SciViews/mongoplyr) with:

``` r
# install.packages("remotes")
remotes::install_github("SciViews/mongoplyr")
```

## Example

TODO: a basic example...

``` r
library(mongoplyr)
## basic example code
```

Get help about this package:

``` r
library(help = "mongoplyr")
help("mongoplyr-package")
vignette("mongoplyr") # Note: no vignette is installed with install_github()
```

For further instructions, please, refer to the help pages at <https://www.sciviews.org/mongoplyr/>.

## Code of Conduct

Please note that the mongoplyr project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.
