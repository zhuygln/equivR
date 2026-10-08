# equivR Implementation Plan

## 1. Objective

Implement the Phase 1 `equivR` system described in the ISC proposal (`proposal/03-proposal.qmd`, `proposal/04-timeline.qmd`): a four-month, $5,000 project that modernizes analytical code while independently verifying that its analytical behavior is preserved. The proposal is the authoritative reference for milestones, timing, and budget; this plan describes how to execute it.

Phase 1 delivers two demonstrations, in this order:

1. **SAS -> R**: an R candidate, generated or repaired with an LLM, is validated against pregenerated trusted SAS reference artifacts.
2. **Legacy R -> modern R**: the same framework is applied to refactoring an existing R analysis.

### Invariants

These hold in every milestone and every pull request:

- Deterministic validation is independent of LLM-generated code; the validator never imports, executes, or trusts candidate code paths.
- Only the deterministic validator can accept a candidate. An LLM response can never set validation status.
- All declared required checks must pass; any failed, skipped, or erroring required check gives overall FAIL.
- No live SAS runtime is required in public CI; SAS is used offline only to pregenerate reference artifacts.
- Phase 1 is not a general-purpose SAS-to-R translator, a live SAS integration, or regulatory certification.
- No claim of mathematical or program equivalence is made beyond the checks declared in the contract.

## 2. Recommended implementation architecture

The proposal allows the deterministic validation core to be implemented in R and/or Python. For Phase 1, the recommended split is:

| Layer | Recommended implementation | Responsibility |
|---|---|---|
| Equivalence contract | Language-neutral YAML/JSON schema | Keys, schema/missingness rules, ignored fields, tolerances, required analytical outputs |
| Deterministic validation core | R-first, with small Python utilities only where useful | Key alignment, schema/value checks, numeric tolerances, structured-result comparison, fail-closed decision |
| Artifact adapters | R + Python | Normalize reference/candidate artifacts into a canonical comparison representation |
| R-facing workflow | R functions + thin CLI | Local invocation, CI invocation, configuration, report access |
| Evidence layer | Shared structured format | Machine-readable result plus human-readable report, provenance, checksums |
| LLM orchestration | Python | Model-provider abstraction, repair prompting, bounded generate/repair/revalidate loop |
| Benchmark suite | Language-neutral fixtures | SAS -> R (pregenerated SAS artifacts) and legacy R -> modern R, plus future community cases |

The important trust boundary is that the LLM orchestration layer can propose code or repairs but can never mark a candidate as accepted. Only the deterministic validator can do that.

## 3. Canonical objects

### 3.1 Equivalence contract

Version the contract from the start, for example `equivr-contract/v1`.

Minimum fields:

- contract/schema version
- reference/candidate artifact descriptors
- row keys
- required and ignored fields
- missing-value rules
- exact-match fields
- numeric absolute/relative tolerances
- required structured analytical results
- per-check required/optional status
- metadata fields to capture but not compare

A useful design rule is that every acceptance decision must be reconstructable from the contract plus the two normalized artifacts.

### 3.2 Normalized artifact

Define a canonical internal representation independent of whether the source came from legacy R, SAS, Python, or another runtime.

Phase 1 should support:

- tabular datasets
- scalar/named analytical results
- vectors/tables of estimates
- confidence intervals
- counts
- p-values
- basic provenance metadata

Do not require the reference runtime to be installed in CI. Cross-runtime benchmarks should use pregenerated trusted artifacts.

### 3.3 Validation result

A validation run should return a stable machine-readable result containing:

- overall status: `PASS` / `FAIL`
- contract version
- check-level results
- structured mismatch diagnostics
- artifact hashes/checksums
- runtime/session metadata
- source revision if available
- timestamps
- evidence/report locations

A failed required check must always force overall `FAIL`.

## 4. Repository layout

Recommended target layout:

```text
equivR/
├── R/
│   ├── contract.R
│   ├── normalize.R
│   ├── compare_dataset.R
│   ├── compare_results.R
│   ├── evidence.R
│   └── cli.R
├── python/
│   └── equivr_agent/
│       ├── model_interface.py
│       ├── repair_loop.py
│       ├── prompts.py
│       └── providers/
├── schemas/
│   ├── contract-v1.schema.json
│   └── result-v1.schema.json
├── benchmarks/
│   ├── sas-to-r/
│   └── legacy-r-to-modern-r/
├── examples/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── golden/
├── docs/
│   ├── contract.md
│   ├── benchmark-format.md
│   ├── architecture.md
│   └── implementation-plan.md
└── .github/workflows/
```

The exact file names can change, but keeping validation, LLM orchestration, schemas, and benchmarks separated will reinforce the trust boundary.

## 5. Four-month implementation schedule

The schedule follows the proposal's milestone timing (M1 and M2 in Months 1-2, M3 in Months 2-3, M4 in Months 3-4, M5 in Month 4). Workstreams overlap where the proposal's timing requires it. Week numbers are relative to project start; status reflects the repository as of PR #1.

| Weeks | Milestone | Work | Concrete output | Acceptance gate | Status |
|---|---|---|---|---|---|
| 1-4 | M1 | Contract v1; key, schema, missingness, and value checks; fail-closed result object; golden tests; CI | `R/contract.R`, `R/compare_dataset.R`, `R/result.R`, schemas, nine golden cases, R-CMD-check on four platforms | Any required failure gives FAIL with actionable diagnostics; golden evidence is byte-stable | Done (PR #1) |
| 2-4 (parallel) | M2 prep | Choose a small public SAS workflow; run it offline to pregenerate reference datasets and selected results with provenance | `benchmarks/sas-to-r/reference/` plus a note on how the artifacts were generated | Artifacts committed; nothing downstream needs SAS | Not started |
| 5-6 | M1 close-out | Merge PR #1; freeze `contract-v1` dataset semantics; tag the M1 release | Tagged M1 release | `main` green; contract changes after this need a version bump | Pending merge |
| 5-6 | M2 | Artifact normalization for the SAS exports; structured analytical-result comparison (estimates, confidence intervals, counts, p-values) through the contract's reserved `results` section | SAS-export adapter; `R/compare_results.R`; result fixtures | Named-result fixtures pass and fail deterministically, alone and with datasets | Not started |
| 7-8 | M2 | Produce the R candidate with an LLM (single-pass or manually guided; the automated loop is M4) and validate it against the SAS reference; seed deliberate mismatches | `benchmarks/sas-to-r/` with contract, candidate, expected results | SAS -> R benchmark runs from a clean checkout without SAS; seeded regressions FAIL with diagnostics | Not started |
| 7-10 | M3 | Legacy R -> modern R benchmark, reusing the M2 adapters and result checks | `benchmarks/legacy-r-to-modern-r/` | Equivalent refactor PASSes; seeded analytical changes FAIL | Not started |
| 9-11 | M3 | R-friendly invocation (`equiv_run()` plus a thin command-line wrapper); reference CI workflow; benchmark contribution format | `R/cli.R`, CI workflow, `docs/benchmark-format.md` | Both benchmarks run locally and in CI with one command | Not started |
| 10-12 | M4 | Model-independent provider interface; bounded generate -> execute -> validate -> diagnose -> repair loop | `python/equivr_agent/` (or R equivalent) | A known failing candidate is accepted only after all required checks pass; the loop stops at its iteration limit | Not started |
| 12-14 | M4 | Reproducibility evidence: contract version, checksums, R/Python session information, source revision, model/provider metadata; replayed repair trace for credential-free CI | Evidence schema extension; recorded trace | Repeated runs give equivalent evidence; CI never calls a paid API | Not started |
| 14-16 | M5 | User, architecture, and contribution docs; examples; release hardening | Docs, examples, tagged Phase 1 release | All proposal success criteria met | Not started |

### Dependencies

- M2 builds on the merged M1 validator; SAS artifact preparation can start before the merge because it only produces data.
- M3 reuses the M2 artifact adapters and structured-result checks rather than building its own.
- M4 needs both benchmarks, because the repair loop is demonstrated on them.
- M5 documents and releases what M1-M4 deliver; no new features start in M5.

### Failure recovery

Mirrors the proposal: if an LLM cannot produce a correct candidate, narrow or manually repair the example while preserving the validation experiment; document unsupported SAS/R behavior as out of scope; model-provider failure must not affect deterministic CI; the repair loop stops after a bounded number of attempts.

## 6. Milestone mapping to the ISC proposal

Milestone names, timing, and amounts match `proposal/04-timeline.qmd`. Artifact normalization and structured analytical-result comparison are technical requirements, not separate proposal milestones; they are delivered under the milestones that need them.

| Proposal milestone | Timing | Weeks | Deliverable | Supporting technical requirements | Budget |
|---|---|---:|---|---|---:|
| M1 Equivalence contract and deterministic validation | Month 1-2 | 1-6 | Contract v1, deterministic dataset validation, structured diagnostics, tests | Dataset normalization (CSV/RDS/data frame), checksums, fail-closed result | $1,250 |
| M2 SAS -> R modernization demonstration | Month 1-2 | 2-8 | SAS -> R benchmark against pregenerated SAS reference artifacts | SAS-export artifact adapter; structured-result comparison (estimates, CIs, counts, p-values) | $1,000 |
| M3 Legacy R -> modern R, R-friendly invocation, CI, benchmark format | Month 2-3 | 7-11 | Legacy R benchmark; `equiv_run()`/CLI; reference CI workflow; contribution format | Reuses M2 adapters and result checks | $1,000 |
| M4 Model-independent bounded LLM repair loop and reproducibility evidence | Month 3-4 | 10-14 | Provider-neutral model interface; bounded repair loop; evidence/provenance | Session, revision, and model metadata; replayed trace for CI | $750 |
| M5 Documentation, examples, release hardening, tagged release | Month 4 | 14-16 | User, architecture, and contribution docs; tagged release | — | $1,000 |
| **Total** | 4 months | | | | **$5,000** |

## 7. LLM-dependent, model-independent design

The automated repair workflow requires an LLM, but `equivR` must not encode assumptions about a specific vendor or model family.

Define a minimal model interface such as:

```text
generate(request, context, configuration) -> candidate_change
```

The provider adapter should handle authentication, request/response formatting, model identifiers, and provider-specific options. The rest of the system should see only the provider-neutral result.

For the Phase 1 demonstration:

1. exercise the same repair workflow with at least two distinct representative LLM backends when practical;
2. record provider/model identifier and generation configuration in provenance;
3. never allow an LLM response to set validation status;
4. cap repair iterations and stop on PASS, unrecoverable execution failure, repeated identical diagnostics, or iteration limit;
5. preserve the complete sequence of candidate versions and validation results for the demonstration.

Model API costs used for project evaluation remain self-funded or in-kind, consistent with the grant budget.

## 8. Benchmark specification

Each benchmark directory should be self-contained and openly licensed. A benchmark should contain:

```text
benchmark/
├── benchmark.yaml
├── contract.yaml
├── reference/
├── candidate/
├── expected/
└── README.md
```

`benchmark.yaml` should state the scenario, source/target runtimes, how artifacts were generated, expected initial status, and any runtime prerequisites.

The two required Phase 1 benchmarks, in delivery order, are:

| Benchmark | Milestone | Purpose | Required behavior |
|---|---|---|---|
| SAS -> R | M2 | Primary use case: an LLM-assisted R candidate judged against a trusted SAS workflow | R candidate is validated against pregenerated SAS reference artifacts without SAS in CI; seeded mismatches fail |
| Legacy R -> modern R | M3 | Show the same framework supports long-term maintenance within R | Equivalent modernization passes; seeded analytical changes fail |

The existing `examples/contracts/cross-runtime-to-r.yaml` becomes the starting point for the SAS -> R contract in M2.

The contribution format should make it straightforward for the community to add future package-replacement, SAS-to-R, Python-to-R, refactoring, and AI-assisted R cases.

## 9. Test strategy

Use three levels of tests.

**Unit tests** cover contract parsing, key alignment, missingness, tolerance boundaries, structured-result checks, checksum generation, and failure aggregation.

**Golden integration tests** compare complete expected machine-readable validation results for fixed fixtures. These are especially important because the project promises deterministic evidence.

**End-to-end tests** run both public benchmarks from a clean checkout and run the bounded LLM repair demonstration when model credentials are available. CI without credentials should still test all deterministic components and a replayed/cached repair trace so core CI never depends on a paid service.

## 10. Closed-loop control logic

Recommended control sequence:

```text
candidate
   ↓
execute
   ↓
normalize artifacts
   ↓
deterministic validation
   ├── PASS → evidence → accept
   └── FAIL → structured diagnostics
                    ↓
               LLM repair
                    ↓
             candidate revision
                    └──────────────→ execute again
```

The controller should never optimize for "LLM confidence." Progress should be measured only through deterministic validation state: fewer unresolved required checks, reduced numeric/schema differences, or final PASS.

## 11. Main risks and mitigations

| Risk | Mitigation |
|---|---|
| Scope expands into translation-agent research | Keep Phase 1 artifact-based; translation remains an external producer of candidates |
| Cross-runtime semantic differences are difficult to normalize | Use small explicit adapters and pregenerated artifacts; document unsupported cases |
| Equivalence contracts become too broad | Version a minimal v1 and add new check types only when required by benchmarks |
| LLM behavior varies across providers | Model interface isolates providers; deterministic validator is unchanged |
| API/service unavailable | Support multiple model backends; deterministic tests do not depend on hosted APIs |
| Benchmarks overfit authors' use cases | Publish contribution format early and intentionally use two different initial benchmark classes |
| False confidence from incomplete contracts | Reports state exactly which declared checks were evaluated; no claim outside the contract |
| Non-deterministic reports | Stable ordering, explicit tolerances, fixed schemas, and golden-result tests |

## 12. Definition of done

Phase 1 is complete only when all of the following are true (aligned with the proposal's Success section):

- the SAS -> R and legacy R -> modern R workflows both run from a clean checkout, locally and in CI;
- both use explicit equivalence contracts and produce deterministic diagnostics and reproducible validation evidence;
- every failed required check forces overall FAIL, and seeded mismatches fail with actionable diagnostics;
- the SAS -> R example validates against pregenerated trusted artifacts, and no live SAS runtime is needed in CI;
- the repair loop is model/provider independent, bounded, and the LLM never determines acceptance;
- an R-friendly invocation path, CI example, and benchmark contribution format are documented; and
- an initial public release is tagged.

## 13. Immediate next steps

M1's deterministic foundation is in place (PR #1). The next major delivery target is the M2 SAS -> R demonstration, so that a real migration tests whether the contract, artifact adapters, and diagnostics are sufficient for the primary use case before the generic validator grows further.

1. Merge PR #1 and tag the M1 release; treat `contract-v1` dataset semantics as frozen.
2. Pick a small, openly licensed SAS workflow and pregenerate its reference datasets and selected results offline, recording how they were produced.
3. Define the `results` section of the contract for estimates, confidence intervals, counts, and p-values, driven by what the SAS example actually produces.
4. Add the SAS-export adapter and structured-result comparison with golden fixtures.
5. Generate the R candidate with an LLM, validate it, and add seeded mismatches; keep all of this deterministic in CI.

The automated repair loop (M4) is attached only after both benchmarks validate deterministically, which preserves the core trust model: the validator is stable before any model-driven layer depends on it.

