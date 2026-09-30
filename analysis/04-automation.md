# 04 — Flows, Triggers & Automation

Scope: `force-app/main/default/flows/` (266 `.flow-meta.xml`), `flowDefinitions/` (266), `triggers/` (61), `workflows/` (17 files), `approvalProcesses/` (4), `objects/*/validationRules/` (123 rules), plus the trigger handler, domain and service classes and all Batch, Schedulable, Queueable and `@future` classes in `classes/`. This was static analysis only. Nothing was run against an org and no `sf`/git commands were used.

**Method.** All flow XML was parsed with Python (ElementTree). For each flow I extracted:
- the `<start>` element: object, trigger type, record trigger type, filters, `filterFormula`, `triggerOrder`, `doesRequireRecordChangedToMeetCriteria` and schedule
- Process Builder metadata: `ObjectType`, `TriggerType` and `RecursiveCountVariable`
- the connector graph

DML or SOQL inside a loop means an element that can be reached from a loop's `nextValueConnector` before control returns to that loop.

Apex was scanned with a comment- and string-aware loop-body parser, then the riskiest paths were read by hand. The per-record dispatch methods of `TriggerFactory` (`beforeInsert(SObject)` and similar) were treated as loop bodies, because `TriggerFactory` calls them once per record.

**Flow status.** In this report, "Active" means `<status>Active</status>` in the flow file. The flowDefinition's `activeVersionNumber` was cross-checked against it (see W-16).

## Summary

- **Automation is concentrated on a few core objects.** `Case` (2 triggers, 9 before-save and 15 after-save flows, 2 scheduled flows) and `Application__c` (1 trigger, 15 after-save flows, 1 Process Builder of 203 elements, 3 invocable PBs, 24 validation rules) are the most automated. None of the 67 active record-triggered flows on 13 multi-flow object/event pairs sets `<triggerOrder>`, so execution order among them is not defined.
- **Retired automation is still carrying core business logic.** There are 48 active Process Builders (41 record-triggered and 7 invocable, 1,039 elements in total) across 38 objects. They include the Application (203 elements), License (141), Filing (76) and Payment (44) PBs, plus 1 active Workflow Rule. Salesforce ended support for PB and Workflow Rules on 2025-12-31.
- **Critical: the platform-event subscriber `PVLProcessTrigger` is not bulk-safe.** It runs SOQL, DML, `Flow.Interview.start()` and `System.enqueueJob` once per event inside the event loop, and it has no retry or checkpoint handling. Any delivery of more than 50 "Generate PDF/VF Page" events (for example from mass notifications) throws a limit exception. The whole event batch is then lost.
- **Critical: the BREG trigger framework's static "first run" guard silently skips trigger logic.** This affects the second and later 200-record chunks and partial-save retries (`Database.update(list, false)`, which BREG batches use on Account). `BREGCaseTrigger` sets a global static flag that turns off every later Case trigger run in the transaction.
- **The PVL money-path objects (Transaction, TransactionLine, Payment) cascade into each other with no recursion guards.** Every `TransactionLine__c` insert or update re-saves its parent `Transaction__c`, even when nothing changed. Transaction runs 2 triggers, 3 PBs (one with recursion enabled) and 3 flows, and these write back to TransactionLine and Payment. Payment has 3 independent Apex triggers.
- **Async work is started per record from triggers.** Examples are `Database.executeBatch` in `licenseService`, `LicenseTypeHandler` and `NotificationDomain`, a per-record `@future` in `CertificateRequestService`, and `enqueueJob` plus DML per iteration in the BREG Document and TransactionLine handlers. The `@future` calls have no `System.isBatch()` or `isFuture()` guards.
- **Flow quality debt is broad.**
  - Fault handling: 577 of 609 DML and action elements in active non-PB flows have no fault connector.
  - Loops: 21 loops in 14 active flows run DML, SOQL, subflows or email actions per iteration. This includes a scheduled flow that fails at about 75 bounced emails a day.
  - Hard-coded values: 11 distinct hard-coded record IDs in 9 active flows, from at least 2 orgs, plus 150 hard-coded LicenseType IDs in one PB, and error emails going to former vendor (PacificPoint) staff.
  - Other: 28 after-save flows update their own triggering record.
- **Async estate.** There are 89 Batch, 18 Queueable and 59 Schedulable classes and 32 `@future` methods. 39 batches have an empty `finish()`, only 2 use `Database.RaisesPlatformEvents`, and Payment batches take 24 scheduled-job slots running every 5 minutes with no overlap guard.

| Severity | Count |
|---|---|
| Critical | 2 |
| High | 6 |
| Medium | 9 |
| Low | 5 |

| Headline metric | Value |
|---|---|
| Flow files: Active / Draft / Obsolete | 233 / 13 / 20 |
| Active record-triggered flows (before-save / after-save / before-delete) | 16 / 69 / 1 (27 objects) |
| Active scheduled flows / platform-event flows | 7 / 0 (1 Draft PE flow) |
| Active Process Builders (record-triggered + invocable) | 41 + 7 = **48** on 38 objects |
| Active Workflow Rules / field updates with `reevaluateOnChange=true` | 1 / 6 (Exam__c 3, Investigation__c 3) |
| Active approval processes | 4 (Exam__c 1, Investigation__c 3) |
| Validation rules (active / total) | 105 / 123 |
| Apex triggers / objects with >1 trigger | 61 / 6 (`pymt__PaymentX__c` ×3, `Account`, `Case`, `Transaction__c`, `TransactionLine__c`, `Application_Cache__c` ×2) |
| Triggers with no bypass switch (no OrgConfiguration/BREG_Setting/static disable) | 37 / 61 |
| Trigger frameworks in use | 3 (`TriggerFactory`/`ITrigger`, `BREGBaseTriggerHandler`, `fflib_SObjectDomain`), plus about a dozen triggers with inline logic |
| Active non-PB flows with ≥1 DML/action lacking a fault path | 159 / 185 (151 have **no** fault paths at all) |
| Active flows at API ≤ 50 | 55 (20 non-PB) |

## Automation Matrix

The table lists the 25 most-automated objects, ranked by total number of automation components. Counts are for active components only.

- **RT flows**: record-triggered flows.
- **Active VRs**: shown as active/total.
- **Types**: the number of distinct mechanisms present (trigger, before-save, after-save, PB, workflow rule, approval process, active VR).
- `pymt__PaymentX__c` after-save includes 1 before-delete flow (`Delete_Payment_Flow`).
- `Case` and `Account` have no validation rules in source.

| # | Object | Apex triggers (events) | Before-save RT flows | After-save RT flows | Sched. flows | Process Builders (+invocable) | Active WF rules | Approval procs | Active VRs | Types | Flags |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `Case` | `BREGCaseTrigger` (bupdate binsert aupdate ainsert)<br>`QualCaseTrigger` (ainsert aupdate) | 9 | 15 | 2 | 0 | — | — | 0/0 | 3 | 3+ types; 2 triggers; 15 after-save, no triggerOrder; 9 before-save, no triggerOrder |
| 2 | `Application__c` | `ApplicationTrigger` (binsert ainsert bupdate aupdate adelete aundelete) | — | 15 | — | 1 (+3) | — | — | 24/27 | 4 | 3+ types; 15 after-save, no triggerOrder; PB (retired) |
| 3 | `pymt__PaymentX__c` | `BREGPaymentTrigger` (binsert ainsert)<br>`PaymentAll` (binsert bupdate ainsert aupdate bdelete adelete)<br>`PaymentTrigger` (binsert ainsert bupdate aupdate bdelete adelete) | 1 | 5 | — | 2 | — | — | 0/0 | 4 | 3+ types; 3 triggers; 5 after-save, no triggerOrder; PB (retired) |
| 4 | `License__c` | `LicenseAll` (ainsert binsert bupdate aupdate) | — | 4 | 1 | 1 (+2) | — | — | 5/7 | 4 | 3+ types; 4 after-save, no triggerOrder; PB (retired) |
| 5 | `TravelApproval__c` | `TravelApprovalTrigger` (binsert bupdate) | 3 | 2 | 1 | 1 | — | — | 3/3 | 5 | 3+ types; 2 after-save, no triggerOrder; 3 before-save, no triggerOrder; PB (retired) |
| 6 | `Transaction__c` | `TransactionAll` (ainsert aupdate adelete aundelete bupdate bdelete)<br>`dlrs_TransactionTrigger` (bdelete binsert bupdate adelete ainsert aundelete aupdate) | — | 3 | — | 3 | — | — | 1/3 | 4 | 3+ types; 2 triggers; 3 after-save, no triggerOrder; PB (retired) |
| 7 | `Account` | `AccountTrigger` (binsert ainsert bupdate aupdate adelete aundelete)<br>`BREGAccountTrigger` (binsert bupdate aupdate) | 1 | — | — | 1 | 1 | — | 0/0 | 4 | 3+ types; 2 triggers; PB (retired) |
| 8 | `AssociatedLicense__c` | `AssociatedLicenseTrigger` (binsert bupdate ainsert aupdate adelete) | — | 3 | — | 1 | — | — | 2/2 | 4 | 3+ types; 3 after-save, no triggerOrder; PB (retired) |
| 9 | `InsuranceBond__c` | `InsuranceBondTrigger` (binsert bupdate bdelete ainsert aupdate adelete) | — | 2 | — | 1 (+1) | — | — | 1/2 | 4 | 3+ types; 2 after-save, no triggerOrder; PB (retired, recursion enabled) |
| 10 | `Investigation__c` | `InvestigationAll` (binsert bupdate ainsert aupdate bdelete adelete) | — | — | — | 1 | — | 3 | 0/0 | 3 | 3+ types; PB (retired) |
| 11 | `INET_Request__c` | `CATV_InetTrigger` (ainsert bupdate) | 1 | 1 | 1 | 0 | — | — | 6/6 | 4 | 3+ types |
| 12 | `SEBCase__c` | `SEBCaseAll` (ainsert aupdate) | — | 2 | — | 1 | — | — | 2/4 | 4 | 3+ types; 2 after-save, no triggerOrder; PB (retired) |
| 13 | `TransactionLine__c` | `BREGTransactionLineTrigger` (ainsert aupdate)<br>`TransactionLineAll` (ainsert aupdate adelete aundelete binsert bdelete bupdate) | — | 1 | — | 1 | — | — | 4/4 | 4 | 3+ types; 2 triggers; PB (retired) |
| 14 | `ExamsRequired__c` | — | — | 3 | — | 1 | — | — | 2/3 | 3 | 3+ types; 3 after-save, no triggerOrder; PB (retired) |
| 15 | `Exam__c` | `ExamAll` (bupdate ainsert aupdate) | — | — | — | 1 | — | 1 | 0/1 | 3 | 3+ types; PB (retired) |
| 16 | `Filing__c` | `FilingAll` (bupdate ainsert aupdate) | — | — | — | 1 (+1) | — | — | 30/31 | 3 | 3+ types; PB (retired) |
| 17 | `LicenseClassification__c` | `LicenseClassificationTrigger` (binsert ainsert bupdate aupdate adelete aundelete) | — | 1 | — | 1 | — | — | 0/0 | 3 | 3+ types; PB (retired) |
| 18 | `Task` | `BREGTaskTrigger` (ainsert aupdate) | — | 1 | — | 1 | — | — | 0/0 | 3 | 3+ types; PB (retired) |
| 19 | `UJET__UJET_Session__c` | `QualUjetSessionTrigger` (ainsert aupdate) | — | 2 | — | 0 | — | — | 0/0 | 2 | 2 after-save, no triggerOrder |
| 20 | `LicenseType__c` | `LicenseTypeTrigger` (binsert ainsert bupdate aupdate bdelete adelete aundelete) | — | — | — | 1 | — | — | 1/1 | 3 | 3+ types; PB (retired) |
| 21 | `SEBCaseTeam__c` | `SEBCaseTeamTrigger` (binsert ainsert bupdate aupdate bdelete adelete) | — | — | — | 1 | — | — | 1/1 | 3 | 3+ types; PB (retired) |
| 22 | `Worksheet__c` | — | — | 1 | — | 1 | — | — | 1/1 | 3 | 3+ types; PB (retired) |
| 23 | `breg_Transaction__c` | `BREGTransactionTrigger` (binsert bupdate) | — | 1 | — | 0 | — | — | 1/1 | 3 | 3+ types |
| 24 | `ApplicationClassifications__c` | `ApplicationClassificationsTrigger` (ainsert adelete aundelete) | — | — | — | 1 | — | — | 0/0 | 2 | PB (retired) |
| 25 | `ApplicationRequirement__c` | `ApplicationRequirementTrigger` (ainsert aupdate bupdate) | — | — | — | 1 | — | — | 0/0 | 2 | PB (retired) |

