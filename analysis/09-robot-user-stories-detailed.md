# DCCA Robot Functionality — Reverse-Engineered User Stories (Detailed)

**Source:** `force-app/main/default` (DCCA Salesforce DX project)
**Prepared:** 2026-10-05
**Status:** Reverse-engineered from code only. Not yet validated against the live org, DocuSign workflow configuration, or BREG policy owners.
**Supersedes / extends:** `analysis/07-breg-annual-robot-user-stories.md` (7 high-level stories). This version breaks the robot into granular, testable stories with Given/When/Then criteria, a full entity-type rule matrix, and defects found during reverse engineering.

---

## 1. Robot inventory

| Robot | Implementation in this repo | Covered here |
|---|---|---|
| **BREG Annual Report Robot** | Full Apex implementation — 7 production classes, ~2,000 LOC (`BREGAnnualRobot*.cls`) | Epics A–F |
| **Annual Robot Validation (shadow) Batch** | `BREGAnnualRobotValidationBatch.cls` — read-only readiness report | Epic F |
| **Transaction "Robot Process" flag** | Field + validation rule only; set by an external integration (no Apex logic in repo) | Epic G |
| **Certified Copy Robot** | Field `breg_Document__c.breg_Certified_Copy_Robot_Message__c` on the Document layout only; logic lives outside this repo (likely the DocuSign / integration layer) | Epic G (placeholder) |

### Source files

| File | Responsibility |
|---|---|
| `classes/BREGCaseTriggerHandler.cls:731-734, 1072-1094` | Detects candidate Cases and calls the robot |
| `classes/BREGAnnualRobot.cls` | Entry point, feature switch, queueable, follow-up release |
| `classes/BREGAnnualRobotEngine.cls` | Bulk-loads all related data into an evaluation context |
| `classes/BREGAnnualRobotRules.cls` | All business rules, sequencing, outcome plans, comments |
| `classes/BREGAnnualRobotComparison.cls` | "No changes" comparison: filed data vs. registered data |
| `classes/BREGAnnualRobotWithoutSharing.cls` | All SOQL/DML (system context) |
| `classes/BREGAnnualRobotUtil.cls` | Year parsing and status helpers |
| `classes/BREGAnnualRobotValidationBatch.cls` | Shadow comparison report (CSV) |
| `classes/BREGStartDocusignWorkflow.cls:118-123` | DocuSign "BREG Annual Robot Process" hand-off |
| `objects/BREG_Setting__c/fields/Annual_Robot_Enabled__c` | Feature switch (default **off**) |
| `labels/CustomLabels.labels-meta.xml` (`BREG_AnnualRobot_*`) | All robot messages shown to staff |

---

## 2. Personas

| Persona | Interest in the robot |
|---|---|
| **Business owner / filer** (public portal) | Wants a "no changes" annual report processed fast |
| **BREG processing specialist** | Wants only clean filings auto-processed; needs clear reasons when a filing is routed to them |
| **BREG supervisor / operations manager** | Wants throughput, control over when the robot runs, and confidence it isn't approving bad filings |
| **BREG system administrator** | Turns the robot on/off, runs readiness reports, investigates errors |
| **Integration user** | External system that sets robot-related flags on transactions/documents |

---

## 3. End-to-end flow

```text
Filer submits web annual report (form code ANN-*) declaring "No changes"
  │
  ▼
Case updated → BREGCaseTriggerHandler (after update)
  • Origin = Web, annual form code, AND
  • Status just changed to Received  OR  No-Changes just changed to true
  • Case is Received AND No-Changes = true
  │
  ▼  (async Queueable)
BREGAnnualRobot.processCaseIds
  • STOP if migration bypass on, or Annual_Robot_Enabled__c = false
  • Reload Case (must still be Received / Web / No-Changes / BREG_Case)
  • Pull in every other eligible ANN- Case for the same entity
  • Build evaluation context (payments, agents, affiliations, stock, annuals, conflicts...)
  │
  ▼  per entity, oldest filing year first
  ├─ earlier year still pending in robot  → In Queue          + private comment
  ├─ earlier year unresolved / blocked    → Routed for manual + private comment
  ├─ any business rule fails              → Routed for manual + private comment listing ALL reasons
  └─ all rules pass                       → Completed + timestamp + private success comment
                                               │
                                               ▼
                                   Start DocuSign "BREG Annual Robot Process"
                                   (workflow log created)  — if start throws → Error
                                               │
                                               ▼
                                   Re-run robot for this entity's "In Queue" cases
```

---

## 4. User stories

Story IDs use the prefix **RBT-**. Each story lists implementation evidence so testers and developers can trace it back to code.

### Epic A — Triggering and control

