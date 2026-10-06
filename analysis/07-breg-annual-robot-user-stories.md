# BREG Annual Robot — Reverse-Engineered User Stories

**Status:** derived from source code, not validated against the live Salesforce org or policy owners.  
**Scope:** the code explicitly named `BREGAnnualRobot`; this is not a catalogue of every scheduled or automated process in the org.  
**Primary role:** BREG processing staff, who need straightforward annual filings processed without manual review and exceptions made reviewable.

## What the robot does

The Annual Robot is an asynchronous BREG process for eligible online annual-report Cases. It begins after a Case is handled by `BREGCaseTriggerHandler`; then it evaluates records, including related entity, annual, payment, affiliation, stock, and web-filing data. It either:

1. marks the Case **Completed** and starts the **BREG Annual Robot Process** DocuSign workflow;
2. marks it **Routed for manual** with a non-public Case comment listing every failed business rule; or
3. marks it **In Queue** while an earlier annual filing for the same entity is still being processed.

The org-level/user-level BREG setting `Annual_Robot_Enabled__c` defaults to false. When the feature is disabled, or BREG data-migration triggers are disabled, no robot work is performed.

## Observed process flow

```text
Eligible web annual Case reaches Received status
  -> BREG case handler queues robot work
  -> reload Case and related business data outside sharing rules
  -> evaluate filings for the same entity from oldest year first
  -> [all rules pass] Completed + timestamp + private success comment
       -> create workflow log + queue DocuSign annual workflow
       -> release any later annuals waiting in queue
  -> [one or more rules fail] Routed for manual + private failure comment
  -> [earlier eligible annual is still processing] In Queue + private queue comment
```

## Backlog-ready user stories

### AR-01 — Automatically identify annual filings eligible for robot processing

**As a** BREG operations manager, **I want** the robot to start only for the correct online annual filings, **so that** manual and non-annual work is not processed accidentally.

**Acceptance criteria**

- A Case is submitted to the robot only after it has `Status = Received` and `breg_No_Changes__c = true`.
- The reloaded Case must also be a web-originated `BREG_Case` record with an `ANN-` form code; otherwise it is ignored without a robot status update.
- Processing is asynchronous, so it does not hold up the Case update transaction.
- No processing occurs when either the BREG global data-migration trigger bypass is on or `Annual_Robot_Enabled__c` is false.

**Implementation evidence:** `BREGCaseTriggerHandler.cls:728-734`, `BREGAnnualRobot.cls:4-42`, `BREGAnnualRobotWithoutSharing.cls:7-81`.

### AR-02 — Validate an annual filing before automatic completion

**As a** BREG processing specialist, **I want** the robot to apply the prerequisite checks consistently, **so that** only complete and valid annual reports are automatically handled.

**Acceptance criteria**

- The Case must have a contact, file number, annual form code, work-item ID, and work-item number.
- It must reference an annual record that is not in `P`, `H`, or `NR` status.
- The entity must exist and have an eligible entity status: `Active (A)` or `Annual report 1 yr delinquent (1)`.
- The Case must have a paid transaction line, unless payment has been explicitly overridden.
- A pending conflicting entity transaction (for the enumerated amendment/dissolution forms) prevents automatic completion.
- Missing, future-dated, or future-year annual, Case, or incorporation data prevents automatic completion.
- Duplicate annual records for the same year or multiple qualifying Cases for the same annual prevent automatic completion.

**Implementation evidence:** `BREGAnnualRobotRules.cls:271-324`, `397-463`, `520-590`; data retrieval in `BREGAnnualRobotWithoutSharing.cls:167-234`.

### AR-03 — Ensure a “no changes” filing actually matches the registered business

**As a** BREG reviewer, **I want** the robot to detect reported changes before it auto-processes a filing, **so that** an annual report cannot change the official record without review.

**Acceptance criteria**

- The robot compares entity identity and addresses, nature of business, and applicable entity-type fields between the Case and its Account/entity.
- It compares the active agent, non-agent affiliations, and stock records between the Case and entity.
- Numeric comparison values are normalized before comparison.
- If any difference is found, the Case is routed for manual processing and its comment identifies the affected field categories (including counts where multiple differences have the same category).

**Implementation evidence:** `BREGAnnualRobotRules.cls:476-518`; `BREGAnnualRobotComparison.cls:35-137` and subsequent affiliation/stock comparison methods.

### AR-04 — Enforce entity, agent, and officer/partner eligibility rules

**As a** BREG compliance specialist, **I want** automatic processing to enforce entity governance rules, **so that** filings lacking required representatives or involving restricted relationships go to staff.

**Acceptance criteria**