**Pairs with several record-triggered flows on the same object and event, none with `<triggerOrder>`:**
- `Application__c` after-save: 15
- `Case` after-save: 15
- `Case` before-save: 9
- `pymt__PaymentX__c` after-save: 4
- `License__c` after-save: 4
- `AssociatedLicense__c` after-save: 3
- `ExamsRequired__c` after-save: 3
- `Transaction__c` after-save: 3
- `TravelApproval__c` before-save: 3
- 2 each: `InsuranceBond__c`, `SEBCase__c`, `TravelApproval__c`, `UJET__UJET_Session__c` (all after-save)

## Findings

### [CRITICAL] ID W-01: `PVLProcessTrigger` (platform-event subscriber) runs SOQL, DML, flows and queueable jobs per event, with no retry handling
**Confidence**: The code path is Confirmed. The failure at normal renewal and notification volumes is Likely.

**Evidence**: `force-app/main/default/triggers/PVLProcessTrigger.trigger` (265 lines, `after insert` on `PVLProcess__e`) loops over `Trigger.new` (line 6). Inside that loop, depending on `Type__c`, it does the following:
- **"Generate VF Page"** (line 17) and **"Generate PDF"** (lines 32-37, once per file engine): calls `PVL_VFPDFGenerator.producePDFToFile` / `PVL_PDFGenerator.producePDFToFile`. Each call runs `System.enqueueJob(...)` (`classes/PVL_VFPDFGenerator.cls:39-40`, `classes/PVL_PDFGenerator.cls:421-431`).
- **"Terminate Associated License"**, **"Terminate Insurance Bonds"** and **"Terminate License"**: DML per event at lines 57, 74 and 88, with SOQL at line 66.
- **"DependencyFlow"**: 2 SOQL queries per event (lines 95, 105, one with `FOR UPDATE`). Then `Flow.Interview.createInterview('ApplicationRenewalDependencyCheck').start()` runs once per application (lines 133-143). That flow has 95 elements and runs system mode without sharing, calling 15 Apex invocables.
- **"MultiDependencyFlow"**: 2 SOQL per event (lines 159, 171) and a flow start per application (lines 212-216).
- **"CallLicenseHistoryFlow"**: SOQL (line 221) and a flow start per license (line 225).
- **"ScanResultApplication"**: updates one record, then re-publishes the rest of the list as a new event (lines 235-247). This is a self-chaining event loop that processes one record per delivery.
- **"App - Recreate Transaction Lines"**: `Database.executeBatch` per event (line 260).
- The trigger has no `try/catch`, `EventBus.RetryableException` or `EventBus.TriggerContext.setResumeCheckpoint`.

The events are produced at volume:
- `classes/NotificationDomain.cls:34-50` publishes one `PVLProcess__e` per `Notification__c`.
- The Notification records come from the invocable PBs `LicenseSubProcessNotifications` (17 `Notification__c` creates) and `ApplicationSubProcessNotifications` (11 creates), and from `ApplicationProcesses`.
- `PaymentImmediateActions` creates `PVLProcess__e` directly.

**Impact**: Platform-event triggers receive up to 2,000 events per execution. With synchronous limits, 51 "Generate PDF/VF" events in one delivery exceed the 50-`enqueueJob` limit. More than about 50 DependencyFlow events exceed the 100-SOQL limit. The exception is not retryable, so every event in that delivery is dropped. Licence letters and PDFs would then silently fail to generate and license terminations would not be applied. The dependency flow also runs as one non-bulkified interview per application, so CPU time grows linearly with volume.

**Recommendation**: Rewrite the subscriber so it processes events in bulk:
- Group events by `Type__c` and collect IDs across all events.
- Run one query and one DML per type.
- Enqueue one Queueable per type that carries the collected IDs, or use `Database.executeBatch` once.
- Call `setResumeCheckpoint(replayId)` per event and throw `EventBus.RetryableException` on transient failures.
- Set the trigger batch size with `PlatformEventSubscriberConfig`.
- Replace the per-application `Flow.Interview.start()` with a bulk invocable, or pass the flow a collection.

**Effort**: L

### [CRITICAL] ID W-02: The BREG trigger framework's static recursion guards skip trigger logic for later chunks and partial-save retries
**Confidence**: The mechanism is Confirmed. That it skips logic in production is Likely (it depends on DML size and whether the `allOrNone=false` retry path runs).

**Evidence**:
- `classes/BREGBaseTriggerHandler.cls:9` sets `ALLOW_RECURSION_DEFAULT = false`. Line 13 declares `private static Set<String> triggerHandlerAndOperation`. `canRun()` (lines 172-174) returns false once `handlerName + operationType` has been registered (lines 181-189). The key is never cleared, so any later execution of the same handler and operation in the transaction is skipped.
- The following BREG triggers use the default guard: `BREGAccountTrigger`, `BREGAccountAffiliationTrigger`, `BREGPaymentTrigger`, `BREGDocumentTrigger`, `BREGTNTMSMTrigger`, `BREGTransactionLineTrigger`, `BREGTaskTrigger`, `BREGTransactionTrigger` and `BREGTransactionBusinessInfoTrigger` (all `new XxxHandler().run()`).
- `triggers/BREGCaseTrigger.trigger:7-12` sets `TriggerUtils.disableTrigger = true` (a global static, `classes/TriggerUtils.cls:2`) after the first after-trigger. It is only reset by `TriggerUtils.resetDisableTrigger` (called from flow `BREG_Transaction_Line_After`) and `BREGRegistrationFormController.cls:248`. So every later Case DML in the same transaction skips the whole `BREGCaseTriggerHandler`, before and after. This includes after-save flows that update `$Record` (`BREG_Case_Status_Approved.Update_Case`, `BREG_Case_Set_Bypass_Status_Change_Validation.Update_Case`, `Update_Parent_Case_to_Withdrawn_for_WD_Child_Case`).
- Partial-save DML on these objects:
  - `BREGAccountStatus2DissolutionBatch.cls:107`, `BREGR7ExpirationBatch.cls:114` and `BREGDelinquencyStatusUpdateBatchJob.cls:185,401` (Account and Annual)
  - `BREGTNTMSMExpirationBatch.cls:114`
  - `BREGBackfillCaseLabelBatch.cls:83`
  - All use `Database.update(list, false)`.
- `BREGBatchJobConfigurationController.cls:70` lets an admin choose any batch size.

**Impact**:
- *Chunking*: Apex DML of more than 200 records (batch scope over 200, flows updating large collections, anonymous Apex, data fixes) fires triggers in chunks of 200 in the same transaction. Records 201 and above bypass all BREG handler logic.
- *Partial-save retries*: when a `Database.update(..., false)` has failures, the platform rolls back and re-runs triggers for the successful records. Static state is not rolled back, so the retry skips the handler.

  Both cases commit records without their BREG side effects, such as status transitions, derived fields and DocuSign workflows. This silent data inconsistency is hard to detect.

**Recommendation**:
- Replace the per-handler "ran once" guard with a guard keyed on record ID (a static `Set<Id>` of processed records per operation), or use change detection.
- Clear the guard key in an `andFinally` step when `Trigger.size` chunks complete.
- Replace `TriggerUtils.disableTrigger` with a scoped bypass (`disable → try/finally → restore`) and never leave it set after the trigger exits.
- Add 201-record and partial-failure tests.

**Effort**: M

### [HIGH] ID W-03: Save cascades across Transaction, TransactionLine and Payment have no recursion guard or change detection
**Confidence**: The individual links are Confirmed. The runtime depth of the cycle is Likely and should be verified with a debug log of one payment.

**Evidence**:
- `triggers/TransactionLineAll.trigger:3-16` calls `TransactionLineHandler.UpdateParentTotalAmount` on every after insert, update and delete. `classes/TransactionLineHandler.cls:3-38` re-queries every parent `Transaction__c` and runs an unconditional `update transactionList` (line 38), even when no amount changed and even when `TotalAmount__c` is unchanged.
- `Transaction__c` automation:
  - `TransactionAll` (no bypass; lines 23-40). It updates group-parent Transactions (`TransactionHandler.cls:3-45`), child Transactions (lines 49-77) and Payments (lines 82-106).
  - `dlrs_TransactionTrigger`.
  - PBs `TransactionConsolidatedProcessBuilder` (**`RecursiveCountVariable` = recursion enabled**; updates `pymt__PaymentX__c`, `Filing__c`, `Transaction__c`, `TransactionLine__c`, `HPEAPRequest__c`), `TransactionPVLProcessBuilder` (34 elements; creates and updates `TransactionLine__c` and updates `Transaction__c` ×7) and `TransactionHPEAPProcessBuilder`.
  - After-save flows `Clear_Most_Recent_Bounced_Check`, `Transaction_Send_PVL_Email_Receipt` (updates Payment) and `New_PVL_Transactions`.
- `TransactionLine__c` automation:
  - Triggers `BREGTransactionLineTrigger` and `TransactionLineAll`.
  - PB `TransactionLineImmediateActions` (updates `TransactionLine__c` ×11).
  - After-save flow `BREG_Transaction_Line_After` (updates Case).
- `pymt__PaymentX__c` automation:
  - Triggers `PaymentTrigger` (lines 70-71 → `TransactionPaymentAmtCalculator.calculate` updates Transaction), `PaymentAll` and `BREGPaymentTrigger`.
  - PB `PaymentImmediateActions` (updates Payment ×11, `Transaction__c`, `TransactionLine__c`, `Application__c`, and publishes `PVLProcess__e`).
  - Flows `PaymentChargebackCreateNegativeCollectionAllocation` (updates TransactionLine) and `Payment_Request_Refund` (updates TransactionLine).
- None of the PVL Apex triggers here has a recursion guard. `TriggerFactory.execute` (`classes/TriggerFactory.cls:46-110`) has none either.

**Impact**: A single payment or line edit re-saves Transaction, which re-saves TransactionLine and Payment, and so on. Each hop re-runs all triggers, PBs (the consolidated PB up to 5 extra times), after-save flows and roll-ups. This consumes SOQL, DML and CPU and raises row-lock contention with the 5-minute payment batches (W-13). Under bulk load (lockbox imports, reconciliation, data migration) the likely failures are `Too many SOQL queries: 101`, CPU timeouts or `UNABLE_TO_LOCK_ROW`. Because PB ordering is undefined, totals can also be computed from stale values.

**Recommendation**:
- Add change detection to `TransactionLineHandler.UpdateParentTotalAmount`: only process lines whose Amount, Transaction or PaidStatus changed, and only update parents whose computed total differs.
- Add a static processed-ID guard in `TransactionHandler` and `TransactionLineHandler`.
- Consolidate the three Transaction PBs and the TransactionLine PB into one before-save and one after-save flow per object, or into Apex.
- Merge `PaymentAll` and `PaymentTrigger` (see W-08).

**Effort**: L

### [HIGH] ID W-04: `Application__c`, `Case`, `License__c` and `pymt__PaymentX__c` have too much automation with undefined order
**Confidence**: Confirmed (counts and ordering). The CPU and limit risk is Likely.

**Evidence** (see the Automation Matrix):
- `Application__c`:
  - `ApplicationTrigger` (6 events, `TriggerFactory` without a recursion guard).
  - PB `ApplicationProcesses`: 203 elements, 107 decision rules, 13 subflow calls, 82 DML elements across 10 objects including License__c ×22. Plus invocable PBs `ApplicationSubProcessNotifications` (55), `ApplicationSubProcessPhaseChange` (32) and `ApplicationSubProcessTransactionInvocable` (12).
  - 15 after-save flows with no `triggerOrder`. Eight of them update the Application record itself again (see Appendix A6).
  - 24 active validation rules.
- `Case`: `BREGCaseTrigger` and `QualCaseTrigger`, 9 before-save flows and 15 after-save flows (none ordered), including 3 near-duplicate owner-assignment before-save flows (`Case_Complaint_Update_Owner`, `Case_Complaints_DCA_Complaints_Update_Owner`, `Case_Complaints_General_Complaints_Update_Owner`) and a test flow (W-16).
- `License__c`: `LicenseAll`, PB `LicenseImmediateActions` (141 elements; creates `Application__c` ×12 and updates `License__c` ×31), invocable PBs `LicenseSubProcessNotifications` (56) and `LicenseSubProcessAssociatedLicense` (15), and 4 after-save flows (`License_Inactivation_Flow` has 41 elements and 10 update elements).
- **Cross-object cycle**: License → (`LicenseImmediateActions`) creates or updates Application → (`ApplicationProcesses`) updates License ×22 → `LicenseAll` and the License PB re-run. `AssociatedLicense__c` flows update `License__c`, and `License__c` flows and PBs update `AssociatedLicense__c`.

**Impact**: Order among the 15 after-save flows and the PBs on each object is not deterministic. Several flows read fields that others write (for example the A3 dates and `Phase__c`), so outcomes can differ between releases. Each same-record update re-runs the whole save order, including the 203-element PB, and Apex triggers re-fire without guards. This is the most likely source of CPU timeouts during renewal batches (`GenerateRenewalApplicationBatch`, `LicenseExpire`, `ForfeitureLicense`) and data loads.

**Recommendation**:
- For each object, consolidate into at most one before-save flow (field defaults and same-record updates) plus a small number of after-save flows with explicit `triggerOrder`, or move the logic into the Apex handler.
- Migrate `ApplicationProcesses` and `LicenseImmediateActions` first (W-05).
- Move all same-record updates into before-save flows.
- Add entry criteria with "only when updated to meet criteria".

