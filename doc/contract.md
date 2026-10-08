# equivR contract v1 (`equivr-contract/v1`)

An equivalence contract declares, before validation runs, exactly what must hold for a candidate artifact to be accepted as equivalent to a trusted reference. Acceptance is decided only by deterministic checks against this contract. No claim is made beyond what the contract declares.

Machine-readable schema: [`schemas/contract-v1.schema.json`](../schemas/contract-v1.schema.json).

## Example

```yaml
version: equivr-contract/v1
name: legacy-r-to-modern-r
reference: {path: reference/adsl.csv, format: csv}
candidate: {path: candidate/adsl.csv, format: csv}
keys: [USUBJID]
fields:
  required: [USUBJID, ARM, AGE]
  exact: [AGE]
  ignore: [CREATED_AT]
  capture_only: [PROGRAM]
missing:
  default: match
  fields: {ARM: forbid}
tolerance:
  abs: 1.0e-10
  rel: 1.0e-12
  fields: {SD: {abs: 1.0e-6}}
checks:
  schema.extra_fields: optional
```

More complete examples for the two Phase 1 benchmark classes are in [`examples/contracts/`](../examples/contracts/).

## Fields

| Field | Meaning |
|---|---|
| `version` | Must be `equivr-contract/v1`. Unknown versions are rejected. |
| `name`, `description` | Free-text labels, recorded in the evidence. |
| `reference`, `candidate` | Artifact descriptors: a path string or `{path, format, description}`. Paths are relative to the contract file. Formats: `csv`, `rds`. Optional when artifacts are passed directly to `equiv_validate()`. |
| `keys` | Column(s) that identify a row. Rows are aligned by key, never by position. Required. |
| `fields.required` | Columns that must exist in both artifacts. |
| `fields.exact` | Columns compared exactly even when numeric. |
| `fields.ignore` | Columns excluded from all checks. |
| `fields.capture_only` | Columns recorded in the artifact column list but not compared (e.g. program name). |
| `missing.default` | `match` (missing on one side must be missing on the other) or `forbid` (no missing values allowed). Default `match`. |
| `missing.fields` | Per-column override of the missing rule. |
| `tolerance.abs`, `tolerance.rel` | Default numeric tolerances (default 0, i.e. exact). |
| `tolerance.fields` | Per-column `{abs, rel}` overrides. |
| `checks` | Map of check id to `required` or `optional`. Every check is required unless listed here as optional. |
| `results` | Reserved for structured analytical results. Must be empty in v1. A non-empty value is rejected so that declared results are never silently ignored. |

Unknown fields anywhere in the contract are rejected. Key columns cannot be ignored or capture-only.

## Checks

All checks are evaluated on every run and reported in this order.

| Check id | Fails when |
|---|---|
| `schema.missing_fields` | A compared reference column, or a `fields.required` column, is absent. |
| `schema.extra_fields` | The candidate has a compared column the reference lacks. |
| `schema.type_mismatch` | Column types differ (`numeric`, `character`, `logical`, `date`, `datetime`). Integer and double are both `numeric`; factors are `character`. Entirely missing columns have type `unknown` and match any type. |
| `keys.present` | A key column is absent from either artifact. |
| `keys.unique_reference`, `keys.unique_candidate` | A key value occurs more than once. |
| `rows.missing_in_candidate`, `rows.extra_in_candidate` | A key exists on only one side. |
| `values.missingness` | The missing-value rule is violated. `NA` and `NaN` both count as missing. |
| `values.exact` | A non-numeric value, or a value in a `fields.exact` column, differs. |
| `values.numeric` | `abs(reference - candidate) > abs + rel * abs(reference)`. The boundary is inclusive. Infinite values match only the same infinity. |

If key columns are missing, row and value checks are `skipped`. If keys are duplicated, value checks are `skipped`, because alignment would be ambiguous.

## Acceptance rule (fail-closed)

The overall status is `PASS` only if **every required check has status `pass`**. A required check that is `fail`, `skipped`, or `error` makes the result `FAIL`. An unexpected error during comparison marks all checks `error` and the result `FAIL`. Optional checks are evaluated and reported, but they never change the status.

## Evidence

`equiv_validate()` returns an `equivr-result/v1` object (schema: [`schemas/result-v1.schema.json`](../schemas/result-v1.schema.json)), which can be serialized with `write_result_json()`. It records:

- the contract version, name, source, and a canonical sha256 hash of the parsed contract;
- each artifact's source, format, sha256, dimensions, and column list (file artifacts are hashed byte-for-byte);
- every check with its required flag, status, mismatch count, affected fields, message, and up to `max_diagnostics` diagnostics. The full mismatch count is always kept;
- provenance: the equivR and R versions, platform, git revision, and timestamp.

Apart from `provenance`, the evidence is deterministic: two runs on the same inputs produce identical JSON.
