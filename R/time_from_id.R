#' Get timestamp for ObjectID of MongoDB documents
#'
#' @description Each MongoDB document has an ObjectID. When it is automatically
#'   constructed (it is almost always the case), the first part of the ObjectID
#'   is a timestamp indicating when the document was added. [time_from_id()]
#'   recovers this timestamp.
#'
#' @param id A vector with one or more objid.
#' @param tz The timezone to use (GMT by default).
#'
#' @return A **POSIXct object with time extracted from the ObjectID.
#' @export
#'
#' @examples
#' # ObjectID 5a682326bf8380e6e6584ba5 was created at
#' # ISODate("2018-01-24T06:09:42Z")
#' time_from_id("5a682326bf8380e6e6584ba5")
#' # Get it in West Europe time
#' time_from_id("5a682326bf8380e6e6584ba5", tz = "CET")
time_from_id <- function(id, tz = "GMT") {
  timestamp <- substring(id, 1L, 8L)
  seconds <- as.numeric(paste0("0x", timestamp))
  as.POSIXct(seconds, origin = "1960-01-01", tz = tz)
}