**Effort**: XL

### [HIGH] ID W-05: 48 active Process Builders and 1 active Workflow Rule, including the core Application, License, Payment and Transaction logic
**Confidence**: Confirmed.

**Evidence**:
- 41 `processType=Workflow` and 7 `InvocableProcess` flows have `<status>Active</status>` and a matching `activeVersionNumber` (full list in Appendix A1). Together they contain 1,039 elements.
- Largest: `ApplicationProcesses` (203), `LicenseImmediateActions` (141), `FilingImmediateActions` (76), `LicenseSubProcessNotifications` (56), `ApplicationSubProcessNotifications` (55), `PaymentImmediateActions` (44) and `TransactionPVLProcessBuilder` (34).
- Two PBs have recursion enabled: `TransactionConsolidatedProcessBuilder` and `InsuranceBondHandler`. The PB `InsuranceBondHandler` has the same name as the Apex class `classes/InsuranceBondHandler.cls`.
- Active Workflow Rule: `workflows/Account.workflow-meta.xml` → `SetSEBSECFlag` (onCreateOnly; field update `AccounSetSEBSECFlag`).
- A further 13 Draft or Obsolete PBs are still in source (W-16).

**Impact**: Salesforce ended support for Process Builder and Workflow Rules on 2025-12-31. They still run, but there are no bug fixes or support cases, and they cannot be edited in newer tooling. PBs also have poor bulk performance: each criteria node is evaluated per record, and they run in undefined order with after-save flows. Every critical PVL object depends on them.

**Recommendation**: Migrate by object, highest risk first: Transaction and Payment (financial), then Application and License, then the rest. Use the Migrate to Flow tool as a starting point and then refactor:
- same-record updates → before-save
- cross-object DML → after-save, bulkified
- email alerts → flow Send Email actions or Apex

Retire the Account Workflow Rule into `BREG_Account_Before`.

**Effort**: XL

### [HIGH] ID W-06: Batch jobs, `@future` calls and Queueable jobs are started per record from triggers
**Confidence**: Confirmed.

**Evidence** (TriggerFactory calls the handler once per record: `classes/TriggerFactory.cls:66-75, 95-104`):
- `classes/licenseService.cls:52-73`: `generatePostCard` and `generateRenewalNotification` run `Database.executeBatch(...)` for each License whose flag is set. They are called from `LicenseHandler.beforeUpdate(oldSo, so)`.
- `classes/LicenseTypeHandler.cls:90-259`: `beforeUpdate(oldSo, so)` holds 12 flag-driven `Database.executeBatch` sites per LicenseType record, for example lines 107, 118, 135, 144, 154, 163, 184, 197, 207, 238, 241 and 259.
- `classes/NotificationDomain.cls:36-40`: `Database.executeBatch(new DocumentGeneratorProcessBatch(...), 10)` inside a `for` over notifications.
- `classes/CertificateRequestService.cls:4-19`: `captureForPocketWallCertReq(so)` is called per record from `CertificateRequestHandler.afterInsert` (line 8) and calls the `@future(callout=true)` method `generatePocketFiles` (line 21) **once per record**.
- `classes/BREGDocumentTriggerHandler.cls:81-85, 187-200` and `classes/BREGTransactionLineTriggerHandler.cls:114-119, 130-143`: in loops, `BREGStartDocusignWorkflow.createWorkflowLogSafely(...)` does one insert per call (`BREGStartDocusignWorkflow.cls:133-141` → `BREGUtils.cls:1370-1378`, `dmlService.insertLog`), followed by `System.enqueueJob(new BREGStartDocusignWorkflow(...))`.
- `triggers/PVLProcessTrigger.trigger:260` (see W-01).

**Impact**: The following all throw `LimitException` and roll back the user's save or the whole batch chunk:
- 51 or more certificate requests in one transaction: `@future` limit of 50.
- More than 50 BREG documents, certificates or regular copies in one transaction: `enqueueJob` limit of 50, plus DML per iteration.
- More than 100 flagged Licenses or LicenseTypes: Apex flex queue limit of 100 holding batch jobs.
- `Database.executeBatch` called from a batch `execute()`: not allowed.

**Recommendation**: Collect IDs in the per-record method and launch one job per transaction in `andFinally()` / `bulkAfter()`, using a batch or Queueable that takes a set of IDs. Insert workflow logs in bulk (`createWorkflowLogsSafely` already exists at `BREGStartDocusignWorkflow.cls:143`) and enqueue a single Queueable that processes the list.

**Effort**: M

### [HIGH] ID W-07: DML, SOQL, subflows and email actions inside flow loops (21 loops in 14 active flows)
**Confidence**: Confirmed by graph traversal. The runtime thresholds are Likely.

**Evidence** (full list in Appendix A3). The most severe:
- `Express_Change_Broker_Email_Bouncebacks` is a scheduled flow with no object, so it runs as one interview. It loops over all `EmailMessage` records from the last 24 hours. Per iteration it runs `Get_Record` (SOQL), `Update_Record` and `Add_Log_Item` (2 DML). **It fails at about 75 bounced emails a day** (150-DML limit).
- `Application_Public_Accountancy_Renewal`, loop `Loop_through_all_associated_CPA`: 3 Get Records, 5 Updates and 2 `Create_License_History` subflows per iteration. `Loop_through_all_associated_licenses`: 1 Get and 2 Updates. `Application_Pharamcy_Renewal`, loop `Loop_Associated_PHY_Licenses`: 2 Gets, 2 Updates and 1 subflow.
- Record-triggered: `Application_REAC_Process.Update_Each_Associated_License` and `Application_Set_Exam_Eligible_Start_Date.Update_Exam_Start_Date` do an Update per iteration.
- Screen flows: `AccountUploadBatchTransactions` (3 loops with a Get or Create per iteration; a cashier batch upload) and `TransactionGroupTransactions.UpdateRelatedTransactions`.
- Email actions in loops: `BREG_Notification_Sending` (4 loops), `BREG_Transaction_notificatons`, `CATV_Notifications_on_Status_change`, `Case_DO_Due_Date_Reminder`, `Testing_Email_Functions` (2 loops) and `Work_Item_Sub_flow_Transfer_work_item`.

**Impact**: Each iteration uses its own SOQL and DML allowance. Renewal flows for entities with many associated licenses (CPA firms, pharmacies) can reach the 100-SOQL or 150-DML limits, especially when started from `PVLProcessTrigger` or `ApplicationRenewalDependencyCheck`. Each `Create_License_History` subflow call adds more DML. Email actions sent in loops can hit email invocation limits and send duplicates when the flow is retried.

**Recommendation**: Inside the loop, only assign values to record variables and add them to a collection, then run one Update or Create after the loop. Replace the Get-in-loop with a single Get before the loop, filtered with `IN`. Make `Create_License_History` accept a collection. For email, build a recipient collection and send once, or use an email alert with a collection.

**Effort**: M

### [HIGH] ID W-08: Several unordered Apex triggers on the same object, three trigger frameworks and two bypass schemes
**Confidence**: Confirmed.

**Evidence**:
- `pymt__PaymentX__c` has **3 triggers**: `PaymentAll` (6 events → `PaymentAllHandler`), `PaymentTrigger` (6 events; inline dedup and Transaction amount calculation, lines 14-73) and `BREGPaymentTrigger` (before and after insert). `PaymentAll` and `PaymentTrigger` check the same `OrgConfiguration__c.DisableTriggers__c` and `PaymentDeduplicator.disableTrigger` flags, but they run in an undefined order.
- `Account`: `AccountTrigger` (TriggerFactory) and `BREGAccountTrigger` (BREG framework).
- `Case`: `BREGCaseTrigger` and `QualCaseTrigger`.
- `Transaction__c`: `TransactionAll` and `dlrs_TransactionTrigger`.
- `TransactionLine__c`: `TransactionLineAll` and `BREGTransactionLineTrigger`.
- `Application_Cache__c`: `ApplicationCacheTrigger` and `DraftApplicationTrigger`. The latter updates its own records in after-trigger (`DraftApplicationTrigger.trigger:4-16`).
- Frameworks:
  - `TriggerFactory`/`ITrigger`: 22 handlers, per-record dispatch, no recursion guard.
  - `BREGBaseTriggerHandler`.
  - `fflib_SObjectDomain` (`CaseTeamAssignmentTrigger.trigger:2`).
  - About a dozen triggers with substantial inline logic (for example `EarnedCETrigger`, `CollectionsAllocationTrigger`, `PVLProcessTrigger`, `PaymentTrigger`, `DraftApplicationTrigger`, `TravelApprovalTrigger`).
- Bypass: PVL triggers use `OrgConfiguration__c`, BREG triggers use `BREG_Setting__c.Global_Data_Migration_Triggers_Disabled__c`, and 37 of 61 triggers have no bypass at all. That includes `TransactionAll`, `TransactionLineAll`, `EarnedCETrigger`, `FilingAll`, `ExamAll`, `InvestigationAll`, `SEBCaseAll` and the `dlrs_*` triggers. The full list is in Appendix A5.
- `triggers/TransactionAll.trigger` calls `TriggerFactory.createAndExecuteHandler` (line 40) but does not subscribe to `before insert`, so `Transaction_Handler`'s before-insert hooks can never run.
- `triggers/StatusHistoryTrigger.trigger` is active but its whole body is commented out (lines 3-44).

**Impact**: Behaviour depends on undefined trigger order (for example Payment dedup versus allocation). A single data-migration bypass cannot turn off all automation. Each framework needs its own recursion and bulk rules, which multiplies defects (see W-02 and W-03).

**Recommendation**:
- Standardise on one handler framework with one trigger per object, one metadata-driven bypass (custom permission or custom metadata) and a record-ID recursion guard.
- Merge `PaymentAll`, `PaymentTrigger` and `BREGPaymentTrigger` first.
- Delete `StatusHistoryTrigger`.

**Effort**: L

### [MEDIUM] ID W-09: Hard-coded record IDs and user names in active flows
**Confidence**: Confirmed.

**Evidence** (element API names; the line numbers are in the flow XML):
- `Account_Set_Contact_on_Person_Account` (PB), elements `myRule_19_A1` and `myRule_23_A1` (lines 1337 and 1815): `PVL_License_Type__c` is set to a literal comma-separated list of **150 `a2x…` IDs**.
- `SEBCaseImmediateActions` `myRule_3_A1` and `myRule_22_A1`: `OwnerId = 00Gt0000000ynQyEAI` (queue).
- `Application_New_Task_for_Portal_Update` formulas `IntegrationUserOwnerID = "005t00000022GqIAAU"` (user) and `ContactId` compares to `012t0000000PLy1AAG` (record type).
- `PaymentImmediateActions` `myRule_35_A1`: `pymt__Contact__c = 003t000000d3b4nAAA`.
- `HPEAPRequestConsolidatedProcessBuilderforHPEAPRequestObject` `myRule_1_A1`: `Account__c = 001t000000IZXZw` and `Contact__c = 003t000000NEiaZ`.
- Cashier code IDs:
  - `TransactionPVLProcessBuilder.myRule_14_A1`: `a0St0000001LMoQEAW`
  - `TransactionHPEAPProcessBuilder.myRule_1_A1`: `a0St0000000llsD`
  - constants `x005CashierCodeId` and `x011CashierCodeId` in `ApplicationPVLRenewalPermitToPracticeFeeHelper` and `PVL_Renewal_PermitToPractoce_Subflow`
- `BREG_TNTMSM_Expire_Now.Get_Permissions_of_the_current_user`: `PermissionSetId = 0PScq000000KU3b`. The `cq` pod prefix differs from the `t0` prefix of the other IDs, so the IDs come from at least 2 orgs.
- `Update_Payment_Owner` (before-save on Payment): terminal device URNs are hard-coded to named people (`Get_User_Susan_Kanda`, `Get_User_Rebecca_Bolosan` by `Name`).

**Impact**: These records do not exist in developer sandboxes, scratch orgs or a rebuilt org, so the automation fails or writes bad references there. The user and person names break when staff change. Record-level configuration is hidden inside a retired PB.

**Recommendation**: Replace them with Custom Metadata or Custom Labels (cashier codes, queue developer names, terminal-to-user mapping), look up record types by `DeveloperName`, and look up queues and permission sets by `DeveloperName` or `Name`. Replace the 150-ID list with a field or criteria on `LicenseType__c`.

**Effort**: M

### [MEDIUM] ID W-10: Missing fault paths in flows, including screen flows that call Apex and payment integrations
**Confidence**: Confirmed.

