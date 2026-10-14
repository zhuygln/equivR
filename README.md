# equivR

**Reproducible Cross-Runtime Equivalence for R Analytics**

`equivR` is an independent open-source project for modernizing analytical code while independently verifying that its declared analytical behavior matches trusted reference artifacts. The first planned demonstration is **SAS → R**, using pregenerated SAS outputs; the second is **legacy R → modern R**.

> **Generation proposes; validation decides.**

A human or a large language model (LLM) may write or repair candidate R code, but only deterministic validation against a versioned equivalence contract decides acceptance. A candidate is accepted only when all required checks in the contract pass; anything else is FAIL with diagnostics for repair. A PASS certifies only what the contract checks; it is not a proof of general program equivalence.

## Planned architecture

One authoritative R validator, used in three ways (see [`doc/equivR_implementation_plan.md`](doc/equivR_implementation_plan.md)):

1. **Validation-only / R-native:** an installable R package for local and CI use, with no Python, API key, coding assistant, or model credentials required.
2. **Standalone modernization agent:** an optional Python CLI that uses an interchangeable coding-agent SDK to propose and repair an R candidate, then calls the same R validator.
3. **Bring Your Own Agent (BYOA):** users of GitHub Copilot in VS Code, Claude Code, or OpenAI Codex call `equivR` through a local MCP server, the CLI, and portable Agent Skills, keeping their existing approved sign-in. No separate `equivR` model subscription is needed in this mode.

In every mode the coding agent can edit only the candidate. It cannot change the locked reference artifacts, the contract, the validator, or the verdict. Because an external agent may skip validation, the final verdict must always be reproducible with the independent validate command and in CI.

Phase 1 is artifact-based. It is not a general SAS-to-R or Python-to-R translator, does not need live SAS in CI, and is not regulatory certification.

## Current status

This is early-stage work. **None of the architecture above is implemented on `main` yet.**

- **On `main`:** a small base-R proof of concept, [`R/equivR.R`](R/equivR.R), with [`examples/basic_validation.R`](examples/basic_validation.R). It demonstrates the fail-closed acceptance rule: exact match → PASS; numeric difference within tolerance → PASS; difference outside tolerance → FAIL with diagnostics; structural or key mismatch → FAIL.
- **Reference only:** an earlier M1 implementation (R package, `contract-v1` parser, dataset checks, golden tests) is kept on the unmerged branch `feature/m1-deterministic-core` from closed pull request #1. Pieces may be ported later; it is not the baseline.
- **Next:** an architecture decision record, a small synthetic SAS → R task, and a time-boxed coding-agent SDK comparison (implementation plan, Section 12).

Run the prototype checks with:

```sh
Rscript examples/basic_validation.R
```

## Project leads

- **Yonglin Zhu — co-PI / co-lead; Senior Staff Scientist at SAS Institute** ([ORCID](https://orcid.org/0000-0003-0245-827X))
- **Xing Cai — co-PI / co-lead; founding member of the R Working Group at Thermo Fisher Scientific Inc.** ([ORCID](https://orcid.org/0009-0004-5983-3338), [LinkedIn](https://www.linkedin.com/in/xingcai))

Both project leads have current employers, but `equivR` is independent open-source work. It is not sponsored, funded, directed, or endorsed by either employer, and it does not depend on employer-owned code, data, infrastructure, or proprietary resources.

## R Consortium ISC proposal

This repository is the project link for our **R Consortium ISC 2026-2** grant proposal. **The grant has not been awarded**; the proposal describes the Phase 1 work we plan to do, and development can proceed independently of an award.

The proposal requests **$5,000 over four months** across five milestones:

| Milestone | Deliverable |
|---|---|
| M1 | Equivalence contract, deterministic validation, diagnostics, tests |
| M2 | SAS → R modernization demonstration using pregenerated SAS references |
| M3 | Legacy R → modern R, R-friendly invocation, CI, benchmark format |
| M4 | Model-independent bounded LLM repair loop and reproducibility evidence |
| M5 | Documentation, examples, release hardening, tagged release |

No ISC funding is requested for travel, workshops, hardware, publication fees, cloud services, AI credits, indirect costs, or licensed SAS software.

Proposal sources live in [`proposal/`](proposal/) and follow the official R Consortium ISC Quarto structure:

- `proposal/isc-proposal.qmd` (entry point) and section files `00-exec-summary.qmd` … `05-success.qmd`
- `proposal/equivR_ISC_2026-2_proposal.md` (combined Markdown copy)
- `proposal/figures/equivR-workflow.pdf` (Figure 1)
- `proposal/isc-proposal.pdf` (rendered proposal) and `proposal/SUBMISSION_FORM.md`

Render the proposal from inside `proposal/`:

```sh
cd proposal && quarto render isc-proposal.qmd --to hikmah-pdf
```

## License

Software code in this repository is released under the [Mozilla Public License 2.0 (MPL-2.0)](LICENSE). The proposal scaffold and retained Hikmah formatting files derive from the official R Consortium ISC proposal template; see [`NOTICE.md`](NOTICE.md).
