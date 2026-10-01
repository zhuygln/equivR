# equivR: Reproducible Cross-Runtime Equivalence for R Analytics

*R Consortium ISC 2026-2 grant proposal — convenience combined Markdown copy.*

# Executive Summary

`equivR` is an open-source cross-runtime validation toolkit for R modernization and migration. It is designed for workflows in which R is a source, target, or participating runtime: for example, legacy R to modern R, SAS to R, Python to R, package replacement, refactoring, and AI-assisted R development. The validation infrastructure may use Python internally for orchestration and artifact handling, while the interfaces, examples, and benchmark cases are centered on R-community workflows.

The core principle is:

> **Generation proposes; validation decides.**

A large language model, translator, or developer may generate or repair code, but `equivR` never accepts a candidate because its producer says it is correct. A candidate must execute and satisfy an explicit equivalence contract against a trusted reference. Any failed required check blocks acceptance and returns deterministic diagnostics for repair and re-validation. Within the declared contract, acceptance requires **100% of required checks passing**.

This need is visible in current R Consortium work. The Submissions Working Group has highlighted reproducibility and reviewability challenges [@reviewable2026], while Pilot 5 already performs project-specific QC by comparing R-generated ADaM datasets with prior reference datasets in CI [@pilot5].

A minimal proof of concept already demonstrates the core fail-closed comparison pattern, including exact matches, tolerance-aware numerical comparison, structural mismatches, and deterministic failure diagnostics. The grant will turn that pattern into reusable cross-runtime infrastructure with a language-neutral equivalence contract, runtime adapters, structured-result validation, reproducibility metadata, R-facing workflows, and a community benchmark format.

We request **$5,000 over four months**, entirely for project labor and technical development. No grant funds are requested for cloud or AI credits.

# Signatories

## Project team

