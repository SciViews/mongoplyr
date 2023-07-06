#' @details
#' Use {dplyr} verbs to query a MongoDB database. This uses {dbplyr} to create
#' SQL queries, and then converts them into MongoDB JSON queries with
#' "mongotranslate" from the MongoDB BI Connector (to be installed; Make sure
#' you have adequate license to use it).
#'
#' One can also recover the JSON query to use it directly into "mongolite". This
#' way, {mongoplyr} serves as a translator from "dplyr" code to MongoDB JSON
#' queries. One the JSON string is constructed, use it with {mongolite} and you
#' do not need {mongoplyr} any more to run your code.
#'
#' Before you can use this package, you must install "mongotranslate" and
#' "mongodrdl" from MongoDB and make them available on your PATH (or specify the
#' directory where they are in `options(mongotranslate.path = ....)`). Follow
#' instructions to install BI Connector on Premise on your system. Note that
#' "mongotranslate" is apparently not available for Windows. Consequently, the
#' {mongoplyr} package is useless on this OS. Use Linux or MacOS (use WLS on
#' Windows, or a Docker container or a virtual machine instead).
#'
#' @section Important functions:
#'
#' - [tbl_mongo()] creates an object that connects to your MongoDB database and
#' use {dplyr} verbs in a lazy way.
#' - [mongo_schema()] compute a schema to match a collection of MongoDB
#' documents with a corresponding SQL table (required to translate SQL query
#' into JSON MongoDB aggregation language).
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom dplyr collect collapse
#' @importFrom dbplyr remote_query simulate_odbc tbl_lazy
#' @importFrom mongolite mongo ssl_options
## usethis namespace: start
## usethis namespace: end
NULL