- The entity must have an active agent; an entity acting as agent is rejected unless it is a CRA.
- A CRA entity itself is not auto-processed.
- Except for configured excluded entity types, an entity affiliation other than an agent prevents automation.
- Required active roles are checked by entity type: for example, the required partner counts for G5/G6/K5/K6; director/officer counts for incorporated types; and member or manager for LLC types based on management type.
- A bounced check on the entity, or on a related GP of its parent entity, prevents automation.
- A GP under an LLP parent is routed for manual processing.

**Implementation evidence:** `BREGAnnualRobotRules.cls:326-395`, `440-463`, `604-689`; supporting queries in `BREGAnnualRobotWithoutSharing.cls:236-344`.

### AR-05 — Process annual filings chronologically per business

**As a** BREG operations manager, **I want** filings for the same entity processed in filing-year order, **so that** later annual reports cannot leapfrog unresolved older reports.

**Acceptance criteria**

- Robot-eligible annual Cases for the same entity are sorted by annual processing year, oldest first.
- If an earlier eligible annual is still awaiting robot completion, a later annual is set to **In Queue** with an explanatory Case comment.
- If a prior annual record or Case is unresolved or final-blocked, a later annual is set to **Routed for manual** with the prior-annual reason.
- Once a Case is completed, any queued Cases for the same entity are re-enqueued for evaluation.

**Implementation evidence:** `BREGAnnualRobot.cls:44-85`; `BREGAnnualRobotRules.cls:202-244`, `693-817`.

### AR-06 — Record a traceable outcome for every evaluated filing

**As a** BREG processing specialist, **I want** a clear robot status, processing time, and internal explanation on every evaluated Case, **so that** I can prioritize and resolve work without reproducing the checks.

**Acceptance criteria**

- Outcomes use the statuses **Completed**, **In Queue**, **Routed for manual**, or **Error**. (`Not Started` is also defined as a lifecycle value.)
- A successfully completed Case receives the robot processing timestamp.
- Every robot decision creates a non-public Case comment: a success message, queue message, or de-duplicated list of validation failures.
- A Case with any validation reason is routed for manual rather than partially completed.
- If starting the downstream DocuSign workflow throws an exception, an otherwise successful Case is changed to **Error** and receives a generic failure comment.

**Implementation evidence:** `BREGAnnualRobotRules.cls:15-19`, `141-191`, `202-244`, `800-817`.

### AR-07 — Generate the annual document package after automatic approval

**As a** BREG processing specialist, **I want** the robot to start the approved annual’s DocuSign workflow, **so that** the required documents are produced without rekeying or manual initiation.

**Acceptance criteria**

- For each successful Case, the system creates a workflow log identified as started by `Annual Robot Process`.
- It queues the external workflow named `BREG Annual Robot Process`.
- The queued worker starts the DocuSign workflow for each successful Case and stores the response against the workflow log.
- Failures before the workflow starts are reflected through AR-06’s Error status; downstream DocuSign response handling should be monitored separately.

**Implementation evidence:** `BREGAnnualRobotRules.cls:141-162`; `BREGStartDocusignWorkflow.cls:1-124`.

## Decision table: status outcomes

| Condition | Robot result | Staff-visible operational effect |
|---|---|---|
| Feature disabled, trigger bypassed, or input outside scope | No robot action | Case is unchanged by the robot |
| Earlier eligible annual still processing | In Queue | Wait for the older filing; it is automatically retried after a success |
| Validation or comparison failures | Routed for manual | Read the internal Case comment and resolve/reprocess manually |
| All validation rules pass and DocuSign initiation succeeds | Completed | Timestamp and success comment recorded; document workflow queued |
| Error initiating DocuSign after otherwise passing checks | Error | Failure comment recorded; staff intervention required |

## Product questions to validate before treating these stories as requirements

1. Which BREG users can enable the feature and whether it should be governed by an explicit release/change-control process. The field defaults to disabled in source.
2. Whether annual filing due dates should block automation. The code contains that rule but it is commented out.
3. Whether public-initial-filing document validation is intentionally disabled. The call is commented out because the DocuSign robot workflow marks the document public later.
4. Whether the entity-status rules and all entity-type/role minimums remain current policy.
5. What staff workflow resolves **Routed for manual** and **Error**, and whether a manual retry action is needed.
6. Whether success should be recorded before DocuSign has completed. Current code treats successful *initiation* as completion and does not show a downstream completion callback in this robot path.

## Reverse-engineering limitations

The stories describe behavior present in the repository as of 2026-10-05. Salesforce configuration and data that can alter runtime behavior—record types, custom-label text, permissions, active workflows, and external DocuSign configuration—are not fully represented or proven by this source-only review.