#### RBT-01 — Start the robot when a "no changes" web annual report is received

**As a** BREG operations manager
**I want** the robot to pick up an online annual report automatically when it reaches *Received* and the filer has declared no changes
**so that** straightforward filings are processed without waiting for a specialist.

**Acceptance criteria**

1. **Given** a Case with Origin = `Web` and an annual form code, **when** its Status changes to `Received` and `breg_No_Changes__c` = true, **then** the Case is submitted to the robot.
2. **Given** a web annual Case already in `Received`, **when** `breg_No_Changes__c` changes from false to true, **then** the Case is submitted to the robot.
3. **Given** a Case with Origin other than `Web`, or a non-annual form code, **then** it is never submitted.
4. **Given** a Case that is `Received` but `breg_No_Changes__c` = false, **then** it is not submitted.
5. Only **updates** start the robot; inserting a Case already in `Received` does not.

**Evidence:** `BREGCaseTriggerHandler.cls:1072-1094`, `BREGAnnualRobot.cls:65-82`

---

#### RBT-02 — Turn the robot on or off

**As a** BREG system administrator
**I want** a setting that turns the robot on or off for the whole org or for specific users
**so that** we can control rollout and pause automation during incidents or data loads.

**Acceptance criteria**

1. **Given** `BREG_Setting__c.Annual_Robot_Enabled__c` = false (the default), **when** an eligible Case is received, **then** no robot status, comment, or workflow is produced.
2. **Given** `Global_Data_Migration_Triggers_Disabled__c` = true, **then** the robot does nothing, even if it is enabled.
3. The setting is read as the running user's value first, falling back to the org default (hierarchy custom setting).
4. Cases skipped while the robot was disabled are **not** reprocessed automatically when it is re-enabled (see Gap G-07).

**Evidence:** `BREGAnnualRobot.cls:33-63`, `BREG_Setting__c/fields/Annual_Robot_Enabled__c` (default false)

---

#### RBT-03 — Process asynchronously and re-check eligibility before acting

**As a** filer
**I want** my submission to save immediately while the robot runs in the background
**so that** the portal doesn't slow down or fail because of robot processing.

**Acceptance criteria**

1. Robot work runs in a Queueable job, separate from the Case update transaction.
2. At execution, each Case is reloaded and processed only if it is **still** `Status = Received`, `Origin = Web`, `breg_No_Changes__c = true` and record type `BREG_Case`.
3. Cases that no longer qualify are silently ignored, with no status or comment.
4. The robot reads data in system context (without sharing) so results don't depend on who triggered it.

**Evidence:** `BREGAnnualRobot.cls:12-31`, `BREGAnnualRobotWithoutSharing.cls:5-86`

---

### Epic B — Multi-year sequencing

#### RBT-04 — Evaluate all of an entity's pending annual reports together, oldest first

**As a** BREG processing specialist
**I want** multiple outstanding annual reports for the same company to be evaluated in filing-year order
**so that** a later year is never approved before an earlier one.

**Acceptance criteria**

1. **Given** a robot run for one Case, **then** all other eligible Cases for the same entity (Received, Web, No-Changes, `BREG_Case`, form code `ANN-%`) are added to the same run.
2. Cases are grouped by entity and sorted by annual filing year, oldest first; Cases with no filing year go last.
3. Cases with no entity are still evaluated (and fail the "entity missing" rule).

**Evidence:** `BREGAnnualRobotWithoutSharing.cls:88-130`, `BREGAnnualRobotRules.cls:111-139, 823-853`

---

#### RBT-05 — Queue a later-year filing while an earlier year is still being processed

**As a** BREG processing specialist
**I want** a later-year annual to wait when an earlier year for the same company is still in progress
**so that** filings are completed in the correct order.

**Acceptance criteria**

1. **Given** an earlier-year annual Case for the same entity that is robot-eligible and either (a) in the same run and not yet decided / itself queued, or (b) outside the run, not Completed and not Routed for manual / Error, **then** the later Case gets Robot Status = `In Queue`.
2. A private Case comment is added: *"Annual Robot queued. Waiting for older annual filings for this company to be processed first."*
3. Queued Cases are not evaluated against business rules in that run.

**Evidence:** `BREGAnnualRobotRules.cls:203-205, 692-732`

---

#### RBT-06 — Release queued filings when an earlier year completes

**As a** BREG processing specialist
**I want** queued filings to be re-evaluated automatically once the earlier year is completed by the robot
**so that** I don't need to restart them by hand.

**Acceptance criteria**

