# Basic equivR validation scenarios. Run from the repository root after
# installing the package (R CMD INSTALL .), or with devtools::load_all().
library(equivR)

reference <- data.frame(
  id = c("A", "B", "C"),
  estimate = c(1.0, 2.0, 3.0),
  group = c("x", "y", "z"),
  stringsAsFactors = FALSE
)

contract <- equiv_contract(keys = "id", abs_tol = 1e-8, rel_tol = 1e-8)

# 1. Exact match
stopifnot(equiv_passed(equiv_validate(reference, reference, contract)))

# 2. Difference inside tolerance
within <- reference
within$estimate[2] <- within$estimate[2] + 1e-10
stopifnot(equiv_passed(equiv_validate(reference, within, contract)))

# 3. Difference outside tolerance
outside <- reference
outside$estimate[2] <- outside$estimate[2] + 1e-3
r3 <- equiv_validate(reference, outside, contract)
stopifnot(!equiv_passed(r3), "values.numeric" %in% unlist(r3$summary$failed_required))
print(r3)

# 4. Missing row
r4 <- equiv_validate(reference, reference[-3, ], contract)
stopifnot(!equiv_passed(r4), "rows.missing_in_candidate" %in% unlist(r4$summary$failed_required))

# Machine-readable evidence
evidence <- tempfile(fileext = ".json")
write_result_json(r3, evidence)
cat("Evidence written to", evidence, "\n")

cat("All equivR example checks passed.\n")
