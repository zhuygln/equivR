# equivR

**Reproducible Cross-Runtime Equivalence for R Analytics**

`equivR` is an independent open-source cross-runtime validation toolkit for R modernization and migration. It validates whether a new analytical implementation reproduces the important data and statistical results of a trusted reference.

R is the community and workflow focus, not a restriction on implementation language. A trusted reference may originate in legacy R, SAS, Python, or another analytical runtime. A candidate may be modern R, a refactor, a package migration, or AI-assisted code. The validation infrastructure may use R and Python internally, but acceptance is based on independently observed artifacts and an explicit equivalence contract.

> **Generation proposes; validation decides.**

A candidate is accepted only when **all required checks in the declared contract pass**. Otherwise `equivR` returns deterministic diagnostics for repair and re-validation.

## Phase 1 scope

The R Consortium ISC proposal funds a focused first phase:

- a language-neutral equivalence-contract specification;
- deterministic dataset and structured-result validation;
- runtime/artifact normalization for R and pregenerated cross-runtime references;
- an R-friendly CLI or thin wrapper plus CI workflow;
- reproducibility metadata and machine-/human-readable evidence;
- an initial benchmark suite with:
  1. legacy R -> modern R, and
  2. cross-runtime trusted reference -> R;
- a documented format for community-contributed benchmark cases.

The grant does **not** fund a general SAS-to-R or Python-to-R translator, a coding agent, live SAS integration, regulatory certification, or a proof of universal program equivalence. Those may become future consumers or extensions of the validation layer.

## Project leads

- **Yonglin Zhu — co-PI / co-lead; Senior Staff Scientist at SAS Institute** ([ORCID](https://orcid.org/0000-0003-0245-827X))
- **Xing Cai — co-PI / co-lead; founding member of the R Working Group at PPD** ([ORCID](https://orcid.org/0009-0004-5983-3338), [LinkedIn](https://www.linkedin.com/in/xingcai))

Both project leads have current employers, but `equivR` is independent open-source work. It is not sponsored, funded, directed, or endorsed by either employer, and it does not depend on employer-owned code, data, infrastructure, or proprietary resources.

## R Consortium ISC proposal

This repository is the project link for our **R Consortium ISC 2026-2** technical grant proposal.

All proposal sources live in [`proposal/`](proposal/) and follow the official R Consortium ISC Quarto structure:

- `proposal/isc-proposal.qmd` (entry point)
- `proposal/00-exec-summary.qmd`
- `proposal/01-signatories.qmd`
- `proposal/02-problemdefinition.qmd`
- `proposal/03-proposal.qmd`
- `proposal/04-timeline.qmd`
- `proposal/05-success.qmd`
- `proposal/figures/equivR-cross-runtime-overview.png`
- `proposal/SUBMISSION_FORM.md`

Project code lives at the repo root:

- Minimal prototype: [`R/equivR.R`](R/equivR.R)
- Prototype examples: [`examples/basic_validation.R`](examples/basic_validation.R)

Render the proposal from inside the `proposal/` directory:

```sh
cd proposal && quarto render isc-proposal.qmd
```

The proposal uses the official [`RConsortium/isc-proposal`](https://github.com/RConsortium/isc-proposal) structure and Hikmah PDF format.

## Initial prototype

The current base-R proof of concept demonstrates the fail-closed acceptance semantics the full toolkit will preserve:

- exact match -> PASS;
- numerical difference inside tolerance -> PASS;
- numerical difference outside tolerance -> FAIL with diagnostics;
- structural/key mismatch -> FAIL.

This is deliberately small. The grant expands the proof of concept into reusable cross-runtime infrastructure, R-facing workflows, evidence generation, and community benchmarks.

Run the prototype checks with:

```sh
Rscript examples/basic_validation.R
```

## License

Software code in this repository is released under the [MIT License](LICENSE). The proposal scaffold and retained Hikmah formatting files derive from the official R Consortium ISC proposal template; see [`NOTICE.md`](NOTICE.md).

## Funding note

The proposal requests **$5,000 over four months**. No ISC funding is requested for travel, workshops, hardware, publication fees, cloud services, AI credits, indirect costs, or licensed SAS software.

## Status

Early prototype and grant-proposal stage.