1. **Given** a run in which at least one Case for an entity ends `Completed`, **then** every Case for that entity with Robot Status `In Queue` (Received, No-Changes, `BREG_Case`, `ANN-%`) is sent to a new robot run.
2. The follow-up run applies the full rule set from RBT-04 onward.
3. Release happens only after a **robot** completion. A manual completion by staff does not release queued Cases (see Gap G-03).
4. ⚠ As coded, the released Case is usually routed to manual because the earlier annual record isn't `P` yet (see Gap G-10). The intended behaviour needs product-owner confirmation.

**Evidence:** `BREGAnnualRobot.cls:84-96`, `BREGAnnualRobotWithoutSharing.cls:154-169`

---

#### RBT-07 — Route to manual when an earlier year is unresolved

**As a** BREG processing specialist
**I want** a later-year annual sent to me when an earlier year can't be handled by the robot
**so that** I can resolve the years together.

**Acceptance criteria** — the Case is `Routed for manual` with reason *"A previous annual case for an earlier filing year is not closed and blocks robot processing"* when **any** of the following apply:

1. The entity has an annual record for an earlier year whose status is not `P` (Processed) or `NR`.
2. An earlier-year annual Case for the entity is in `Received` but is not robot-eligible (e.g. has changes) and is not Completed.
3. An earlier-year Case in the same run was just Routed for manual or Error.
4. An earlier-year Case outside the run already has Robot Status Routed for manual or Error.

**Evidence:** `BREGAnnualRobotRules.cls:207-214, 734-784`

---

### Epic C — Business-rule validation

All rules are evaluated and **every** failing reason is collected (de-duplicated) into one comment. A Case is auto-completed only if **zero** reasons are collected.

#### RBT-08 — Require the web filing to be fully mapped

**As a** BREG processing specialist
**I want** the robot to stop when legacy web-filing data hasn't been mapped onto the Case
**so that** decisions aren't based on incomplete data.

**Acceptance criteria**

1. **Given** a linked `breg_WEB_WEB_FILING_INFO__c` with Mapping Status `Error`, **then** reason *"Web filing info mapping status is Error."*
2. **Given** Mapping Status `Not Started` or blank, **then** reason *"Web filing info mapping status is Not Started."*
3. **Given** no web filing info record at all, **then** this rule passes.

**Evidence:** `BREGAnnualRobotRules.cls:246-257`

---

#### RBT-09 — Require complete Case identifiers

**As a** BREG processing specialist
**I want** the robot to check that the Case has the identifiers needed for downstream processing
**so that** generated documents and legacy records link correctly.

**Acceptance criteria** — each missing item adds its own reason:

| Check | Reason text |
|---|---|
| `ContactId` is blank | Contact is missing on the case. |
| `breg_File__c` is blank | File Number is missing. |
| `breg_Form_Code__c` is blank or doesn't contain `ANN-` | Form Code is missing or is not an annual form. |
| `breg_Workitem_ID__c` is blank | Work Item ID is missing. |
| `breg_Workitem_Number__c` is blank | Work Item Number is missing. |

**Evidence:** `BREGAnnualRobotRules.cls:271-290`

---

#### RBT-10 — Allow only eligible entities

**As a** BREG supervisor
**I want** the robot to process only companies in good enough standing, and never companies that are themselves registered agents
**so that** higher-risk entities always get human review.

**Acceptance criteria**

1. No entity linked → *"Company is not linked to the case."* (other entity-based rules are skipped).
2. Entity Status other than `Active (A)` or `Annual report 1 yr delinquent (1)` → *"Company status is not eligible for robot processing…"* (2-year delinquent was deliberately excluded; see §6).
3. Entity is a Certified Registered Agent (`breg_BRIM_CRA_FL__c` = true) → *"Company is registered as a Certified Registered Agent (CRA)."*

**Evidence:** `BREGAnnualRobotRules.cls:292-301, 342-356, 592-596`

---

#### RBT-11 — Validate the annual record and prevent duplicates

**As a** BREG processing specialist
**I want** the robot to confirm there is exactly one valid annual record and one Case for that year
**so that** the same annual is never processed twice.

**Acceptance criteria**

1. No annual record linked → *"Annual record is missing."*
2. Annual status `P` (Processed), `H` (Held) or `NR` → *"Annual record status is not eligible for robot processing…"*
3. Entity has more than one annual record with the same filing year → *"Company has multiple annual records for the same filing year."*
4. The annual record is linked to more than one `ANN-` Case (ignoring Cases in `Pending Submission`, `New`, `Expired`) → *"Annual record is linked to multiple annual cases."*

**Evidence:** `BREGAnnualRobotRules.cls:303-312, 397-438`, `BREGAnnualRobotWithoutSharing.cls:171-184`

---

#### RBT-12 — Confirm payment

