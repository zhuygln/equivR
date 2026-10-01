# Equivalence contract (equivr-contract/v1): construction, parsing, validation.

CONTRACT_VERSION <- "equivr-contract/v1"

CONTRACT_TOP_FIELDS <- c(
  "version", "name", "description", "reference", "candidate", "keys",
  "fields", "missing", "tolerance", "checks", "results"
)

CHECK_IDS <- c(
  "schema.missing_fields",
  "schema.extra_fields",
  "schema.type_mismatch",
  "keys.present",
  "keys.unique_reference",
  "keys.unique_candidate",
  "rows.missing_in_candidate",
  "rows.extra_in_candidate",
  "values.missingness",
  "values.exact",
  "values.numeric"
)

#' Check identifiers defined by contract v1
#'
#' Every check is required unless the contract's `checks` section marks it
#' `optional`. Checks are always evaluated and reported in this order.
#'
#' @return A character vector of check ids.
#' @export
equiv_check_ids <- function() CHECK_IDS

#' Build an equivalence contract in R
#'
#' Creates an `equivr-contract/v1` contract without a YAML file. The first
#' four arguments match the original prototype.
#'
#' @param keys Character vector of row-key columns.
#' @param abs_tol,rel_tol Default numeric tolerances. A numeric value passes
#'   when `abs(reference - candidate) <= abs_tol + rel_tol * abs(reference)`.
#' @param ignore Columns excluded from comparison.
#' @param required Columns that must exist in both artifacts.
#' @param exact Columns compared exactly even when numeric.
#' @param capture_only Columns recorded as present but not compared.
#' @param missing Default missing-value rule: `"match"` (missing must be
#'   missing on both sides) or `"forbid"` (no missing values allowed).
#' @param missing_fields Named list of per-column missing-value rules.
#' @param field_tolerance Named list of per-column `list(abs =, rel =)`.
#' @param checks Named list mapping check ids to `"required"` or `"optional"`.
#' @param name,description Optional labels.
#' @return An `equiv_contract` object.
#' @export
equiv_contract <- function(keys, abs_tol = 0, rel_tol = 0, ignore = character(),
                           required = character(), exact = character(),
                           capture_only = character(), missing = "match",
                           missing_fields = list(), field_tolerance = list(),
                           checks = list(), name = NULL, description = NULL) {
  as_contract(list(
    version = CONTRACT_VERSION,
    name = name,
    description = description,
    keys = keys,
    fields = list(
      required = required, ignore = ignore, exact = exact,
      capture_only = capture_only
    ),
    missing = list(default = missing, fields = missing_fields),
    tolerance = list(abs = abs_tol, rel = rel_tol, fields = field_tolerance),
    checks = checks
  ))
}

#' Read an equivalence contract from YAML or JSON
#'
#' Artifact paths in the contract are resolved relative to the contract file.
#'
#' @param path Path to a `.yaml`, `.yml` or `.json` contract.
#' @return An `equiv_contract` object.
#' @export
read_contract <- function(path) {
  if (!file.exists(path)) stop("Contract file not found: ", path, call. = FALSE)
  raw <- if (grepl("\\.json$", path, ignore.case = TRUE)) {
    jsonlite::read_json(path, simplifyVector = TRUE)
  } else {
    yaml::read_yaml(path, handlers = YAML_BOOL_HANDLERS)
  }
  if (!is.list(raw)) stop("Contract must be a mapping: ", path, call. = FALSE)
  contract <- as_contract(raw)
  attr(contract, "source") <- path
  attr(contract, "base_dir") <- dirname(path)
  contract
}

# YAML 1.1 turns y/n/yes/no/on/off into booleans, which corrupts column names
# such as `N` or `Y`. Only true/false are booleans in a contract.
yaml_bool <- function(x) {
  if (x %in% c("true", "True", "TRUE")) return(TRUE)
  if (x %in% c("false", "False", "FALSE")) return(FALSE)
  x
}
YAML_BOOL_HANDLERS <- list("bool#yes" = yaml_bool, "bool#no" = yaml_bool)

