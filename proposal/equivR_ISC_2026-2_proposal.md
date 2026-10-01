# equivR: Reproducible Cross-Runtime Equivalence for R Analytics

*R Consortium ISC 2026-2 grant proposal — convenience combined Markdown copy.*

# Executive Summary

`equivR` is an open-source cross-runtime validation toolkit for R modernization, migration, and refactoring. R is the community focus; the implementation language of a trusted reference or candidate is outside the trust model, and Python may be used internally for orchestration.

> **Generation proposes; validation decides.**

A translator, LLM, or developer may produce code, but acceptance requires execution against an explicit equivalence contract. Any failed required check blocks acceptance and returns deterministic diagnostics for repair and re-validation.

A minimal proof of concept already demonstrates exact, tolerance-aware, and structural checks. The project also builds on prior delivery of a completed SAS-to-Python modernization framework using AI-assisted transformation, hybrid execution, and independent numerical validation. The grant turns these proven patterns into reusable R-centered infrastructure: a language-neutral contract, cross-runtime artifact normalization, structured-result validation, reproducibility evidence, R-facing workflows, and community benchmark cases.

# Signatories

## Project team

**Yonglin Zhu** - co-PI / co-lead; Senior Staff Scientist at SAS Institute. ORCID [0000-0003-0245-827X](https://orcid.org/0000-0003-0245-827X); <zhuygln@gmail.com>. Led development of a completed SAS-to-Python modernization framework using AI-assisted transformation, hybrid SAS/Python execution, and numerical-equivalence validation. Leads architecture, equivalence-contract design, and validation workflow implementation. Project: <https://github.com/zhuygln/equivR>.

We request **$5,000 over four months** for project labor. No funds are requested for cloud services or AI credits.

**Xing Cai** - co-PI / co-lead; founding member of the R Working Group at PPD. ORCID [0009-0004-5983-3338](https://orcid.org/0009-0004-5983-3338); <caixingtt@gmail.com>. Applied analytics experience with SAS, R, Python, statistical modeling, and data-science workflows; co-leads R-community use-case design, benchmark development, testing, documentation, and applied evaluation.

`equivR` is independent open-source work: it is not sponsored, funded, or endorsed by either co-PI's employer and does not depend on employer-owned code, data, or infrastructure.

**Contributors / consulted.** None at submission time; community contributions will be invited through the public repository and benchmark process. The design is informed by public R Consortium Submissions Working Group materials [@pilot5; @submissions2026; @reviewable2026]; citation does not imply endorsement.

# The Problem

Recent R Consortium discussion on making R submissions reviewable for FDA highlights a practical challenge: reviewers may be able to receive R code but still struggle to recreate the sponsor's environment, install dependencies, or reproduce the submitted results [@reviewable2026]. As R becomes a more important open-source option for clinical-trial analysis, reviewability and reproducibility become as important as whether the code runs at all.

The R Submissions Working Group is already addressing this problem. Its 2026 plan includes environment-preservation approaches such as containers and WebAssembly, and it also plans to expand the use of AI and automation in future submission pipelines [@submissions2026].

Preserving an old environment, however, does not solve every long-term problem. R versions and packages change, legacy code becomes difficult to maintain, and organizations eventually need to refactor or migrate analytical workflows. At that point the question becomes:

> Can we change the implementation while preserving the analytical behavior that made the original workflow trustworthy?

Today, teams usually answer this with project-specific comparison scripts and manual review. There is no common infrastructure for defining what must remain equivalent and then checking those requirements across legacy R, modern R, SAS, Python, or AI-assisted rewrites.

Large language models make modernization easier, but they cannot be trusted to validate their own output. `equivR` therefore targets the missing layer: LLM-assisted modernization combined with independent equivalence validation, so analytical workflows can evolve while remaining reproducible, reviewable, and trustworthy.

# The proposal

## Overview

`equivR` will provide a practical way to modernize analytical code without giving up the trusted behavior of the original workflow.

The first target is SAS -> R. A trusted SAS workflow will be used to generate reference artifacts. An LLM will produce or revise an R implementation, and `equivR` will independently compare the R results with the trusted SAS reference. If required checks fail, the diagnostics are returned for another repair attempt. The candidate is accepted only when all declared checks pass.

> **Generation proposes; validation decides.**

This approach builds on our previous SAS -> Python modernization work, but the new project is centered on R and on a reusable validation workflow rather than on a single translation system.

Over four months, we will:

1. define a machine-readable equivalence contract;
2. implement deterministic comparison of datasets and selected analytical results;
3. demonstrate SAS -> R modernization using pregenerated SAS reference artifacts;
4. demonstrate legacy R -> modern R using the same validation framework;
5. connect validation diagnostics to a model-independent LLM repair loop; and
6. provide an R-friendly workflow, CI example, documentation, and an initial release.

For the R community, the benefit is a second path to long-term reviewability. Instead of preserving an old runtime indefinitely, a workflow can be modernized while the trusted implementation remains the reference for what must not change.

## Detail

The project separates code generation from acceptance.

The LLM is responsible for proposing a refactor, translation, or repair. `equivR` is responsible for deciding whether that proposal is analytically equivalent to the trusted reference.

The basic workflow is:

```
trusted reference
      |
      v
reference artifacts

source code
      |
      v
LLM modernization
      |
      v
candidate implementation
      |
      v
execute and normalize
      |
      v
deterministic validation
   |               |
 PASS             FAIL
   |               |
accept         diagnostics
                   |
                   v
                repair
                   |
                   +----> validate again
```

The first demonstration will use a trusted SAS workflow and an R candidate. The second will use legacy R and modern R. Together, these cases show that the same validation layer can support both cross-runtime migration and long-term maintenance within R.

### Minimum Viable Product

The Phase 1 MVP will allow a user to:

1. provide trusted reference artifacts and source code to be modernized;
2. generate or revise an R candidate with a selected LLM;
3. declare what must remain equivalent, including:
   * row keys and identity;
   * required variables and schema;
   * missing-value behavior;
   * ignored metadata;
   * exact categorical values;
   * numerical tolerances; and
   * selected results such as estimates, confidence intervals, counts, and p-values;
4. execute the R candidate and normalize its outputs;
5. receive deterministic PASS/FAIL status with structured diagnostics;
6. send failed diagnostics back to the LLM for another repair attempt; and
7. record machine-readable and human-readable validation evidence.

Two public examples will be delivered:

* SAS -> R, using pregenerated SAS reference artifacts so a SAS runtime is not required in CI; and
* legacy R -> modern R, showing that the same workflow applies to R maintenance and refactoring.

A contribution format will allow additional community cases to be added later.

### Architecture

Phase 1 has four main components.

**1. LLM modernization interface.** A model-independent interface sends source code, task context, and validation diagnostics to an LLM and receives a proposed implementation or repair. `equivR` will not depend on one model provider or model family.

**2. Equivalence contract.** A machine-readable contract defines what behavior must be preserved. This makes acceptance criteria explicit instead of scattering them across one-off scripts and manual review.

**3. Runtime and artifact layer.** The candidate is executed and its outputs are converted into a common form for comparison. Trusted SAS artifacts may be generated ahead of time, so the proprietary runtime does not need to be present in CI.

**4. Deterministic validator and evidence.** The validator applies the contract to the trusted and candidate artifacts. Any failed required check blocks acceptance and produces structured diagnostics. Passing runs produce reproducibility metadata and validation evidence that can be used locally or in CI.

The R-facing interface will be kept thin: an R-friendly command or wrapper will invoke the workflow without requiring users to interact directly with the internal orchestration layer.

### Assumptions

The project depends on a few explicit assumptions.

* A trusted reference implementation or trusted reference artifacts are available.
* The behavior that matters can be expressed through datasets and selected analytical results.
* Acceptable differences can be stated explicitly, including numerical tolerances where exact equality is not appropriate.
* General-purpose LLMs are capable of producing useful SAS -> R and legacy R -> modern R candidates when given source code and repair diagnostics.

If an LLM cannot complete a transformation, the validation layer still remains useful: it can evaluate human-written or externally generated candidates. If a behavior cannot be represented by the Phase 1 contract, that behavior will be documented as out of scope rather than treated as verified.

Phase 1 deliberately limits scope to small, testable examples and artifact-based validation. It does not attempt to prove universal program equivalence or cover every SAS/R feature.

### External dependencies

The project will use open-source R and Python libraries, standard CI tooling, and existing general-purpose LLMs.

The automated modernization loop requires access to an LLM, but not to any particular vendor. The interface will allow different capable hosted or local models to be used.

SAS is needed only to create the trusted reference artifacts for the initial SAS -> R example. The shipped CI workflow will use pregenerated artifacts and will not require licensed SAS software.

Any proprietary model API costs used during development or evaluation will be self-funded or provided in kind rather than charged to the ISC grant.

# Project plan

## Start-up phase

**Month 1.** Finalize governance, **MIT license**, contribution guidance, CI/reporting, the contract schema, validation-result model, and core/adapter boundary. The existing proof of concept already demonstrates exact-match, within-tolerance, mismatch, and structural-failure cases.

## Technical delivery

**M1 - Contract and dataset validation (Month 1-2) - $1,250.** Implement keyed matching, schema/missingness checks, exact categorical and tolerance-aware numeric comparison, and structured diagnostics; public fixtures show pass/fail behavior.

**M2 - Cross-runtime normalization and structured results (Month 2) - $1,000.** Add artifact adapters and comparison of named results; one example validates pregenerated cross-runtime artifacts against an R candidate without a proprietary runtime in CI.

**M3 - R-facing workflow and benchmark suite (Month 2-3) - $1,000.** Provide an R-friendly CLI/thin wrapper and reference CI workflow; both initial benchmark cases run from a clean checkout with a documented contribution path.

**M4 - Evidence and closed-loop validation (Month 3-4) - $750.** Capture R/Python session metadata, source revision, checksums, and machine-readable results; demonstrate a failed candidate repaired and accepted only after all required contract checks pass.

**M5 - Documentation and release (Month 4) - $1,000.** Complete user/architecture/contribution documentation, benchmark examples, and release hardening; publish an initial tagged release.

## Other aspects

Development is public at <https://github.com/zhuygln/equivR> under the **MIT License**, with a documented community benchmark format and feedback through GitHub issues/discussions. We will publish project announcement and completion/update material suitable for R Consortium/community channels.

## Budget & funding plan

| Milestone | Amount |
|---|---:|
| Contract and dataset validation | $1,250 |
| Cross-runtime normalization and structured results | $1,000 |
| R-facing workflow and benchmark suite | $1,000 |
| Evidence and closed-loop validation | $750 |
| Documentation and release | $1,000 |
| **Total** | **$5,000** |

No grant funds are requested for travel, workshops, hardware, publication fees, cloud services, AI credits, indirect costs, or licensed SAS software.

# Success

## Definition of done

An R user can provide reference artifacts and a candidate, declare a contract, run validation locally or in CI, and receive deterministic diagnostics and reproducible evidence without the reference runtime present. Both initial benchmark cases run from a clean checkout, and one closed-loop example accepts a repaired candidate only after **100% of required declared checks pass**. A contribution specification supports additional community cases.

## Measuring success

Success means: CI passes; both benchmark cases reproduce from a clean checkout; deterministic machine- and human-readable evidence is produced; the closed-loop example passes; an R-friendly invocation path and benchmark contribution specification are documented; and an initial tagged release is published. Any declared mismatch must fail closed with actionable diagnostics.

## Future work

Future consumers may include live SAS/other runtime adapters, richer result schemas, hybrid SAS/R or Python/R orchestration, repository-scale translation, and automated multi-step repair - not Phase 1 deliverables.