**As a** BREG supervisor
**I want** the robot to complete only filings that have been paid, unless staff have overridden payment
**so that** the state doesn't approve unpaid filings.

**Acceptance criteria**

1. **Given** at least one `TransactionLine__c` for the Case with `PaidStatus__c = 'Paid'`, **then** the rule passes.
2. **Given** `breg_Override_Payment__c` = true, **then** the rule passes even with no paid line.
3. Otherwise → *"No paid transaction line is associated with this work item."*

**Evidence:** `BREGAnnualRobotRules.cls:314-318`, `BREGAnnualRobotWithoutSharing.cls:186-196`

---

#### RBT-13 — Block when a conflicting transaction is pending

**As a** BREG processing specialist
**I want** the robot to hold an annual when an amendment, dissolution, or similar filing for the same company is still open
**so that** the annual doesn't reflect data that is about to change.

**Acceptance criteria**

1. Conflicting form codes: `ADD`, `X-8`, `X-7`, `DC-2`, `DNP-2`, `LLC-2`, `ODC`.
2. A conflicting Case is "pending" if its status is not `Approved`, `Rejected`, `Completed`, `Expired`, `Purged` or `Pending Submission`.
3. **Given** a pending conflicting Case for the same entity submitted **on or before** the annual (or with either submission date blank), **then** reason *"No conflicting transactions must be pending in the system such as - ADD, X-8, …"*
4. A conflicting Case submitted **after** the annual does not block it.

**Evidence:** `BREGAnnualRobotEngine.cls:96-124`, `BREGAnnualRobotWithoutSharing.cls:198-210`

---

#### RBT-14 — Validate the registered agent

**As a** BREG supervisor
**I want** the robot to confirm the company has an acceptable registered agent
**so that** the state can always serve legal notices.

**Acceptance criteria**

1. No active agent affiliation (Role `Agent`, Status `A`, no End Date) → *"Company has no active Agent."*
2. The most recent active agent is of Type `Entity` **and** that entity is not a CRA → *"The registered agent is an entity, so the filing must be reviewed manually."*
3. An individual agent, or an entity agent that is a CRA, passes.
4. If several active agents exist, only the one with the latest Start Date is evaluated (see Gap G-08).

**Evidence:** `BREGAnnualRobotRules.cls:326-340`, `BREGAnnualRobotWithoutSharing.cls:308-326`

---

#### RBT-15 — Enforce minimum governance roles by entity type

**As a** BREG supervisor
**I want** the robot to check that each company has the minimum officers, directors, partners, members or managers its entity type requires
**so that** non-compliant entities are reviewed by staff.

**Acceptance criteria** — counted from the entity's **active** affiliations (Status `A`, no End Date):

| Code | Entity type (from `breg_Entity_Type_Codes`) | Minimum requirement |
|---|---|---|
| D1 | Domestic Profit Corporation | ≥1 **individual** Director, ≥1 Officer |
| D2 | Domestic Nonprofit Corporation | ≥3 **individual** Directors, ≥1 Officer |
| D9 | Domestic Corporation Sole | ≥1 Officer |
| P1 | Professional Corporation | ≥1 Director, ≥1 Officer |
| S1 | Sustainable Business Corporation | ≥1 Director, ≥1 Officer |
| F1 | Foreign Profit Corporation | ≥1 Director **or** Officer |
| F2 | Foreign Nonprofit Corporation | ≥1 Director **or** Officer |
| A1 | Agricultural Cooperative With Stock | ≥1 Director, ≥1 Officer |
| A2 | Agricultural Cooperative Without Stock | ≥3 Directors, ≥1 Officer |
| C1 | Consumer Cooperative With Stock | ≥1 Director, ≥1 Officer |
| C2 | Consumer Cooperative Without Stock | ≥3 Directors, ≥1 Officer |
| C5 / C6 | Domestic / Foreign LLC | Manager-managed: ≥1 Manager; otherwise ≥1 Member |
| G5 / G6 | Domestic / Foreign General Partnership | ≥2 Partners |
| K5 / K6 | Domestic / Foreign LLP | ≥2 Partners |
| L6 | Foreign Limited Partnership | ≥1 Partner |
| Q6 | Foreign LLLP | ≥1 Partner |
| Other types | — | No role check |

1. Each unmet requirement adds its own reason (see Gap G-01: several reason texts name the wrong entity type).
2. LLC management style comes from the Case field `breg_Is_Manager_Managed__c`.

**Evidence:** `BREGAnnualRobotRules.cls:376-395, 607-690`

---

#### RBT-16 — Route companies with entity-type officers/directors

**As a** BREG processing specialist
**I want** filings where another company holds a non-agent role to be reviewed manually
**so that** corporate-ownership structures are checked by a person.

