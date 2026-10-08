test_that("equiv_contract builds a v1 contract with defaults", {
  ct <- equiv_contract(keys = "id")
  expect_s3_class(ct, "equiv_contract")
  expect_equal(ct$version, "equivr-contract/v1")
  expect_equal(ct$missing$default, "match")
  expect_equal(ct$tolerance$abs, 0)
  expect_setequal(names(ct$checks), equiv_check_ids())
  expect_true(all(unlist(ct$checks) == "required"))
})

test_that("read_contract parses YAML and resolves numeric strings", {
  path <- write_temp_yaml(c(
    "version: equivr-contract/v1",
    "keys: [id, visit]",
    "tolerance:",
    "  abs: 1e-6",
    "  fields:",
    "    estimate: {rel: 0.01}",
    "missing:",
    "  fields:",
    "    estimate: forbid",
    "checks:",
    "  schema.extra_fields: optional"
  ))
  ct <- read_contract(path)
  expect_equal(ct$keys, c("id", "visit"))
  expect_equal(ct$tolerance$abs, 1e-6)
  expect_equal(ct$tolerance$fields$estimate, list(rel = 0.01))
  expect_equal(ct$missing$fields$estimate, "forbid")
  expect_equal(ct$checks$schema.extra_fields, "optional")
  expect_equal(attr(ct, "source"), path)
})

test_that("YAML 1.1 boolean words stay column names", {
  ct <- read_contract(write_temp_yaml(c(
    "version: equivr-contract/v1",
    "keys: [Y, ON]",
    "fields:",
    "  exact: [N, no, off]"
  )))
  expect_equal(ct$keys, c("Y", "ON"))
  expect_equal(ct$fields$exact, c("N", "no", "off"))
})

test_that("invalid contracts are rejected", {
  bad <- function(...) expect_error(equivR:::as_contract(list(...)), "Invalid equivR contract")
  bad(keys = "id")                                                   # no version
  bad(version = "equivr-contract/v2", keys = "id")
  bad(version = "equivr-contract/v1", keys = character())
  bad(version = "equivr-contract/v1", keys = "id", typo = 1)
  bad(version = "equivr-contract/v1", keys = "id", tolerance = list(abs = -1))
  bad(version = "equivr-contract/v1", keys = "id", tolerance = list(abs = "x"))
  bad(version = "equivr-contract/v1", keys = "id", missing = list(default = "ignore"))
  bad(version = "equivr-contract/v1", keys = "id", checks = list(values.fuzzy = "optional"))
  bad(version = "equivr-contract/v1", keys = "id", checks = list(values.exact = "maybe"))
  bad(version = "equivr-contract/v1", keys = "id", fields = list(ignore = "id"))
  bad(version = "equivr-contract/v1", keys = "id", fields = list(skip = "x"))
  bad(version = "equivr-contract/v1", keys = "id", results = list(list(name = "est")))
  bad(version = "equivr-contract/v1", keys = "id", reference = list(path = "a.sas7bdat",
                                                                    format = "sas7bdat"))
})

test_that("contract hash ignores YAML layout but tracks content", {
  a <- equiv_contract(keys = "id", field_tolerance = list(b = list(abs = 1), a = list(abs = 2)))
  b <- equiv_contract(keys = "id", field_tolerance = list(a = list(abs = 2), b = list(abs = 1)))
  c <- equiv_contract(keys = "id", abs_tol = 1e-9)
  expect_equal(equivR:::contract_sha256(a), equivR:::contract_sha256(b))
  expect_false(equivR:::contract_sha256(a) == equivR:::contract_sha256(c))
})

test_that("shipped example contracts are valid", {
  dir <- test_path("..", "..", "examples", "contracts")
  skip_if_not(dir.exists(dir), "examples/ not available (installed package check)")
  for (f in list.files(dir, pattern = "\\.yaml$", full.names = TRUE)) {
    expect_s3_class(read_contract(f), "equiv_contract")
  }
})