**Evidence**:
- 577 of 609 DML and action elements in the 185 active non-PB flows have no `faultConnector`. 151 flows have no fault handling at all.
- 11 active screen flows call Apex without a fault path:
  - `Reconciliation_Batch_Push_to_Oracle_GL.Send_Reconciliation_Batch_to_Oracle` (`OracleGLBatchloadFlowService`)
  - `Generate_Payment_Adjustment.Generate_Payment_Adjustment`
  - `BREG_Refund_Submit_Request.CaseLifecycleHandler_Execute_Action_from_Flow_Action_1`
  - `BREG_Case_Rejection.Upload` and `BREG_Document_Upload_Screen_Flow.Upload_Documents_to_Docusign` (`DocuSignAPI`)
  - `BREG_Case_Approval.Define_Form_Category`
  - `Application_Generate_Deficiency` and `License_Generate_Notice_of_Licensure` (`GeneratePDF`, `SendEmail`, `View_PDF`)
  - `Add_Case_Team_Member.Check_Case_Access`
  - `BoardProgramRunMultipleLicenseTypesAuditBatchJob.AuditUserSelectedLicenses`
  - `File_Upload_RecordAction.getDefaultRecordTypeId`
- The 7 invocable PBs send their "process failed" emails to former vendor staff (W-17).

**Impact**: Users see the generic "An unhandled fault has occurred" screen. The failure is emailed only to the flow's last modifier. For record-triggered flows the whole save rolls back without a friendly message. Integration failures to Oracle GL and DocuSign are not logged in a durable place.

**Recommendation**: Add fault paths to every DML, Apex and callout element. Route them to a shared error-logging subflow that writes to `Application_Log__c` or `breg_Handler_Log_Message__c`, and show a user-friendly error screen. Give payment and integration flows priority.

**Effort**: M

### [MEDIUM] ID W-11: 28 after-save flows update their own triggering record, and 2 do so on every edit
**Confidence**: Confirmed.

**Evidence** (full list in Appendix A6):
- 28 active after-save flows update `$Record` or the same object: Application ×8, Case ×7, ExamsRequired ×3 and 10 others.
- No change guard at all:
  - `Exams_Required_Validation` (`CreateAndUpdate`, no filters): runs a Get on every ExamsRequired save and sets `Prevent_Save__c = true` through `Update_Prevent_Save_Field`. This is validation implemented as a second DML.
  - `DO_Referral_Case_Close_Case_Status` (`Update`, `filterFormula` without `doesRequireRecordChangedToMeetCriteria`): sets `Status='Closed'` on **every** later edit of a closed DO Referral case.
- Eleven others check for changes only in in-flow `ISCHANGED`/`$Record__Prior` decisions and do not set `doesRequireRecordChangedToMeetCriteria`. The interview therefore starts whenever the start filters match, not only when the fields change.

**Impact**: Each update re-runs the full save order: before triggers, validation rules, after triggers, PBs and the other flows. This roughly doubles CPU and DML on the busiest objects (W-04). It is a common cause of "maximum trigger depth exceeded" and CPU timeouts.

**Recommendation**: Move same-record field assignments into before-save flows or Apex before triggers. Set entry conditions with "only when a record is updated to meet the criteria". Replace `Exams_Required_Validation` with a before-save check that uses `addError` or a custom error element.

**Effort**: M

### [MEDIUM] ID W-12: `@future` methods called from trigger context without `isBatch()`/`isFuture()` guards
**Confidence**: Confirmed (code). Runtime failure is Likely whenever a batch or future touches these objects with the triggering flags set.

**Evidence**:
- `classes/ApplicationClassificationsService.cls:48,53`: `reGenerateTransactionLines` (`@future`) is called from `runFinally` on every after trigger of `ApplicationClassifications__c`.
- `classes/ApplicationService.cls:693`: `generateCheckoutForm` (`@future(callout=true)`) is called from `ApplicationHandler.bulkAfter` (`ApplicationHandler.cls:68`).
- `classes/licenseService.cls:1016`: `sendRenewalEmails` is called from `LicenseHandler.cls:61`.
- `classes/FileDetailService.cls:5,9`.
- `classes/CATV_UserTriggerHandler.cls:47,95` → `@future` at lines 99 and 105.
- `classes/CATV_InetTriggerHandler.cls:4` → line 36.
- `classes/BREGCaseStatusHandlerBase.cls:128` → line 1794 (the comment reads "urgent hotfix 13 April 2026… Permanent fix needed").
- For comparison, `licenseService.cls:298,798` do check `!System.isBatch()`, so the pattern is known but applied inconsistently.

**Impact**: The platform throws `System.AsyncException: Future method cannot be called from a future or batch method` when these records are changed by any batch (renewal, expiry or forfeiture batches) or by a `@future`/Queueable chain. The whole batch chunk then fails.

**Recommendation**: Replace `@future` with a Queueable enqueued once per transaction, guarded with `if (System.isBatch() || System.isFuture()) { run synchronously or defer }`. Replace the BREG hotfix with a permanent fix.

**Effort**: M

### [MEDIUM] ID W-13: Payment batches self-schedule every 5 minutes (24 cron slots) with no overlap protection
**Confidence**: Confirmed (code). Overlapping runs are Likely.

**Evidence**:
- `classes/PaymentXBatch.cls:54-190`: `schedule5min()` and `schedule()` abort and re-create 12 and 4 `System.schedule` jobs with hard-coded crons `0 0 * * * ?` through `0 55 * * * ?`. `execute(SchedulableContext)` at lines 192-194 starts a new batch every time with no check for one already running. `finish()` at lines 367-375 chains `DCCAFeeScheduleBatch` with scope 2000.
- `classes/PaymentAllocateTransactionLinesBatch.cls:3-55` does the same with 12 jobs. Its `finish()` at lines 230-233 is empty.
- Other hard-coded crons:
  - `DepositRollupsBatch` (`0 10 * * * ?`)
  - `QualRetrySchedulable` (hourly)
  - `RollingLicenseExpiredStatusBatch`, `RBEntityPrincipalBrokerSuspenseBatch`, `SuspenseDueDateProcessingBatch`, `util_closer_LogCleanupBatch`, `PVLAppStatusSnapshotRefreshScheduler` (daily)
  - `BREGDBEDTReportScheduler` (monthly)

**Impact**: Two Payment batches start every 5 minutes, which is 576 batch starts a day. They use 24 of the 100 scheduled-Apex slots and compete for the 5 concurrent batch slots. If a run takes more than 5 minutes, two instances process the same payments, which risks double allocation and `UNABLE_TO_LOCK_ROW` against user payment saves (W-03).

**Recommendation**: Use one scheduler that checks `AsyncApexJob` for an active instance before starting a new one, or a self-rescheduling Queueable or `System.scheduleBatch` from `finish()`. Move cron expressions to Custom Metadata. Consider moving to event-driven processing (a Payment platform event or change data capture).

**Effort**: M

### [MEDIUM] ID W-14: Async jobs report errors poorly and chain without guards
**Confidence**: Confirmed.

**Evidence** (inventory in Appendix A4):
- There are 89 Batchable classes. 39 have an empty `finish()`, for example `PaymentAllocateTransactionLinesBatch`, `ForfeitureLicense`, `LicenseRMELoseBatch`, `InsuranceStatusBatch`, `SEBCasePenaltyBatch` and `DeleteUnPaidAppsBatch`.
- Only 2 classes implement `Database.RaisesPlatformEvents` (`util_closer_LogCleanupBatch`, `util_closer_CaseStatusBatch`), and no trigger in the repo subscribes to `BatchApexErrorEvent`.
- 25 classes chain further jobs: `finish()` → `executeBatch` in `LicenseExpire`, `InsuranceSuspenseBatch`, `InsurancePortalSubmissionBatch`, `RealEstateRenewalBatch`, `ScheduledGenerateFiles`, `BatchFlagLicenseBeforeAudit`/`ForAudit`, `AsyncCompletePaymentsDeposit` and `PaymentXBatch`; Queueable self-chaining in `IMLCCQueueable.cls:383` (and `BREGAmazonSesQueueable.cls:73`).
- 49 Schedulable classes have no scheduling code, so they are presumably scheduled by hand in Setup and are not traceable in source.
- `IMLCCQueueable.cls:383` suppresses chaining in tests with `Test.isRunningTest()`.
- Five Queueables use Finalizers (`BREGAmazonSesQueueable`, `FileDetailCreatorController`, `PVL_PDFGenerator`, `PVLRenewApp`, `PVL_SendPVLEmails`), which is good practice to keep.

**Impact**: Failed chunks are only visible in Apex Jobs, and licence expiry, forfeiture and suspense jobs can fail partly without anyone being notified. Chained jobs can loop or stop without notice. The schedule inventory cannot be rebuilt from source after a sandbox refresh.

**Recommendation**: Add `Database.RaisesPlatformEvents` plus a `BatchApexErrorEvent` subscriber that writes to the common log. In `finish()`, check `AsyncApexJob.NumberOfErrors` and send a notification. Keep scheduled jobs in Custom Metadata with a post-deploy scheduling script.

**Effort**: M

### [MEDIUM] ID W-15: Inline triggers with ineffective recursion flags and duplicate DML
**Confidence**: Confirmed.

**Evidence**:
- `triggers/EarnedCETrigger.trigger`:
  - `isUpdateLicenseOnce` (line 9) is a **local** variable, so the guard at line 55 never works.
  - The trigger issues **2 separate updates to the same `License__c` records** (lines 52 and 118), and each re-runs `LicenseAll`, `LicenseImmediateActions` (141 elements) and the License flows.
  - There is no bypass.
- `triggers/CollectionsAllocationTrigger.trigger:25-26` queries in the trigger body (acceptable), but the business logic sits in the trigger with no handler or bypass.
- `triggers/DraftApplicationTrigger.trigger:4-16` runs a self-update DML in after insert and update on the same object as `ApplicationCacheTrigger`.

**Impact**: Each CE credit change doubles the License save cascade. Under CE bulk loads (CE providers upload many records), this adds CPU and SOQL pressure on the License automation stack.

**Recommendation**: Move the logic into a handler. Compute both roll-ups in one pass and issue one update. Convert `DraftApplicationTrigger`'s Name sync to a before trigger or a before-save flow.

**Effort**: S

### [MEDIUM] ID W-16: Flow version state does not match flowDefinitions, and inactive or test flows are in source
**Confidence**: Confirmed.

**Evidence**:
- Four flows have a flow file with status Draft or Obsolete while the flowDefinition still sets `activeVersionNumber`:
  - `LicenseNotificationEmailUpdate` (Draft, def v1)
  - `SEBCaseContact_UpdateName` (Draft, def v1). It is **called as a subflow by the active PB `SEBCaseContact_ImmediateActions`**.
  - `DO_Referral_Added_to_Case_Team_Email` (Obsolete, def v1)
  - `Work_Item_Update_Record_on_Create` (Obsolete, def v7)
- 33 Draft or Obsolete flows remain in source (list in Appendix A1b). 29 flowDefinitions have no `activeVersionNumber`.
- `Testing_Email_Functions` (label "Testing: Email Functions") is **Active**. It is an after-save flow on Case with no change-based entry criteria, and in 2 loops it emails DO case team members when Comments or Division change.

**Impact**: What gets deployed depends on how the flowDefinition and flow file are resolved, so a deploy can deactivate or activate the wrong version. The PB's subflow call may fail if the Draft version is deployed. A test flow sends real emails to staff.

**Recommendation**: Reconcile the flow files with the org's active versions and delete obsolete flows from source (`destructiveChanges`). Deactivate or remove `Testing_Email_Functions` after confirming with the business. Add a CI check that fails when the flow status and flowDefinition disagree.

**Effort**: S

### [MEDIUM] ID W-17: Hard-coded email addresses and URLs in flows and email alerts, including vendor and personal addresses
**Confidence**: Confirmed.

**Evidence**:
- The PB fault emails (`emailSimple` "Your Process Failed to Execute") go to vendor staff:
  - `jiaying.feng@pacificpointcorp.com`: `ApplicationSubProcessNotifications`, `ApplicationSubProcessTransactionInvocable`, `LicenseSubProcessNotifications`, `LicenseSubProcessAssociatedLicense`
  - `flint.tearney@pacificpointcorp.com`: `Account_Set_Contact_on_Person_Account`, `ApplicationSubProcessPhaseChange`
  - `arnold.chung@pacificpointcorp.com`: `FilingSubProcessStalledFiling`
  - `rumina.deguzman@pacificpointcorp.com`: `InsuranceBondSubProcessActivationInactivationHandler`
- Email alerts with vendor or personal CCs:
  - `workflows/Application__c.workflow-meta.xml` `ExamBranchNotificationofAddressChange` CCs `flint.tearney@pacificpointcorp.com` and **`flint.tearney@gmail.com`**
  - `RICOReferral__c.SubmittoRICOEmail` CCs a PacificPoint address and a PacificPoint user
  - `Requisition__c` (3 alerts) CC `kaitlin.nelsen@pacificpointcorp.com`
  - `DFIRegistration__c` sender is `hawaiidfi1@gmail.com`
  - Named staff recipients are in `Filing__c`, `SEBCase__c`, `TravelApproval__c` and `Requisition__c` alerts
