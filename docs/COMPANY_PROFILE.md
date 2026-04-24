# Company Profile

**Organization:** Wilkes & Liberty, LLC  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Overview

Wilkes & Liberty, LLC is a small technology firm providing headless CMS, web delivery, and digital infrastructure services. W&L has no active federal contracts. The compliance posture in this repo is aspirational-federal-readiness preparation for future W&L bids.

---

## Principal's Current Employment

Jeremy Michael Cerda (Owner, W&L) is concurrently W2-employed on a federal engagement. This is personal employment — W&L is not a party to that engagement.

| Field | Value |
|-------|-------|
| **Employment type** | W2 employee (not a W&L engagement) |
| **W2 employer / clearance sponsor** | Gridiron IT |
| **Employment chain** | Jeremy (W2) → Gridiron IT → GDIT → EPA |
| **Agency** | U.S. Environmental Protection Agency (EPA) |
| **Trust level** | Tier 4 Public Trust (High Risk) — Level 4 investigation |
| **W&L role in this chain** | None — W&L is not a party to this contract |

**Important distinctions:**
- W&L has no contractual relationship with EPA, GDIT, or Gridiron IT.
- Flow-down clauses, reporting obligations, and the federal contract device are Gridiron IT / Jeremy-as-individual concerns — not W&L concerns.
- Jeremy's Tier 4 clearance was obtained as a Gridiron IT W2 employee. It is his personal clearance, not a W&L clearance.

**W&L relevance:** This information is documented here because:
1. Jeremy's continuous-evaluation obligations (see [Continuous Evaluation](#continuous-evaluation)) affect the W&L environment indirectly — audit logging and access controls in this repo should meet the hygiene expectations of a Tier 4 holder.
2. When W&L begins bidding on federal work, Jeremy's concurrent EPA employment may trigger OCI analysis (see OPEN_ISSUES.md §6).
3. Aleksandra Cerda's spousal relationship with Jeremy is relevant to Jeremy's SF-86 (cohabitant scope) regardless of W&L's contracting status.

---

## Compliance Posture

W&L has no active federal contracts. The compliance documentation in `docs/compliance/` (SSP, POA&M, INCIDENT_RESPONSE, etc.) reflects **aspirational-federal-readiness** controls — good hygiene appropriate for a small firm whose principal holds federal trust clearance, and preparation for future W&L federal bids.

**Current-relevance framing:**
- The principal (Jeremy) is a cleared individual subject to Tier 4 Public Trust continuous evaluation. Audit logging, SSH session recording, and incident response in this repo are *consistent with* those expectations.
- Spousal disclosure documentation (see [Spousal / Related-Party Disclosure](#spousal--related-party-disclosure)) is load-bearing for Jeremy's clearance maintenance as an individual — SF-86 Section 18 covers cohabitants.

**Applicable frameworks (aspirational readiness for future W&L bids):**
- **NIST SP 800-171 Rev 2** — 110 controls; current implementation status in [SSP.md](compliance/SSP.md); gaps in [POAM.md](compliance/POAM.md)
- **FAR Part 9 / FAR 9.504** — Future W&L bids: spousal financial interests may constitute OCI; see OPEN_ISSUES.md §6 for analysis task
- **13 CFR 121 (SBA affiliation)** — Future W&L set-aside eligibility determinations; spousal business activities count; see OPEN_ISSUES.md §6

**Not yet applicable (monitor for future bids):**
- FAR 52.244-6 — subcontract flow-down; applies when W&L holds a subcontract
- DFARS 252.204-7012 — Safeguarding CDI; not applicable unless W&L holds a DoD subcontract
- FedRAMP — not applicable to this platform at present
- CMMC — would become relevant for DoD work

---

## Continuous Evaluation

Jeremy's Tier 4 Public Trust position is subject to periodic re-investigation and continuous evaluation as a Gridiron IT W2 employee:

- **Investigation scope:** Tier 4 (High Risk) investigations cover financial history, foreign contacts, cohabitants, and spouse (SF-86 Section 18 and Section 17). Aleksandra Cerda's information is included in Jeremy's adjudication as spouse/cohabitant.
- **Self-reporting obligations:** Reportable events include foreign travel, foreign contacts, financial hardship, arrests/charges, and cohabitant changes. Self-reporting routes through **Gridiron IT** (Jeremy's W2 employer and clearance sponsor of record) — not through W&L and not directly to the agency or GDIT. Consult Gridiron IT's FSO for specific triggers and timelines. See OPEN_ISSUES.md.
- **W&L infrastructure relevance:** The logging, audit trails, SSH session recording (Tailscale Premium), and incident response capabilities in this repo are *consistent with* the operational security hygiene expected of a Tier 4 holder. Unexplained or anomalous access events on infrastructure controlled by a Tier 4 holder may become relevant to continuous evaluation — though this environment is not an EPA-contract system.

---

## Spousal / Related-Party Disclosure

Aleksandra Cerda is Jeremy Michael Cerda's spouse. Relevant disclosures:

- **SF-86:** Spousal information is required in Section 18 (cohabitant/spouse); directly relevant to Jeremy's Tier 4 investigation as an individual cleared person.
- **FAR 9.504 (OCI — future W&L bids):** When W&L bids on federal work, spousal financial interests may constitute an Organizational Conflict of Interest. An OCI analysis will be required; see OPEN_ISSUES.md §6. Not a current obligation since W&L has no active federal contracts.
- **13 CFR 121 (SBA affiliation — future W&L set-asides):** Spousal business activities count toward affiliation for small-business set-aside eligibility (8(a), WOSB/EDWOSB, VOSB, HUBZone). Disclose in SAM.gov registration and set-aside certifications when W&L pursues these programs.
- **OGE standards:** Spousal employment/financial interests are reportable under OGE rules in a federal contractor context — becomes relevant when W&L holds a federal contract.

Aleksandra has a Tailscale and Keycloak account (`acerda`) for business continuity purposes. This account is documented in ROLES.md and PROJECT_PLAN.md Phase D. It does not constitute employment.

---

## Contact

**Owner / Primary Point of Contact:** Jeremy Michael Cerda  
**Email:** `jmcerda@wilkesliberty.com`  
**Organization:** Wilkes & Liberty, LLC
