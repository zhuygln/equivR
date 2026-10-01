source("R/equivR.R")

reference <- data.frame(
  id = c("A", "B", "C"),
  estimate = c(1.0, 2.0, 3.0),
  group = c("x", "y", "z"),
  stringsAsFactors = FALSE
)

contract <- equiv_contract(keys = "id", abs_tol = 1e-8, rel_tol = 1e-8)

# 1. Exact match
r1 <- equiv_compare(reference, reference, contract)
stopifnot(r1$pass)

# 2. Difference inside tolerance
within <- reference
within$estimate[2] <- within$estimate[2] + 1e-10
r2 <- equiv_compare(reference, within, contract)
stopifnot(r2$pass)

# 3. Difference outside tolerance
outside <- reference
outside$estimate[2] <- outside$estimate[2] + 1e-3
r3 <- equiv_compare(reference, outside, contract)
stopifnot(!r3$pass)
stopifnot(any(vapply(r3$failures, function(x) identical(x$type, "numeric"), logical(1))))

# 4. Missing row
missing <- reference[-3, ]
r4 <- equiv_compare(reference, missing, contract)
stopifnot(!r4$pass)
stopifnot(any(vapply(r4$failures, function(x) identical(x$type, "rows"), logical(1))))

cat("All equivR prototype checks passed.\n")
