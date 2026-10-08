# Artifact normalization: turn a data.frame or file into a canonical dataset.
# M1 covers tabular artifacts only; cross-runtime adapters arrive in M2.

SUPPORTED_FORMATS <- c("csv", "rds")

#' Normalize a tabular artifact
#'
#' Reads a data.frame, CSV file or RDS file into the canonical comparison
#' form: a plain data.frame with factors converted to character, plus a
#' sha256 checksum. File artifacts are hashed byte-for-byte; in-memory
#' data.frames are hashed from a canonical JSON serialization.
#'
#' CSV files are read with empty strings and `NA` treated as missing.
#'
#' @param x A data.frame, an existing `equiv_dataset`, or a file path.
#' @param format File format (`"csv"` or `"rds"`); inferred from the extension
#'   when `NULL`.
#' @param source Label recorded in evidence. Defaults to the path, or
#'   `"<data.frame>"` for in-memory data.
#' @return An `equiv_dataset` object.
#' @export
as_equiv_dataset <- function(x, format = NULL, source = NULL) {
  if (inherits(x, "equiv_dataset")) return(x)

  if (is.character(x) && length(x) == 1L) {
    if (!file.exists(x)) stop("Artifact file not found: ", x, call. = FALSE)
    format <- format %||% infer_format(x)
    data <- switch(format,
      csv = utils::read.csv(x, stringsAsFactors = FALSE, check.names = FALSE,
                            na.strings = c("", "NA"), strip.white = FALSE),
      rds = readRDS(x),
      stop("Unsupported artifact format: ", format, call. = FALSE)
    )
    if (!is.data.frame(data)) stop("Artifact is not tabular: ", x, call. = FALSE)
    data <- canonicalize_frame(data)
    return(new_equiv_dataset(data, source %||% x, format,
                             digest::digest(file = x, algo = "sha256")))
  }

  if (!is.data.frame(x)) {
    stop("Artifact must be a data.frame or a file path", call. = FALSE)
  }
  data <- canonicalize_frame(x)
  new_equiv_dataset(data, source %||% "<data.frame>", "data.frame", frame_sha256(data))
}

new_equiv_dataset <- function(data, source, format, sha256) {
  structure(
    list(data = data, source = source, format = format, sha256 = sha256),
    class = "equiv_dataset"
  )
}

#' @export
print.equiv_dataset <- function(x, ...) {
  cat("<equiv_dataset ", x$source, ": ", nrow(x$data), " rows x ",
      ncol(x$data), " cols, sha256 ", substr(x$sha256, 1, 12), ">\n", sep = "")
  invisible(x)
}

canonicalize_frame <- function(x) {
  x <- as.data.frame(x, stringsAsFactors = FALSE, optional = TRUE)
  if (anyDuplicated(names(x))) {
    stop("Artifact has duplicate column names: ",
         paste(unique(names(x)[duplicated(names(x))]), collapse = ", "), call. = FALSE)
  }
  for (nm in names(x)) {
    if (is.factor(x[[nm]])) x[[nm]] <- as.character(x[[nm]])
  }
  rownames(x) <- NULL
  x
}

# Canonical type used by schema.type_mismatch. All-missing columns are
# "unknown" because CSV readers cannot infer a type for them.
canonical_type <- function(v) {
  if (all(is.na(v))) return("unknown")
  if (inherits(v, "Date")) return("date")
  if (inherits(v, "POSIXt")) return("datetime")
  if (is.logical(v)) return("logical")
  if (is.numeric(v)) return("numeric")
  if (is.character(v)) return("character")
  "other"
}

infer_format <- function(path) {
  ext <- tolower(sub(".*\\.", "", basename(path)))
  if (ext %in% SUPPORTED_FORMATS) ext else "csv"
}

frame_sha256 <- function(data) {
  types <- vapply(data, canonical_type, character(1))
  sha256_text(canonical_json(list(columns = names(data), types = unname(types),
                                  data = unname(as.list(data)))))
}

sha256_text <- function(text) digest::digest(text, algo = "sha256", serialize = FALSE)

canonical_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA, null = "null",
                                na = "null", Date = "ISO8601", POSIXt = "ISO8601"))
}