# Normalize a raw list into a fully populated, validated contract.
as_contract <- function(x) {
  unknown <- setdiff(names(x), CONTRACT_TOP_FIELDS)
  if (length(unknown)) {
    contract_error("unknown top-level field(s): ", paste(unknown, collapse = ", "))
  }
  if (!identical(x$version, CONTRACT_VERSION)) {
    contract_error("`version` must be \"", CONTRACT_VERSION, "\", got: ",
                   if (is.null(x$version)) "<missing>" else format(x$version))
  }

  fields <- x$fields %||% list()
  check_subfields(fields, c("required", "ignore", "exact", "capture_only"), "fields")
  missing <- x$missing %||% list()
  check_subfields(missing, c("default", "fields"), "missing")
  tolerance <- x$tolerance %||% list()
  check_subfields(tolerance, c("abs", "rel", "fields"), "tolerance")

  contract <- list(
    version = CONTRACT_VERSION,
    name = as_scalar_string(x$name, "name"),
    description = as_scalar_string(x$description, "description"),
    reference = as_descriptor(x$reference, "reference"),
    candidate = as_descriptor(x$candidate, "candidate"),
    keys = as_names(x$keys, "keys"),
    fields = list(
      required = as_names(fields$required, "fields.required"),
      ignore = as_names(fields$ignore, "fields.ignore"),
      exact = as_names(fields$exact, "fields.exact"),
      capture_only = as_names(fields$capture_only, "fields.capture_only")
    ),
    missing = list(
      default = as_missing_rule(missing$default %||% "match", "missing.default"),
      fields = sort_named(lapply_named(as_named_list(missing$fields, "missing.fields"),
                                       function(nm, v) as_missing_rule(v, paste0("missing.fields.", nm))))
    ),
    tolerance = list(
      abs = as_tolerance(tolerance$abs %||% 0, "tolerance.abs"),
      rel = as_tolerance(tolerance$rel %||% 0, "tolerance.rel"),
      fields = sort_named(lapply_named(as_named_list(tolerance$fields, "tolerance.fields"),
                                       function(nm, v) as_field_tolerance(v, nm)))
    ),
    checks = as_check_levels(x$checks),
    results = list()
  )

  if (!length(contract$keys)) contract_error("`keys` must name at least one column")
  excluded <- c(contract$fields$ignore, contract$fields$capture_only)
  bad_keys <- intersect(contract$keys, excluded)
  if (length(bad_keys)) {
    contract_error("key column(s) cannot be ignored or capture_only: ",
                   paste(bad_keys, collapse = ", "))
  }
  if (length(x$results)) {
    contract_error("`results` (structured analytical results) is reserved in v1 ",
                   "and not yet supported; remove it or leave it empty")
  }

  structure(contract, class = "equiv_contract")
}

#' @export
print.equiv_contract <- function(x, ...) {
  cat("<equiv_contract ", x$version, ">\n", sep = "")
  if (!is.null(x$name)) cat("  name:      ", x$name, "\n", sep = "")
  cat("  keys:      ", paste(x$keys, collapse = ", "), "\n", sep = "")
  cat("  tolerance: abs=", format(x$tolerance$abs), " rel=", format(x$tolerance$rel),
      "\n", sep = "")
  cat("  missing:   ", x$missing$default, "\n", sep = "")
  optional <- names(x$checks)[unlist(x$checks) == "optional"]
  if (length(optional)) cat("  optional:  ", paste(optional, collapse = ", "), "\n", sep = "")
  invisible(x)
}

# Canonical sha256 of the normalized contract (independent of YAML layout).
contract_sha256 <- function(contract) {
  sha256_text(canonical_json(unclass(contract)))
}

# Requirement level ("required"/"optional") for a check id.
check_level <- function(contract, id) contract$checks[[id]]

# ---- helpers ---------------------------------------------------------------

