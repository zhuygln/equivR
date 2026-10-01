# Deterministic dataset comparison. Every check in CHECK_IDS is evaluated and
# returned in a fixed order; nothing here decides overall acceptance.

compare_dataset <- function(ref, cand, contract, max_diagnostics = 20L) {
  r <- ref$data
  cd <- cand$data
  keys <- contract$keys
  excluded <- c(contract$fields$ignore, contract$fields$capture_only)
  ref_cols <- setdiff(names(r), excluded)
  cand_cols <- setdiff(names(cd), excluded)
  comparable <- intersect(ref_cols, cand_cols)

  acc <- lapply(stats::setNames(CHECK_IDS, CHECK_IDS), function(id) new_acc(max_diagnostics))
  skipped <- list()

  # -- schema ---------------------------------------------------------------
  for (f in setdiff(ref_cols, cand_cols)) {
    acc_add(acc$schema.missing_fields, f, list(field = f, missing_from = "candidate"))
  }
  for (f in contract$fields$required) {
    for (side in c("reference", "candidate")) {
      present <- if (side == "reference") names(r) else names(cd)
      already <- side == "candidate" && f %in% setdiff(ref_cols, cand_cols)
      if (!f %in% present && !already) {
        acc_add(acc$schema.missing_fields, f, list(field = f, missing_from = side))
      }
    }
  }
  for (f in setdiff(cand_cols, ref_cols)) {
    acc_add(acc$schema.extra_fields, f, list(field = f))
  }
  for (f in comparable) {
    tr <- canonical_type(r[[f]])
    tc <- canonical_type(cd[[f]])
    if (tr != "unknown" && tc != "unknown" && tr != tc) {
      acc_add(acc$schema.type_mismatch, f,
              list(field = f, reference_type = tr, candidate_type = tc))
    }
  }

  # -- keys -----------------------------------------------------------------
  for (k in keys) {
    if (!k %in% names(r)) acc_add(acc$keys.present, k, list(field = k, missing_from = "reference"))
    if (!k %in% names(cd)) acc_add(acc$keys.present, k, list(field = k, missing_from = "candidate"))
  }

  if (acc$keys.present$n > 0L) {
    reason <- "key column(s) unavailable; rows cannot be aligned"
    for (id in c("keys.unique_reference", "keys.unique_candidate",
                 "rows.missing_in_candidate", "rows.extra_in_candidate",
                 "values.missingness", "values.exact", "values.numeric")) {
      skipped[[id]] <- reason
    }
    return(finish_checks(acc, skipped, contract))
  }

  rk <- encode_keys(r, keys)
  ck <- encode_keys(cd, keys)
  add_duplicates(acc$keys.unique_reference, r, keys, rk)
  add_duplicates(acc$keys.unique_candidate, cd, keys, ck)

  # -- rows -----------------------------------------------------------------
  for (i in which(!duplicated(rk) & !rk %in% ck)) {
    acc_add(acc$rows.missing_in_candidate, NULL, list(key = key_values(r, keys, i)))
  }
  for (i in which(!duplicated(ck) & !ck %in% rk)) {
    acc_add(acc$rows.extra_in_candidate, NULL, list(key = key_values(cd, keys, i)))
  }

  # -- values ---------------------------------------------------------------
  if (anyDuplicated(rk) || anyDuplicated(ck)) {
    reason <- "duplicate keys make row alignment ambiguous"
    for (id in c("values.missingness", "values.exact", "values.numeric")) skipped[[id]] <- reason
    return(finish_checks(acc, skipped, contract))
  }

  ri <- which(rk %in% ck)
  ci <- match(rk[ri], ck)

  for (f in setdiff(comparable, keys)) {
    a <- r[[f]][ri]
    b <- cd[[f]][ci]
    na_a <- is.na(a)
    na_b <- is.na(b)
    rule <- contract$missing$fields[[f]] %||% contract$missing$default
    miss_bad <- if (rule == "forbid") na_a | na_b else xor(na_a, na_b)
    for (j in which(miss_bad)) {
      acc_add(acc$values.missingness, f, value_diag(f, r, keys, ri[j], a[j], b[j]))
    }

    keep <- which(!na_a & !na_b)
    if (!length(keep)) next
    a <- a[keep]
    b <- b[keep]
    rows <- ri[keep]

    if (is.numeric(a) && is.numeric(b) && !f %in% contract$fields$exact) {
      tol <- field_tolerance(contract, f)
      same <- a == b
      delta <- ifelse(same, 0, abs(a - b))
      allowed <- tol$abs + tol$rel * abs(a)
      bad <- !same & ((is.infinite(a) | is.infinite(b)) | delta > allowed)
      for (j in which(bad)) {
        d <- value_diag(f, r, keys, rows[j], a[j], b[j])
        d$delta <- json_value(delta[j])
        d$tolerance <- if (is.finite(allowed[j])) allowed[j] else NA
        acc_add(acc$values.numeric, f, d)
      }
    } else {
      bad <- if (is.numeric(a) && is.numeric(b)) a != b else compare_string(a) != compare_string(b)
      for (j in which(bad)) {
        acc_add(acc$values.exact, f, value_diag(f, r, keys, rows[j], a[j], b[j]))
      }
    }
  }

  finish_checks(acc, skipped, contract)
}

