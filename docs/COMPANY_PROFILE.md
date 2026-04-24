# Company Profile

**Organization:** Wilkes & Liberty, LLC  
**Maintained by:** Jeremy Michael Cerda (`jmcerda@wilkesliberty.com`)  
**Last reviewed:** 2026-04-23

---

## Overview

Wilkes & Liberty, LLC is a small technology firm providing headless CMS, web delivery, and digital infrastructure services.

---

## Current Engagements

### EPA Subcontract (Active)

| Field | Value |
|-------|-------|
| **Status** | Active |
| **Role** | Subcontractor |
| **Prime contractor** | [Prime name — fill in; treat as sensitive] |
| **Contract number** | [Contract number — fill in; treat as sensitive] |
| **Agency** | U.S. Environmental Protection Agency (EPA) |
| **Personnel** | Jeremy Michael Cerda (`jmcerda`) |
| **Trust level** | Tier 4 Public Trust (High Risk) — Level 4 investigation |
| **Scope** | [Fill in scope of work under this subcontract] |

**Notes:**
- Jeremy's Tier 4 position is subject to continuous evaluation. See [Continuous Evaluation](#continuous-evaluation) below.
- Subcontractor flow-down clauses apply. FAR 52.244-6 (Subcontracts for Commercial Products and Commercial Services) applies; EPA-specific clauses flowed down by the prime may also apply. **Open issue:** obtain the complete flow-down clause list from the prime contractor — see OPEN_ISSUES.md.
- Any EPA-originated data handled under this engagement is subject to EPA data-handling policies and potentially FOIA (5 U.S.C. § 552). Confirm with the prime whether any EPA-agency data is processed in Wilkes & Liberty's environment. See OPEN_ISSUES.md.

---

## Compliance Posture

This organization is **currently performing federal work** under the EPA subcontract above. The compliance documentation in `docs/compliance/` (SSP, POA&M, INCIDENT_RESPONSE, ACCESS_CONTROL, etc.) reflects the controls in place for this active engagement, not aspirational preparation.

**Applicable frameworks:**
- **NIST SP 800-171 Rev 2** — 110 controls; current implementation status in [SSP.md](compliance/SSP.md); gaps in [POAM.md](compliance/POAM.md)
- **FAR Part 9** — Contractor responsibility and conflicts of interest; spousal relationship documented in PROJECT_PLAN.md decision log
- **FAR 52.244-6** — Subcontracts for commercial items (flow-down requirement)
- **EPA-specific clauses** — TBD; obtain from prime

**Not yet applicable (monitor):**
- DFARS 252.204-7012 (Safeguarding Covered Defense Information) — not applicable unless prime holds a DoD contract
- FedRAMP — not applicable to this platform at present
- CMMC — not applicable at present; would become relevant for DoD work

---

## Continuous Evaluation

Jeremy's Tier 4 Public Trust position is subject to periodic re-investigation and continuous evaluation:

- **Investigation scope:** Tier 4 (High Risk) investigations cover financial history, foreign contacts, cohabitants, and spouse (SF-86 Section 18 and Section 17). Aleksandra Cerda's information is included in Jeremy's adjudication as spouse/cohabitant.
- **Self-reporting obligations:** Reportable events include foreign travel, foreign contacts, financial hardship, arrests/charges, and cohabitant changes. Consult the prime contractor's FSO (Facility Security Officer) or the issuing agency for specific self-reporting triggers and timelines. See OPEN_ISSUES.md.
- **Infrastructure relevance:** The logging, audit trails, SSH session recording (Tailscale Premium), and incident response capabilities in this repo partially satisfy the operational security expectations for a Tier 4 holder. Unexplained or anomalous access events on infrastructure controlled by a Tier 4 holder may become relevant to continuous evaluation.

---

## Spousal / Related-Party Disclosure

Aleksandra Cerda is Jeremy Michael Cerda's spouse. For federal contracting and clearance purposes:

- **SF-86:** Spousal information is required in Section 18 (cohabitant/spouse); already relevant for Jeremy's Tier 4 investigation.
- **FAR 9.504:** Spousal financial interests may constitute an Organizational Conflict of Interest in the context of contract awards.
- **13 CFR 121 (SBA affiliation):** Spousal business activities count toward affiliation determinations for small-business set-aside eligibility (8(a), WOSB/EDWOSB, VOSB, HUBZone). Disclose as appropriate in SAM.gov registration and set-aside certifications.
- **OGE standards:** Spousal employment and financial interests are reportable under Office of Government Ethics rules for federal contractor contexts.

Aleksandra has a Tailscale and Keycloak account (`acerda`) for business continuity purposes. This account is documented in ROLES.md and PROJECT_PLAN.md Phase D. It does not constitute employment and grants no authority over the contract.

---

## Contact

**Owner / Primary Point of Contact:** Jeremy Michael Cerda  
**Email:** `jmcerda@wilkesliberty.com`  
**Organization:** Wilkes & Liberty, LLC
