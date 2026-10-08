# Golden evidence tests. Regenerate expected.json with EQUIVR_UPDATE_GOLDEN=1
# and review the diff before committing.

golden_cases <- list.dirs(test_path("golden"), recursive = FALSE)

expected_status <- c(
  exact_match = "PASS", tolerance_pass = "PASS", optional_extra_field = "PASS",
  tolerance_fail = "FAIL", duplicate_keys = "FAIL", missing_rows = "FAIL",
  schema_mismatch = "FAIL", missingness_mismatch = "FAIL", exact_field_override = "FAIL"
)

test_that("every golden case has a declared expected status", {
  expect_setequal(basename(golden_cases), names(expected_status))
})

for (dir in golden_cases) {
  case <- basename(dir)
  test_that(paste("golden:", case), {
    res <- equiv_validate(contract = file.path(dir, "contract.yaml"))
    expect_equal(res$status, expected_status[[case]])

    actual <- stable_evidence(res)
    expected_path <- file.path(dir, "expected.json")
    if (identical(Sys.getenv("EQUIVR_UPDATE_GOLDEN"), "1")) {
      jsonlite::write_json(actual, expected_path, auto_unbox = TRUE, digits = NA,
                           pretty = TRUE, null = "null", na = "null")
    }
    expect_true(file.exists(expected_path))
    expect_equal(actual, jsonlite::read_json(expected_path))
  })
}
