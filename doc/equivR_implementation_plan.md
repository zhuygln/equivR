# equivR Implementation Plan

**Architecture revision:** 14 October 2026 (supersedes the 13 October revision)
**Status:** proposed implementation plan; replaces earlier schedules, not the R Consortium ISC proposal.
**Authority for scope and milestone commitments:** `proposal/03-proposal.qmd`, `proposal/04-timeline.qmd` and `proposal/05-success.qmd`.

> **equivR modernizes analytical code through an agentic workflow and establishes confidence in the result through independent, reproducible verification.**

## 1. Objective and scope

Consider migrating an existing SAS analytical program to R. The objective is not to reproduce one table of numbers, but to:

1. **Understand the original analytical workflow:** inspect the source code, dependencies, procedures, data structures and relevant statistical semantics.
2. **Generate an R implementation:** use an LLM-powered coding agent to translate or modernize the original program.
3. **Execute and test the implementation:** run the candidate R program on representative datasets, using trustworthy reference results from the original runtime.
4. **Identify semantic differences:** determine whether discrepancies arise from data handling, missing values, numerical methods, statistical conventions or other behavioral differences.
5. **Repair the implementation:** use the agent to revise the code based on structured diagnostics and domain knowledge.
6. **Establish evidence of equivalence:** verify the final implementation across meaningful tests, edge cases and declared analytical requirements.

The end product is **a modernized, executable R implementation with an auditable verification report**: code changes, reproducible tests, provenance and residual limitations. It is not a PASS/FAIL comparison of two saved outputs. Deterministic comparison of output artifacts is an essential part of the verification infrastructure, but it is not the defining feature of the system.

The first Phase 1 demonstration is SAS → R, using pregenerated SAS reference outputs; the second is legacy R → modern R. Generation and repair are agentic, but **acceptance is never decided by the model**: only independent, deterministic verification against declared acceptance criteria can accept a candidate.

Phase 1 is deliberately bounded (see Section 2.3). It does not promise a general SAS-to-R or Python-to-R translator, live SAS in CI, regulatory certification, or a proof that arbitrary programs are equivalent. The system must be model-independent, usable without proprietary IDEs, and practical for enterprise users with existing coding-agent subscriptions and security controls.

## 2. Fundamental architectural decisions

### 2.1 Architecture overview

```text
Original SAS / legacy R project
  source code · dependencies · data semantics · analytical requirements
                              |
                              v
+------------------------------------------------------------+
| Agentic modernization engine                               |
|   Analyze -> Plan -> Generate -> Execute -> Diagnose -> Repair
|   (standalone coding-agent SDK, or Copilot / Claude Code / Codex)
+------------------------------------------------------------+
                              |            ^
              candidate R +   |            |  structured diagnostics,
              execution runs  v            |  semantic-difference findings
+------------------------------------------------------------+
| Verification and convergence infrastructure                |
|   contracts · test generation · reference execution/artifacts
|   statistical checks · invariants · differential testing   |
|   deterministic acceptance · evidence                      |
+------------------------------------------------------------+
                              |
        feedback until acceptance criteria pass
        or limitations are reported
                              v
Modernized R code + verification report
  code changes · reproducible tests · provenance · residual limitations
```

The two halves are deliberately separate. The modernization engine is allowed to be creative and nondeterministic. The verification infrastructure is independent of it, reproducible, and the only authority for acceptance.

### 2.2 Two user-facing workflows

1. **Standalone modernization:** `equivR` runs its own coding agent (through an interchangeable coding-agent SDK) and its own verification loop, from source analysis to verification report.
2. **Bring Your Own Agent (BYOA):** users of GitHub Copilot in VS Code, Claude Code or OpenAI Codex drive the modernization in their existing assistant, which uses `equivR`'s modernization skills, execution tools and verification infrastructure through a local MCP server, CLI and portable Agent Skills. The assistant keeps its own agent loop and model authentication; no additional `equivR`-specific model subscription is required.

In both workflows the same verification infrastructure decides acceptance. Its deterministic validation API is also a **reusable capability in its own right**: developers and CI can re-run verification independently, from R or the CLI, without Python, a coding assistant or model credentials. This is how a verdict reached during an agent session is reproduced and audited; it is not a separate product mode.

An existing enterprise subscription does not necessarily authorize SDK/API usage, and an administrator may restrict local tools. User guides must distinguish supported client usage from programmatic SDK credentials and disclose when prompts or code may be sent to the user's configured model provider.

