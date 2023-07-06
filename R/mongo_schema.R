#' Compute a schema for a MongoDB collection
#'
#' @description
#' A DRDL schema is required to match SQL queries with MongoDB aggregation
#' language because MongoDB do not store structured data. However, your data may
#' have a intrinsic structure, which is computed. `mtcars_schema()` provides
#' precomputed schema for the `mtcars` dataset, see also `?mtcars` for example
#' and testing purpose in the absence of the "mongodrdl" binaries (correct
#' providing the `mtcars` data are inserted unmodified in an empty collection).
#'
#' @param mongo A **mongo** object as obtained from [mongo()] or
#' attr([tbl_mongo()], "mongo").
#' @param max_scan The maximum of documents to scan to elaborate the structure
#' (100 by default).
#' @param recalc Is the schema recalculated, in case it is present in the
#' **mongo** object (`FALSE` by default)?
#' @param path The path to the "mongodrdl" binaries. If it is accessible on the
#' search path, or indicated in the "mongotranslate.path" option, no need to
#' specify it.
#' @param x A **mongo_schema** object.
#' @param ... Further arguments passed to [print()] (not used currently).
#' @param db The name of the database.
#' @param collection The name of the collection.
#'
#' @return A **mongo_schema** object with the schema as character string and a
#' sample attribute that contains a data.frame with the three first documents in
#' the collection, as an example of what is in that collection.
#'
#' @details
#' The MongoDB BI Connector's "mongodrdl" external program is used to compute
#' the schema, unless a "schema" attribute is found in the mongo object and
#' `recalc = FALSE`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # We use the same little MongoDB server with mtcars set up for {mongolite}
#' library(mongoplyr)
#' database <- "test"
#' collection <- "mtcars"
#' mongodb_url <- "mongodb+srv://readwrite:test@cluster0-84vdt.mongodb.net"
#'
#' # Connect and make sure the collection contains the mtcars dataset
#' mcon <- mongolite::mongo(collection, database, mongodb_url)
#' mcon$drop()
#' mcon$insert(mtcars)
#'
#' # mtcars_schema() returns a precomputed schema for the mtcars dataset
#' schema <- mtcars_schema(db = database, collection = collection)
#' schema
#'
#' # This schema can be added as an attribute to the connection to avoid
#' # recalculating it every time
#' attr(mcon, 'schema') <- schema
#'
#' # Calling mongo_schema() on a mongo objet that already has a schema attached
#' # just retrieves it (no recalculation)
#' schema2 <- mongo_schema(mcon)
#' identical(schema, schema2)
#'
#' # ... unless there is nothing attached, or you use recalc = TRUE
#' # In this case, "mongodrdl" must be installed and accessible
#' # see vignette("mongoplyr")
#' schema3 <- mongo_schema(mcon, recalc = TRUE)
#' schema3
#' # There is no particular order in the documents collection. So, do not expect
#' # to get always the same three documents as example
#' # However, the schema in itself should be fairly consistent (extracted with
#' #`as.character()` here)
#' identical(as.character(schema), as.character(schema3))
#'
#' mcon$disconnect()
#' }
mongo_schema <- function(mongo, max_scan = 100L, recalc = FALSE,
path = getOption("mongotranslate.path")) {
  if (!inherits(mongo, "mongo"))
    stop("'mongo' must be a mongo object.")

  # Is there already a schema in the mongo object?
  schema <- attr(mongo, 'schema')
  if (!is.null(schema) && !isTRUE(recalc))
    return(schema)

  # If there is no sample attribute, create one...
  # We scan up to max_scan documents to construct the data.frame, but then,
  # we just need its structure... so, we also keep 3 first documents as example
  stopifnot(
    "'max_scan' must be numeric." = is.numeric(max_scan),
    "'max_scan' must be scalar (length one numeric)." = length(max_scan) == 1
  )
  max_scan <- as.integer(max_scan)
  sample <- mongo$find('{}', limit = max_scan)[1:3, ]
  attr(sample, "max_scan") <- max_scan

  # Get connection parameters from the mongo object (a little bit tricky!)
  orig <- .mongo_orig(mongo)
  # Either the database is in the URL, or it is provided separately. In that
  # case, we need to append it to the URL
  if (basename(orig$url) != orig$db) {
    url <- paste(orig$url, orig$db, sep = "/")
  } else {# database already in the URL
    url <- orig$url
  }

  # Create a schema for this database using mongodrdl
  cmd <- paste0('"', .mongodrdl(path), '" --uri ', url, ' -c "', orig$name,
    '" -s ', max_scan)
  if (.Platform$OS.type == "windows")
    cmd <- paste("wsl", cmd) # The program is run under Linux from within WSL
  # TODO: more meaninful error message in case of error here
  schema <- system(cmd, intern = TRUE)
  if (!is.character(schema) && schema[1] != "schema:")
    stop("There was a problem when calculating the schema for the collection.")
  structure(schema, sample = sample, class = "mongo_schema")
}