# ---- accumulators ----------------------------------------------------------

new_acc <- function(max_diagnostics) {
  env <- new.env(parent = emptyenv())
  env$n <- 0L
  env$fields <- character()
  env$diagnostics <- list()
  env$max <- max_diagnostics
  env
}

acc_add <- function(acc, field, diagnostic) {
  acc$n <- acc$n + 1L
  if (!is.null(field) && !field %in% acc$fields) acc$fields <- c(acc$fields, field)
  if (length(acc$diagnostics) < acc$max) {
    acc$diagnostics[[length(acc$diagnostics) + 1L]] <- diagnostic
  }
}

finish_checks <- function(acc, skipped, contract) {
  lapply(unname(CHECK_IDS), function(id) {
    a <- acc[[id]]
    status <- if (!is.null(skipped[[id]])) "skipped" else if (a$n > 0L) "fail" else "pass"
    list(
      id = id,
      required = identical(check_level(contract, id), "required"),
      status = status,
      n_mismatch = a$n,
      fields = as.list(a$fields),
      message = check_message(id, status, a, skipped[[id]]),
      diagnostics = a$diagnostics,
      n_diagnostics_omitted = a$n - length(a$diagnostics)
    )
  })
}

check_message <- function(id, status, acc, skip_reason) {
  if (status == "skipped") return(paste0("Not evaluated: ", skip_reason, "."))
  if (status == "pass") return("OK")
  what <- switch(id,
    schema.missing_fields = "required/reference field(s) missing",
    schema.extra_fields = "extra candidate field(s)",
    schema.type_mismatch = "field(s) with mismatched types",
    keys.present = "key column(s) missing",
    keys.unique_reference = "duplicated key value(s) in reference",
    keys.unique_candidate = "duplicated key value(s) in candidate",
    rows.missing_in_candidate = "reference row(s) missing in candidate",
    rows.extra_in_candidate = "extra candidate row(s)",
    values.missingness = "missing-value mismatch(es)",
    values.exact = "exact-value mismatch(es)",
    values.numeric = "numeric value(s) outside tolerance"
  )
  msg <- paste(acc$n, what)
  if (length(acc$fields) && startsWith(id, "values.")) {
    msg <- paste0(msg, " in: ", paste(acc$fields, collapse = ", "))
  }
  paste0(msg, ".")
}

# ---- keys and values -------------------------------------------------------

# Encode composite keys as strings. NA is encoded distinctly from the string "NA".
encode_keys <- function(df, keys) {
  parts <- lapply(keys, function(k) {
    v <- df[[k]]
    s <- compare_string(v)
    s[is.na(v)] <- "\001NA"
    s
  })
  do.call(paste, c(parts, sep = "\r"))
}

add_duplicates <- function(acc, df, keys, encoded) {
  dup <- unique(encoded[duplicated(encoded)])
  for (k in dup) {
    i <- match(k, encoded)
    acc_add(acc, NULL, list(key = key_values(df, keys, i), count = sum(encoded == k)))
  }
}

key_values <- function(df, keys, i) {
  stats::setNames(lapply(keys, function(k) json_value(df[[k]][i])), keys)
}

value_diag <- function(field, df, keys, i, a, b) {
  list(field = field, key = key_values(df, keys, i),
       reference = json_value(a), candidate = json_value(b))
}

field_tolerance <- function(contract, field) {
  per <- contract$tolerance$fields[[field]] %||% list()
  list(abs = per$abs %||% contract$tolerance$abs,
       rel = per$rel %||% contract$tolerance$rel)
}

compare_string <- function(v) {
  if (inherits(v, "POSIXt")) return(format(v, "%Y-%m-%dT%H:%M:%OS6%z"))
  as.character(v)
}

json_value <- function(v) {
  if (length(v) != 1L || is.na(v)) return(NA)
  # JSON has no infinity; keep it distinguishable from missing (null).
  if (is.numeric(v) && is.infinite(v)) return(if (v > 0) "Inf" else "-Inf")
  if (is.numeric(v) || is.logical(v)) return(unname(v))
  if (inherits(v, "Date") || inherits(v, "POSIXt")) return(compare_string(v))
  as.character(v)
}