### 2.3 Phase 1 commitment versus long-term direction

The ISC proposal commits Phase 1 to an LLM that generates or repairs R code, a bounded repair loop, deterministic acceptance and two complete modernization demonstrations, while narrowing verification to pregenerated SAS reference artifacts and selected analytical results.

| Capability | Phase 1 commitment | Long-term direction |
|---|---|---|
| Agent-generated R code | Yes | Yes |
| Automated diagnosis and repair | Bounded example | More sophisticated autonomous repair |
| Verification of datasets and statistical outputs | Yes | Broader behavioral and semantic verification |
| Multiple meaningful test cases | Desirable | Systematic test generation |
| Automated source-code semantic analysis | Limited | Deeper static and dynamic analysis |
| Live SAS execution | Not required | Optional runtime adapter |
| General equivalence proof | No | Selected formal or property-based methods where practical |

Phase 1 does not claim that arbitrary SAS and R programs can be proven equivalent. Every verification report states exactly what was checked and what remains unverified.

### 2.4 Separate agent orchestration from verification orchestration

Agent orchestration (repository navigation, model interaction, editing files, invoking shell tools and context management) is delegated to an existing coding-agent runtime. `equivR` should not rebuild a general-purpose coding harness.

`equivR` owns the **modernization workflow** around that runtime (what to analyze, what to plan, what context and diagnostics to give the agent) and the **verification workflow** (reference locking, test selection, execution budgets, candidate execution, comparison, diagnosis, attempts, convergence, acceptance and evidence). Begin with a small, typed Python state machine; consider LangGraph or durable workflow engines only if measured requirements for checkpointing, long-running tasks or recovery justify them. MCP is a tool protocol, not an orchestration engine.

### 2.5 Component and language choices

| Layer | Choice | Responsibility |
|---|---|---|
| Modernization engine (analysis, planning, generation, repair) | **Python** workflow around a selected coding-agent runtime | Source inspection, migration plan, agent prompts and context, repair from diagnostics. Phase 1: limited source analysis, bounded repair |
| Coding-agent runtime | Select after measured SDK spike | Repository-aware code generation and repair; never owns PASS/FAIL |
| Verification orchestration | **Python**, initially a typed state machine | Run candidates, select tests, manage attempts and budgets, assemble the verification report |
| Verification core | **R package** | Normalization, dataset and statistical-result comparison, invariants, fail-closed decisions, diagnostics, evidence |
| Test generation / differential testing | Python orchestration + R execution | Multiple inputs, seeded and edge cases, differential runs against references. Phase 1: a small hand-built set; systematic generation is long-term |
| Equivalence contract | Versioned YAML/JSON with JSON Schema | Row keys, field rules, tolerances, structured analytical results, required checks |
| BYOA integration | **Local MCP server + portable skills + CLI** | Interoperate with Copilot, Claude Code, Codex without replacing them |
| Execution | Isolated R workspace/container, pinned dependencies | Execute untrusted R candidates, limit network/time/resources, keep trusted inputs read-only |
| Artifacts | CSV + explicit schema / JSON first; Parquet optionally | Exchange trusted and candidate results across runtimes |
| Evidence and report | Versioned result JSON, hashes, provenance, human-readable report | Reproducible decisions, attempt lineage, check-level details, residual limitations |
| CI | GitHub Actions + R checks + Python tests | Credential-free deterministic acceptance |

R and Python communicate through stable, documented interfaces; do not implement the verification core independently in both languages. The model may edit candidate code, but must not change the locked reference, equivalence contract, verification engine or final verdict.

### 2.6 SDK and framework evaluation

Benchmark these on an identical small synthetic SAS → R modernization task:

- **OpenHands Software Agent SDK:** open-source coding-agent option for standalone execution.
- **GitHub Copilot SDK:** standalone candidate with supported sign-in/BYOK configurations; particularly relevant to prior SASaiPy experience.
- **OpenAI Codex SDK:** programmatic coding-agent option.
- **Pydantic AI Harness:** lightweight alternative if a full coding harness adds unnecessary complexity.

Do not mistake the general OpenAI Agents SDK for the coding-oriented Codex SDK; evaluate the former only if a custom tools/workflows design proves necessary. SDK availability, licensing, authentication, enterprise suitability and sandbox behavior must be verified at implementation time.

