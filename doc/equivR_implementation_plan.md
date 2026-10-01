# equivR Implementation Plan

## 1. Objective

Implement the Phase 1 `equivR` system described in the ISC proposal as a four-month, cross-runtime validation toolkit for R modernization.

The system must support a trust model in which candidate generation may be performed by a developer, translator, or LLM, while acceptance is decided only by deterministic validation against a trusted reference and an explicit equivalence contract.

Phase 1 is deliberately artifact-based. It does **not** build a general SAS-to-R/Python-to-R translator, a live SAS runtime integration, regulatory certification, or a proof of universal program equivalence.

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
| Benchmark suite | Language-neutral fixtures | Legacy R -> modern R and cross-runtime reference -> R, plus future community cases |

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
│   ├── legacy-r-to-modern-r/
│   └── cross-runtime-to-r/
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

| Week | Work | Concrete output | Acceptance gate |
|---|---|---|---|
| 1 | Freeze Phase 1 scope and contract semantics | Contract v1 draft; canonical artifact/result schemas; check taxonomy | Two hand-written contracts can represent the two planned benchmark classes |
| 2 | Implement key/schema validation | Key alignment, duplicate-key detection, required/extra field checks, missingness rules | Golden PASS/FAIL fixtures behave deterministically |
| 3 | Implement value comparison | Exact categorical and abs/rel numeric tolerance logic | Boundary/tolerance tests pass |
| 4 | Diagnostics and result object | Structured mismatch objects and fail-closed aggregation | Any required failure produces overall FAIL with actionable diagnostics |
| 5 | Artifact normalization | R dataset/result adapters; canonical artifact representation | Same logical artifact normalizes reproducibly |
| 6 | Structured analytical-result validation | Estimates, CIs, counts, p-values | Named result fixtures validate independently and with datasets |
| 7 | Cross-runtime reference handling | Pregenerated SAS/Python-style reference artifacts; import adapters | No proprietary runtime required in CI |
| 8 | R-facing invocation | Thin R interface/CLI and reference CI workflow | Validation runs from a clean checkout with one command |
| 9 | Benchmark 1 | Legacy R -> modern R case | Benchmark runs cleanly and detects seeded regressions |
| 10 | Benchmark 2 + contribution format | Cross-runtime reference -> R case; benchmark specification | Both initial cases run from a clean checkout |
| 11 | Model-independent LLM interface | Provider-neutral model client and configuration | Swap between at least two representative model backends without validator changes |
| 12 | Closed-loop repair workflow | Generate/revise -> execute -> validate -> diagnose -> repair -> revalidate | A known failing candidate is repaired and accepted only after all required checks pass |
| 13 | Evidence/provenance | Checksums, R/Python session metadata, revision metadata, machine-readable evidence | Repeated deterministic runs produce equivalent validation results |
| 14 | Hardening | Error taxonomy, edge cases, retry/termination rules, CI expansion | No silent acceptance paths; failures are typed |
| 15 | Documentation/release candidate | User guide, architecture guide, benchmark contribution guide | New user can run both benchmarks from docs alone |
| 16 | Final verification and release | Tagged Phase 1 release; final CI; project update material | All proposal success criteria satisfied |

## 6. Milestone mapping to the ISC proposal

| Proposal milestone | Weeks | Implementation deliverable | Budget |
|---|---:|---|---:|
| M1 Contract and dataset validation | 1-4 | Contract v1, dataset comparison, diagnostics, fixtures | $1,250 |
| M2 Cross-runtime normalization and structured results | 5-7 | Artifact adapters, canonical representation, named-result validation | $1,000 |
| M3 R-facing workflow and benchmark suite | 8-10 | R invocation, CI workflow, two benchmark cases, contribution format | $1,000 |
| M4 Evidence and closed-loop validation | 11-14 | Model-independent LLM interface, repair loop, provenance/evidence | $750 |
| M5 Documentation and release | 15-16 | Docs, release hardening, tagged release | $1,000 |

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

The two required Phase 1 benchmarks are:

| Benchmark | Purpose | Required behavior |
|---|---|---|
| Legacy R -> modern R | Demonstrate direct value to R maintainers and modernization workflows | Equivalent modernization passes; seeded analytical changes fail |
| Cross-runtime reference -> R | Demonstrate language-independent trust model | R candidate is judged from pregenerated reference artifacts without the source runtime in CI |

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

Phase 1 is complete only when all of the following are true:

- an R user can run `equivR` locally and in CI;
- both public benchmark cases run from a clean checkout;
- the deterministic validator returns stable machine-readable and human-readable evidence;
- every failed required check forces overall failure;
- one bounded LLM-driven example starts with a failing candidate, uses diagnostics to revise it, and reaches acceptance only after all declared required checks pass;
- the LLM can be swapped through the model abstraction without changes to validation logic;
- the community benchmark contribution format is documented;
- no licensed SAS runtime is needed to run the shipped CI examples; and
- an initial tagged release is published.

## 13. Immediate next steps

The first implementation sprint should focus only on the deterministic foundation:

1. freeze `contract-v1`;
2. define normalized artifact and validation-result schemas;
3. split the current proof-of-concept code into contract, normalization, comparison, and evidence modules;
4. add golden fixtures for exact match, tolerance pass, tolerance fail, duplicate/missing keys, schema mismatch, and missing-value mismatch;
5. put all deterministic tests in CI before adding any LLM integration.

This ordering preserves the proposal's core trust model: the validator becomes stable before the model-driven repair layer is attached.
