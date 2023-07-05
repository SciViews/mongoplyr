test_that("time extracted from objid", {
  expect_equal(
    time_from_id("5a682326bf8380e6e6584ba5"),
    as.POSIXct("2008-01-24 06:09:42", tz = "GMT")
  )
})