Use one fixed source program, contract, trusted reference, task and environment per comparison. Record: analytical correctness, attempts to acceptance, time, API cost, tool/workspace control, diagnostic injection, sandbox isolation, trace quality, version constraints and maintenance burden. Adopt one primary standalone backend after the spike; at least one other representative backend should be demonstrably swappable without touching verification logic. Defer support for every possible runtime until demand justifies it.

A minimal adapter interface is conceptually:

```text
propose_or_repair(task, read_only_context, diagnostics, writable_workspace, limits)
    -> candidate_revision + agent_trace_metadata
```

### 2.7 Enterprise interoperability as a product requirement

Expose core capabilities through a single implementation with three faces: R API, command-line interface and local MCP tools. Suggested tools:

```text
equivr_analyze_source
equivr_run_candidate
equivr_validate
equivr_inspect_diagnostics
equivr_report
```

Portable Markdown skills encapsulate domain knowledge (SAS procedure semantics, R idioms, how to read equivR diagnostics), not framework-specific orchestration:

```text
skills/sas-to-r/SKILL.md
skills/modernize-r/SKILL.md
skills/diagnose-equivalence/SKILL.md
```

Provide thin per-client setup in `integrations/vscode-copilot/`, `integrations/claude-code/` and `integrations/codex/`; do not create three different modernization or verification engines. Document how to use an existing approved coding-agent sign-in, how local MCP tool permissions work, and how to run final verification independently.

**Crucial trust boundary:** an externally orchestrated Copilot, Claude Code or Codex session may ignore instructions or skip verification. A generated agent summary cannot itself establish acceptance. The independent `equivr validate` command and CI must be able to reconstruct the verdict using protected artifacts and contract.

### 2.8 Rejected and deferred technology

Do not depend on VS Code/Copilot as the sole agent host; do not build a new low-level coding harness; and do not introduce Kubernetes, Temporal, a hosted UI, multi-agent collaboration, or LangGraph merely because the workflow has a loop. Revisit each only with measured evidence of need.

## 3. Canonical objects and trust boundary

### 3.1 Equivalence contract

Define `equivr-contract/v1` in YAML/JSON. It states source/candidate artifact descriptors, required and ignored columns, row keys, schema and missing-value rules, exact categorical fields, absolute/relative numeric tolerances, required structured results (estimates, confidence intervals, counts, p-values), and required versus optional checks. Reject unknown fields and unsupported versions rather than silently ignoring them. The reference and locked contract are read-only to any candidate-editing agent.

### 3.2 Normalized artifacts

The canonical representation must support datasets, scalar/named results, vectors/tables of estimates, confidence intervals, counts, p-values, and metadata. Use pregenerated trusted SAS artifacts in the public demonstration, with a documented generation procedure and checksums, so public CI never requires a licensed SAS runtime. Preserve missingness, types, time/date interpretations, row keys and result names explicitly rather than assuming CSV or Parquet encodes them fully.

### 3.3 Validation result and evidence

Define a stable `equivr-result/v1` including PASS/FAIL, contract version/hash, artifact checksums, required check statuses, keyed diagnostic differences, environment/R version, source revision where available, timestamps, and report locations. Missing, skipped, unsupported, or errored required checks must produce overall FAIL. Separate deterministic comparison evidence from potentially nondeterministic model trace metadata.

### 3.4 Security and validity caveats

Execute untrusted R candidate code in an isolated workspace/container with resource limits and restricted network access. Treat reference artifacts, test cases and contracts as immutable trusted inputs. Add seeded regressions, multiple synthetic inputs and holdout/metamorphic checks to reduce the risk of hard-coded output imitation. A PASS certifies only what the contract actually checks; it is not a formal proof of general semantic equivalence.

### 3.5 Source analysis artifacts

The modernization engine records what it learned about the original program before generating code: procedures and functions used, inputs and outputs, data-handling assumptions (missing values, formats, sort order, by-group processing), statistical methods and options, and known semantic risks between the source and target runtimes. In Phase 1 this is a limited, partly agent-produced inventory; it guides generation and diagnosis and is included in the report, but it is never evidence of equivalence on its own.

### 3.6 Verification report

The final deliverable of each modernization run is a versioned report that combines:

