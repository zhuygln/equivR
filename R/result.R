# Validation entry point, fail-closed aggregation, and evidence output.

RESULT_VERSION <- "equivr-result/v1"

#' Validate a candidate artifact against a trusted reference
#'
#' Runs every contract check and aggregates fail-closed: the overall status is
#' `"PASS"` only when every required check has status `"pass"`. A required
#' check that fails, is skipped, or errors makes the result `"FAIL"`. Optional
#' checks are reported but never change the status.
#'
#' @param reference,candidate A data.frame, file path, or `equiv_dataset`.
#'   When `NULL`, the artifact declared in the contract is used, resolved
#'   relative to the contract file.
#' @param contract An `equiv_contract` or a path to a contract file.
#' @param max_diagnostics Maximum diagnostics kept per check. The full count
#'   is always reported in `n_mismatch`.
#' @return An `equiv_result` object. Use [result_to_json()] or
#'   [write_result_json()] for the machine-readable form.
#' @export
equiv_validate <- function(reference = NULL, candidate = NULL, contract,
                           max_diagnostics = 20L) {
  if (is.character(contract)) contract <- read_contract(contract)
  if (!inherits(contract, "equiv_contract")) {
    stop("`contract` must be an equiv_contract or a contract file path", call. = FALSE)
  }
  ref <- resolve_artifact(reference, contract, "reference")
  cand <- resolve_artifact(candidate, contract, "candidate")

  checks <- tryCatch(
    compare_dataset(ref, cand, contract, max_diagnostics = max_diagnostics),
    error = function(e) error_checks(contract, conditionMessage(e))
  )

  failed_required <- required_failures(checks)
  failed_optional <- vapply(checks, function(ch) {
    isFALSE(ch$required) && !identical(ch$status, "pass")
  }, logical(1))
  ids <- vapply(checks, `[[`, character(1), "id")

  structure(
    list(
      schema_version = RESULT_VERSION,
      status = aggregate_status(checks),
      contract = list(
        version = contract$version,
        name = contract$name,
        source = attr(contract, "source"),
        sha256 = contract_sha256(contract)
      ),
      artifacts = list(reference = artifact_info(ref), candidate = artifact_info(cand)),
      summary = list(
        n_checks = length(checks),
        n_passed = sum(vapply(checks, function(ch) ch$status == "pass", logical(1))),
        failed_required = as.list(ids[failed_required]),
        failed_optional = as.list(ids[failed_optional])
      ),
      checks = checks,
      provenance = provenance()
    ),
    class = "equiv_result"
  )
}

#' @rdname equiv_validate
#' @description `equiv_compare()` is the original prototype name, kept as an
#'   alias of `equiv_validate()`.
#' @export
equiv_compare <- function(reference, candidate, contract) {
  equiv_validate(reference, candidate, contract)
}

#' Did a validation pass?
#'
#' @param x An `equiv_result`.
#' @return `TRUE` only when the overall status is `"PASS"`.
#' @export
equiv_passed <- function(x) {
  inherits(x, "equiv_result") && identical(x$status, "PASS")
}

#' Machine-readable validation evidence
#'
#' Serializes a result to JSON (`equivr-result/v1`). Field order is fixed, so
#' two runs on the same inputs differ only in `provenance`.
#'
#' @param x An `equiv_result`.
#' @param path Output file path.
#' @param pretty Pretty-print the JSON.
#' @return `result_to_json()` returns a JSON string; `write_result_json()`
#'   returns `path` invisibly.
#' @export
result_to_json <- function(x, pretty = TRUE) {
  stopifnot(inherits(x, "equiv_result"))
  as.character(jsonlite::toJSON(unclass(x), auto_unbox = TRUE, digits = NA,
                                pretty = pretty, null = "null", na = "null"))
}

#' @rdname result_to_json
#' @export
write_result_json <- function(x, path, pretty = TRUE) {
  writeLines(result_to_json(x, pretty = pretty), path, useBytes = TRUE)
  invisible(path)
}

