
#' Create a tbl_mongo lazy connection to a MongoDB collection
#'
#' @description The **tbl_mongo** object is a lazy connection to a MongoDB
#'   collection that you can use with {dbplyr} and {dplyr} verbs. The query
#'   in MongoDB JSON language is computed on [collect()]ing the results, or
#'   by using [collapse()] to retrieve the JSON command in a character string.
#'
#' @param collection The collection to use in the MongoDB database.
#' @param db  The database to use from the MongoDB server.
#' @param url The URL to the MongoDB server. This uses [mongo()] from
#' {mongolite} internally, see the documentation at
#' https://jeroen.github.io/mongolite/connecting-to-mongodb.html.
#' @param max_scan The maximum number of documents to scan in the collection in
#' order to infer the corresponding schema with mongodrdl (1000 by default).
#' @param ... More parameters to [mongo()] to connect to the MongoDB server.
#' @param mongotranslate.path The path to the mongotranslate and mongodrdl
#' software. Can be set via `options(mongotranslate.path = ....)`, or left empty
#' if these executables are on the search path.
#' @param keep.names Logical (`FALSE` by default). Should the (strange) names
#' constructed by {dbplyr} be kept in the JSON MongoDB query or not?
#' @param x A **tbl_mongo** or a **mongo_query** object as obtained with [collapse()].
#' @param sql Should the corresponding SQL statement be printed as well as the
#' JSON query (`FALSE` by default?
#'
#' @return A **tbl_mongo** object that contains the logic to process queries on
#' a MongoDB collection through {dplyr} verbs. [collect()] returns a data.frame
#' with the result from querying the MongoDB collection. [collapse()] returns
#' the MongoDB JSON query corresponding to the process in a **mongo_query**
#' object.
#' @export
#'
#' @examples
#' \donttest{
#' # We use the same little MongoDB server with mtcars set up for {mongolite}
#' # Note that mongotranslate and mongodrdl must be installed and accessible
#' # see vignette("mongoplyr").
#' library(mongoplyr)
#' library(dplyr)
#' database <- "test"
#' collection <- "mtcars"
#' mongodb_url <- "mongodb+srv://readwrite:test@cluster0-84vdt.mongodb.net"
#' tbl <- tbl_mongo(collection, database, url = mongodb_url)
#'
#' # Create a simple mongodb query
#' tbl2 <- tbl |>
#'   filter(mpg < 20) |>
#'   select(mpg, cyl, hp)
#' tbl2
#' # Use collect() to get the result
#' collect(tbl2)
#' # Use collapse() to get the JSON query
#' (query <- collapse(tbl2))
#' # Use this JSON query directly in mongolite
#' # Note, the connection is available as tbl2$mongo here but you do not
#' # need {mongoplyr} any more and can use mongolite::mongo()$find() instead
#' tbl2$mongo$aggregate(query)
#'
#' # A more complex exemple with summarise by group
#' # Note: currently, names must be fun_var in summarise()
#' query2 <- tbl |>
#'   select(mpg, cyl, hp) |>
#'   group_by(cyl) |>
#'   summarise(
#'     mean_mpg = mean(mpg, na.rm = TRUE), sd_mpg = sd(mpg, na.rm = TRUE),
#'     mean_hp  = mean(hp, na.rm = TRUE),  sd_hp  = sd(hp, na.rm = TRUE)) |>
#'     collapse()
#' query2
#' tbl$mongo$aggregate(query2)
#' }
tbl_mongo <- function(collection = "test", db = "test",
url = "mongodb://localhost", max_scan = 1000L, ...,
mongotranslate.path = getOption("mongotranslate.path")) {

  mongo <- mongolite::mongo(collection, db = db, url = url, ...)

  tbl <- mongo$find('{}', limit = max_scan)[1L, ]
  tbl <- tbl_lazy(tbl, con = simulate_odbc()) # Fake ODBC connection
  tbl$mongo <- mongo
  tbl$mongo.db <- db # TODO: deal with db in the URL too
  tbl$mongo.collection <- collection
  tbl$mongo.url <- url
  tbl$max_scan <- max_scan

  # Create a schema for this database using mongodrdl
  cmd <- paste0('"', .mongodrdl(), '" --uri ',
    paste(url, db, sep = "/"), ' -c "', collection, '" -s ', max_scan)
  drdl <- system(cmd, intern = TRUE)
  tbl$mongo.drdl <- drdl
  tbl$mongo.translate <- .mongotranslate()

  class(tbl) <- unique(c("tbl_mongo", class(tbl)))
  tbl
}

#' @export
#' @rdname tbl_mongo
#' @method print tbl_mongo
print.tbl_mongo <- function(x, ...) {
  cat("<tbl_mongo> A lazy MongoDB table\n")
  cat("- server URL:", x$mongo.url, "\n")
  cat("- max scan. :", x$max_scan, "\n\n")
  cat(x$mongo.drdl, sep = "\n")
  invisible(x)
}

#' @export
#' @rdname tbl_mongo
#' @method collapse tbl_mongo
collapse.tbl_mongo <- function(x, keep.names = FALSE, ...) {
  .tbl_mongo_query(x, keep.names = keep.names, ...)
}