- `DCCA_Complaint_Re_Assign_Case` hard-codes 16 division mailboxes.
- URLs: `Case_Complaint_Send_Email_After_Submit` contains `https://hi-dcca.lightning.force.com/`, and `express_change_broker` contains `https://mypvl.dcca.hawaii.gov/…`.

**Impact**:
- *Data exposure*: record details are sent to former vendor and personal Gmail accounts. This is a privacy and compliance problem for a government regulator.
- *Broken notifications and wrong links*: alerts fail or are misdirected when staff change, and sandboxes contain production links.

**Recommendation**: Remove external and personal addresses now. Route PB and flow fault emails to a monitored DCCA mailbox, or better, to a log object (W-10). Use Custom Metadata or Custom Labels, or public groups, for division mailboxes, and `$Api`/`URL.getOrgDomainUrl()` or labels for URLs.

**Effort**: S

### [LOW] ID W-18: Old API versions on flows and triggers
**Confidence**: Confirmed.

**Evidence**:
- 55 active flows are at API ≤ 50 (64 flow files are at 49.0). The 20 non-PB ones include `AccountUploadBatchTransactions`, `TransactionGroupTransactions`, `ApplicationWizard`, `LicenseRenewProcess`, `PaymentStatusToBFC` and `Application_License_Generator`.
- Triggers are at API 39.0-48.0: for example `TransactionAll` and `TransactionLineAll` at 39.0, `ApplicationTrigger`, `LicenseAll` and `ApplicationClassificationsTrigger` at 41.0, and `PaymentAll` and `PaymentTrigger` at 43.0.

**Impact**: Older runtime behaviour applies (for example flow bulkification and null-handling differences, and missing newer features such as `$Record__Prior` in old PBs). Old versions will eventually be retired.

**Recommendation**: Raise the API version during W-04 and W-05 refactors and regression-test.

**Effort**: S

### [LOW] ID W-19: Flows running in system mode without sharing
**Confidence**: The inventory is Confirmed. Guest exposure is Unverified: the repo has no Experience Cloud site or network metadata.

**Evidence**: 10 flows declare `runInMode=SystemModeWithoutSharing`:
- Screen flows: `BREG_Create_Child_Case` (on `flexipages/BREG_Work_Item`), `BREG_Create_Refund_Case`, `BREG_Manual_Filing` (`lwc/breg_newCaseButton`), `CC_Work_Item_General_Transfer`, `CC_Work_Item_Take_Ownership`, `Case_Call_Center_Update_Branch_on_Case`, `DCCA_Complaint_Re_Assign_Case` and `License_Certificate_Request` (creates Transaction and TransactionLine).
- Autolaunched: `ApplicationRenewalDependencyCheck` and `Work_Item_Sub_flow_Transfer_work_item`.

**Impact**: Users can create or update records they cannot see. The risk is low if these flows are internal only. If any are embedded in the PVL or BREG portal, it becomes a sharing bypass.

**Recommendation**: Confirm where each is used. Default to `DefaultMode` (user context) and elevate only specific elements through invocable Apex with explicit checks.

**Effort**: S

### [LOW] ID W-20: Approval-process field updates re-evaluate workflow on objects that also have PBs and triggers
**Confidence**: Likely.

**Evidence**: `workflows/Exam__c.workflow-meta.xml` (`SetExamStatusToExamReportApproved`, `SetExamStatusToSentForSupervisorReview`, `SetExamStatus_To_UpdatesRequired`) and `workflows/Investigation__c.workflow-meta.xml` (`Investigation_StatusCorrectionsRequired`, `…CorrectionsSuAtt`, `…SupervisingAttorney`) use `reevaluateOnChange=true`. They are used by the 4 active approval processes. The same objects run `ExamAll`/`InvestigationAll` (no recursion guard) and the PBs `ExamImmediateActions`/`InvestigationImmediateActions`.

**Impact**: Approval steps re-run the update triggers and PBs, which can send duplicate emails or status-history rows (`StatusHistoryAux.LogStatus`).

**Recommendation**: Review this during PB migration. Add change guards in the trigger's status logging.

**Effort**: S

### [LOW] ID W-21: PB logic defects and duplicated flow logic
**Confidence**: Likely.

**Evidence**:
- `Account_Set_Contact_on_Person_Account` rule "Account Name Changes" ANDs `isChanged` on Name, FirstName, MiddleName and LastName. It fires only when all four change together, which is probably meant to be OR.
- There are 5 near-duplicate per-board renewal flows (`Application_Nursing_Renewal` 57 elements, `_Pharamcy_` 43, `_Public_Accountancy_` 54, `_Hawaii_Medical_Board_` 48, `_ElectricianandPlumber_`), plus about 12 Apex `*Renewal` classes called from `ApplicationRenewalDependencyCheck`.
- There are 3 near-duplicate Case owner-assignment before-save flows.
- 17 flows contain `Copy_N_of_*` elements (`BREG_Manual_Filing` has 15).

**Impact**: Name changes may never sync to the related records. Fixes to renewal logic have to be repeated in several places.

**Recommendation**: Fix the rule during PB migration. Build one metadata-driven renewal subflow or service.

**Effort**: M

### [LOW] ID W-22: Scheduled flow volumes and filters
**Confidence**: Likely.

**Evidence**: There are 7 active scheduled flows:
- Record-based, batched by the platform in groups of 200: `BREG_Case_Expire` and `BREG_Case_Submit_Reopened` (Case, daily), `CATV_Auto_Close_Draft_Request` (INET_Request__c, daily, filter `Status__c = Draft` only), `License_Renewing_Inactive_Flow` (License__c, daily) and `TravelApprovalSendSOCTApproachingDeadlineEmail`.
- Single-interview: `Express_Change_Broker_Daily_Cron` (bulk update after the loop, which is fine) and `Express_Change_Broker_Email_Bouncebacks` (W-07).

`BREG_Case_Expire` updates `$Record` Status on Cases, which fires `BREGCaseTrigger`. That trigger's static flag (W-02) applies per 200-record batch.

**Impact**: This is low today. `CATV_Auto_Close_Draft_Request` selects every Draft request daily and relies on in-flow date checks. The single-interview flows do not scale.

**Recommendation**: Put the date conditions in the start filters. Convert the bounceback flow to a record-based scheduled path or a batch.

**Effort**: S

## Appendix

### A1. Active Process Builders (48)

| Process Builder | Type | Object | Trigger | API | Elements | Recursion enabled | DML targets |
|---|---|---|---|---|---|---|---|
| `ApplicationProcesses` | PB | `Application__c` | onAllChanges | 52.0 | 203 | No | Application__c×27, License__c×22, LicenseHistory__c×13, Suspense__c×7, Transaction__c×4, AssociatedLicense__c×3, Notification__c×3, ApplicationClassifications__c×1, ExamsRequired__c×1, Account×1 |
| `LicenseImmediateActions` | PB | `License__c` | onAllChanges | 52.0 | 141 | No | License__c×31, Application__c×14, AssociatedLicense__c×3, LicenseClassification__c×2, LicenseHistory__c×1, InsuranceBond__c×1, Account×1, Suspense__c×1, Notification__c×1 |
| `FilingImmediateActions` | PB | `Filing__c` | onAllChanges | 53.0 | 76 | No | Filing__c×13, Account×12, FileDetails__c×1 |
| `LicenseSubProcessNotifications` | Invocable PB | `License__c` | invoked | 49.0 | 56 | No | Notification__c×17, License__c×17 |
| `ApplicationSubProcessNotifications` | Invocable PB | `Application__c` | invoked | 49.0 | 55 | No | Application__c×21, Notification__c×11, Task×2, ApplicationRequirement__c×1 |
| `PaymentImmediateActions` | PB | `pymt__PaymentX__c` | onAllChanges | 52.0 | 44 | No | pymt__PaymentX__c×11, PVLProcess__e×1, Transaction__c×1, Application__c×1, TransactionLine__c×1 |
| `TransactionPVLProcessBuilder` | PB | `Transaction__c` | onAllChanges | 53.0 | 34 | No | TransactionLine__c×8, Transaction__c×7, pymt__PaymentX__c×1, License__c×1 |
| `ApplicationSubProcessPhaseChange` | Invocable PB | `Application__c` | invoked | 49.0 | 32 | No | Application__c×18 |
| `ExamRequiredProcesses` | PB | `ExamsRequired__c` | onAllChanges | 49.0 | 30 | No | ExamsRequired__c×8, Application__c×4, ExamResults__c×1 |
| `Account_Set_Contact_on_Person_Account` | PB | `Account` | onAllChanges | 49.0 | 26 | No | Account×4, pymt__PaymentX__c×2, Filing__c×2, Transaction__c×1, Application__c×1, License__c×1, Exam__c×1, SEBCase__c×1 |
| `ExamImmediateActions` | PB | `Exam__c` | onAllChanges | 53.0 | 24 | No | Exam__c×6, FileDetails__c×2, Account×1 |
| `SEBCaseImmediateActions` | PB | `SEBCase__c` | onAllChanges | 49.0 | 24 | No | SEBCase__c×6, SEBCaseNumber__c×1 |
| `TransactionLineImmediateActions` | PB | `TransactionLine__c` | onAllChanges | 49.0 | 24 | No | TransactionLine__c×11 |
| `InsuranceBondSubProcessActivationInactivationHandler` | Invocable PB | `InsuranceBond__c` | invoked | 49.0 | 23 | No | License__c×9 |
| `TransactionConsolidatedProcessBuilder` | PB | `Transaction__c` | onAllChanges | 49.0 | 18 | Yes | Transaction__c×3, pymt__PaymentX__c×2, Filing__c×2, TransactionLine__c×1, HPEAPRequest__c×1 |
| `Travel_Ap` | PB | `TravelApproval__c` | onAllChanges | 49.0 | 16 | No | Worksheet__c×8, TravelApproval__c×2 |
| `LicenseSubProcessAssociatedLicense` | Invocable PB | `License__c` | invoked | 49.0 | 15 | No | AssociatedLicense__c×5 |
| `RequisitionImmediateActions` | PB | `Requisition__c` | onAllChanges | 49.0 | 15 | No | Requisition__c×2 |
| `ApplicationSubProcessTransactionInvocable` | Invocable PB | `Application__c` | invoked | 50.0 | 12 | No | Task×2, Transaction__c×1, Application__c×1 |
| `Notification_Process` | PB | `Notification__c` | onAllChanges | 49.0 | 12 | No | Task×3, Application__c×2, License__c×1 |
| `PreLicenseCEEnrollmentImmediateActions` | PB | `PrelicenseCEEnrollment__c` | onAllChanges | 53.0 | 12 | No | Earned_Continuing_Education__c×2, PrelicenseCEEnrollment__c×2, Earned_Prelicense__c×1 |
| `ApplicationRequirementProcesses` | PB | `ApplicationRequirement__c` | onAllChanges | 49.0 | 11 | No | ApplicationRequirement__c×3, Task×1 |
| `AssociatedLicenseProcesses` | PB | `AssociatedLicense__c` | onAllChanges | 49.0 | 11 | No | License__c×5 |
| `Associated_Account_Immediate_Actions` | PB | `Associated_Account__c` | onAllChanges | 53.0 | 10 | No | License__c×2 |
| `Payment_PVL_Bulk_Data_Subscription` | PB | `pymt__PaymentX__c` | onAllChanges | 51.0 | 10 | No | pymt__PaymentX__c×1 |
| `LicenseClassificationImmediateActions` | PB | `LicenseClassification__c` | onAllChanges | 49.0 | 9 | No | LicenseClassification__c×3, License__c×1 |
| `ApplicationClassificationProcesses` | PB | `ApplicationClassifications__c` | onAllChanges | 49.0 | 8 | No | ApplicationClassifications__c×2 |
| `InvestigationImmediateActions` | PB | `Investigation__c` | onAllChanges | 49.0 | 8 | No | Investigation__c×2 |
| `Terminal_Payments_to_Payments` | PB | `cterminal__Terminal_Payment__c` | onAllChanges | 49.0 | 8 | No | pymt__PaymentX__c×4 |
| `FilingSubProcessStalledFiling` | Invocable PB | `Filing__c` | invoked | 49.0 | 7 | No | Filing__c×1 |
| `File_Detail_Processes` | PB | `FileDetails__c` | onAllChanges | 53.0 | 6 | No | FileDetails__c×3 |
| `LicenseRequirementProcesses` | PB | `LicenseRequirements__c` | onAllChanges | 49.0 | 6 | No | LicenseRequirements__c×2 |
| `Course_Immediate_Actions` | PB | `Course__c` | onAllChanges | 49.0 | 5 | No | PrelicenseCEEnrollment__c×1, Course__c×1 |
| `ExamResultsProcesses` | PB | `ExamResults__c` | onAllChanges | 49.0 | 5 | No | ExamsRequired__c×1, Application__c×1 |
| `HPEAPRequestConsolidatedProcessBuilderforHPEAPRequestObject` | PB | `HPEAPRequest__c` | onAllChanges | 49.0 | 5 | No | Transaction__c×1 |
| `LicenseTypeImmediateActions` | PB | `LicenseType__c` | onAllChanges | 49.0 | 4 | No | LicenseType__c×2 |
| `PVL_Portal_User_Immediate_Actions` | PB | `PVL_Portal_User__c` | onAllChanges | 52.0 | 4 | No | Application__c×1, License__c×1 |
| `SEBCaseTeam_ImmediateActions` | PB | `SEBCaseTeam__c` | onAllChanges | 49.0 | 4 | No | SEBCaseTeam__c×2 |
| `TaskImmediateActions` | PB | `Task` | onAllChanges | 49.0 | 4 | No |  |
| `Deposit_Immediate_Actions` | PB | `Deposits__c` | onAllChanges | 52.0 | 3 | No | Deposits__c×1 |
| `RICOReferralImmediateActions` | PB | `RICOReferral__c` | onAllChanges | 49.0 | 3 | No |  |
| `SEBCaseContact_ImmediateActions` | PB | `SEBCaseContact__c` | onAllChanges | 49.0 | 3 | No |  |
| `TransactionHPEAPProcessBuilder` | PB | `Transaction__c` | onCreateOnly | 49.0 | 3 | No | TransactionLine__c×1 |
| `CertificationRequestImmediateActions` | PB | `CertificateRequest__c` | onCreateOnly | 50.0 | 2 | No | Transaction__c×1 |
| `InsuranceBondHandler` | PB | `InsuranceBond__c` | onAllChanges | 49.0 | 2 | Yes | InsuranceBond__c×1 |
| `InsurancePortalSubmissionImmediateActions` | PB | `InsurancePortalSubmission__c` | onAllChanges | 50.0 | 2 | No |  |
| `SEB_Case_Number_Immediate_Actions` | PB | `SEBCaseNumber__c` | onAllChanges | 51.0 | 2 | No | SEBCase__c×1 |
| `Worksheet_Processes` | PB | `Worksheet__c` | onAllChanges | 49.0 | 2 | No | Worksheet__c×1 |