**Acceptance criteria**

1. **Given** an active affiliation with Type `Entity` and a role other than `Agent`, **then** reason *"Company has an active non-agent account affiliation of type Entity."*
2. Exempt entity types (where entity partners/members are normal): F1, F2, C5, C6, K6, L6, Q6, G6.

**Evidence:** `BREGAnnualRobotRules.cls:3, 358-374, 598-605`

---

#### RBT-17 — Block on bounced checks

**As a** BREG cashier / supervisor
**I want** companies with an outstanding bounced check (directly or through a child general partnership) sent for manual review
**so that** the state collects outstanding money before approving filings.

**Acceptance criteria**

1. Entity `breg_Bounced_Check__c` = true → *"Company has an outstanding bounced check."*
2. Any child account of type G5/G6 with a bounced check → *"Related GP account has an outstanding bounced check."*

**Evidence:** `BREGAnnualRobotRules.cls:440-451`, `BREGAnnualRobotWithoutSharing.cls:227-237`

---

#### RBT-18 — Route general partnerships with an LLP parent

**As a** BREG processing specialist
**I want** a GP (G5/G6) whose parent is an LLP (K5/K6) to be processed manually
**so that** the paired GP/LLP records are kept consistent.

**Acceptance criteria**

1. Entity type G5/G6 with a parent account of type K5/K6 → *"Company is a General Partner and has an LLP parent account."*

**Evidence:** `BREGAnnualRobotRules.cls:453-464`

---

#### RBT-19 — Check that dates make sense

**As a** BREG processing specialist
**I want** filings with missing or future dates sent to me
**so that** data-entry or integration errors are caught before approval.

**Acceptance criteria** — "today" and "current year" are calculated in GMT:

| Field | Missing → reason | Future → reason |
|---|---|---|
| Annual `breg_Filing_Date__c` | Annual Filing Date is missing. | after today |
| Annual `breg_Filing_Year__c` | Annual Filing Year is missing. | greater than current year |
| Annual `breg_Received_Date__c` | Received Date is missing. | after now |
| Case `breg_Submission_Date__c` | *(label says "Received Date is missing.")* | after now |
| Case `breg_Annual_Report_Filing_Year__c` | Annual Report Filing Year is missing. | greater than current year |
| Entity `breg_Incorporation_Date__c` | Incorporation Date is missing. | after today |

See Gap G-02: the submission-date and annual received-date checks use the same message text, so when both fail only one appears.

**Evidence:** `BREGAnnualRobotRules.cls:466-590`

---

### Epic D — "No changes" verification

#### RBT-20 — Verify the filer's "no changes" declaration against the registry

**As a** BREG supervisor
**I want** the robot to confirm that the data filed on the annual report matches what is on record for the company
**so that** filings that actually contain changes are never auto-approved.

**Acceptance criteria**

1. The following Case fields are compared with the entity (Account) record:
   - Entity name, entity type, nature of business (vs. `breg_Purpose__c`)
   - Mailing address: street, street 2, city, state, country, postal code
   - Company address: street, street 2, city, state, country, postal code (vs. Billing address)
   - Number of initial members, for A2, C2, C5, C6
   - Membership fees received, for A2, C2
   - Number of shareholders, for A1, C1
2. Comparison ignores case and leading/trailing whitespace. Blank numeric fields are treated as `0`; commas and dots are stripped from numeric fields (see Gap G-05).
3. Any difference → reason *"Annual no-change data differs from the related entity record. Diff fields: <list>"*

**Evidence:** `BREGAnnualRobotComparison.cls:75-107, 151-183, 381-424`, `BREGAnnualRobotRules.cls:476-518`

---

#### RBT-21 — Detect registered-agent changes

**As a** BREG processing specialist
**I want** any change to the registered agent detected
**so that** agent changes always go through manual review.

**Acceptance criteria**

1. The agent on the Case is compared with the entity's active agent across 14 fields (role, type, entity name/location/country, first/last name, full address, titles).
2. *"Registered agent details changed."* if: only one side has an agent, the Case agent is marked To Remove, or any field differs.

**Evidence:** `BREGAnnualRobotComparison.cls:225-271`

---

#### RBT-22 — Detect officer, director, partner, member and manager changes

**As a** BREG processing specialist
**I want** each person or entity on the filing matched with the registry and differences classified
**so that** I can quickly see what changed.

**Acceptance criteria**

