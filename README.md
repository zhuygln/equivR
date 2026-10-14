# equivR

**Reproducible Cross-Runtime Equivalence for R Analytics**

`equivR` is an independent open-source project that **modernizes analytical code through an agentic workflow and establishes confidence in the result through independent, reproducible verification.** The first planned demonstration is **SAS → R**, using pregenerated SAS reference outputs; the second is **legacy R → modern R**.

The goal is not to compare two saved tables. Given an existing analytical program, equivR is meant to understand it, generate an R implementation with an LLM-powered coding agent, execute it against trusted reference results, diagnose semantic differences (missing values, numerical methods, statistical conventions, data handling), repair the code, and produce **modernized R code plus a verification report**: code changes, reproducible tests, provenance and residual limitations.

> **Generation proposes; validation decides.**

The agent writes and repairs code, but it never decides acceptance. Only independent, deterministic verification against declared acceptance criteria can accept a candidate, and a PASS certifies only what was checked; it is not a proof of general program equivalence.

## Planned architecture

```text
Original SAS / legacy R project
        |
Agentic modernization engine
  Analyze -> Plan -> Generate -> Execute -> Diagnose -> Repair
  (standalone coding-agent SDK, or Copilot / Claude Code / Codex)
        |            ^
        v            |  diagnostics
Verification and convergence infrastructure
  contracts · test generation · reference artifacts · statistical checks
  invariants · differential testing · evidence
        |
Modernized R code + verification report
```

Two user-facing workflows (see [`doc/equivR_implementation_plan.md`](doc/equivR_implementation_plan.md)):

1. **Standalone modernization:** equivR runs its own coding agent and verification loop.
2. **Bring Your Own Agent:** GitHub Copilot, Claude Code or OpenAI Codex uses equivR's modernization skills, execution tools and verification infrastructure through a local MCP server and CLI, keeping its existing approved sign-in.

Underneath both, a deterministic verification core in R can be re-run on its own, locally or in CI, without Python, a coding assistant or model credentials, so any verdict reached during an agent session can be reproduced and audited. The agent can edit only the candidate code, never the locked references, tests, contract or verdict.

Phase 1 is deliberately bounded: pregenerated SAS reference artifacts, selected analytical results, a bounded repair example, and no live SAS in CI. It is not a general SAS-to-R translator or regulatory certification.

## Current status

This is early-stage work. **None of the architecture above is implemented on `main` yet.**

- **On `main`:** a small base-R proof of concept, [`R/equivR.R`](R/equivR.R), with [`examples/basic_validation.R`](examples/basic_validation.R). It demonstrates the fail-closed acceptance rule: exact match → PASS; numeric difference within tolerance → PASS; difference outside tolerance → FAIL with diagnostics; structural or key mismatch → FAIL.
- **Reference only:** an earlier M1 implementation (R package, `contract-v1` parser, dataset checks, golden tests) is kept on the unmerged branch `feature/m1-deterministic-core` from closed pull request #1. Pieces may be ported later; it is not the baseline.
- **Next:** a vertical slice of the whole workflow on one small synthetic SAS program (analyze → plan → generate → execute → diagnose → repair → verification report), together with a time-boxed coding-agent SDK comparison (implementation plan, Section 12).

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