#' @export
format.equiv_result <- function(x, ...) {
  lines <- c(
    paste0("equivR validation: ", x$status),
    paste0("contract:  ", x$contract$version,
           if (!is.null(x$contract$name)) paste0(" (", x$contract$name, ")"),
           "  sha256 ", substr(x$contract$sha256, 1, 12)),
    artifact_line("reference", x$artifacts$reference),
    artifact_line("candidate", x$artifacts$candidate),
    "checks:"
  )
  for (ch in x$checks) {
    tag <- switch(ch$status, pass = "pass", fail = "FAIL", skipped = "SKIP", error = "ERR ")
    lvl <- if (ch$required) "" else " (optional)"
    lines <- c(lines, sprintf("  [%s] %s%s: %s", tag, ch$id, lvl, ch$message))
    for (d in ch$diagnostics) lines <- c(lines, paste0("         - ", format_diag(d)))
    if (ch$n_diagnostics_omitted > 0) {
      lines <- c(lines, sprintf("         ... %d more", ch$n_diagnostics_omitted))
    }
  }
  lines
}

#' @export
print.equiv_result <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# ---- helpers ---------------------------------------------------------------

# Fail-closed rule: PASS only if every required check is exactly "pass".
aggregate_status <- function(checks) {
  if (any(required_failures(checks))) "FAIL" else "PASS"
}

required_failures <- function(checks) {
  vapply(checks, function(ch) !isFALSE(ch$required) && !identical(ch$status, "pass"),
         logical(1))
}

resolve_artifact <- function(x, contract, side) {
  if (!is.null(x)) return(as_equiv_dataset(x))
  desc <- contract[[side]]
  if (is.null(desc)) {
    stop("No ", side, " artifact given and none declared in the contract", call. = FALSE)
  }
  base <- attr(contract, "base_dir") %||% "."
  path <- if (grepl("^(/|~|[A-Za-z]:)", desc$path)) desc$path else file.path(base, desc$path)
  as_equiv_dataset(path, format = desc$format, source = desc$path)
}

artifact_info <- function(ds) {
  list(source = ds$source, format = ds$format, sha256 = ds$sha256,
       n_rows = nrow(ds$data), n_cols = ncol(ds$data),
       columns = as.list(names(ds$data)))
}

error_checks <- function(contract, message) {
  lapply(unname(CHECK_IDS), function(id) list(
    id = id,
    required = identical(check_level(contract, id), "required"),
    status = "error", n_mismatch = 0L, fields = list(),
    message = paste0("Validation error: ", message),
    diagnostics = list(), n_diagnostics_omitted = 0L
  ))
}

provenance <- function() {
  list(
    equivR_version = as.character(utils::packageVersion("equivR")),
    r_version = R.version.string,
    platform = R.version$platform,
    source_revision = git_revision(),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

git_revision <- function() {
  rev <- tryCatch(
    suppressWarnings(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
    error = function(e) character()
  )
  if (length(rev) == 1L && grepl("^[0-9a-f]{40}$", rev)) rev else NULL
}

artifact_line <- function(label, a) {
  sprintf("%-10s %s (%d rows x %d cols)  sha256 %s", paste0(label, ":"), a$source,
          a$n_rows, a$n_cols, substr(a$sha256, 1, 12))
}

format_diag <- function(d) {
  show <- function(v) if (length(v) == 1L && is.na(v)) "NA" else format(v, digits = 15)
  parts <- character()
  if (!is.null(d$field)) parts <- c(parts, d$field)
  if (!is.null(d$key)) {
    parts <- c(parts, paste0("@ ", paste(names(d$key), vapply(d$key, show, ""), sep = "=",
                                       collapse = ", ")))
  }
  for (nm in setdiff(names(d), c("field", "key"))) {
    parts <- c(parts, paste0(nm, "=", show(d[[nm]])))
  }
  paste(parts, collapse = " ")
}