- the code changes (the modernized R program and its revision history across attempts);
- the source analysis and migration plan;
- the tests executed (inputs, references, seeded and edge cases) and the contract used;
- check-level results and the deterministic verdict from `equivr-result/v1`;
- semantic differences found and how each was resolved;
- provenance (artifact hashes, environment, source revision, agent backend and model metadata);
- **residual limitations**: behavior not covered by the contract or tests, unsupported constructs, and anything accepted with documented caveats.

The report must be reproducible: re-running verification from the stored artifacts and contract yields the same verdict.

## 4. Proposed repository layout

```text
equivR/
├── R/                         # R package: verification core (deterministic)
│   ├── contract.R
│   ├── normalize.R
│   ├── compare_dataset.R
│   ├── compare_results.R
│   └── evidence.R
├── equivr/                     # Python: agentic modernization engine and verification orchestration
│   ├── analysis/               # source inspection and migration planning
│   ├── workflow/               # modernization/convergence state machine
│   ├── agent_backends/         # replaceable coding-agent adapters
│   ├── verification/           # test selection, differential runs, calls the R core, builds the report
│   ├── execution/              # isolated candidate execution
│   ├── mcp_server/
│   └── cli.py
├── schemas/
├── skills/
│   ├── sas-to-r/SKILL.md
│   ├── modernize-r/SKILL.md
│   └── diagnose-equivalence/SKILL.md
├── integrations/
│   ├── vscode-copilot/
│   ├── claude-code/
│   └── codex/
├── benchmarks/
│   ├── sas-to-r/
│   └── legacy-r-to-modern-r/
├── examples/
├── tests/
├── doc/
│   ├── contract.md
│   ├── architecture.md
│   ├── enterprise-integration.md
│   └── equivR_implementation_plan.md
└── .github/workflows/
```

This is a target layout, not a description of existing files. Preserve useful proven code where appropriate, but do not revive closed PR #1 as an architectural baseline.

### 4.1 Current repository state (14 October 2026)

On `main`, only the following exist outside `proposal/`:

| Path | What it is | Target-layout status |
|---|---|---|
| `R/equivR.R` | Base-R proof of concept (`equiv_contract()`, `equiv_compare()`) with fail-closed exact/tolerance/structural checks | Prototype; to be replaced by the R verification-core modules above |
| `examples/basic_validation.R` | Script exercising the prototype's PASS/FAIL cases | Kept as a smoke example until the package exists |
| `doc/equivR_implementation_plan.md` | This plan | Current |
| `LICENSE`, `NOTICE.md`, `README.md` | MPL-2.0 license, template attribution, project overview | Current |

Everything else in the layout (the R package modules, `DESCRIPTION`, `schemas/`, `tests/`, `equivr/`, `skills/`, `integrations/`, `benchmarks/`, `doc/contract.md`, `doc/architecture.md`, `doc/enterprise-integration.md`, `.github/workflows/`) does not exist on `main` yet.

An earlier M1 implementation (R package scaffolding, `contract-v1` parser, dataset checks, JSON schemas, golden tests, R-CMD-check workflow) is preserved on the unmerged branch `feature/m1-deterministic-core` from closed PR #1. It is reference material only: individual pieces may be ported into the verification core after the vertical slice, through new reviewed changes, but the branch is not the baseline for this layout.

## 5. Four-month engineering schedule

The schedule starts with a **vertical slice of the whole modernization workflow**, not with a standalone comparison library, and then hardens each component. The ISC milestone deliverables in Section 6 are unchanged: M1's committed deliverable (equivalence contract, deterministic validation, diagnostics, tests) is still produced within Months 1–2; only the engineering order begins with the slice.

