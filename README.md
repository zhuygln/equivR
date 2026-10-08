# equivR

**Reproducible Cross-Runtime Equivalence for R Analytics**

`equivR` is an independent open-source toolkit for modernizing analytical code while independently verifying that its analytical behavior is preserved. It checks whether a candidate implementation reproduces the results of a trusted reference under an explicit, versioned equivalence contract.

R is the community and workflow focus. A trusted reference may come from SAS, legacy R, or another runtime; a candidate may be modern R written by a developer or proposed by a large language model (LLM). Acceptance is based only on observed artifacts and the declared contract.

> **Generation proposes; validation decides.**

A candidate is accepted only when **all required checks in the declared contract pass**; otherwise the result is FAIL with deterministic diagnostics for repair and re-validation. An LLM may generate or repair code, but it never decides acceptance. No claim is made beyond what the contract declares.

## Proposed Phase 1

The R Consortium ISC 2026-2 proposal in [`proposal/`](proposal/) (not yet awarded) describes a four-month Phase 1:

1. **SAS -> R** modernization demonstration, validated against pregenerated SAS reference artifacts, so public CI never needs a SAS runtime;
2. **legacy R -> modern R** demonstration using the same framework;
3. a model-independent, bounded LLM repair loop driven by validation diagnostics;
4. an R-friendly local/CI workflow, reproducibility evidence, documentation, and an initial release.

Phase 1 is not a general-purpose SAS-to-R translator, a live SAS integration, regulatory certification, or a proof of universal program equivalence. See [`doc/equivR_implementation_plan.md`](doc/equivR_implementation_plan.md) for the milestone schedule.

## Project leads

- **Yonglin Zhu — co-PI / co-lead; Senior Staff Scientist at SAS Institute** ([ORCID](https://orcid.org/0000-0003-0245-827X))
- **Xing Cai — co-PI / co-lead; founding member of the R Working Group at Thermo Fisher Scientific Inc.** ([ORCID](https://orcid.org/0009-0004-5983-3338), [LinkedIn](https://www.linkedin.com/in/xingcai))

Both project leads have current employers, but `equivR` is independent open-source work. It is not sponsored, funded, directed, or endorsed by either employer, and it does not depend on employer-owned code, data, infrastructure, or proprietary resources.

## R Consortium ISC proposal

This repository is the project link for our **R Consortium ISC 2026-2** grant proposal.

All proposal sources live in [`proposal/`](proposal/) and follow the official R Consortium ISC Quarto structure:

- `proposal/isc-proposal.qmd` (entry point)
- `proposal/00-exec-summary.qmd`
- `proposal/01-signatories.qmd`
- `proposal/02-problemdefinition.qmd`
- `proposal/03-proposal.qmd`
- `proposal/04-timeline.qmd`
- `proposal/05-success.qmd`
- `proposal/figures/equivR-workflow.pdf` (Figure 1)
- `proposal/SUBMISSION_FORM.md`

Project code lives at the repo root as an R package:

- Package sources: [`R/`](R/) (contract, normalization, dataset comparison, result/evidence)
- Contract specification: [`doc/contract.md`](doc/contract.md) and JSON schemas in [`schemas/`](schemas/)
- Examples: [`examples/basic_validation.R`](examples/basic_validation.R) and [`examples/contracts/`](examples/contracts/)
- Implementation plan: [`doc/equivR_implementation_plan.md`](doc/equivR_implementation_plan.md)

Render the proposal from inside the `proposal/` directory:

```sh
cd proposal && quarto render isc-proposal.qmd
```

The proposal uses the official [`RConsortium/isc-proposal`](https://github.com/RConsortium/isc-proposal) structure and Hikmah PDF format.

## Install and run

`equivR` is in early development. Milestone M1 (equivalence contract and deterministic dataset validation) is implemented: `contract-v1` in YAML/JSON or built in R, CSV/RDS/data-frame datasets, eleven named schema/key/row/value checks, fail-closed aggregation, and JSON evidence with SHA-256 checksums. Structured analytical results (the contract's reserved `results` section), SAS artifact adapters, the R command-line wrapper, and the LLM repair loop are planned for M2-M4.

```r
# install.packages("remotes")
remotes::install_github("zhuygln/equivR")
```

Validate a candidate against a reference with a YAML contract:

```r
library(equivR)

res <- equiv_validate(contract = "contract.yaml")   # artifacts declared in the contract
res                                                 # human-readable report
equiv_passed(res)                                   # TRUE only if all required checks pass
write_result_json(res, "evidence.json")             # machine-readable evidence
```

Or build the contract in R:

```r
res <- equiv_validate(reference_df, candidate_df,
                      equiv_contract(keys = "id", abs_tol = 1e-8, rel_tol = 1e-8))
```

Semantics are fail-closed:

- exact match -> PASS;
- numerical difference inside tolerance -> PASS;
- numerical difference outside tolerance -> FAIL with diagnostics;
- structural, key, or missing-value mismatch -> FAIL;
- a required check that cannot be evaluated -> FAIL.

Development:

```sh
R CMD INSTALL . && Rscript examples/basic_validation.R
Rscript -e 'testthat::test_local()'
EQUIVR_UPDATE_GOLDEN=1 Rscript -e 'testthat::test_local()'   # regenerate golden evidence, then review the diff
```

## License

Software code in this repository is released under the [Mozilla Public License 2.0 (MPL-2.0)](LICENSE). The proposal scaffold and retained Hikmah formatting files derive from the official R Consortium ISC proposal template; see [`NOTICE.md`](NOTICE.md).

## Funding note

The proposal requests **$5,000 over four months**; no funding has been awarded yet. No ISC funding is requested for travel, workshops, hardware, publication fees, cloud services, AI credits, indirect costs, or licensed SAS software.

## Status

- **M1** (equivalence contract and deterministic validation): implemented, under review in pull request #1.
- **Next: M2** (SAS -> R modernization demonstration with pregenerated SAS reference artifacts).
- Grant proposal: prepared for the R Consortium ISC 2026-2 cycle; not yet awarded.
