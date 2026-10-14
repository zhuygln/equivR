# equivR Implementation Plan

**Architecture revision:** 13 October 2026
**Status:** proposed implementation plan; replaces the previous component-first schedule, not the R Consortium ISC proposal.
**Authority for scope and milestone commitments:** `proposal/03-proposal.qmd` and `proposal/04-timeline.qmd`.

## 1. Objective and scope

`equivR` is an independent, open-source toolkit for modernizing analytical implementations while verifying that their declared analytical behavior matches trusted reference artifacts. The first demonstration is SAS → R, using pregenerated SAS outputs; the second is legacy R → modern R. An LLM or human may create or repair candidate code, but only deterministic validation against a versioned equivalence contract decides acceptance.

Phase 1 is artifact-based. It does not promise a general SAS-to-R or Python-to-R translator, access to live SAS in CI, regulatory certification, or universal program equivalence. The system must be model-independent, usable without proprietary IDEs, and practical for enterprise users with existing coding-agent subscriptions and security controls.

## 2. Fundamental architectural decisions

### 2.1 Three modes, one authoritative validator

1. **Validation-only / R-native:** R users invoke an installable R package locally or in CI, with no Python installation, API key, coding assistant, or model credentials required.
2. **Standalone modernization agent:** a Python CLI uses an interchangeable coding-agent SDK to inspect source code, propose and repair an R candidate, and invoke the same R validator.
3. **Bring Your Own Agent (BYOA):** users of GitHub Copilot in VS Code, Claude Code, or OpenAI Codex invoke `equivR` through a local MCP server, CLI and portable Agent Skills. The coding assistant retains control of its own agent loop and model authentication; an additional `equivR`-specific model subscription is not required in this mode.

The existing enterprise subscription does not necessarily authorize SDK/API usage, and an administrator may restrict local tools. User guides must distinguish supported client usage from programmatic SDK credentials and disclose when prompts or code may be sent to the user's configured model provider.

### 2.2 Separate agent orchestration from verification workflow

Agent orchestration (repository navigation, model interaction, editing files, invoking shell tools and context management) should be delegated to an existing coding-agent runtime. `equivR` should not rebuild a general-purpose coding harness.

Verification workflow orchestration belongs to `equivR`: reference locking, execution budgets, candidate execution, comparison, diagnostics, attempts, convergence, acceptance and evidence. Begin with a small, typed Python state machine; consider LangGraph or durable workflow engines only if measured requirements for checkpointing, long-running tasks or recovery justify them. MCP is a tool protocol, not an orchestration engine.

### 2.3 Component and language choices

| Layer | Choice | Responsibility |
|---|---|---|
| Equivalence contract | Versioned YAML/JSON with JSON Schema | Row keys, field rules, tolerances, structured analytical results, required checks |
| Authoritative validator | **R package** | Normalization, data/result comparisons, fail-closed decisions, diagnostics, evidence |
| Standalone CLI/controller | **Python**, initially a typed state machine | Launch candidate runs, manage attempts and adapters, enforce budgets |
| Coding-agent runtime | Select after measured SDK spike | Repository-aware code generation and repair; never owns PASS/FAIL |
| BYOA integration | **Local MCP server + portable skills + CLI** | Interoperate with Copilot, Claude Code, Codex without replacing them |
| Execution | Isolated R workspace/container, pinned dependencies | Execute untrusted R candidates, limit network/time/resources, keep trusted inputs read-only |
| Artifacts | CSV + explicit schema / JSON first; Parquet optionally | Exchange trusted and candidate results across runtimes |
| Evidence | Versioned result JSON, hashes, provenance | Reproducible decisions, attempt lineage, check-level details |
| CI | GitHub Actions + R checks + Python tests | Credential-free deterministic acceptance |

R and Python must communicate through stable, documented interfaces; do not implement the validator independently in both languages. The model may edit candidate code, but must not change the locked reference, equivalence contract, validation engine or final verdict.

### 2.4 SDK and framework evaluation

Benchmark these on an identical small synthetic SAS → R repair task:

- **OpenHands Software Agent SDK:** open-source coding-agent option for standalone execution.
- **GitHub Copilot SDK:** standalone candidate with supported sign-in/BYOK configurations; particularly relevant to prior SASaiPy experience.
- **OpenAI Codex SDK:** programmatic coding-agent option.
- **Pydantic AI Harness:** lightweight alternative if a full coding harness adds unnecessary complexity.

Do not mistake the general OpenAI Agents SDK for the coding-oriented Codex SDK; evaluate the former only if a custom tools/workflows design proves necessary. SDK availability, licensing, authentication, enterprise suitability and sandbox behavior must be verified at implementation time.

Use one fixed contract, trusted reference, prompt/task, source program and environment per comparison. Record: analytical correctness, attempts to PASS, time, API cost, tool/workspace control, diagnostic injection, sandbox isolation, trace quality, version constraints and maintenance burden. Adopt one primary standalone backend after the spike; at least one other representative backend should be demonstrably swappable without touching validation logic. Defer support for every possible runtime until demand justifies it.