| Timing | Work | Output and gate |
|---|---|---|
| Week 1 | Vertical slice part 1 + SDK spike | One small synthetic SAS program with pregenerated reference outputs and a locked contract. Minimal source analysis and migration plan. Compare OpenHands/Copilot SDK/Codex SDK on generating the first R candidate; record the architecture decision |
| Week 2 | Vertical slice part 2 | Analyze → plan → generate → execute → diagnose → repair on that program; at least one semantic difference found and repaired; first verification report; protected contract/reference; one MCP call demonstrated |
| Weeks 3–4 | M1 verification-core hardening + M2 preparation | Contract v1, exact/numeric/key/schema/missingness checks, fail-closed evidence, golden fixtures; pregenerated SAS artifacts for the public M2 example |
| Weeks 5–6 | M2 SAS → R modernization | Agent-generated R validated against SAS references; canonical statistical-result checks; multiple test inputs and seeded regressions; verification report from a clean checkout |
| Week 7 | BYOA interoperability groundwork | Shared CLI/MCP tools and portable skills; pilot Copilot/Codex, then Claude Code; same verdict through R API, CLI and MCP |
| Weeks 8–9 | M3 legacy R → modern R | Second modernization benchmark with its verification report; benchmark contribution format; seeded analytical differences rejected |
| Week 10 | M3 interfaces and CI | R-friendly invocation, full credential-free CI re-verifying both benchmarks, clean-checkout setup |
| Weeks 11–12 | M4 bounded agent repair | Typed controller, replaceable backend, iteration/cost/time limits, failing-to-accepted repair trace |
| Weeks 13–14 | M4 reproducibility/security | Report provenance, hashes, source/model metadata, immutable reference tests, sandbox hardening, BYOA acceptance tests |
| Week 15 | M5 docs and release candidate | Standalone and BYOA setup guides, independent re-verification guide, architecture and contribution docs |
| Week 16 | M5 final release | Tagged release; deterministic CI green; published demonstrations with verification reports |

## 6. Mapping to submitted ISC milestones and budget

| Milestone | Proposal timing | Committed deliverable | Amount |
|---|---|---|---:|
| **M1** | Month 1–2 | Equivalence contract, deterministic validation, diagnostics, tests | **$1,250** |
| **M2** | Month 1–2 | SAS → R modernization demonstration using pregenerated SAS references | **$1,000** |
| **M3** | Month 2–3 | Legacy R → modern R, R-friendly invocation, CI, benchmark format | **$1,000** |
| **M4** | Month 3–4 | Model-independent bounded LLM repair loop and reproducibility evidence | **$750** |
| **M5** | Month 4 | Documentation, examples, release hardening and tagged release | **$1,000** |

Total requested grant budget: **$5,000** over four months. No additional grant funds are assumed for cloud services, AI credits, hardware, travel, licensed SAS or indirect costs. The vertical slice, SDK evaluation, MCP and BYOA support are engineering design and adoption decisions under these milestones, not new funding promises. Implementation can proceed independently of a grant award.

## 7. Modernization and convergence loop

```text
original SAS / legacy R program + trusted reference artifacts + locked contract
                              |
                  analyze source and plan migration
                              |
             coding agent generates R (standalone or BYOA)
                              |
                    isolated R execution on test inputs
                              |
                    normalize output artifacts
                              |
            independent deterministic verification (R core)
                      /                       \
                PASS (all required)        FAIL / ERROR
                     |                           |
           assemble verification report   diagnose semantic differences
                     |                           |
         accept modernized R + report     bounded agent repair
                                                 |
                                          next candidate
                                    (or stop and report limitations)
```

The controller stops upon verified acceptance, exhausted attempts/time/cost, unrecoverable execution failure or repeated nonprogress; a run that stops without acceptance still produces a report stating what failed and what remains unresolved. It records source analysis, candidate revisions and verification outputs. Neither an SDK nor an MCP client can determine acceptance, and the model cannot lower required tolerances or edit tests as part of repair. BYOA mode cannot guarantee an external client's loop behavior; independent CLI/CI re-verification is mandatory before claims of verified equivalence.

## 8. Public benchmark specification

Each benchmark is self-contained and openly redistributable:

```text
benchmark/
├── benchmark.yaml
├── source/         # original SAS or legacy R program
├── contract.yaml
├── reference/      # pregenerated and hashed, read-only
├── inputs/         # representative and edge-case test datasets
├── candidate/      # modernized R implementation
├── expected/       # expected verdicts for golden and seeded cases
└── README.md
```

Benchmark manifests document source/target runtimes, artifact generation, expected initial status, test inputs, tool prerequisites and provenance. The two required public cases are SAS → R first and legacy R → modern R second. Contributors may later add other cross-runtime and R package-migration cases.

## 9. Test plan