**Active Workflow Rules (1):** `workflows/Account.workflow-meta.xml` → `Account%3ASetSEBSECFlag` (onCreateOnly, criteria on `User.ProfileId`, action FieldUpdate `AccounSetSEBSECFlag`). All other 16 workflow files hold only email alerts or field updates used by approval processes and PBs (52 alerts and 16 field updates in total). Inactive rules: `Contact` (1) and `Lead` (1).

### A1b. Draft/Obsolete flows still in source (33)

| Flow | processType | Status | flowDefinition activeVersionNumber |
|---|---|---|---|
| `BREG_Annual_Notifications` | AutoLaunchedFlow | Draft | — |
| `BREG_Case_Annual_Auto_Approval` | AutoLaunchedFlow | Draft | — |
| `BREG_Email_Logs` | Flow | Draft | — |
| `BREG_Schedule_notification_sending` | AutoLaunchedFlow | Draft | — |
| `BREG_Scheduled_field_update` | AutoLaunchedFlow | Draft | — |
| `DFIRegistrationProcesses` | Workflow | Draft | — |
| `Filing` | AutoLaunchedFlow | Draft | — |
| `LicenseNotificationEmailUpdate` | AutoLaunchedFlow | Draft | 1 (mismatch) |
| `License_Update_Employer_Address` | AutoLaunchedFlow | Draft | — |
| `PVL_Process_Flow` | AutoLaunchedFlow | Draft | — |
| `Payment_Test` | Workflow | Draft | — |
| `Payment_Test_AC` | Workflow | Draft | — |
| `SEBCaseContact_UpdateName` | AutoLaunchedFlow | Draft | 1 (mismatch) |
| `ApplicationLog_IMLCC_Integration_Error` | AutoLaunchedFlow | Obsolete | — |
| `ApplicationRNEW_RSTRHandler` | Workflow | Obsolete | — |
| `Application_Phase_X_Required_Validation` | AutoLaunchedFlow | Obsolete | — |
| `BREG_Account_Validation_Rules` | AutoLaunchedFlow | Obsolete | — |
| `BREG_TNTMSM_Expire` | AutoLaunchedFlow | Obsolete | — |
| `DO_Referral_Added_to_Case_Team_Email` | AutoLaunchedFlow | Obsolete | 1 (mismatch) |
| `DepositSetStatustoCarryOverforNegativeDeposits` | Workflow | Obsolete | — |
| `Exam_Required_EASLA_Requirement_Process` | AutoLaunchedFlow | Obsolete | — |
| `Exam_Requirements_PDG_Board` | AutoLaunchedFlow | Obsolete | — |
| `License_Name_Immediate_Actions` | Workflow | Obsolete | — |
| `PaymentSetFeeScheduleandDepositonCompletedRefunds` | Workflow | Obsolete | — |
| `PaymentSetPaymentTypeonRefunds` | Workflow | Obsolete | — |
| `PaymentSetPaymentonTransactionLines` | Workflow | Obsolete | — |
| `PaymentSetTransactionFeesonCompletedCreditCardPayments` | Workflow | Obsolete | — |
| `PaymentVoidedStatusUpdate` | Workflow | Obsolete | — |
| `Payment_Status_to_Void` | AutoLaunchedFlow | Obsolete | — |
| `TransactionLineSetRefundAmount` | Workflow | Obsolete | — |
| `TransactionLineSetRefundReqDatetoToday` | Workflow | Obsolete | — |
| `Transaction_Line_Request_Refund` | AutoLaunchedFlow | Obsolete | — |
| `Work_Item_Update_Record_on_Create` | AutoLaunchedFlow | Obsolete | 7 (mismatch) |

### A2. Largest flows (by element count)

| # | Flow | Type | Status | API | Elements | Decisions | Object |
|---|---|---|---|---|---|---|---|
| 1 | `ApplicationProcesses` | Workflow | Active | 52.0 | 203 | 107 | Application__c |
| 2 | `LicenseImmediateActions` | Workflow | Active | 52.0 | 141 | 79 | License__c |
| 3 | `ApplicationRenewalDependencyCheck` | AutoLaunchedFlow | Active | 52.0 | 95 | 47 | — |
| 4 | `AccountUploadBatchTransactions` | Flow | Active | 49.0 | 78 | 20 | — |
| 5 | `FilingImmediateActions` | Workflow | Active | 53.0 | 76 | 39 | Filing__c |
| 6 | `Application_Nursing_Renewal` | AutoLaunchedFlow | Active | 57.0 | 57 | 23 | — |
| 7 | `LicenseSubProcessNotifications` | InvocableProcess | Active | 49.0 | 56 | 19 | License__c |
| 8 | `ApplicationSubProcessNotifications` | InvocableProcess | Active | 49.0 | 55 | 16 | Application__c |
| 9 | `Application_Public_Accountancy_Renewal` | AutoLaunchedFlow | Active | 58.0 | 54 | 16 | — |
| 10 | `express_change_broker` | AutoLaunchedFlow/RecordAfterSave | Active | 63.0 | 52 | 3 | PVL_Express_Change_Broker_Form__c |
| 11 | `TransactionGroupTransactions` | Flow | Active | 49.0 | 51 | 20 | — |
| 12 | `BREG_Notification_Sending` | AutoLaunchedFlow | Active | 64.0 | 49 | 11 | — |
| 13 | `Application_Hawaii_Medical_Board_Renewal` | AutoLaunchedFlow | Active | 58.0 | 48 | 14 | — |
| 14 | `Work_Item_Sub_flow_Transfer_work_item` | AutoLaunchedFlow | Active | 65.0 | 47 | 12 | — |
| 15 | `Payment_Status_to_BCF_or_Chargeback` | AutoLaunchedFlow/RecordAfterSave | Active | 62.0 | 46 | 8 | pymt__PaymentX__c |

### A3. DML / SOQL / subflow / email actions inside flow loops (active flows)

| Flow | Type | Loop element | In-loop elements (type → object/action) |
|---|---|---|---|
| `AccountUploadBatchTransactions` | Flow | `LoopCashierCodes` | `LookupCashierCode` (Lookups → CashierCode__c); `LookupFeeCode` (Lookups → CashierCode__c) |
| `AccountUploadBatchTransactions` | Flow | `LoopCreationofCashierCodes` | `CreateTransactionLine` (Creates → TransactionLine__c) |
| `AccountUploadBatchTransactions` | Flow | `LoopFeeCodeColl` | `LookupFeeCode` (Lookups → CashierCode__c) |
| `Application_Pharamcy_Renewal` | AutoLaunchedFlow | `Loop_Associated_PHY_Licenses` | `Create_License_History1` (subflow → Create_License_History); `Query_Application1` (Lookups → Application__c); `Query_License_History2` (Lookups → LicenseHistory__c); `Renew_Application2` (Updates → Application__c); `Renew_License2` (Updates → License__c) |
| `Application_Public_Accountancy_Renewal` | AutoLaunchedFlow | `Loop_through_all_associated_CPA` | `Create_License_History2` (subflow → Create_License_History); `Create_License_History3` (subflow → Create_License_History); `Get_Associated_CPA_License` (Lookups → License__c); `Query_License_History1` (Lookups → LicenseHistory__c); `Query_License_History_for_FPTP` (Lookups → LicenseHistory__c); `Renew_Application2` (Updates → Application__c); `Renew_License2` (Updates → License__c); `Update_Application_to_D1` (Updates → Application__c); `Update_License2` (Updates → License__c) |
| `Application_Public_Accountancy_Renewal` | AutoLaunchedFlow | `Loop_through_all_associated_licenses` | `Get_Application` (Lookups → Application__c); `Renew_Application` (Updates → Application__c); `Renew_License` (Updates → License__c) |
| `Application_REAC_Process` | AutoLaunchedFlow/RecordAfterSave | `Loop_through_Current_Associated_Licenses` | `Update_Each_Associated_License` (Updates → AssociatedLicense__c) |
| `Application_Set_Exam_Eligible_Start_Date` | AutoLaunchedFlow/RecordAfterSave | `Loop_through_exams_required_records` | `Update_Exam_Start_Date` (Updates → ExamsRequired__c) |
| `BREG_Notification_Sending` | AutoLaunchedFlow | `Look_for_related_annuals` | `Send_14_days_Annual_reminder` (action → emailSimple); `Send_Early_Annual_reminder` (action → emailSimple) |
| `BREG_Notification_Sending` | AutoLaunchedFlow | `Loop_for_Annual_notifications` | `Send_14_days_Annual_reminder` (action → emailSimple); `Send_Early_Annual_reminder` (action → emailSimple) |
| `BREG_Notification_Sending` | AutoLaunchedFlow | `Loop_for_PBR_Notifications` | `Send_Publicity_Rights_Name_Notifications` (action → emailSimple) |
| `BREG_Notification_Sending` | AutoLaunchedFlow | `Loop_for_TN_Notifications` | `Send_TNTMSM_Notifications` (action → emailSimple) |
| `BREG_Transaction_notificatons` | AutoLaunchedFlow/RecordAfterSave | `Loop_for_notifications` | `Send_email_notification` (action → emailSimple) |
| `CATV_Notifications_on_Status_change` | AutoLaunchedFlow/RecordAfterSave | `Loop_Through_Contacts` | `Quote_Requested` (action → emailSimple) |
| `Case_DO_Due_Date_Reminder` | AutoLaunchedFlow/RecordAfterSave | `Loop_through_Case_Team_Assignments3` | `Send_Email_to_Divisions_1_Days_Before` (action → emailSimple) |
| `Express_Change_Broker_Email_Bouncebacks` | AutoLaunchedFlow/Scheduled | `Loop` | `Add_Log_Item` (Creates → Express_Change_Broker_History__c); `Get_Record` (Lookups → PVL_Express_Change_Broker_Form__c); `Update_Record` (Updates → PVL_Express_Change_Broker_Form__c) |
| `PaymentBCFTransactionLine` | AutoLaunchedFlow | `Loop_Child_Transaction` | `Update_Child_Transaction_Line_Paid_Status_to_BCF` (Updates → TransactionLine__c) |
| `Testing_Email_Functions` | AutoLaunchedFlow/RecordAfterSave | `Loop_Case_Team_Assignment_Records` | `Send_Email_from_DO_Team` (action → emailSimple) |
| `Testing_Email_Functions` | AutoLaunchedFlow/RecordAfterSave | `Loop_DO_Staff_Case_Team_Assignments` | `Copy_2_of_Send_Email_from_DO_Team` (action → emailSimple) |
| `TransactionGroupTransactions` | Flow | `LoopSelectedTransactions` | `UpdateRelatedTransactions` (Updates → Transaction__c) |
| `Work_Item_Sub_flow_Transfer_work_item` | AutoLaunchedFlow | `Loop_Through_Email_Users` | `Send_Email_Notification_to_Users` (action → emailSimple) |

### A3b. Apex SOQL/DML/async inside loops in automation code (hand-verified subset)