A minimal adapter interface is conceptually:

```text
propose_or_repair(task, read_only_context, diagnostics, writable_workspace, limits)
    -> candidate_revision + agent_trace_metadata
```

### 2.5 Enterprise interoperability as a product requirement

Expose core capabilities through a single implementation with three faces: R API, command-line interface and local MCP tools. Suggested tools:

```text
equivr_validate
equivr_run_candidate
equivr_inspect_diagnostics
equivr_evidence
```

Portable Markdown skills encapsulate domain knowledge, not framework-specific orchestration:

```text
skills/sas-to-r/SKILL.md
skills/modernize-r/SKILL.md
skills/diagnose-equivalence/SKILL.md
```

Provide thin per-client setup in `integrations/vscode-copilot/`, `integrations/claude-code/` and `integrations/codex/`; do not create three different validation or repair engines. Document how to use an existing approved coding-agent sign-in, how local MCP tool permissions work, and how to run final validation independently.

**Crucial trust boundary:** an externally orchestrated Copilot, Claude Code or Codex session may ignore instructions or skip validation. A generated agent summary cannot itself establish PASS. The independent `equivr validate` command and CI must be able to reconstruct the verdict using protected artifacts and contract.

### 2.6 Rejected and deferred technology

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

## 4. Proposed repository layout

```text
equivR/
├── R/                         # R package: authoritative deterministic validator
│   ├── contract.R
│   ├── normalize.R
│   ├── compare_dataset.R
│   ├── compare_results.R
│   └── evidence.R
├── equivr/                     # Optional Python standalone agent and tools
│   ├── workflow/
│   ├── agent_backends/
│   ├── execution/
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

## 5. Four-month engineering schedule

Workstreams overlap so the complete modernization workflow is validated early, while formal ISC milestones remain unchanged.

| Timing | Work | Output and gate |
|---|---|---|
| Week 1 | SDK and enterprise interoperability spike | Compare OpenHands/Copilot SDK/Codex SDK on fixed SAS → R task; demonstrate local MCP call; record architecture decision |
| Week 2 | Complete thin vertical slice | Generate R → execute → compare → diagnose → repair; one seeded failure detected; protected contract/reference |
| Weeks 3–4 | M1 validation hardening + M2 preparation | Contract v1, exact/numeric/key/schema/missingness checks, fail-closed evidence, golden fixtures; pregenerated SAS artifact |
| Weeks 5–6 | M2 SAS → R example | Canonical result checks, SAS reference provenance, clean-checkout benchmark and seeded regression failures |
| Week 7 | BYOA interoperability groundwork | Shared CLI/MCP tools and portable skills; pilot Copilot/Codex, then Claude Code; same verdict through R API/CLI/MCP |
| Weeks 8–9 | M3 legacy R → modern R | Second benchmark, documented benchmark contribution format, seeded analytical differences rejected |
| Week 10 | M3 interfaces and CI | R-friendly invocation, full credential-free CI, clean-checkout setup |
| Weeks 11–12 | M4 bounded agent repair | Typed controller, replaceable backend, iteration/cost/time limits, failed-to-PASS repair trace |
| Weeks 13–14 | M4 reproducibility/security | Artifacts, hashes, source/model metadata, immutable reference tests, sandbox hardening, BYOA acceptance tests |
| Week 15 | M5 docs and release candidate | R-only, standalone and enterprise BYOA setup guides; architecture and contribution docs |
| Week 16 | M5 final release | Tagged release; deterministic CI green; published demo and evidence |

## 6. Mapping to submitted ISC milestones and budget

| Milestone | Proposal timing | Committed deliverable | Amount |
|---|---|---|---:|
| **M1** | Month 1–2 | Equivalence contract, deterministic validation, diagnostics, tests | **$1,250** |
| **M2** | Month 1–2 | SAS → R modernization demonstration using pregenerated SAS references | **$1,000** |
| **M3** | Month 2–3 | Legacy R → modern R, R-friendly invocation, CI, benchmark format | **$1,000** |
| **M4** | Month 3–4 | Model-independent bounded LLM repair loop and reproducibility evidence | **$750** |
| **M5** | Month 4 | Documentation, examples, release hardening and tagged release | **$1,000** |

Total requested grant budget: **$5,000** over four months. No additional grant funds are assumed for cloud services, AI credits, hardware, travel, licensed SAS or indirect costs. SDK evaluation, MCP and BYOA support are engineering design and adoption decisions under these milestones, not new funding promises. Implementation can proceed independently of a grant award.

## 7. Agent-independent control logic

```text
trusted SAS/R reference + locked contract
                     |
          coding agent proposes R
            (standalone or BYOA)
                     |
           isolated R execution
                     |
          normalize output artifacts
                     |
        authoritative R validation
                /           \
             PASS           FAIL / ERROR
               |                  |
       emit hashed evidence   structured diagnostics
               |                  |
          accept result    bounded agent repair
                                  |
                             next candidate
