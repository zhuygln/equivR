test_that("any non-pass required check forces FAIL", {
  base <- equiv_validate(ref_df(), ref_df(), equiv_contract(keys = "id"))$checks
  expect_equal(equivR:::aggregate_status(base), "PASS")
  for (i in seq_along(base)) {
    for (status in c("fail", "skipped", "error", NA, "unknown")) {
      checks <- base
      checks[[i]]$status <- status
      expect_equal(equivR:::aggregate_status(checks), "FAIL",
                   info = paste(checks[[i]]$id, status))
      checks[[i]]$required <- FALSE
      expect_equal(equivR:::aggregate_status(checks), "PASS",
                   info = paste(checks[[i]]$id, status, "optional"))
    }
  }
})

test_that("a check with no explicit required flag is treated as required", {
  checks <- list(list(id = "x", status = "fail"))
  expect_equal(equivR:::aggregate_status(checks), "FAIL")
})

test_that("optional failures are reported but do not change the status", {
  cand <- ref_df()
  cand$extra <- 1
  strict <- equiv_validate(ref_df(), cand, equiv_contract(keys = "id"))
  lenient <- equiv_validate(ref_df(), cand, equiv_contract(
    keys = "id", checks = list(schema.extra_fields = "optional")))
  expect_equal(strict$status, "FAIL")
  expect_equal(strict$summary$failed_required, list("schema.extra_fields"))
  expect_equal(lenient$status, "PASS")
  expect_equal(lenient$summary$failed_optional, list("schema.extra_fields"))
  expect_equal(status_of(lenient, "schema.extra_fields"), "fail")
})

test_that("skipped required checks are not a pass", {
  cand <- rbind(ref_df(), ref_df()[1, ])
  res <- equiv_validate(ref_df(), cand, equiv_contract(
    keys = "id", checks = list(keys.unique_candidate = "optional")))
  expect_equal(status_of(res, "values.numeric"), "skipped")
  expect_equal(res$status, "FAIL")
  expect_true("values.numeric" %in% unlist(res$summary$failed_required))
})

test_that("internal errors fail closed", {
  local_mocked_bindings(compare_dataset = function(...) stop("boom"))
  res <- equiv_validate(ref_df(), ref_df(), equiv_contract(keys = "id"))
  expect_equal(res$status, "FAIL")
  expect_true(all(vapply(res$checks, `[[`, "", "status") == "error"))
  expect_match(res$checks[[1]]$message, "boom")
})

test_that("evidence JSON is deterministic and complete", {
  cand <- ref_df()
  cand$estimate[2] <- 2.001
  ct <- equiv_contract(keys = "id")
  a <- equiv_validate(ref_df(), cand, ct)
  b <- equiv_validate(ref_df(), cand, ct)
  expect_identical(stable_evidence(a), stable_evidence(b))

  ev <- jsonlite::fromJSON(result_to_json(a), simplifyVector = FALSE)
  expect_equal(names(ev), c("schema_version", "status", "contract", "artifacts",
                            "summary", "checks", "provenance"))
  expect_equal(ev$schema_version, "equivr-result/v1")
  expect_match(ev$artifacts$reference$sha256, "^[0-9a-f]{64}$")
  expect_equal(names(ev$provenance), c("equivR_version", "r_version", "platform",
                                       "source_revision", "timestamp"))
  expect_length(ev$checks, length(equiv_check_ids()))

  path <- tempfile(fileext = ".json")
  write_result_json(a, path)
  expect_equal(jsonlite::read_json(path)$status, "FAIL")
})

test_that("artifact checksums identify content", {
  a <- as_equiv_dataset(ref_df())
  b <- as_equiv_dataset(ref_df())
  cand <- ref_df()
  cand$estimate[1] <- 1.5
  expect_equal(a$sha256, b$sha256)
  expect_false(a$sha256 == as_equiv_dataset(cand)$sha256)

  path <- tempfile(fileext = ".csv")
  utils::write.csv(ref_df(), path, row.names = FALSE)
  ds <- as_equiv_dataset(path)
  expect_equal(ds$format, "csv")
  expect_equal(ds$sha256, digest::digest(file = path, algo = "sha256"))
})

test_that("contract artifacts resolve relative to the contract file", {
  res <- equiv_validate(contract = test_path("golden", "exact_match", "contract.yaml"))
  expect_equal(res$status, "PASS")
  expect_equal(res$artifacts$reference$source, "reference.csv")
})

test_that("the printed report shows status and failing diagnostics", {
  cand <- ref_df()
  cand$estimate[2] <- 2.5
  out <- format(equiv_validate(ref_df(), cand, equiv_contract(keys = "id")))
  expect_match(out[1], "FAIL")
  expect_true(any(grepl("\\[FAIL\\] values.numeric", out)))
  expect_true(any(grepl("estimate @ id=B", out)))
  expect_output(print(equiv_validate(ref_df(), ref_df(), equiv_contract(keys = "id"))), "PASS")
})

test_that("equiv_compare remains as a prototype-compatible alias", {
  expect_true(equiv_passed(equiv_compare(ref_df(), ref_df(), equiv_contract(keys = "id"))))
})
