# Minimal equivR prototype
# Base R only. This is intentionally small and exists to demonstrate
# fail-closed acceptance semantics for the ISC proposal.

equiv_contract <- function(keys, abs_tol = 0, rel_tol = 0, ignore = character()) {
  stopifnot(length(keys) >= 1, abs_tol >= 0, rel_tol >= 0)
  structure(
    list(keys = keys, abs_tol = abs_tol, rel_tol = rel_tol, ignore = ignore),
    class = "equiv_contract"
  )
}

.equiv_key <- function(x, keys) {
  if (!all(keys %in% names(x))) {
    stop("Missing key column(s): ", paste(setdiff(keys, names(x)), collapse = ", "))
  }
  do.call(paste, c(x[keys], sep = "\r"))
}

equiv_compare <- function(reference, candidate, contract) {
  stopifnot(is.data.frame(reference), is.data.frame(candidate),
            inherits(contract, "equiv_contract"))

  ignored <- unique(contract$ignore)
  ref_cols <- setdiff(names(reference), ignored)
  cand_cols <- setdiff(names(candidate), ignored)

  failures <- list()

  missing_in_candidate <- setdiff(ref_cols, cand_cols)
  extra_in_candidate <- setdiff(cand_cols, ref_cols)
  if (length(missing_in_candidate)) {
    failures[[length(failures) + 1]] <- list(
      type = "schema", detail = paste("Missing columns:", paste(missing_in_candidate, collapse = ", "))
    )
  }
  if (length(extra_in_candidate)) {
    failures[[length(failures) + 1]] <- list(
      type = "schema", detail = paste("Extra columns:", paste(extra_in_candidate, collapse = ", "))
    )
  }

  comparable <- intersect(ref_cols, cand_cols)
  if (!all(contract$keys %in% comparable)) {
    failures[[length(failures) + 1]] <- list(
      type = "key", detail = "One or more key columns are unavailable after schema comparison."
    )
    return(structure(list(pass = FALSE, failures = failures), class = "equiv_result"))
  }

  rk <- .equiv_key(reference, contract$keys)
  ck <- .equiv_key(candidate, contract$keys)

  if (anyDuplicated(rk)) {
    failures[[length(failures) + 1]] <- list(type = "key", detail = "Reference keys are not unique.")
  }
  if (anyDuplicated(ck)) {
    failures[[length(failures) + 1]] <- list(type = "key", detail = "Candidate keys are not unique.")
  }

  missing_rows <- setdiff(rk, ck)
  extra_rows <- setdiff(ck, rk)
  if (length(missing_rows)) {
    failures[[length(failures) + 1]] <- list(
      type = "rows", detail = paste(length(missing_rows), "reference row(s) missing in candidate.")
    )
  }
  if (length(extra_rows)) {
    failures[[length(failures) + 1]] <- list(
      type = "rows", detail = paste(length(extra_rows), "extra candidate row(s).")
    )
  }

  common_keys <- intersect(rk, ck)
  if (length(common_keys)) {
    ri <- match(common_keys, rk)
    ci <- match(common_keys, ck)

    for (nm in setdiff(comparable, contract$keys)) {
      a <- reference[[nm]][ri]
      b <- candidate[[nm]][ci]

      both_na <- is.na(a) & is.na(b)
      one_na <- xor(is.na(a), is.na(b))
      if (any(one_na)) {
        failures[[length(failures) + 1]] <- list(
          type = "missingness", variable = nm,
          detail = paste(sum(one_na), "missing-value mismatch(es).")
        )
      }

      keep <- !(both_na | one_na)
      if (!any(keep)) next

      if (is.numeric(a) && is.numeric(b)) {
        delta <- abs(a[keep] - b[keep])
        tol <- contract$abs_tol + contract$rel_tol * abs(a[keep])
        bad <- which(delta > tol)
        if (length(bad)) {
          failures[[length(failures) + 1]] <- list(
            type = "numeric", variable = nm,
            max_delta = max(delta[bad]),
            detail = paste(length(bad), "value(s) outside tolerance.")
          )
        }
      } else {
        bad <- which(as.character(a[keep]) != as.character(b[keep]))
        if (length(bad)) {
          failures[[length(failures) + 1]] <- list(
            type = "value", variable = nm,
            detail = paste(length(bad), "exact-value mismatch(es).")
          )
        }
      }
    }
  }

  structure(
    list(pass = length(failures) == 0, failures = failures),
    class = "equiv_result"
  )
}

print.equiv_result <- function(x, ...) {
  cat(if (x$pass) "PASS\n" else "FAIL\n")
  if (!x$pass) {
    for (f in x$failures) {
      variable <- if (!is.null(f$variable)) paste0(" [", f$variable, "]") else ""
      cat("-", f$type, variable, ":", f$detail, "\n")
    }
  }
  invisible(x)
}
