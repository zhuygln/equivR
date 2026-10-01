validate <- function(cand, ref = ref_df(), ...) {
  equiv_validate(ref, cand, equiv_contract(keys = "id", ...))
}

test_that("identical data passes every check", {
  res <- validate(ref_df())
  expect_equal(res$status, "PASS")
  expect_true(all(vapply(res$checks, `[[`, "", "status") == "pass"))
})

test_that("rows are aligned by key, not position", {
  cand <- ref_df()[c(3, 1, 2), ]
  expect_true(equiv_passed(validate(cand)))
})

test_that("absolute tolerance boundary is inclusive", {
  cand <- ref_df()
  cand$estimate[2] <- 2.5
  expect_true(equiv_passed(validate(cand, abs_tol = 0.5)))
  cand$estimate[2] <- 2.5 + 2^-20
  res <- validate(cand, abs_tol = 0.5)
  expect_equal(status_of(res, "values.numeric"), "fail")
})

test_that("relative tolerance scales with the reference value", {
  cand <- ref_df()
  cand$estimate <- cand$estimate * 1.001
  expect_true(equiv_passed(validate(cand, rel_tol = 0.002)))
  expect_false(equiv_passed(validate(cand, rel_tol = 0.0005)))
})

test_that("per-field tolerance overrides the default", {
  cand <- ref_df()
  cand$estimate[1] <- 1.1
  expect_false(equiv_passed(validate(cand, abs_tol = 1e-8)))
  expect_true(equiv_passed(validate(cand, abs_tol = 1e-8,
                                    field_tolerance = list(estimate = list(abs = 0.25)))))
})

test_that("numeric diagnostics carry key, values, delta and tolerance", {
  cand <- ref_df()
  cand$estimate[2] <- 2.5
  ch <- check_of(validate(cand, abs_tol = 0.1), "values.numeric")
  expect_equal(ch$n_mismatch, 1L)
  d <- ch$diagnostics[[1]]
  expect_equal(d$field, "estimate")
  expect_equal(d$key, list(id = "B"))
  expect_equal(c(d$reference, d$candidate, d$delta, d$tolerance), c(2, 2.5, 0.5, 0.1))
})

test_that("infinite values match only the same infinity", {
  ref <- ref_df()
  ref$estimate[1] <- Inf
  cand <- ref
  expect_true(equiv_passed(validate(cand, ref = ref, rel_tol = 0.1)))
  cand$estimate[1] <- -Inf
  expect_false(equiv_passed(validate(cand, ref = ref, rel_tol = 0.1)))
  cand$estimate[1] <- 1e300
  res <- validate(cand, ref = ref, rel_tol = 0.1)
  expect_false(equiv_passed(res))
  d <- check_of(res, "values.numeric")$diagnostics[[1]]
  expect_equal(d[c("reference", "candidate", "delta")],
               list(reference = "Inf", candidate = 1e300, delta = "Inf"))
})

test_that("missing values: match rule vs forbid rule, NaN counts as missing", {
  ref <- ref_df()
  ref$estimate[2] <- NA
  cand <- ref
  cand$estimate[2] <- NaN
  expect_true(equiv_passed(validate(cand, ref = ref)))
  expect_false(equiv_passed(validate(cand, ref = ref, missing = "forbid")))
  expect_false(equiv_passed(validate(cand, ref = ref,
                                     missing_fields = list(estimate = "forbid"))))
  cand$estimate[2] <- 2
  res <- validate(cand, ref = ref)
  expect_equal(status_of(res, "values.missingness"), "fail")
  expect_equal(status_of(res, "values.numeric"), "pass")
})

test_that("exact fields compare character, and numeric exactly when declared", {
  cand <- ref_df()
  cand$group[3] <- "Z"
  expect_equal(status_of(validate(cand), "values.exact"), "fail")
  cand <- ref_df()
  cand$estimate[1] <- 1 + 1e-12
  expect_true(equiv_passed(validate(cand, abs_tol = 1e-8)))
  expect_false(equiv_passed(validate(cand, abs_tol = 1e-8, exact = "estimate")))
})