contract_error <- function(...) {
  stop("Invalid equivR contract: ", ..., call. = FALSE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

check_subfields <- function(x, allowed, where) {
  if (!is.list(x)) contract_error("`", where, "` must be a mapping")
  unknown <- setdiff(names(x), allowed)
  if (length(unknown)) {
    contract_error("unknown field(s) in `", where, "`: ", paste(unknown, collapse = ", "))
  }
}

as_scalar_string <- function(x, where) {
  if (is.null(x)) return(NULL)
  if (!is.character(x) || length(x) != 1L) contract_error("`", where, "` must be a string")
  x
}

as_names <- function(x, where) {
  if (is.null(x) || (is.list(x) && !length(x))) return(character())
  x <- unlist(x, use.names = FALSE)
  if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
    contract_error("`", where, "` must be a list of column names")
  }
  if (anyDuplicated(x)) contract_error("`", where, "` contains duplicate names")
  x
}

as_named_list <- function(x, where) {
  if (is.null(x) || !length(x)) return(list())
  if (!is.list(x) && !is.atomic(x)) contract_error("`", where, "` must be a mapping")
  x <- as.list(x)
  if (is.null(names(x)) || any(!nzchar(names(x)))) {
    contract_error("`", where, "` must be a mapping of column name to value")
  }
  x
}

lapply_named <- function(x, f) {
  out <- lapply(names(x), function(nm) f(nm, x[[nm]]))
  names(out) <- names(x)
  out
}

sort_named <- function(x) if (length(x)) x[order(names(x), method = "radix")] else x

as_missing_rule <- function(x, where) {
  if (!is.character(x) || length(x) != 1L || !x %in% c("match", "forbid")) {
    contract_error("`", where, "` must be \"match\" or \"forbid\"")
  }
  x
}

# YAML 1.1 reads "1e-8" (no decimal point) as a string, so accept numeric strings.
as_tolerance <- function(x, where) {
  value <- suppressWarnings(as.numeric(x))
  if (length(value) != 1L || is.na(value) || !is.finite(value) || value < 0) {
    contract_error("`", where, "` must be a single non-negative number")
  }
  value
}

as_field_tolerance <- function(x, field) {
  if (!is.list(x)) contract_error("`tolerance.fields.", field, "` must be a mapping")
  check_subfields(x, c("abs", "rel"), paste0("tolerance.fields.", field))
  out <- list()
  if (!is.null(x$abs)) out$abs <- as_tolerance(x$abs, paste0("tolerance.fields.", field, ".abs"))
  if (!is.null(x$rel)) out$rel <- as_tolerance(x$rel, paste0("tolerance.fields.", field, ".rel"))
  out
}

as_check_levels <- function(x) {
  x <- as_named_list(x, "checks")
  unknown <- setdiff(names(x), CHECK_IDS)
  if (length(unknown)) contract_error("unknown check id(s): ", paste(unknown, collapse = ", "))
  levels <- stats::setNames(as.list(rep("required", length(CHECK_IDS))), CHECK_IDS)
  for (id in names(x)) {
    v <- x[[id]]
    if (!is.character(v) || length(v) != 1L || !v %in% c("required", "optional")) {
      contract_error("`checks.", id, "` must be \"required\" or \"optional\"")
    }
    levels[[id]] <- v
  }
  levels
}

as_descriptor <- function(x, where) {
  if (is.null(x)) return(NULL)
  if (is.character(x) && length(x) == 1L) x <- list(path = x)
  if (!is.list(x)) contract_error("`", where, "` must be a mapping with `path`")
  check_subfields(x, c("path", "format", "description"), where)
  path <- as_scalar_string(x$path, paste0(where, ".path"))
  if (is.null(path)) contract_error("`", where, ".path` is required")
  format <- x$format %||% infer_format(path)
  if (!format %in% SUPPORTED_FORMATS) {
    contract_error("`", where, ".format` must be one of: ",
                   paste(SUPPORTED_FORMATS, collapse = ", "))
  }
  list(path = path, format = format,
       description = as_scalar_string(x$description, paste0(where, ".description")))
}
