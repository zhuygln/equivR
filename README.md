# equivR

**Reproducible Cross-Runtime Equivalence for R Analytics**

`equivR` is a proposed open-source R package for validating whether a candidate R analytical workflow reproduces the important data and statistical results of a trusted reference implementation.

The initial motivating use case is SAS-to-R and hybrid SAS/R analytics, but the core abstraction is broader:

```text
trusted reference + candidate R output + equivalence contract
                         ↓
                validation evidence
```

This repository is currently being prepared for the R Consortium ISC 2026-2 technical grant call.


## Project leads

- **Yonglin Zhu — co-PI / co-lead** ([ORCID](https://orcid.org/0000-0003-0245-827X))
- **Xing Cai — co-PI / co-lead** ([LinkedIn](https://www.linkedin.com/in/xingcai))

Both project leads have current employers, but `equivR` is independent open-source work. It is not sponsored, funded, directed, or endorsed by either employer, and it does not depend on employer-owned code, data, infrastructure, or proprietary resources.

## Proposal

The proposal follows the official R Consortium ISC Quarto structure:

- `proposal/00-exec-summary.qmd`
- `proposal/01-signatories.qmd`
- `proposal/02-problemdefinition.qmd`
- `proposal/03-proposal.qmd`
- `proposal/04-timeline.qmd`
- `proposal/05-success.qmd`

Render `isc-proposal.qmd` with Quarto.

## Initial MVP

The first release aims to provide:

- explicit equivalence contracts;
- dataset/schema/value comparison;
- tolerance-aware numerical validation;
- selected structured analytical-result comparison;
- reproducible CI metadata;
- machine-readable validation output; and
- a human-readable evidence report.

Automatic SAS-to-R translation and coding-agent repair are future research directions, not grant deliverables.

## Status

Proposal / prototype stage.

## License

MIT proposed for the project code. Proposal text may use an appropriate documentation license separately.