| Location | Pattern |
|---|---|
| `force-app/main/default/triggers/PVLProcessTrigger.trigger:6-263` | Per-event SOQL (66, 95, 105, 159, 171, 221), DML (57, 74, 88, 237), `Flow.Interview.start` (142, 216, 226), `enqueueJob` via PDF generators (17, 34-36), `EventBus.publish` (247), `executeBatch` (260) |
| `force-app/main/default/classes/licenseService.cls:57,69` | `Database.executeBatch` per License (called per record by `TriggerFactory`) |
| `force-app/main/default/classes/LicenseTypeHandler.cls:107-259` | 12 `Database.executeBatch` sites in per-record `beforeUpdate` |
| `force-app/main/default/classes/NotificationDomain.cls:39` | `Database.executeBatch` inside `for` over notifications |
| `force-app/main/default/classes/CertificateRequestService.cls:18` | `@future(callout=true)` per record from `afterInsert(SObject)` |
| `force-app/main/default/classes/BREGDocumentTriggerHandler.cls:83-85, 197-199` | `createWorkflowLogSafely` (insert) + `System.enqueueJob` per case/doc |
| `force-app/main/default/classes/BREGTransactionLineTriggerHandler.cls:117-118, 133-143` | `createWorkflowLogSafely` (insert) + `System.enqueueJob` per certificate/line |
| `force-app/main/default/classes/BREG_SendBREGEmails.cls:43`, `PVL_SendPVLEmails.cls:49`, `DraftApplicationService.cls:16` | `System.enqueueJob` inside loop (invocable/queue helpers) |
| `force-app/main/default/classes/MVRRenewal.cls:40,82,139,164,301` | SOQL + DML inside loops (renewal helper invoked from `ApplicationRenewalDependencyCheck`) |
| `force-app/main/default/classes/BREGCaseStatusHandlerTNTMSMAssignment.cls:64`, `BREGCaseStatusHandlerMerger.cls:328` | SOQL / DML inside loop in Case status handlers |
| `force-app/main/default/classes/ApplicationDocCreateController.cls:27-35` | insert + SOQL + insert per iteration (screen flow `GeneratePDF` action) |
| `force-app/main/default/classes/PVL_PDFGenerator.cls:42,215,283`, `DocGeneratorDataSourceDomain.cls:52,80,87,110` | `Database.query` inside loops (document generation) |
| `force-app/main/default/classes/ReconciliationBatchJob.cls:274` | SOQL per ContentVersion inside loop |
| `force-app/main/default/classes/GeneratePicklistOptionsCont.cls:63,69` | insert inside loop |


### A4. Async job inventory (Batch / Queueable / Schedulable / @future)

Counts: 89 Batchable, 18 Queueable, 59 Schedulable, 32 `@future` methods in 28 classes. "Launched by" lists non-test classes that call `new <Class>(`. "—" means the job is presumably scheduled by hand in Setup.