#' @export
#' @rdname mongo_schema
#' @method print mongo_schema
print.mongo_schema <- function(x, ...) {
  cat("<mongo_schema> for (3 first documents):\n")
  print(attr(x, 'sample'))
  cat("\n")
  cat(as.character(x), sep = "\n")
  invisible(x)
}

#' @export
#' @rdname mongo_schema
mtcars_schema <- function(db = "test", collection = "mtcars") {
  structure(
    c("schema:", paste("- db:", db), "  tables:",
      paste("  - table:", collection), paste("    collection:", collection),
      "    pipeline: []", "    columns:",
      "    - Name: _id", "      MongoType: bson.ObjectId",
      "      SqlName: _id", "      SqlType: objectid",
      "    - Name: _row", "      MongoType: string",
      "      SqlName: _row", "      SqlType: varchar",
      "    - Name: am", "      MongoType: float64",
      "      SqlName: am", "      SqlType: float",
      "    - Name: carb", "      MongoType: float64",
      "      SqlName: carb", "      SqlType: float",
      "    - Name: cyl", "      MongoType: float64",
      "      SqlName: cyl", "      SqlType: float",
      "    - Name: disp", "      MongoType: float64",
      "      SqlName: disp", "      SqlType: float",
      "    - Name: drat", "      MongoType: float64",
      "      SqlName: drat", "      SqlType: float",
      "    - Name: gear", "      MongoType: float64",
      "      SqlName: gear", "      SqlType: float",
      "    - Name: hp", "      MongoType: float64",
      "      SqlName: hp", "      SqlType: float",
      "    - Name: mpg", "      MongoType: float64",
      "      SqlName: mpg", "      SqlType: float",
      "    - Name: qsec", "      MongoType: float64",
      "      SqlName: qsec", "      SqlType: float",
      "    - Name: vs", "      MongoType: float64",
      "      SqlName: vs", "      SqlType: float",
      "    - Name: wt", "      MongoType: float64",
      "      SqlName: wt", "      SqlType: float" ),
    sample = datasets::mtcars[1:3, ],
    class = "mongo_schema"
  )
}

# Get the origin of a mongo object (a little bit tricky)
.mongo_orig <- function(mongo) {
  eval(as.name('orig'), envir = mongo)
}

# Get the mongodrdl excutable (from Mongo BI Connector)
.mongodrdl <- function(path = getOption("mongotranslate.path")) {
  if (.Platform$OS.type == "windows") {# Do not test (probably run from WSL)
    if (is.null(path)) {
      mongodrdl <- "mongodrdl"
    } else {
      mongodrdl <- file.path(path, "mongodrdl")
    }
  } else {# Linux or MacOS: full test
    if (is.null(path)) {
      mongodrdl <- Sys.which("mongodrdl")
    } else {
      mongodrdl <- path.expand(file.path(path, "mongodrdl"))
    }
    if (mongodrdl == "" || !file.exists(mongodrdl))
      stop("You must install MongoDB BI Connector and indicate the path ",
        "in options(mongotranslate.path = ...) before use, see ?tbl_mongo.")
  }
  mongodrdl
}