#' @export
#' @rdname tbl_mongo
#' @method collect tbl_mongo
collect.tbl_mongo <- function(x, keep.names = FALSE, ...) {
  query <- .tbl_mongo_query(x, keep.names = keep.names)
  x$mongo$aggregate(query)
}

# Get the mongotranslate excutable (from Mongo BI Connector)
.mongotranslate <- function(path = getOption("mongotranslate.path")) {
  if (is.null(path)) {
    mongotranslate <- Sys.which("mongotranslate")
  } else {
    mongotranslate <- path.expand(file.path(path, "mongotranslate"))
  }
  if (mongotranslate == "" || !file.exists(mongotranslate))
    stop("You must install MongoDB BI Connector and indicate the path ",
      "in options(mongotranslate.path = ...) before use, see ?tbl_mongo.")
  mongotranslate
}

# Get the mongodrdl excutable (from Mongo BI Connector)
.mongodrdl <- function(path = getOption("mongotranslate.path")) {
  if (is.null(path)) {
    mongodrdl <- Sys.which("mongodrdl")
  } else {
    mongodrdl <- path.expand(file.path(path, "mongodrdl"))
  }
  if (mongodrdl == "" || !file.exists(mongodrdl))
    stop("You must install MongoDB BI Connector and indicate the path ",
      "in options(mongotranslate.path = ...) before use, see ?tbl_mongo.")
  mongodrdl
}

# From here, one can use selected dplyr verbs on tbl and:
# - get equivalent MongoDB query (json object) with collapse()
# - perform the query on the MongoDB database with collect()
.tbl_mongo_query <- function(x, keep.names = FALSE, ...) {
  sql <- as.character(remote_query(x))
  # We got a SQL quesry that we have to rework to suit our particular context
  # of a MongoDB collection (we do so by using regular expressions, without
  # parsing the SQL statements)

  # The table here is always `df` => replace everywhere with the collection
  sql <- gsub("`df`", paste0("`", x$mongo.collection, "`"), sql)

  # Translate the sql query into MongoDB query (JSON) using mongotranslate
  sql_file <- tempfile(fileext = ".sql")   # The SQL query
  drdl_file <- tempfile(fileext = ".drdl") # The schema
  on.exit({ unlink(sql_file); unlink(drdl_file) })
  writeLines(sql, sql_file)
  writeLines(x$mongo.drdl, drdl_file)

  # TODO: query MongoDB version and adjust accordingly
  cmd <- paste0('"', x$mongo.translate,
    '" -mongoVersion latest -dbName "', x$mongo.db, '" --queryFile "',
    sql_file, '" --schema "', drdl_file, '"')
  mongo_query <- system(cmd, intern = TRUE)

  # The forelast line renames the variables with strange names, like
  # app is renamed sdd_DOT_something_DOT_app... We don't want this...
  # so we rename properly
  idx <- length(mongo_query) - 1
  forelast <- mongo_query[idx]

  # Get rid of the strange names for the forelast line
  if (!isTRUE(keep.names)) {
    # TODO: this does not work if the collection has an _ in its name!
    name_prefix <- paste0('"', x$mongo.db, '_DOT_[^_]+_DOT_')
    forelast <- gsub(paste0(name_prefix, '([^"()]+)"'), '"\\1"',
      forelast)
    # stddev_samp really should give a name sd
    forelast <- gsub('_stddev_samp', '_sd', forelast)
    # Also rework sdd_DOT_qXX_DOT_fun(sdd_DOT_qXX_name) into fun_name
    forelast <- gsub(paste0('"', x$mongo.db, '_DOT_([a-zA-Z]+)\\('), '"\\1_',
      forelast)
    forelast <- gsub(paste0('"([a-zA-Z]+)_', x$mongo.db,
      '_DOT_q[0-9]+_DOT_([^)]+)\\)"'), '"\\1_\\2"', forelast)
  }

  # The trailing comma at the forelast line makes problem in mongo$find()
  # which returns Invalid JSON object -> eliminate it
  mongo_query[idx] <- sub(', *$', '', forelast)

  # Replace everywhere _DOT_ by __
  mongo_query <- gsub("_DOT_", "__", mongo_query)

  # mongolite does not accepts definition of data using, e.g., NumberInt("0")
  # We must convert it into { "$numberInt" : "0" }
  mongo_query <- gsub('N([a-zA-Z]+)\\(("[^"]+")\\)', '{"$n\\1": \\2}',
    mongo_query)
  mongo_query <- gsub('([a-zA-Z]+)\\(("[^"]+")\\)', '{"$\\1": \\2}',
    mongo_query)

  # Replace leading \t by two spaces
  mongo_query <- sub('^\t', '  ', mongo_query)

  # Append the computed SQL query
  attr(mongo_query, "sql") <- sql
  class(mongo_query) <- c("mongo_query", "character")
  mongo_query
}

#' @export
#' @rdname tbl_mongo
#' @method print mongo_query
print.mongo_query <- function(x, sql = FALSE, ...) {
  cat("<mongo_query>\n")
  cat(x, sep = '\n')
  if (isTRUE(sql)) {
    cat("\n=== Equivalent SQL statement:\n")
    cat(attr(x, "sql"), sep = '\n')
  }
  invisible(x)
}