```

The controller stops upon validated PASS, exhausted attempts/time/cost, unrecoverable execution failure or repeated nonprogress. It records candidate revisions and validator outputs. Neither an SDK nor an MCP client can determine acceptance, and the model cannot lower required tolerances as part of repair. BYOA mode cannot guarantee an external client's loop behavior; final independent CLI/CI validation is mandatory before claims of verified equivalence.

## 8. Public benchmark specification

Each benchmark is self-contained and openly redistributable:

```text
benchmark/
├── benchmark.yaml
├── contract.yaml
├── reference/      # pregenerated and hashed, read-only
├── candidate/      # R implementation
├── expected/       # expected PASS/FAIL for golden or seeded cases
└── README.md
```

Benchmark manifests document source/target runtimes, artifact generation, expected initial status, test inputs, tool prerequisites and provenance. The two required public cases are SAS → R first and legacy R → modern R second. Contributors may later add other cross-runtime and R package-migration cases.

## 9. Test plan

1. **R unit tests:** contract parsing, key alignment, missing values, exact and tolerance boundaries, structured results, hashes and required-check aggregation.
2. **Golden tests:** complete machine-readable expected verdicts for deterministic fixtures, including boundary failures and malformed inputs.
3. **End-to-end benchmarks:** both examples run from a clean checkout, with no live SAS and no hosted LLM; seeded regressions must fail.
4. **SDK spike:** use the same task/reference/contract to compare agent backends on verified success, attempts, runtime, expense, observability and permissions.
5. **BYOA compatibility:** Copilot, Claude Code and Codex can call the local `equivR` MCP tools; R API, CLI and MCP return the same verdict on identical inputs; document access prerequisites per client.
6. **Adversarial and security:** agents cannot rewrite references/contracts, fabricate PASS, or skip required checks; untrusted code is subject to execution limits.
7. **CI design:** required CI never calls paid models; optional external-provider tests are separate and access-dependent.

## 10. Main risks and mitigations

| Risk | Mitigation |
|---|---|
| Rebuilding Copilot's coding harness | Adopt existing coding-oriented SDK; define small replaceable backend adapter |
| Lock-in to one IDE/model/account | Independent R validation, CLI, MCP and portable skills |
| Subscription incompatible with SDK API | Distinguish BYOA client mode and standalone API/SDK credentials; document limits |
| External agent omits validation | Require independent final command/CI verification |
| Agent changes test oracle/contract | Immutable reference/contract, checksums, permissions and adversarial tests |
| Reference case too easy to game | Multiple input cases, seeded failures and holdout/metamorphic checks |
| Cross-runtime semantic mismatch | Explicit adapters and contracts; document unsupported behavior |
| Data leaves enterprise through model calls | Local validation, explicit provider/trust boundary and configurable network policy |
| Excessive frameworks or packaging scope | One core, one primary standalone SDK, minimal controller, thin integrations |
| Undetected required-check error | Fail closed, typed errors and golden integration tests |

## 11. Definition of done

Phase 1 is complete only when:

- an R user can install/run the deterministic validator locally and in CI without Python or LLM credentials;
- the public SAS → R and legacy R → modern R benchmarks work from clean checkouts without live SAS;
- required checks always enforce fail-closed acceptance, with reproducible diagnostics and evidence;
- a bounded agent-driven repair demonstration begins with a failing R candidate and reaches an independently verified PASS;
- the coding-agent backend can be replaced without modifying the validator, with an alternate adapter exercised in a representative test;
- standalone CLI operation is documented, including credential requirements for its chosen SDK;
- local MCP tools and portable skills are demonstrated or documented with VS Code Copilot, Claude Code and Codex, including unsupported/client-policy caveats;
- using an existing supported BYOA client does not require a new `equivR`-specific model key or subscription;
- independent final validation, sandbox and read-only reference/contract protections are tested;
- benchmark contribution guidance, enterprise setup, evidence and licensing documentation are published; and
- a tagged initial release passes required model-free CI.

## 12. Immediate next steps

1. Create an architecture decision record (ADR) confirming one R validator, optional Python standalone workflow, CLI/MCP/skills BYOA and SDKs as replaceable components.
2. Assemble one small synthetic SAS → R task with reference artifacts, locked contract and a deliberately wrong R candidate.
3. Run a time-boxed apples-to-apples OpenHands, Copilot SDK (with supported sign-in/BYOK) and Codex SDK spike; consider Pydantic AI Harness if the first choices are overcomplicated.
4. Prove the same validation operation is callable from R, CLI and at least one MCP client; then check Copilot, Claude Code and Codex separately.
5. Implement the narrow complete modernization/repair/verification loop before expanding generic components.
6. Follow the milestones and gates in Sections 5–6, keeping CI fully deterministic and required-check acceptance independent of any coding assistant.

---

**Relationship to closed PR #1:** The earlier M1 deterministic-core work is reference material only. Reuse reviewed tests, contracts or implementation ideas selectively after the architecture spike; do not assume that closed PR fixes the architecture or that its old milestone sequence is authoritative.