1. Each non-agent Case affiliation is paired with the closest-matching unpaired entity affiliation (fewest field differences).
2. Classification:

   | Situation | Label |
   |---|---|
   | Case affiliation flagged `breg_To_Remove__c` | Account affiliation marked for removal. |
   | No registry affiliation left to pair with | Account affiliation added. |
   | Registry affiliation left unpaired | Account affiliation removed. |
   | Individual: only first and/or last name differs (≤2 fields) | Account affiliation name changed. |
   | Entity: only entity name differs | Account affiliation name changed. |
   | All 14 fields differ | Account affiliation is completely different. |
   | Any other difference | Account affiliation details changed. |

3. A blank officer/director title on the filing does **not** count as a difference when the registry has a title.

**Evidence:** `BREGAnnualRobotComparison.cls:194-337, 416-424`

---

#### RBT-23 — Detect stock changes

**As a** BREG processing specialist
**I want** stock classes on the filing compared with registered stock
**so that** capital changes aren't auto-approved.

**Acceptance criteria**

1. Compared fields: class/series, par value, class detail, issued shares, paid shares, remarks, stock amount, stock class.
2. Only current registry stock is used (Start Date set, End Date blank).
3. Best-match pairing as in RBT-22; labels: *Stock added*, *Stock removed*, *Stock details changed*, *Stock is completely different* (all 8 fields differ).

**Evidence:** `BREGAnnualRobotComparison.cls:339-379`, `BREGAnnualRobotWithoutSharing.cls:291-306`

---

#### RBT-24 — Summarise differences in a readable list

**As a** BREG processing specialist
**I want** repeated differences grouped with counts
**so that** the routing comment stays short.

**Acceptance criteria**

1. Differences are listed in the order first found; repeated labels show as `N x <label>` (e.g. *"2 x Stock details changed., Mailing City"*).

**Evidence:** `BREGAnnualRobotRules.cls:494-517`

---

### Epic E — Outcome and hand-off

#### RBT-25 — Record the robot's decision on the Case

**As a** BREG processing specialist
**I want** every evaluated Case to show the robot's outcome and the reasons for it
**so that** I know immediately what needs my attention.

**Acceptance criteria**

1. `breg_Annual_Robot_Status__c` is set to one of `Completed`, `Routed for manual`, `In Queue`, `Error`.
2. `breg_Robot_Processed_DateTime__c` is stamped only for `Completed`, and cleared otherwise.
3. A **non-public** Case comment is added:
   - Completed: *"All business rules passed. Annual was processed by the robot."*
   - Routed for manual / Error: *"Annual Robot failed and the case was routed for manual filing. Reasons:"* followed by one reason per line.
   - In Queue: the queued message (RBT-05).
4. The Case status update runs with Case triggers bypassed, so it doesn't restart the robot or other automation.
5. The robot does **not** change the Case `Status` itself. The downstream DocuSign workflow is expected to do that (to be confirmed).

**Evidence:** `BREGAnnualRobotRules.cls:165-190, 803-809`, `BREGAnnualRobotWithoutSharing.cls:132-152`

---

#### RBT-26 — Start the approval document workflow for robot-completed filings

**As a** filer
**I want** my approved annual report documents generated automatically
**so that** I receive confirmation without staff action.

**Acceptance criteria**