1. **R unit tests:** contract parsing, key alignment, missing values, exact and tolerance boundaries, structured results, hashes and required-check aggregation.
2. **Golden tests:** complete machine-readable expected verdicts for deterministic fixtures, including boundary failures and malformed inputs.
3. **End-to-end modernization:** both benchmarks run from a clean checkout and produce a verification report; deterministic re-verification needs no live SAS and no hosted LLM; seeded regressions must fail.
4. **Differential and multiple-input testing:** each benchmark is verified on more than one input dataset, including edge cases (missing values, ties, empty groups), so a candidate cannot pass by matching one saved output.
5. **Source analysis:** the analysis step identifies the procedures, inputs and outputs of each benchmark program; its inventory is checked against a hand-written expectation.
6. **SDK spike:** use the same program/reference/contract to compare agent backends on verified success, attempts, runtime, expense, observability and permissions.
7. **BYOA compatibility:** Copilot, Claude Code and Codex can call the local `equivR` MCP tools; R API, CLI and MCP return the same verdict on identical inputs; document access prerequisites per client.
8. **Adversarial and security:** agents cannot rewrite references, tests or contracts, fabricate acceptance, or skip required checks; untrusted code is subject to execution limits.
9. **CI design:** required CI never calls paid models; optional external-provider tests are separate and access-dependent.

## 10. Main risks and mitigations

| Risk | Mitigation |
|---|---|
| Rebuilding Copilot's coding harness | Adopt existing coding-oriented SDK; define small replaceable backend adapter |
| Lock-in to one IDE/model/account | Independent R verification core, CLI, MCP and portable skills |
| Subscription incompatible with SDK API | Distinguish BYOA client mode and standalone API/SDK credentials; document limits |
| External agent omits verification | Require independent final command/CI re-verification |
| Agent changes test oracle/contract | Immutable reference/contract/tests, checksums, permissions and adversarial tests |
| Reference case too easy to game | Multiple input cases, seeded failures and holdout/metamorphic checks |
| Cross-runtime semantic mismatch | Source analysis, explicit adapters and contracts; document unsupported behavior in the report |
| Overclaiming equivalence | Reports list exactly what was checked and the residual limitations; no general equivalence claims |
| Data leaves enterprise through model calls | Local verification, explicit provider/trust boundary and configurable network policy |
| Excessive frameworks or packaging scope | One verification core, one primary standalone SDK, minimal controller, thin integrations |
| Undetected required-check error | Fail closed, typed errors and golden integration tests |

## 11. Definition of done

Phase 1 is complete only when:

- both public demonstrations (SAS → R and legacy R → modern R) produce **modernized, executable R code plus a verification report**, from a clean checkout, without live SAS;
- in at least one demonstration, a bounded agent-driven loop starts from a failing R candidate, diagnoses the semantic differences and reaches independently verified acceptance;
- required checks always enforce fail-closed acceptance, with reproducible diagnostics and evidence;
- verification can be re-run independently, locally and in CI, without Python, a coding assistant or LLM credentials, and reproduces the reported verdict;
- the coding-agent backend can be replaced without modifying the verification core, with an alternate adapter exercised in a representative test;
- standalone operation is documented, including credential requirements for its chosen SDK;
- local MCP tools and portable skills are demonstrated or documented with VS Code Copilot, Claude Code and Codex, including unsupported/client-policy caveats;
- using an existing supported BYOA client does not require a new `equivR`-specific model key or subscription;
- independent re-verification, sandbox and read-only reference/contract/test protections are tested;
- benchmark contribution guidance, enterprise setup, report format and licensing documentation are published; and
- a tagged initial release passes required model-free CI.

## 12. Immediate next steps

1. Create an architecture decision record (ADR) confirming: agentic modernization engine + independent verification infrastructure; two user-facing workflows (standalone, BYOA); a reusable deterministic verification core in R; coding-agent SDKs as replaceable components.
2. Assemble one small synthetic SAS program with pregenerated reference outputs, a locked contract and several test inputs.
3. Build the vertical slice on it: analyze → plan → generate → execute → diagnose → repair → verification report, using the first SDK from a time-boxed OpenHands / Copilot SDK (supported sign-in/BYOK) / Codex SDK comparison; consider Pydantic AI Harness if those are overcomplicated.
4. Prove the same verification operation is callable from R, CLI and at least one MCP client; then check Copilot, Claude Code and Codex separately.
5. Only then harden individual components (verification core, test generation, source analysis) against the milestones and gates in Sections 5–6, keeping CI fully deterministic and acceptance independent of any coding assistant.

---

**Relationship to closed PR #1:** The earlier M1 deterministic-core work is reference material only. Reuse reviewed tests, contracts or implementation ideas selectively for the verification core after the vertical slice; do not assume that closed PR fixes the architecture or that its old milestone sequence is authoritative.