**Yonglin Zhu - co-PI / co-lead; Senior Staff Scientist at SAS Institute.** ORCID: [0000-0003-0245-827X](https://orcid.org/0000-0003-0245-827X). Yonglin has experience modernizing SAS-based analytical systems, cross-language execution, numerical validation, Python-based tooling, and AI-assisted code transformation. He will lead architecture, equivalence-contract design, and validation workflow implementation. Public project artifact: <https://github.com/zhuygln/equivR>.

**Xing Cai - co-PI / co-lead; founding member of the R Working Group at PPD.** ORCID: [0009-0004-5983-3338](https://orcid.org/0009-0004-5983-3338). Xing has applied analytics experience with SAS, R, Python, statistical modeling, and data-science workflows. She will co-lead R-community use-case design, testing, documentation, and applied evaluation.

`equivR` is independent open-source work. It is not sponsored, funded, directed, or endorsed by either co-PI's employer and does not depend on employer-owned code, data, or infrastructure.

## Contributors

None at submission time. Community contributions will be welcomed through the public repository and benchmark-contribution process.

## Consulted

No formal external reviewers at submission time. The project design is informed by public R Consortium Submissions Working Group materials [@pilot5; @submissions2026; @reviewable2026]. The project will actively solicit feedback through the public repository and community benchmark process; citation of public material does not imply endorsement.

---
bibliography: references.bib
---

# The Problem

When analytical software is modernized across runtimes - for example, legacy R to modern R, SAS to R, Python to R, or an existing R workflow to an AI-assisted rewrite - producing code that runs is not enough. The harder question is whether the new implementation preserves the analytical behavior that matters.

This affects R developers and analytical teams modernizing validated workflows, maintainers replacing legacy implementations or packages, and teams adopting cross-language or AI-assisted coding where independent evidence of analytical equivalence is needed.

Today this decision is often encoded in one-off scripts. Keys, missing-value rules, ignored metadata, numerical tolerances, required estimates, confidence intervals, and other acceptance criteria are scattered across tests rather than represented as a reusable contract.

AI makes this problem more urgent. An LLM can produce plausible code that is subtly wrong. Asking the same model to review its own output, or generating several variants and choosing the most convincing one, does not provide independent evidence.

`equivR` separates **candidate generation from acceptance**. The source and candidate may be written in different languages; the implementation language is intentionally outside the trust model. Acceptance is based on observed reference/candidate artifacts and an explicit equivalence contract. Every required condition must pass; otherwise the candidate is rejected and structured diagnostics identify what needs repair.

The R Consortium Submissions Working Group already demonstrates the practical value of reference-based validation. Pilot 5 compares R-generated ADaM datasets with prior reference datasets and runs those checks in GitHub Actions [@pilot5]. Recent Working Group discussion emphasizes reproducibility, environment setup, and evidence supporting reviewability [@reviewable2026], while its 2026 plans expand R programs and AI/automation work [@submissions2026].

Object- and data-frame comparison tools address parts of this workflow, but projects still need to assemble their own higher-level acceptance logic around declared criteria, cross-runtime normalization, analytical results, provenance, CI gating, diagnostics, and re-validation. `equivR` targets that reusable layer for the R community.

# The proposal

## Overview

Over four months, we propose `equivR`, an open-source cross-runtime validation toolkit for R modernization and migration. **R is the community and workflow focus, not a restriction on the implementation language.**

A trusted reference may originate in legacy R, SAS, Python, or another analytical runtime. The candidate may be a modern R implementation, a refactor, a package migration, or AI-assisted code. Both are reduced to inspectable artifacts and evaluated under a language-neutral equivalence contract. Runtime adapters normalize those artifacts, a deterministic validation core applies the contract, and R-facing CLI/wrapper/CI workflows expose the result to users. Python may be used internally where it simplifies orchestration or cross-runtime handling; it is an implementation detail rather than a source of analytical trust.

A candidate is accepted only when **all required checks in the declared contract pass**. Any failed check blocks acceptance and produces structured diagnostics for repair and re-validation. This lets generation and transformation techniques evolve independently while keeping the basis for analytical trust deterministic, inspectable, and reproducible.

![Cross-runtime architecture of `equivR`. Trusted references may originate in legacy R, SAS, Python, or another runtime; candidate generation is outside the trust boundary. A language-neutral contract, runtime normalization, and deterministic validation core control acceptance, while R-facing workflows and benchmark cases expose the infrastructure to the R community.](figures/equivR-cross-runtime-overview.png){#fig-equivr-overview width=100%}

## Detail

### Minimum Viable Product

The Phase 1 MVP will let a user:

1. provide trusted reference artifacts produced by legacy R, SAS, Python, or another runtime and a candidate implementation/output in an R modernization workflow;
2. declare keys, schema constraints, ignored fields, missing-value rules, numerical tolerances, and required analytical outputs;
3. normalize and compare datasets and selected structured analytical results;
4. receive deterministic pass/fail status and repair-oriented diagnostics;
5. record reproducibility metadata and artifact checksums;
6. generate machine-readable and human-readable validation evidence; and
7. invoke the workflow from an R-friendly command-line or thin wrapper interface and CI.

Version 1 will cover row identity, required variables, missing values, exact categorical values, tolerance-aware numeric values, and selected results such as estimates, confidence intervals, counts, and p-values.

The project will also define a **community benchmark case format**. The initial suite will contain at least two deliberately different R-relevant cases: **(1) legacy R -> modern R** and **(2) cross-runtime trusted reference -> R**, using pregenerated reference artifacts so no licensed SAS runtime is required in CI. Additional community cases may cover package replacement, refactoring, Python-to-R, SAS-to-R, or AI-assisted R transformation.

**Scope boundary.** This grant does not fund a general SAS-to-R or Python-to-R translator, a coding agent, live SAS integration, regulatory certification, or a proof of universal program equivalence. Those systems may use `equivR` later. The funded deliverable is the independent validation infrastructure and its R-centered benchmark workflows.

### Architecture

`equivR` will separate five concerns:

1. a language-neutral equivalence contract describing what must match;
2. runtime adapters and artifact normalization for R and pregenerated cross-runtime outputs;
3. a deterministic validation core, implemented in R and/or Python where appropriate;
4. an R-facing workflow layer for local use and CI; and
5. evidence generation for machine-readable results, human-readable reports, and reproducibility metadata.

The implementation language of the reference and candidate is intentionally not part of the trust model. A reference may originate in legacy R, SAS, Python, or another runtime; acceptance depends on independently observed artifacts and the declared equivalence contract.

A bounded evaluation harness will also exercise the framework with an LLM-generated or LLM-revised R candidate. The model is outside the trust boundary: it may propose a repair, but only `equivR` can accept the result. This demonstrates **generate -> validate -> diagnose -> repair -> revalidate** without making AI itself a required dependency.

### Assumptions

The MVP assumes users can identify a trusted reference and that important acceptance criteria can initially be expressed through structured datasets and selected analytical results. Numerical equivalence may use explicit tolerances rather than bitwise identity.

The main delivery risks are scope expansion, insufficiently representative benchmark cases, and complexity from multiple runtimes. Scope is controlled by limiting Phase 1 to artifact-based validation rather than code translation or live multi-runtime execution. Cross-runtime coverage uses pregenerated reference artifacts and small adapters. Benchmark coverage is addressed by shipping reference cases and publishing a community contribution format. Behavior outside the declared contract is not claimed to be verified.

### External dependencies

The project will use open-source R and Python libraries plus standard CI tooling. There is no dependency on licensed SAS software: SAS or other proprietary reference artifacts can be generated beforehand. No grant funding will be used for cloud services or AI credits. Hosted-model evaluation, if used, will be provided in-kind; open/local models may also be used.

# Project plan

## Start-up phase

**Month 1.** Finalize governance, the **MIT software license**, contribution guidance, GitHub issue/CI reporting, the language-neutral contract schema, validation-result model, and the boundary between the core and runtime adapters. A minimal proof of concept already demonstrates exact-match, within-tolerance, mismatch, and structural-failure cases.

## Technical delivery

### Milestone 1 - Contract and dataset validation (Month 1-2) - $1,250

Implement the equivalence-contract schema, keyed matching, schema/missingness checks, exact categorical comparison, tolerance-aware numeric comparison, and structured diagnostics.

**Outcome:** public fixtures demonstrate both passing and failing cases under a declared contract.

### Milestone 2 - Cross-runtime normalization and structured results (Month 2) - $1,000

Add artifact normalization/adapters and comparison of named results such as estimates, confidence intervals, counts, and p-values.

**Outcome:** one cross-runtime example validates pregenerated reference artifacts against an R candidate without requiring a proprietary runtime in CI.

### Milestone 3 - R-facing workflow and benchmark suite (Month 2-3) - $1,000

Provide an R-friendly CLI or thin wrapper plus reference CI workflow. Implement the initial benchmark suite with a legacy-R -> modern-R case and a cross-runtime -> R case.

**Outcome:** both benchmark cases run from a clean checkout, and the repository documents how new benchmark cases are contributed.

### Milestone 4 - Evidence and closed-loop validation (Month 3-4) - $750

Capture R/Python session metadata, source revision when available, and artifact checksums; provide machine-readable results and a bounded failed-to-repaired candidate example.

**Outcome:** a clean checkout produces deterministic validation evidence, and one candidate is accepted only after all required contract checks pass.

### Milestone 5 - Documentation and release (Month 4) - $1,000

Complete user documentation, architecture/contribution guidance, benchmark documentation, examples, and release hardening.

**Outcome:** publish an initial tagged release with reproducible R-centered examples.

## Other aspects

Development will be public at <https://github.com/zhuygln/equivR> under the **MIT License**. The repository will include a documented format for **community benchmark cases**, inviting users to contribute small, openly licensed analytical code bases and reference/candidate pairs that exercise real R migration and modernization scenarios.

We will publish an initial project announcement and a completion/update post suitable for R Consortium and community channels, and use GitHub issues and discussions to collect implementation and benchmark feedback.

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

The project is done when an R user can provide trusted reference artifacts and a candidate, declare an equivalence contract, run validation locally or in CI, and receive deterministic diagnostics plus reproducible evidence without requiring the reference runtime to be present.

At least two benchmark cases will run from a clean checkout: **legacy R -> modern R** and **cross-runtime reference -> R**. One closed-loop example will begin with a failed candidate and accept the repaired candidate only after **100% of required checks in the declared contract pass**. This refers only to declared checks, not universal semantic equivalence.

The project will also be **benchmark-ready**: it will publish a contribution specification and repository structure for additional community-contributed cases.

## Measuring success

Success will be measured by: all automated CI checks passing; both initial benchmark cases reproducing from a clean checkout; deterministic machine-readable and human-readable evidence; one failed-to-repaired closed-loop example; a documented benchmark contribution specification; an R-friendly invocation path; and an initial tagged release.

The key behavior is **fail closed**: any declared mismatch blocks acceptance and produces actionable diagnostics.

## Future work

Extensions may include live SAS or other runtime adapters, richer result schemas, hybrid SAS/R or Python/R orchestration, repository-scale translation, and automated multi-step repair. These are future consumers or extensions of the validation layer, not Phase 1 deliverables. The long-term direction is evidence-driven modernization: code can be generated quickly, but trusted deployment requires independent validation.