1. All Completed Cases in a run are passed together to `BREGStartDocusignWorkflow.startDocuSignAnnualRobot`.
2. A workflow log record is created per Case with Started By = *"Annual Robot Process"*, then the DocuSign workflow **"BREG Annual Robot Process"** is queued.
3. **Given** starting the workflow throws an exception, **then** every Completed Case in that run is changed to `Error` with reason *"Annual Robot encountered an unexpected error while starting the workflow."*
4. The DocuSign workflow is expected to mark the initial-filing document as public (which is why the robot's own "public initial filing" check is switched off).

**Evidence:** `BREGAnnualRobotRules.cls:141-163, 220`, `BREGStartDocusignWorkflow.cls:2, 118-123`

---

### Epic F — Readiness and analysis

#### RBT-27 — Shadow-compare filings that declared changes

**As a** BREG operations manager
**I want** a report showing how many "with changes" annual filings actually match the registry
**so that** I can size how much more work the robot could take on and check the comparison logic is accurate.

**Acceptance criteria**

1. The batch selects web `ANN-%` Cases in `Received` with `breg_No_Changes__c` = **false** and an entity.
2. It runs the same comparison as Epic D but **changes no records**.
3. When it finishes, a CSV file *"BREG Annual Robot Validation Results yyyy-MM-dd HH:mm"* is saved to Files with columns: CaseId, Work Item #, EntityId, File #, Entity Name, Status, Owner, Form Code, Form-Config Entity Type, Created Date, **Match** (Yes/No), **DifferenceCount**.
4. Totals (processed, skipped with no entity, with differences, without differences) are written to the debug log.
5. The batch is started manually (no scheduler in the repo), e.g. `Database.executeBatch(new BREGAnnualRobotValidationBatch());`

**Evidence:** `BREGAnnualRobotValidationBatch.cls`

---

### Epic G — External robot hooks (to be confirmed with integration owners)

#### RBT-28 — Restrict the transaction "Robot Process" flag to the integration

**As a** BREG system administrator
**I want** only the integration user to be able to mark a transaction as robot-processed
**so that** staff can't misrepresent how a transaction was processed.

**Acceptance criteria**

1. Changing `breg_Transaction__c.breg_Is_Robot_Process__c` fails with *"Only the Integration User can set Robot Process flag on a Transaction."* unless the user's profile is `Integration` **or** the transaction has a `breg_BRIM_TRANS_ID__c` (legacy BRIM transaction).
2. The flag appears on the Transaction page layout.

**Evidence:** `objects/breg_Transaction__c/validationRules/BREG_Restrict_Robot_Process_Flag`, `fields/breg_Is_Robot_Process__c`

---

#### RBT-29 — Show the certified-copy robot result on a document *(placeholder)*

**As a** BREG processing specialist
**I want** to see the message from the certified-copy robot on the document record
**so that** I know whether a certified copy was produced automatically or needs manual work.

**Acceptance criteria (to be confirmed)**

1. `breg_Document__c.breg_Certified_Copy_Robot_Message__c` (Text 255, history-tracked) is shown on the Document layout.
2. The field is populated by a process outside this repository. The owner and rules need to be identified before this story can be refined.

**Evidence:** `objects/breg_Document__c/fields/breg_Certified_Copy_Robot_Message__c`, `layouts/breg_Document__c-Document Layout`

---

## 5. Gaps and defects found while reverse engineering

These should be raised as defect / tech-debt items or confirmed with the BREG product owner.

| ID | Severity | Finding | Evidence | Suggested fix |
|---|---|---|---|---|
| **G-01** | High (staff-facing) | **Routing messages name the wrong entity type.** Code A1 is *Agricultural Cooperative With Stock*, but its messages say "Domestic Profit Corporation". Same problem for A2 ("Foreign Profit"), C1 ("Domestic Non-Profit"), C2 ("Foreign Non-Profit"), S1 ("Professional Service Corporation", should be Sustainable Business), and D9 ("Domestic Non-Profit", should be Corporation Sole). | `CustomLabels` `BREG_AnnualRobot_{A1,A2,C1,C2,S1,D9}_*` vs `globalValueSets/breg_Entity_Type_Codes` | Correct the label text. Also confirm the 3-director minimum for A2/C2 is intended. |
| **G-10** | High (throughput) | **Multi-year sequencing almost always ends in manual review.** The "previous annual unresolved" check (RBT-07 rule 1) routes a later year to manual whenever an earlier annual *record* isn't `P`/`NR`. Pending annuals have status `D`, and the robot never sets `P` — that happens later in `BREGCaseStatusHandlerAnnuals.cls:284` after the Case completes. So (a) a later year in the same run as a robot-completed earlier year is routed to manual, and (b) a queued Case released by RBT-06 is re-evaluated straight away, usually before the earlier annual reaches `P`, and is also routed to manual. The `In Queue` / release design rarely delivers an auto-completion. | `BREGAnnualRobotRules.cls:745-753`; `BREGAnnualRobot.cls:84-96`; test fixtures use `D` for pending annuals (`BREGAnnualRobotTest.cls:98, 520`) | Treat earlier annuals whose Case was robot-Completed in this run (or has Robot Status `Completed`) as resolved, or release queued Cases only when the earlier annual becomes `P`. Add a two-clean-years test. |
| **G-02** | Medium | **Reasons hidden by duplicate text.** Case Submission Date checks reuse the Annual Received Date wording ("Received Date is missing." / "…greater than the current date and time."). The reason list removes duplicates by text, so if both fail, staff see only one. | `BREG_AnnualRobot_Submission_Date_*` labels; `ReasonCollector` `BREGAnnualRobotRules.cls:855-870` | Change the submission-date labels to say "Submission Date". |
| **G-03** | Medium | **Queued Cases can get stuck.** Queued Cases are released only after a **robot** completion (RBT-06). If the earlier year ends in `Error`, or staff complete it manually, later-year `In Queue` Cases are never re-evaluated. | `BREGAnnualRobot.cls:84-96` | Release/re-evaluate queued Cases when an earlier annual Case is Completed by any means or ends in Error. Add a list view for `In Queue` older than N days. |
| **G-04** | Medium | **DocuSign failures after start aren't reflected.** `Error` is set only if *queuing* the DocuSign job throws. Callout failures inside the queued job leave the robot status as `Completed`. The DocuSign start path is also skipped in tests (`Test.isRunningTest()`). | `BREGAnnualRobotRules.cls:149-162`, `BREGStartDocusignWorkflow.cls` | Feed workflow-log failures back to the robot status; add a test seam instead of the `isRunningTest` skip. |
| **G-05** | Low–Medium | **Number formatting can cause false differences.** Stripping dots from numeric fields means `"1.00"` becomes `"100"` while `"1"` stays `"1"`, which counts as a difference. It also makes `"1.5"` equal `"15"`. | `BREGAnnualRobotComparison.cls:381-395` | Compare as `Decimal` values. |
| **G-06** | Low | Status value `Not Started` is defined but never set by the robot; label `BREG_AnnualRobot_Officer_Entity` exists but is never used. | `BREGAnnualRobotRules.cls:15` | Remove them or use them deliberately. |
| **G-07** | Low | **No catch-up after re-enabling.** Cases received while the robot was disabled are never picked up. | `BREGAnnualRobot.cls:33-36` | Add a one-off/scheduled "sweep" job for Received + No-Changes Cases with blank robot status. |
| **G-08** | Low | With several active agents, only the latest is checked and no "multiple agents" reason is raised. | `BREGAnnualRobotWithoutSharing.cls:308-326`, `BREGAnnualRobotEngine.cls:177-187` | Confirm the rule with BREG; add a reason if multiple active agents should block. |
| **G-09** | Info | Robot outcome comments are non-public, so filers get no explanation when routed to manual. | `BREGAnnualRobotRules.cls:807-809` | Product decision: is a filer-facing status message needed? |

---

## 6. Rules switched off in code (candidate backlog items)

These rules exist but are commented out, which suggests they were deferred. Confirm with the product owner whether they should come back.

| Rule | Location | Note in code |
|---|---|---|
| Case must have a public "Initial Filing" document | `BREGAnnualRobotRules.cls:220, 259-269` | "Document will be marked as Public from Docusign BREG Annual Robot workflow" |
| Annual Filing Due Date missing / in the past | `BREGAnnualRobotRules.cls:537-541` | — |
| Allow entity status "Annual report 2 yr delinquent (2)" | `BREGAnnualRobotRules.cls:594-595` | — |
| Block when the company's agent is a CRA | `BREGAnnualRobotRules.cls:351-355` | Ticket `BREGMO-415` |

---

## 7. Suggested test scenarios (traceable to stories)

| # | Scenario | Expected | Stories |
|---|---|---|---|
| T1 | Clean D1 annual, paid, individual agent, 1 director + 1 officer, data matches | Completed, timestamp, success comment, DocuSign queued | RBT-01, 15, 20, 25, 26 |
| T2 | Robot setting off | No status, no comment | RBT-02 |
| T3 | 2023 and 2024 filed together, both clean | **Intended:** both Completed in order. **Actual code:** 2023 Completed, 2024 Routed for manual (see G-10). No existing test covers this. | RBT-04, 07 |
| T4 | 2024 filed while 2023 is In Queue elsewhere | 2024 In Queue; released after 2023 completes | RBT-05, 06 |
| T5 | 2023 annual record status `H`, 2024 filed | 2024 Routed for manual (previous annual unresolved) | RBT-07 |
| T6 | Unpaid, no override | Routed: payment missing | RBT-12 |
| T7 | Unpaid with `breg_Override_Payment__c` | Passes payment rule | RBT-12 |
| T8 | Pending `X-7` submitted before annual | Routed: conflicting transaction | RBT-13 |
| T9 | Pending `X-7` submitted after annual | Not blocked | RBT-13 |
| T10 | Agent is non-CRA entity | Routed: agent is entity | RBT-14 |
| T11 | D2 with 2 individual directors | Routed: D2 directors required | RBT-15 |
| T12 | C5 manager-managed with only members | Routed: LLC manager required | RBT-15 |
| T13 | D1 with an entity-type officer | Routed: entity affiliation | RBT-16 |
| T14 | G5 child with bounced check under parent | Parent routed: related GP bounced check | RBT-17 |
| T15 | Mailing city differs in case only | Routed: comparison difference, "Mailing City" | RBT-20 |
| T16 | Officer last name changed | Routed: "Account affiliation name changed." | RBT-22 |
| T17 | Two stock classes changed | Routed: "2 x Stock details changed." | RBT-23, 24 |
| T18 | DocuSign start throws | All Completed in run → Error | RBT-26 |
| T19 | Run validation batch | CSV in Files with Match column | RBT-27 |
| T20 | Non-integration user edits Robot Process flag | Validation error | RBT-28 |
