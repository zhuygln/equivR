ref_df <- function() {
  data.frame(id = c("A", "B", "C"), estimate = c(1, 2, 3), group = c("x", "y", "z"),
             stringsAsFactors = FALSE)
}

check_of <- function(result, id) {
  result$checks[[match(id, vapply(result$checks, `[[`, "", "id"))]]
}

status_of <- function(result, id) check_of(result, id)$status

# Parsed JSON evidence without fields that legitimately vary between runs.
stable_evidence <- function(result) {
  x <- jsonlite::fromJSON(result_to_json(result), simplifyVector = FALSE)
  x$provenance <- NULL
  x$contract$source <- NULL
  x
}

write_temp_yaml <- function(lines) {
  path <- tempfile(fileext = ".yaml")
  writeLines(lines, path)
  path
}