| Class | Interfaces | @future methods | Launched/scheduled by (non-test refs) | Hard-coded cron in code | Chains in finish/execute | finish() body |
|---|---|---|---|---|---|---|
| `AMDInactivationBatch` | Batchable, Stateful | — | `licenseService`, `AMDInactivationLetterNoticeController`, `AMDRenewalPushThru` | — | — | empty |
| `ApplicationBatchJob` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `ApplicationClassificationsService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `ApplicationRenewalPushThru` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `ApplicationService` | — | 2 | — (UI/anonymous scheduling) | — | — | n/a |
| `AssociatedInsuranceSuspenseBatch` | Batchable, Stateful | — | `InsuranceSuspenseBatch` | — | — | empty |
| `AssociatedLicenseExpire` | Batchable, Stateful | — | `LicenseExpire` | — | — | empty |
| `AssociatedLicensesStatusUpdate` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `AsyncCompletePaymentsDeposit` | Batchable, Stateful | — | `CompletePaymentsDeposit` | — | Yes | has logic |
| `BREGAccountStatus2DissolutionBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `BREGAgentSearchBatch` | Batchable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `BREGAmazonSesQueueable` | Queueable, AllowsCallouts | — | `BREGTaskTriggerHandler` | — | Yes | n/a |
| `BREGAnnualRobot` | Queueable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGAnnualRobotValidationBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGAnnualRollOverJob` | Batchable, Stateful | — | `BREGAnnualRollOverSchedulable` | — | — | has logic |
| `BREGAnnualRollOverSchedulable` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGBackfillAccountFormLabelBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGBackfillCaseLabelBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGBatch` | Batchable, Stateful, AllowsCallouts | — | `BREGBatchScheduler` | — | — | has logic |
| `BREGBatchScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGBouncedCheckScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGCaseDefaultOwnerReassignment` | Queueable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGCaseHistoryBatch` | Batchable, Stateful | — | `BREGBouncedCheckScheduler` | — | Yes | has logic |
| `BREGCaseStatusHandlerBase` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGDBEDTReportScheduler` | Schedulable | — | — (UI/anonymous scheduling) | 0 55 23 L * ? | — | n/a |
| `BREGDelinquencyStatusUpdateBatchJob` | Batchable, Stateful | — | `BREGDelinquencyBatchController` | — | — | has logic |
| `BREGDocumentPublicVisibilityBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGDocusignTemplatesUpdateBatch` | Batchable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGEntityListBuilderBatch` | Batchable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `BREGR7ExpirationBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREGRunFlowScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGStartDocusignWorkflow` | Queueable, AllowsCallouts | — | `BREGDocumentTriggerHandler`, `BREGEntityListBuilderBatch`, `BREGExternalAPIUploadScannedDocument`, `BREGEntityListWeeklyJob`, `BREGTransactionLineTriggerHandler`, `BREGDelinquencyStatusUpdateBatchJob`, `BREGAgentSearchBatch`, `BREGCaseTriggerHandler` | — | Yes | n/a |
| `BREGStartDocusignWorkflowBatch` | Batchable, Stateful, AllowsCallouts | — | `BREGStartDocusignWorkflowQueuable` | — | — | has logic |
| `BREGStartDocusignWorkflowQueuable` | Queueable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BREGTNTMSMExpirationBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `BREG_SendBREGEmails` | Queueable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | n/a |
| `BatchChargeBack` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `BatchFlagLicenseBeforeAudit` | Batchable, Schedulable, Stateful | — | `LicenseTypeHandler`, `LicenseTypeBatchJobsController`, `BatchFlagMultipleLicenseForAudit` | — | Yes | has logic |
| `BatchFlagLicenseForAudit` | Batchable, Schedulable, Stateful | — | `BatchFlagLicenseBeforeAudit` | — | Yes | has logic |
| `BatchLicenseResetAudit` | Batchable, Stateful | — | `LicenseTypeHandler` | — | — | has logic |
| `BatchUpdateActiveEmployeeLicenseNum` | Batchable, Stateful | — | `RealEstateRenewalBatch`, `InsurancePortalSubmissionBatch`, `licenseService` | — | — | empty |
| `CATV_AccessRequestController` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CATV_InetTriggerHandler` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CATV_RegistrationHandler` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CATV_SelfRegistrationController` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CATV_UserTriggerHandler` | — | 2 | — (UI/anonymous scheduling) | — | — | n/a |
| `CaseTeamMemberService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CertificateRequestService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `CleanRenewApplicationJob` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `ClearAuditInformation` | Batchable, Stateful | — | `LicenseTypeHandler` | — | — | has logic |
| `ContractorRenewalPushThrough` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `CourseStatusUpdateBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `CtEntitySolePrmePushThroughBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `CtRmePushThroughBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `CustomLogger` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `D1D2DependencyRefundNotice` | Batchable, Schedulable, Stateful, AllowsCallouts | — | `D1D2DependencyRefundController` | — | — | has logic |
| `DCCAFeeScheduleBatch` | Batchable, Stateful | — | `PaymentXBatch` | — | — | empty |
| `DeleteUnPaidAppsBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `DepositRollupsBatch` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | 0 10 * * * ? | — | empty |
| `DocuSignAPI` | — | 2 | — (UI/anonymous scheduling) | — | — | n/a |
| `DocumentGeneratorProcessBatch` | Batchable, Stateful, AllowsCallouts | — | `BatchFlagLicenseForAudit`, `NotificationDomain` | — | — | has logic |
| `DocusignStatusService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `DraftApplicationService` | Queueable, AllowsCallouts | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `EmployeeLicenseStatus` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `FileDetailCreatorController` | Queueable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | Yes | n/a |
| `FileDetailDomain` | — | 1 | `FileDetailHandler`, `FileDetailService`, `ExamSharer` | — | — | n/a |
| `FileDetailService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `FixRequirementBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `ForfeitureLicense` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `GenerateListBuilderPayment` | Batchable, Schedulable, Stateful | — | `GenerateListBuilderPaymentDaily` | — | — | empty |
| `GenerateListBuilderPaymentDaily` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `GeneratePostCardBatch` | Batchable, Stateful, AllowsCallouts | — | `LicenseTypeHandler`, `licenseService` | — | — | has logic |
| `GenerateRenewalApplicationBatch` | Batchable, Stateful, AllowsCallouts | — | `ApplicationService`, `PVLProcessTrigger` | — | — | empty |
| `GenerateRenewalNotificationBatch` | Batchable, Stateful, AllowsCallouts | — | `LicenseTypeHandler`, `licenseService`, `BatchFlagLicenseForAudit` | — | — | has logic |
| `GenerateSubscriberPayment` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `GenericCreatePaymentCtrl` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `IMLCCBatchJob` | Schedulable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | n/a |
| `IMLCCPushBatchJob` | Schedulable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | n/a |
| `IMLCCQueueable` | Queueable, AllowsCallouts | — | `IMLCCBatchJob`, `IMLCCPushBatchJob` | — | Yes | n/a |
| `IMLCCSendEmailQueueable` | Queueable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `InsuranceNotificationBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `InsurancePortalSubmissionBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `InsuranceStatusBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `InsuranceSuspenseBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `InvestigationCallsBatch` | Batchable, Stateful, AllowsCallouts | — | `InvestigationCallsController` | — | — | empty |
| `InvestigationNotesBatch` | Batchable, Stateful, AllowsCallouts | — | `InvestigationNotesController` | — | — | empty |
| `LicenseConditionOverdueFinderScheduler` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `LicenseCurrentAndValidFinderScheduler` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `LicenseEmployerAddressUpdateBatch` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `LicenseExpire` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `LicenseMassScannerController` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `LicenseRMELoseBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `LicenseTermination` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | has logic |
| `LicenseTypeBatchUpdateLicense` | Batchable, Stateful | — | `LicenseTypeHandler` | — | — | has logic |
| `LicenseTypeExpire` | Batchable, Schedulable | — | `LicenseTypeHandler` | — | — | empty |
| `LicenseTypeRenewalEmailSender` | Batchable | — | `LicenseTypeHandler` | — | — | has logic |
| `MVRRenewalPushThruBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `NotificationDeletionBatch` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `NotificationFileAttachDeletionBatch` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `PVLAppStatusSnapshotRefreshScheduler` | Schedulable | — | — (UI/anonymous scheduling) | 0 30 8 * * ? | — | n/a |
| `PVLApplicationStatusSnapshotRefreshBatch` | Batchable | — | `PVLAppStatusSnapshotRefreshScheduler` | — | — | empty |
| `PVLErrorHandlerBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `PVLRenewApp` | Queueable | — | — (UI/anonymous scheduling) | — | Yes | n/a |
| `PVL_ListBuilderFileDeletionBatchJob` | Batchable, Schedulable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | has logic |
| `PVL_ListBuilderFileGenerationBatchJob` | Batchable, Schedulable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | has logic |
| `PVL_MassEmailBatch` | Batchable, Stateful | — | `PVL_MassEmailController` | — | — | has logic |
| `PVL_PDFGenerator` | Queueable, AllowsCallouts | 1 | — (UI/anonymous scheduling) | — | Yes | n/a |
| `PVL_SendPVLEmails` | Queueable, AllowsCallouts | 1 | — (UI/anonymous scheduling) | — | Yes | n/a |
| `PVL_VFPDFGenerator` | Queueable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | Yes | n/a |
| `PaymentAdjustmentBatchJob` | Batchable, Stateful | — | `PaymentAdjustmentController`, `RunReconciliationBatchController` | — | — | has logic |
| `PaymentAllocateTransactionLinesBatch` | Batchable, Schedulable | — | `PaymentAllocateBatchProgress`, `PaymentAllHandler` | 0 0 * * * ?, 0 10 * * * ?, 0 15 * * * ?, 0 20 * * * ?, 0 25 * * * ?, 0 30 * * * ?, 0 35 * * * ?, 0 40 * * * ?, 0 45 * * * ?, 0 5 * * * ?, 0 50 * * * ?, 0 55 * * * ? | — | empty |
| `PaymentAutoCloserBatch` | Batchable | — | `PaymentAutoCloserMonitorController`, `PaymentAutoCloserScheduler` | — | — | empty |
| `PaymentAutoCloserScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `PaymentRecwkstCmpController` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `PaymentTerminalController` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `PaymentXBatch` | Batchable, Schedulable, Stateful | — | `PaymentXBatchScheduler`, `PaymentAllHandler`, `PaymentXBatchProgress` | 0 0 * * * ?, 0 10 * * * ?, 0 15 * * * ?, 0 20 * * * ?, 0 25 * * * ?, 0 30 * * * ?, 0 35 * * * ?, 0 40 * * * ?, 0 45 * * * ?, 0 5 * * * ?, 0 50 * * * ?, 0 55 * * * ? | Yes | has logic |
| `PaymentXBatchScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `PersonAccountInvalidAddressFinder` | Batchable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `PublicGroupMembershipBatch` | Batchable, AllowsCallouts | — | — (UI/anonymous scheduling) | — | — | empty |
| `PublicGroupMembershipScheduled` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `QualCallSessionQueueable` | Queueable, AllowsCallouts | — | `QualUjetSessionTriggerHandler`, `QualRetrySchedulable` | — | Yes | n/a |
| `QualCalloutQueueable` | Queueable, AllowsCallouts | — | `QualCaseTriggerHandler`, `QualRetrySchedulable` | — | Yes | n/a |
| `QualRetrySchedulable` | Schedulable | — | — (UI/anonymous scheduling) | 0 0 * * * ? | — | n/a |
| `RBEntityPrincipalBrokerSuspenseBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | 0 0 0 * * ? | — | has logic |
| `RboRenewalDependency` | Queueable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `RealEstateLicensesInactivatorBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | has logic |
| `RealEstateRenewalBatch` | Batchable, Stateful | — | `RealEstateRenewal` | — | Yes | has logic |
| `ReconciliationBatchJob` | Batchable, Schedulable, Stateful | — | `PVL_ListBuilderFileDeletionBatchJob`, `PaymentCutOffBatchController`, `RunReconciliationBatchController` | — | — | has logic |
| `RollingLicenseExpiredStatusBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | 0 0 1 * * ? | — | has logic |
| `SEBCasePenaltyBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `ScheduledClearEarnedCEBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | — | — | empty |
| `ScheduledGenerateFiles` | Batchable, Schedulable, Stateful, AllowsCallouts | — | — (UI/anonymous scheduling) | — | Yes | has logic |
| `SendLetterToPrinterBatchJob` | Batchable, Schedulable, Stateful | — | `ScheduledGenerateFiles` | — | — | empty |
| `SpringCMConnector` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `SpringCMFileHelper` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `SpringCMRestHelper` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `SuspenseDeletionBatchJob` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | — | — | empty |
| `SuspenseDueDateProcessingBatch` | Batchable, Schedulable, Stateful | — | — (UI/anonymous scheduling) | 0 30 0 * * ? | — | has logic |
| `TaxClearanceCheckBatch` | Batchable, Stateful, AllowsCallouts | — | `LicenseTypeHandler` | — | — | has logic |
| `UploadCaseFileToDocSignQueueable` | Queueable, AllowsCallouts | 1 | `ContentDocumentLinkHandler` | — | — | n/a |
| `VFFileService` | — | 1 | — (UI/anonymous scheduling) | — | — | n/a |
| `licenseService` | — | 2 | — (UI/anonymous scheduling) | — | — | n/a |
| `util_closer_CaseStatusBatch` | Batchable, Stateful | — | `util_closer_SchedulerController`, `util_closer_CaseStatusScheduler` | — | — | has logic |
| `util_closer_CaseStatusScheduler` | Schedulable | — | — (UI/anonymous scheduling) | — | — | n/a |
| `util_closer_LogCleanupBatch` | Batchable, Schedulable | — | — (UI/anonymous scheduling) | 0 0 3 * * ? | Yes | has logic |

### A5. Triggers without any bypass switch (37)

`ApplicationCacheTrigger`, `BREGHandlerErrorEventTrigger`, `BREGTransactionTrigger`, `CATV_InetTrigger`, `CATV_UserTrigger`, `CaseTeamAssignmentTrigger`, `CertificateRequestTrigger`, `CollectionsAllocationTrigger`, `ContentDocumentLinkTrigger`, `ContentDocumentTrigger`, `DraftApplicationTrigger`, `EarnedCETrigger`, `ExamAll`, `FileDetailTrigger`, `FilingAll`, `InvestigationAll`, `LicenseRequirementTrigger`, `LicenseTypeTrigger`, `NotificationTrigger`, `PVLErrorHandlerTrigger`, `PVLProcessTrigger`, `QualCaseTrigger`, `QualUjetSessionTrigger`, `SEBCaseAll`, `SEBCaseTeamTrigger`, `SanctionTrigger`, `StatusHistoryTrigger`, `TimeAndExpensesHeaderAll`, `TransactionAll`, `TransactionLineAll`, `TravelApprovalTrigger`, `dlrs_AllegationTrigger`, `dlrs_LegalActionTrigger`, `dlrs_TransactionTrigger`, `sc_FieldMetaDataTrigger`, `tkt_TicketCommentTrigger`, `tkt_TicketTrigger`.

Recursion guards found: `BREGBaseTriggerHandler` (per handler and operation, see W-02), `TriggerUtils.disableTrigger` (Case), `PaymentDeduplicator.disableTrigger`, `PaymentAllHandler.runPaymentXStart`, `TriggerHelper.disable*Trigger` (manual bypass flags), `QualCaseTriggerHandler.isExecuting` and `QualUjetSessionTriggerHandler.isExecuting`. The 22 `TriggerFactory` handlers have none.


### A6. After-save flows that update their own triggering record (28)

| Object | After-save flow | Trigger event | Change guard | Same-record update elements |
|---|---|---|---|---|
| `Application__c` | `ApplicationMassEmailandNotiicationUpdater` | Update | doesRequireRecordChangedToMeetCriteria | `Update_Application` |
| `Application__c` | `Application_A3_End_Time` | Update | ISCHANGED/$Record__Prior in flow | `Update_A3_End_Date`, `Update_A3_Processing_Time` |
| `Application__c` | `Application_A3_Processing_Time` | Update | ISCHANGED/$Record__Prior in flow | `Update_A3_Start_Date` |
| `Application__c` | `Application_Date_of_Licensure` | Update | ISCHANGED/$Record__Prior in flow | `Update_Date_of_Licensure` |
| `Application__c` | `Application_Default_Residence_Country` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `Update` |
| `Application__c` | `Application_New_Online_Renew_Application` | Create | n/a (Create only) | `Capture_Renewal_Address_Snapshot_Fields`, `Capture_Renewal_Mail_To_Fields`, `Update_Application` |
| `Application__c` | `Application_Process` | Create | n/a (Create only) | `UpdateApplicationWithEmptyRecordTypePlaceholder`, `UpdateApplicationWithRecordTypePlaceholder` |
| `Application__c` | `Application_Renewal_Dependency_Flow` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `Update_Application1` |
| `Case` | `BREG_Case_Owner_Reassignment` | Update | ISCHANGED/$Record__Prior in flow | `Update_owner_for_child_cases` |
| `Case` | `BREG_Case_Set_Bypass_Status_Change_Validation` | CreateAndUpdate | doesRequireRecordChangedToMeetCriteria | `Update_Case` |
| `Case` | `BREG_Case_Status_Approved` | CreateAndUpdate | doesRequireRecordChangedToMeetCriteria | `Update_Case` |
| `Case` | `Case_Flow_on_Create` | Create | n/a (Create only) | `Update_Case_Record_Type` |
| `Case` | `Case_on_Create_Email_Support_Case` | Create | n/a (Create only) | `Update_Incoming_Division` |
| `Case` | `DO_Referral_Case_Close_Case_Status` | Update | **none** | `Update_DO_Referral_Case` |
| `Case` | `Update_Parent_Case_to_Withdrawn_for_WD_Child_Case` | CreateAndUpdate | doesRequireRecordChangedToMeetCriteria | `Update_WD_Case`, `Update_WD_case_status` |
| `EnforcementActionDocument__c` | `Enforcement_Action_Document_Get_Public_URL` | CreateAndUpdate | doesRequireRecordChangedToMeetCriteria | `Save_Sharelink` |
| `ExamsRequired__c` | `Application_Classification_Sync_Exam_Status` | Create | n/a (Create only) | `Update_Exam_Status` |
| `ExamsRequired__c` | `Exams_Required_Set_Exams_Eligible_End_Date` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `Update_Exam_Eligible_End_Date`, `Update_Exam_Eligible_End_Date1` |
| `ExamsRequired__c` | `Exams_Required_Validation` | CreateAndUpdate | **none** | `Update_Prevent_Save_Field` |
| `INET_Request__c` | `CATV_Notifications_on_Status_change` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `Update_the_Status_and_Quote_Subtype`, `Update_the_Work_Start_Date`, `Updated_the_status_to_Assign_back` |
| `License__c` | `License_Inactivation_Flow` | Update | doesRequireRecordChangedToMeetCriteria | `Reset`, `ResetRecord`, `Update_Forfeiture_Date`, `Update_License`, `Update_License2`, `Update_License3` |
| `License__c` | `License_Upgrade_RS` | Create | n/a (Create only) | `Upgrade_RS` |
| `PVL_Express_Change_Broker_Form__c` | `express_change_broker` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `move_to_step_1`, `move_to_step_2`, `sync_update_rb_force`, `update_agent_canceled`, `update_cancel_request_nb_denied`, `update_complete_request`, `update_nb_canceled`, `update_step_3`, `update_step_4`, `update_step_5`, `update_verification_sent` |
| `PaymentReconciliation__c` | `Payment_Reconciliation_Send_Refund_Notice_Email` | Update | ISCHANGED/$Record__Prior in flow | `Update_Refund_Date` |
| `SEBCase__c` | `BREG_Case_Creation_Automation` | Create | n/a (Create only) | `Update_SEB_Case` |
| `TravelApproval__c` | `Travel_Approval_Update_UpdatedReturnDateField` | CreateAndUpdate | ISCHANGED/$Record__Prior in flow | `Update_UpdatedReturnDateField` |
| `UJET__UJET_Session__c` | `UJET_Session_On_Create` | Create | n/a (Create only) | `Update_Call_Input_Field` |
| `breg_Annual__c` | `BREG_Annual_Transaction_Creation` | Create | n/a (Create only) | `Update_Transaction_Lookup` |

### A7. Hard-coded record IDs in active flows

| Flow | Element | Field | ID(s) |
|---|---|---|---|
| `Account_Set_Contact_on_Person_Account` (PB) | `myRule_19_A1`, `myRule_23_A1` | `PVL_License_Type__c` | 150 × `a2xt00000011…` (comma list) |
| `ApplicationPVLRenewalPermitToPracticeFeeHelper` | constants `x005CashierCodeId`, `x011CashierCodeId` | — | `a0St0000001mS1bEAE`, `a0St0000001LMooEAG` |
| `PVL_Renewal_PermitToPractoce_Subflow` | constants `x005CashierCodeId`, `x011CashierCodeId` | — | `a0St0000001mS1bEAE`, `a0St0000001LMooEAG` |
| `Application_New_Task_for_Portal_Update` | formula `IntegrationUserOwnerID`; formula `ContactId` | OwnerId / RecordType compare | `005t00000022GqIAAU`, `012t0000000PLy1AAG` |
| `BREG_TNTMSM_Expire_Now` | `Get_Permissions_of_the_current_user` | `PermissionSetId` | `0PScq000000KU3b` |
| `HPEAPRequestConsolidatedProcessBuilderforHPEAPRequestObject` (PB) | `myRule_1_A1` | `Account__c`, `Contact__c` | `001t000000IZXZw`, `003t000000NEiaZ` |
| `PaymentImmediateActions` (PB) | `myRule_35_A1` | `pymt__Contact__c` | `003t000000d3b4nAAA` |
| `SEBCaseImmediateActions` (PB) | `myRule_3_A1`, `myRule_22_A1` | `OwnerId` | `00Gt0000000ynQyEAI` |
| `TransactionHPEAPProcessBuilder` (PB) | `myRule_1_A1` | `CashierCode__c` | `a0St0000000llsD` |
| `TransactionPVLProcessBuilder` (PB) | `myRule_14_A1` | `CashierCode__c` | `a0St0000001LMoQEAW` |
| `Update_Payment_Owner` (before-save) | `Check_on_Terminal_Payment_Device_Id`, `Get_User_Susan_Kanda`, `Get_User_Rebecca_Bolosan` | terminal URN → user `Name` | `urn:tid:3689660a-…`, `urn:tid:84381c9c-…` |

### A8. Method notes and limitations
- The loop-reachability analysis treats nested loops as part of the outer loop body. Screen flows are included because each screen round-trip is a separate transaction, so loops inside one screen step still share limits.
- The Apex loop scan is heuristic (brace matching after comment and string stripping). It does not follow calls across methods, so per-record `TriggerFactory` dispatch was reviewed separately (see W-06). SOQL `for (x : [SELECT…])` headers are not counted.
- Process Builder object and trigger type come from `processMetadataValues` (`ObjectType`, `TriggerType`). Invocable PBs are counted under the object in `ObjectType`.
- The org's actual active flow versions, scheduled-job list (`CronTrigger`) and platform-event subscriber batch size were not checked. Several confidence labels depend on those runtime facts.