test_that("factor and character columns are equivalent", {
  cand <- ref_df()
  cand$group <- factor(cand$group)
  expect_true(equiv_passed(validate(cand)))
})

test_that("ignored and capture_only fields are not compared", {
  cand <- ref_df()
  cand$group <- "changed"
  cand$timestamp <- "now"
  expect_true(equiv_passed(validate(cand, ignore = c("group", "timestamp"))))
  expect_true(equiv_passed(validate(cand, capture_only = c("group", "timestamp"))))
})

test_that("schema checks report missing, extra and retyped fields", {
  cand <- ref_df()
  cand$group <- NULL
  cand$note <- "n"
  cand$estimate <- as.character(cand$estimate)
  res <- validate(cand)
  expect_equal(check_of(res, "schema.missing_fields")$diagnostics[[1]],
               list(field = "group", missing_from = "candidate"))
  expect_equal(check_of(res, "schema.extra_fields")$fields, list("note"))
  expect_equal(check_of(res, "schema.type_mismatch")$diagnostics[[1]],
               list(field = "estimate", reference_type = "numeric", candidate_type = "character"))
})

test_that("required fields must exist on both sides", {
  res <- validate(ref_df(), required = "visit")
  ch <- check_of(res, "schema.missing_fields")
  expect_equal(ch$n_mismatch, 2L)
  expect_false(equiv_passed(res))
})

test_that("all-missing columns do not trigger type mismatches", {
  ref <- ref_df()
  ref$note <- NA
  cand <- ref
  cand$note <- NA_character_
  expect_true(equiv_passed(validate(cand, ref = ref)))
})

test_that("missing key column skips alignment-dependent checks", {
  cand <- ref_df()
  cand$id <- NULL
  res <- validate(cand)
  expect_equal(status_of(res, "keys.present"), "fail")
  for (id in c("rows.missing_in_candidate", "values.numeric", "values.exact")) {
    expect_equal(status_of(res, id), "skipped")
  }
  expect_false(equiv_passed(res))
})

test_that("duplicate keys fail and skip value checks", {
  cand <- rbind(ref_df(), ref_df()[2, ])
  res <- validate(cand)
  ch <- check_of(res, "keys.unique_candidate")
  expect_equal(ch$diagnostics[[1]], list(key = list(id = "B"), count = 2L))
  expect_equal(status_of(res, "values.numeric"), "skipped")
  expect_false(equiv_passed(res))
})

test_that("missing and extra rows are reported by key", {
  cand <- ref_df()[1:2, ]
  cand <- rbind(cand, data.frame(id = "D", estimate = 4, group = "w"))
  res <- validate(cand)
  expect_equal(check_of(res, "rows.missing_in_candidate")$diagnostics[[1]]$key, list(id = "C"))
  expect_equal(check_of(res, "rows.extra_in_candidate")$diagnostics[[1]]$key, list(id = "D"))
})

test_that("composite keys and NA keys are aligned exactly", {
  ref <- data.frame(id = c("A", "A", NA), visit = c(1, 2, 1), y = c(1, 2, 3))
  cand <- ref[3:1, ]
  ct <- equiv_contract(keys = c("id", "visit"))
  expect_true(equiv_passed(equiv_validate(ref, cand, ct)))
  ref2 <- data.frame(id = c("NA", NA), y = 1:2)
  expect_equal(status_of(equiv_validate(ref2, ref2, equiv_contract(keys = "id")),
                         "keys.unique_reference"), "pass")
})

test_that("diagnostics are capped but the full count is kept", {
  ref <- data.frame(id = 1:50, y = 0)
  cand <- data.frame(id = 1:50, y = 1)
  res <- equiv_validate(ref, cand, equiv_contract(keys = "id"), max_diagnostics = 5)
  ch <- check_of(res, "values.numeric")
  expect_equal(ch$n_mismatch, 50L)
  expect_length(ch$diagnostics, 5)
  expect_equal(ch$n_diagnostics_omitted, 45L)
})
