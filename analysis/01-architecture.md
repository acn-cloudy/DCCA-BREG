# 01 — Architecture & Domain Model

Scope: `force-app/main/default/` (classes, triggers, flows, lwc, aura, pages, components, objects, permissionsets/profiles for access checks). `.sf/`, `.sfdx/` and `dcca-review-plan.html` were not analysed. All paths below are relative to repo root; `classes/` = `force-app/main/default/classes/`, `triggers/` = `force-app/main/default/triggers/`, etc.

Method: counts come from Perl scripts over the source tree. Class-to-class references come from identifier matching with comments and string literals removed. Test classes are files whose name contains "test" or that contain `@isTest`. Findings were confirmed by reading the files. Where static analysis cannot see a dependency (Custom Metadata records, anonymous Apex, scheduled jobs in the org), the finding is marked **Unverified**.

## Summary

- **The codebase is several products sharing one org.** It has at least 16 bounded contexts. The two largest are **BREG** (Business Registration: 152 production classes, 43.8k LOC) and **PVL** (Professional & Vocational Licensing: core, renewals, payments, docs; ~366 production classes, ~46k LOC). Most contexts are loosely coupled at the class level: Qualtrics (`Qual*`), `util_closer_*`, `tkt_*` and CATV have almost no dependencies on other contexts. The real coupling is through **shared objects**: Case, Account, `Transaction__c`, `TransactionLine__c` and `pymt__PaymentX__c`.
- **Critical: an OAuth bearer token for DocuSign CLM (SpringCM) is sent to the browser.** `SpringCMConnector.getToken()` is `@AuraEnabled` and returns the org-wide CLM access token. The `springFiles` LWC uses it. The class is enabled for the BREG community profile and the external CATV permission sets.
- **Critical: the recursion guards run each handler only once per transaction.** The BREG trigger framework, and a static flag in `BREGCaseTrigger`, skip all later trigger runs in the same transaction. That includes the second 200-record chunk of a bulk DML. The flag has already needed a Flow workaround and manual resets, which shows it has caused problems.
- **Trigger architecture is fragmented.** There are 5 trigger frameworks plus inline logic, and 7 separate bypass mechanisms. 6 objects have more than one trigger (`pymt__PaymentX__c` has 3). Case has 2 triggers plus 24 active record-triggered flows, and `Application__c` has 1 trigger plus 15.
- **The layering pattern is applied consistently only in PVL.** The Domain/Handler/Service/Selector pattern covers the ~23 objects routed through `TriggerFactory`. BREG uses fat Handler and Utils classes instead. Across the org, 80 of 128 controllers run SOQL or DML directly, and only 149 of 1,441 SOQL statements live in Selector classes.
- **There are large god classes.** 5 controllers exceed 1,000 lines, and the largest non-vendor class is 2,288 lines (`BREGCaseStatusHandlerBase`). Most of these are `without sharing` and `@AuraEnabled`, and they serve portal users.
- **There are 3 separate clients for the same external system (DocuSign CLM / SpringCM).** One of them hard-codes a **UAT** endpoint in production code.
- **There is notable dead or legacy weight.** It includes an active no-op trigger, fully commented-out classes, about 28 unreferenced classes, a vendored fflib library (21k LOC including tests) used by only about 17 classes, and API versions from v31 to v66.

| Severity | Count |
|---|---|
| Critical | 2 |
| High | 8 |
| Medium | 6 |
| Low | 2 |
| **Total** | **18** |

## Context Map

Class counts are split into production and test classes. LOC is physical lines (`wc -l` equivalent). Contexts were assigned by class-name prefix or keyword rules; the rules are in the Appendix.

| Context | Prod classes | Prod LOC | Test classes | Test LOC | Key objects owned / written | Notes |
|---|---|---|---|---|---|---|
| BREG (Business Registration) | 152 | 43,798 | 148 | 47,513 | `breg_*__c` (≈40 objects incl. `breg_Transaction__c`, `breg_Annual__c`, `breg_TN_TM_SM__c`, `breg_Document__c`, `breg_WEB_*` staging), `BREG_*__mdt`; writes **Case** (70 classes), **Account** (68), `TransactionLine__c` (15), `pymt__PaymentX__c` (7) | Own trigger framework (`BREGBaseTriggerHandler`); dynamic status handlers (`BREGCaseStatusHandler*`, 30 classes); 160 of 232 LWCs; 8 `@RestResource` APIs |
| PVL Licensing core | 185 | 22,911 | 125 | 13,310 | `Application__c`, `License__c`, `LicenseType__c`, `AssociatedLicense__c`, `ApplicationRequirement__c`, `LicenseClassification__c`, `Exam*__c`, `InsuranceBond__c`, `Suspense__c`, `Notification__c`, `Application_Cache__c`, `PVLProcess__e` | `TriggerFactory` + Domain/Handler/Service/Selector; built by PacificPoint (2019–2022 headers) |
| PVL Renewals (incl. AMD, Rb/Ct push-thru) | 48 | 7,774 | 43 | 6,091 | `Application__c`, `License__c` (36 classes) | One renewal/push-thru class per board; `BarberingCosmetologyRenewal` is used as a shared utility by 9 other boards' renewals |
| Payments & Finance | 71 | 10,953 | 63 | 7,167 | `Transaction__c`, `TransactionLine__c`, `pymt__PaymentX__c` (Linvio PaymentConnect), `CollectionsAllocation__c`, `Deposits__c`, `Reconciliation_Batch__c`, `FiscalForm__c` | Shared with BREG; 3 triggers on Payment; Oracle GL integration |
| Docs & Integrations (SpringCM/DocuSign CLM/Files) | 62 | 4,756 | 29 | 3,179 | `FileDetails__c`, `ContentDocumentLink`, `SpringCLM_Session__c`, `DocGeneratorDataSource__c` | 3 CLM client stacks; `DocuSignAPI` is functionally BREG-owned |
| Enforcement (RICO / SEB / Investigations) | 18 | 1,248 | 18 | 1,094 | `Investigation__c`, `SEBCase__c`, `SEBCaseTeam__c`, `Sanction__c`, `Filing__c`, `StatusHistory__c`, `TimeandExpenseHeader__c`, `TravelApproval__c`, `RICO*__c` | Mostly inline trigger logic; `AgeDaysSumCalculator` is dead |
| Qual (Qualtrics CX integration) | 15 | 4,710 | 15 | 11,143 | `qual_Integration_Log__c`, `qual_Config__mdt`; reads Case, `UJET__UJET_Session__c` | Self-contained; recent, well-structured; 2 lifecycle triggers |
| util_closer (Case auto-close rule engine) | 17 | 4,117 | 17 | 11,446 | `util_closer_*__c/__mdt` | Self-contained; recent |
| tkt_ (internal ticketing) | 6 | 1,901 | 7 | 4,753 | `tkt_Ticket__c`, `tkt_Ticket_Comment__c`, `tkt_*__mdt` | Self-contained; own bypass (`tkt_Trigger_Control__c`) |
| sc_ (dynamic form builder / "smart" applications) | 33 | 1,748 | 10 | 230 | `Application_Meta_Data__c`, `Card_Meta_Data__c`, `Card_Cache__c`, `Field_Meta_Data__c`, `Field_Filter__c` | Writes StaticResources at runtime via a Tooling API self-callout; duplicate domain classes (`CardCacheDomain` / `sc_CardCacheDomain`) |
| CATV (Cable TV portal) | 9 | 933 | 10 | 756 | `INET_Request__c`, `Account_Access_Request__c`; User trigger | Self-contained except one SpringCM call |
| IMLCC (Interstate Medical Licensure Compact) | 5 | 1,010 | 5 | 506 | `IMLCCSettings__c`, `Application_Log__c` | Called from `ApplicationService` |
| CaseTeam (fflib slice) | 20 | 717 | 2 | 294 | `CaseTeam__c`, `CaseTeamMember__c`, `CaseTeamAssignment__c`, `EmailAlertTrigger__c` | Only real consumer of fflib; bound via `fflibe_*__mdt` |
| Communities / Identity | 12 | 1,040 | 12 | 696 | User, Contact | Stock community controllers + custom registration |
| Shared framework & utilities | 36 | 3,063 | 21 | 1,661 | `OrgConfiguration__c`, `ProcessSwitches__c` | `TriggerFactory`, `ITrigger`, `SObjectDomain`, lookups, constants |
| Vendor: fflib (apex-common + apex-mocks + fflibe) | 41 | 10,580 | 30 | 10,502 | — | 21k LOC vendored for ~17 consumer classes |
| Vendor: dlrs | 0 | 0 | 3 | 39 | — | 3 generated rollup triggers |
| **Total** | **730** | **121,259** | **558** | **~119,100** | | 1,288 classes / 240,351 LOC |

Cross-context class dependencies (production code only; count = distinct from→to class pairs):

| From → To | Pairs | Examples |
|---|---|---|
| PVL Renewals → PVL Licensing core | 102 | `BarberingCosRenewalPushThru`→`ApplicationDomain`, `AssociatedLicenseSelector` |
| PVL Licensing core → Shared | 60 | handlers → `ITrigger`, domains → `SObjectDomain` |
| CaseTeam → fflib | 28 | `CaseTeamAssignmentDomain`→`fflib_SObjectDomain` |
| PVL Licensing core → Docs/CLM | 22 | `PVL_PDFGenerator`→`SpringCMConnector` |
| Shared → PVL Licensing core | 18 | `TriggerFactory`→every PVL handler (closed registry) |
| BREG → Docs/CLM | 13 | BREG handlers/controllers → `DocuSignAPI` |
| Payments → Docs/CLM | 9 | `TDRFormController`→`SpringCMConnector` |
| BREG → Payments | 5 | `BREGAccountTriggerHandler`→`NewTransaction`, `BREGR7ExpirationBatch`→`CreateTransaction` |
| Docs/CLM → BREG | 1 | `DocuSignAPI`→`BREGUtils` (reverse dependency) |
| CATV → Docs/CLM | 1 | `CATV_DashboardController`→`SpringCMDocument` |
| Qual, util_closer, tkt_ → anything | 0 | fully self-contained |

## Findings

### [CRITICAL] ID A-01: DocuSign CLM (SpringCM) OAuth access token exposed to browser and community users

**Evidence**
- `classes/SpringCMConnector.cls:1` is declared `public without sharing class SpringCMConnector`.
- `classes/SpringCMConnector.cls:63-68`: the `@AuraEnabled getToken()` method returns the org-wide CLM access token and persists it.
- `classes/SpringCMConnector.cls:27-50`: `initiateConnection()` performs a refresh-token grant using `SpringCLMSetting__mdt.Client_Secret__c` (line 32).
- `classes/SpringCMConnector.cls:336-345`: `saveToken()` upserts the `RefreshToken__c` and `AccessToken__c` values in plain text into `SpringCLM_Session__c`.
- `lwc/springFiles/springFiles.js:3,72,76`: the LWC imports `SpringCMConnector.getToken` and sets `Authorization: bearer <token>` in a browser XHR. The component is embedded in `aura/FileDetailCreator/FileDetailCreator.cmp:89` and `aura/CustomFileDetailUploader/CustomFileDetailUploader.cmp:19`.
- `SpringCMConnector` class access is `<enabled>true</enabled>` in `profiles/DCCA BREG - CustomerCommunityLogin.profile-meta.xml`, `permissionsets/External_CATV_Provider.permissionset-meta.xml` and `permissionsets/External_CATV_Requestor.permissionset-meta.xml`, plus about 20 internal profiles.
- `lwc/springFileFix/springFileFix.js:3` imports `SpringCMConnector.getAccessToken`, which is **not** `@AuraEnabled` (`classes/SpringCMConnector.cls:70`). That component is probably broken or fails to deploy (Unverified).

**Impact** Any authenticated user with this class access, including external community users, can call the Aura endpoint and obtain a service-account bearer token for the CLM repository. That token gives read/write/delete access to every document in CLM, not only the user's own, and bypasses all Salesforce sharing.

**Recommendation** Remove `getToken` from the client API. Proxy uploads server-side through Apex using a Named Credential or External Credential, or use short-lived, scoped pre-signed upload URLs. Rotate the CLM client secret and refresh token. Move the secret out of Custom Metadata into an External Credential. Remove class access from community profiles and permission sets. Cross-reference: Security report.

**Effort** M

### [CRITICAL] ID A-02: "Once per transaction" recursion guards silently skip BREG trigger logic

**Evidence**
- `classes/BREGBaseTriggerHandler.cls:9` sets `ALLOW_RECURSION_DEFAULT = false`.
- `classes/BREGBaseTriggerHandler.cls:13` stores run history in a static `Set<String> triggerHandlerAndOperation`.
- `classes/BREGBaseTriggerHandler.cls:172-189`: `canRun()` requires `isFirstRun()`, which is keyed only by handler name plus operation. It is not keyed by record IDs. As a result, every BREG handler except Case runs at most once per operation per transaction. The affected handlers are Account, AccountAffiliation, Document, Payment, TNTMSM, Task, Transaction, TxnBusInfo and TransactionLine (10 subclasses, see `grep 'extends BREGBaseTriggerHandler'`).
- `triggers/BREGCaseTrigger.trigger:7-12` sets `TriggerUtils.disableTrigger = true` after the first **after** event. Every later Case DML in the transaction then skips **both** before and after BREG logic, including validations.
- Workarounds already exist:
  - `classes/TriggerUtils.cls:4-10` defines an invocable "Reset Disable Trigger" action.
  - `flows/BREG_Transaction_Line_After.flow-meta.xml:25` calls that action before updating Cases.
  - `classes/BREGRegistrationFormController.cls:248` resets the flag by hand with the comment `// Enable triggers to next DML`.

**Impact** If one Apex DML touches more than 200 records, the platform processes it in 200-record chunks. With these guards, the second and later chunks, and any later DML in the same transaction from Apex, Flow or batch code, silently skip status handling, validation, file-number assignment and fee creation. The result is inconsistent BREG data with no error raised. The workaround flow shows this has already caused defects.

**Recommendation** Replace the flag-based guards with record-level idempotency. Track processed record IDs per operation, or compare old and new field values. Keep an explicit bypass API only for intentional suppression. Add bulk tests with 201+ records.

**Effort** M

### [HIGH] ID A-03: Multiple triggers per object plus heavy Flow overlay (undefined execution order)

**Evidence** 6 objects have more than one trigger:

| Object | Triggers |
|---|---|
| `pymt__PaymentX__c` | `triggers/PaymentAll.trigger`, `triggers/PaymentTrigger.trigger`, `triggers/BREGPaymentTrigger.trigger` (all active, API 43) |
| Account | `triggers/AccountTrigger.trigger` (PVL `TriggerFactory`) + `triggers/BREGAccountTrigger.trigger` (BREG framework) |
| Case | `triggers/BREGCaseTrigger.trigger` + `triggers/QualCaseTrigger.trigger` |
| `Transaction__c` | `triggers/TransactionAll.trigger` (calls both static `TransactionHandler` **and** `TriggerFactory`→`Transaction_Handler`, lines 23-40) + `triggers/dlrs_TransactionTrigger.trigger` |
| `TransactionLine__c` | `triggers/TransactionLineAll.trigger` + `triggers/BREGTransactionLineTrigger.trigger` |
| `Application_Cache__c` | `triggers/ApplicationCacheTrigger.trigger` (`TriggerFactory`→`DraftApplicationHandler`) + `triggers/DraftApplicationTrigger.trigger` (inline logic that does `update` on its own object, lines 3-16) |

Active record-triggered flows per object (from `<start>` in `flows/*.flow-meta.xml`):

| Object | Active record-triggered flows | Also has |
|---|---|---|
| Case | 15 after-save + 9 before-save | 2 triggers |
| `Application__c` | 15 after-save | 1 trigger |
| `pymt__PaymentX__c` | 4 after-save + 1 before-save | 3 triggers |
| `License__c` | 4 | — |
| `Transaction__c` | 3 | 2 triggers |

**Impact** Salesforce does not guarantee the order in which triggers on the same object run. Payment before-insert logic in `PaymentAllHandler.checkDepositIfExisting` and `BREGPaymentTriggerHandler.populateAccountFromContactForBregPayments` can run in either order. Two Payment triggers also both recalculate transaction and line status. Combined with dozens of flows, this makes behaviour hard to predict, uses CPU and SOQL budget, and makes regressions likely.

**Recommendation** Consolidate to one trigger per object, with a dispatcher that routes by record type or context to BREG and PVL handlers. Merge `PaymentAll` and `PaymentTrigger` first. Inventory the Case and Application flows and move the complex ones into Apex or into ordered flows (Flow Trigger Explorer / `triggerOrder`).

**Effort** L

### [HIGH] ID A-04: Five competing trigger frameworks and seven bypass mechanisms

**Evidence** Trigger styles found across the 61 triggers:

| Style | Where | Handlers / triggers |
|---|---|---|
| `TriggerFactory` + `ITrigger`, per-record callbacks | `classes/TriggerFactory.cls:29-169`, `classes/ITrigger.cls` | 23 handlers |
| `BREGBaseTriggerHandler.run()` | `classes/BREGBaseTriggerHandler.cls` | 10 handlers |
| `fflib_SObjectDomain.triggerHandler` | `triggers/CaseTeamAssignmentTrigger.trigger:2`, via `classes/SObjectDomainTriggerHandler.cls` | 1 |
| Static-method handlers | `QualCaseTriggerHandler`, `tkt_TicketTriggerHandler`, `CATV_InetTriggerHandler`, `CATV_UserTriggerHandler`, `TransactionHandler`, `TransactionLineHandler` | 6 |
| `onBeforeInsert`-style instance handlers | `PaymentAllHandler`, `InvestigationAllHandler`, `TimeandExpensesAllHandler` | 3 |
| Inline logic in the trigger body | see A-05 | 11 triggers |
| dlrs managed rollups | `dlrs_*` triggers | 3 |

Bypass mechanisms:
1. `OrgConfiguration__c.DisableTriggers__c` / `DisableAccountTriggers__c` / `DisableLicenseTriggers__c` / `DisableApplicationTriggersForUser__c` (22 references in triggers).
2. `BREG_Setting__c.Global_Data_Migration_Triggers_Disabled__c` (BREG triggers).
3. `ProcessSwitches__c` (`classes/SObjectDomainTriggerHandler.cls:34-40`).
4. `tkt_Trigger_Control__c`.
5. `util_closer_Settings__c`.
6. Static flags in `classes/TriggerHelper.cls:2-9` and `classes/TriggerUtils.cls:2`, plus per-class flags such as `SanctionService.skipTrigger`, `PaymentDeduplicator.disableTrigger` and `TransactionLinePreventDeletion.skipValidation`.
7. The integration-profile check `GlobalUtilities.getIntegrationProfileId()` in `triggers/PaymentAll.trigger:12` and `triggers/PaymentTrigger.trigger:8`.

Many triggers have **no** bypass at all: `CertificateRequestTrigger`, `ContentDocumentLinkTrigger`, `FileDetailTrigger`, `LicenseTypeTrigger`, `NotificationTrigger`, `ExamAll`, `FilingAll`, `SanctionTrigger` (flag only), `InvestigationAll` and others.

There is a copy-paste coupling: `triggers/ExamResultsTrigger.trigger` is disabled by `TriggerHelper.disableApplicationTrigger`.

`TriggerFactory.getHandler` (lines 120-169) is a closed if/else registry, so the shared framework depends on every PVL handler (18 Shared→PVL edges).

**Impact** No single switch disables automation for data loads. Every framework has different recursion, bulk and ordering semantics. The per-record `ITrigger` callbacks encourage static "capture" collections: `classes/ApplicationService.cls` has 21 static collections drained in `runFinally` at line 886. That state can leak across chunks.

**Recommendation** Adopt one framework org-wide. Extend `BREGBaseTriggerHandler`, which is the most modern, after fixing A-02, or adopt a metadata-driven framework. Use one bypass mechanism, for example a hierarchy custom setting plus `Custom Permission` checks. Migrate one object at a time, starting with the shared objects from A-03.

**Effort** XL

### [HIGH] ID A-05: PVLProcess__e used as a generic "command bus" with SOQL/DML/Flow inside the event loop

**Evidence**
- `triggers/PVLProcessTrigger.trigger` is 264 lines, the largest trigger. It dispatches 12 command types by `Type__c`, including 'Generate PDF', 'Terminate License', 'DependencyFlow', 'MultiDependencyFlow', 'MoveSpringCMFiles', 'ScanResultApplication' and 'App - Recreate Transaction Lines'.
- All of this runs inside `for (PVLProcess__e process : processes)` (line 6). Inside that loop are:
  - SOQL at lines 66, 95, 105, 159, 171, 188, 196, 223;
  - DML at lines 57, 74, 88, 237;
  - `Flow.Interview.createInterview(...).start()` at lines 137, 212 and 225, the last one inside a per-record loop;
  - `EventBus.publish` at line 247, where the event republishes itself one application at a time;
  - `Database.executeBatch` at line 260.
- The event is published from 14 production classes and 2 flows (`flows/PVL_Process_Flow.flow-meta.xml`, `flows/PaymentImmediateActions.flow-meta.xml`).
- There is no `EventBus.RetryableException` handling and no subscriber batch-size config in the repo (there is no `platformEventSubscriberConfigs` folder).

**Impact** Platform-event triggers receive up to 2,000 events per batch. About 16 or more 'DependencyFlow' events in one batch will exceed 100 SOQL queries, and the whole batch then fails. Failed events are not retried, so license terminations, PDF generation and collection allocations can be lost with nothing more than a log entry. The self-republishing pattern at lines 229-247 turns N application updates into N serial async transactions.

**Recommendation** Split the event into one handler class per command type, bulkified across all events of that type. Or replace it with Queueables or Transaction Finalizers. Add `RetryableException` handling and a `PlatformEventSubscriberConfig` batch size. Log failed payloads to a durable object.

**Effort** M

### [HIGH] ID A-06: Fat triggers with inline business logic and a broken recursion guard

**Evidence** Triggers with the most logic after stripping comments (statements / SOQL / DML):

| Trigger | Stmts | SOQL | DML | Notes |
|---|---|---|---|---|
| `triggers/PVLProcessTrigger.trigger` | 86 | 6 | 4 | see A-05 |
| `triggers/EarnedCETrigger.trigger` | 47 | 3 | 2 | lines 26, 34, 52, 65, 118. Recursion flag `isUpdateLicenseOnce` is a **local** variable (line 9), checked at line 55 and set at line 120, so it has no effect. The trigger runs two separate license roll-up algorithms (lines 25-53 and 54-122), each doing its own `update` of `License__c` |
| `triggers/CollectionsAllocationTrigger.trigger` | 31 | 1 | 0 | fee-rounding logic inline, lines 16-70 |
| `triggers/PaymentTrigger.trigger` | 13 | 0 | 0 | dedupe and amount routing inline |
| `triggers/DraftApplicationTrigger.trigger` | 11 | 0 | 1 | JSON parsing, self-update |
| `triggers/PVLErrorHandlerTrigger.trigger` | 11 | 0 | 1 | |
| `triggers/CATV_UserTrigger.trigger` | 9 | 1 | 0 | Profile SOQL on every User insert/update |
| `triggers/ContentDocumentTrigger.trigger` | 7 | 1 | 0 | |

Also: `triggers/SEBCaseTeamTrigger.trigger` and `triggers/TravelApprovalTrigger.trigger` have inline loops, and `triggers/sc_FieldMetaDataTrigger.trigger` makes a describe call per record.

By contrast, 44 of 61 triggers are logic-less delegators with 1-5 statements.

**Impact** Logic inside triggers cannot be unit-tested in isolation, cannot be bypassed, and is duplicated. For example, the Payment dedupe routing exists both in `PaymentTrigger` and in `PaymentAllHandler`.

**Recommendation** Move all trigger bodies into handler classes as part of the A-04 consolidation. Delete the non-functional guard in `EarnedCETrigger`.

**Effort** M

### [HIGH] ID A-07: God classes and oversized portal controllers

**Evidence**
- 13 production classes exceed 1,000 lines (the full top 25 is in the Appendix). The non-vendor ones are:

| Class | Lines |
|---|---|
| `classes/BREGCaseStatusHandlerBase.cls` | 2,288 |
| `classes/BREGBusinessDetailsController.cls` | 2,265 |
| `classes/BREGPaymentController.cls` | 1,992 |
| `classes/BREGUtils.cls` | 1,490 |
| `classes/BREGNameClearanceController.cls` | 1,415 |
| `classes/GenericCreatePaymentCtrl.cls` | 1,309 |
| `classes/BREGCaseTriggerHandler.cls` | 1,278 |
| `classes/licenseService.cls` | 1,181 |
| `classes/BREGCaseStatusHandlerAnnuals.cls` | 1,069 |
| `classes/BREGSearchAndBuyController.cls` | 1,059 |
| `classes/ApplicationService.cls` | 1,049 |

- **Controllers over 1,000 lines (5):**

| Controller | Lines | `@AuraEnabled` occurrences | Sharing |
|---|---|---|---|
| `BREGBusinessDetailsController` | 2,265 | 41 | without sharing (line 1) |
| `BREGPaymentController` | 1,992 | 61 | without sharing (line 1) |
| `BREGNameClearanceController` | 1,415 | 33 | with sharing |
| `GenericCreatePaymentCtrl` | 1,309 | 83 | without sharing (line 17) |
| `BREGSearchAndBuyController` | 1,059 | 33 | without sharing |

- `BREGUtils` is a grab-bag with the highest fan-in in the org (39 classes). It mixes form-code classification, dynamic class instantiation (line 264), picklists and log building.
- `classes/BREGAddressProtectionUtils.cls` (887 lines) documents its own "SOQL queries in a loop — known anti-pattern" in its header.

**Impact** These classes are change hotspots with a large regression surface and are hard to test. Their test classes are also huge (`BREGCaseStatusHandlerBaseTest` 2,442 lines, `BREGPaymentControllerTest` 1,683 lines). Large `without sharing` `@AuraEnabled` surfaces widen the attack surface for portal users.

**Recommendation** Split them by responsibility: query/selector, domain rules, and a thin `@AuraEnabled` facade. Start with `BREGPaymentController`, whose fee, transaction-line and receipt logic duplicates `BREGTransactionUtils`, and with `BREGBusinessDetailsController`. Break `BREGUtils` into focused utilities.

**Effort** XL

### [HIGH] ID A-08: The Domain/Handler/Service/Selector pattern exists only in PVL; controllers bypass it widely

**Evidence**
- The PVL objects routed through `TriggerFactory` mostly have the full set of layers:

| Object | Domain | Handler | Service | Selector |
|---|---|---|---|---|
| Application | Y | Y | Y | Y |
| License | Y | Y | `licenseService` | Y |
| AssociatedLicense | Y | Y | Y | Y |
| InsuranceBond | Y | Y | Y | Y |
| Notification | Y | Y | Y | Y |
| Transaction | Y | Y | Y | Y |
| FileDetail | Y | Y | Y | Y |
| LicenseClassification | Y | Y | Y | Y |
| LicenseCondition | Y | Y | Y | Y |
| EligibleCandidateLoad | Y | Y | Y | Y |
| Exam, Filing, Account | Y | Y | Y | missing |
| CertificateRequest, Sanction, ExamResults, DraftApplication | missing | Y | Y | missing |
| Payment, Investigation, SEBCase | missing | missing | missing | missing |

- BREG has **no** Domain or Selector classes. Its only Service classes are `BREGAmazonSesEmailService` and `BREGGetFeeForService`. 111 BREG production classes contain 445 inline SOQL statements.
- Across the org, 425 of 730 production classes contain inline SOQL (1,441 statements). Only 149 of those statements are in the 50 `*Selector` classes.
- 80 of 128 controllers (`*Controller`/`*Ctrl`/`*Cont`) run SOQL (68) or DML (40) directly. Worst cases by SOQL/DML count:

| Controller | SOQL | DML |
|---|---|---|
| `classes/CATV_AccessRequestController.cls` | 10 | 2 |
| `classes/GeneratePicklistOptionsCont.cls` | 9 | 3 |
| `classes/sc_ApplicationController.cls` | 8 | 6 |
| `classes/BREGPaymentController.cls` | 5 | 11 |
| `classes/GenericCreatePaymentCtrl.cls` | 2 | 9 |

**Impact** Query logic is duplicated, field lists drift apart, sharing and FLS are handled inconsistently, and the code is hard to mock in tests. The pattern in the PVL code is not reusable by BREG, the largest context.

**Recommendation** Pick one layering standard and document it. New BREG work should introduce Selectors for Case, Account and `breg_Transaction__c` first, since those carry the most queries. Enforce the standard with PMD rules such as `ApexSOQLInjection` and custom "no SOQL in *Controller" checks in CI.

**Effort** L

### [HIGH] ID A-09: Three separate clients for DocuSign CLM / SpringCM, including a hard-coded UAT endpoint

**Evidence**
- (1) Legacy SpringCM SDK: `SpringCMApiManager`, `SpringCMService`, `SpringCMRestHelper`, `SpringCMWorkflow` and related classes at **API v31-33**. Consumers are `SEBSearchController`, `InvocableSpringCMDocGen`, `ScreenSpringGen`, `CATV_DashboardController` and `UploadCaseFileToDocSignQueueable`.
- (2) `classes/SpringCMConnector.cls` (548 lines, fan-in 30, used by PVL, Payments and Enforcement). It runs its own OAuth refresh and session cache (lines 27-81) and builds URLs from `API_URL__c` in Custom Metadata (lines 207, 324).
- (3) `classes/DocuSignAPI.cls` (836 lines, used by BREG, 13 consumers). It uses Named Credentials `callout:DocuSign`, `DocuSignSource`, `DocuSignUpload` and `DocuSignSourceUpload` (lines 656-658), and depends on `BREGUtils` (lines 80-103).
- `classes/SpringCMConnector.cls:399` hard-codes `https://apiuatna11.springcm.com/v2/folders?search=`. It is called from production batch code at `classes/PVL_ListBuilderFileDeletionBatchJob.cls:72`.
- `classes/SpringCMConnector.cls:435` contains a test stub endpoint `https://test.salesfor.com`.
- 12 VF pages `pages/SpringCM_EOS*.page` are at API v34.

**Impact** The same external system has three sets of auth, error handling and retry semantics. The production batch path calls the **UAT** CLM tenant, so it fails or touches the wrong environment (Unverified whether the batch is scheduled). Credential rotation has to be done in three places.

**Recommendation** Standardise on one CLM client, using `DocuSignAPI` with Named Credentials as the base. Migrate `SpringCMConnector` consumers to it and retire the v31 SDK. Remove the hard-coded endpoints now.

**Effort** L

### [HIGH] ID A-10: Pervasive `without sharing` plus generic "escape hatch" DML helpers

**Evidence**
- Sharing declarations on production classes: 128 `without sharing`, 263 `with sharing`, 34 `inherited sharing`, and **286 with no declaration**.
- There are 4 generic DML helpers that run as system:

| Helper | Lines | What it does | Used by |
|---|---|---|---|
| `classes/AccessLess.cls` | 4 | `insert records` | `AccountService` |
| `classes/WithoutSharingDmlHelper.cls` | 30 | insert helpers | `licenseService` |
| `classes/CATV_WithoutSharingUtility.cls` | 68 | `doInsert`/`doUpsert`/`getParentId` on FeedItem/FeedComment | 4 CATV classes |
| `classes/BREGSObjectUpdaterWithoutSharing.cls` | 51 | `selectRecordsByQuery(String query)` → `Database.query(query)`; `updateRecordsByQuery` | 10 classes |

- BREG also has purpose-specific `without sharing` classes: `BREGCaseControllerWithoutSharing` (updates Case fields from the portal), `BREGContactControllerWithoutSharing` (creates Contacts from the portal), `BREGTransactionUtilsWithoutSharing` and `BREGAnnualRobotWithoutSharing`.
- Why they exist (inferred from the call sites): portal and guest users must create or update records they do not own, such as registration, CATV access requests, BREG case edits and annual-report robot processing.

**Impact** Authorization is granted by class rather than by explicit rules. Any `@AuraEnabled` method that reaches these helpers inherits system access. Classes with no declaration take the caller's mode, which is unpredictable when they are reused.

**Recommendation** Inventory every `without sharing` entry point that has `@AuraEnabled` or `@RestResource` methods. Replace the generic helpers with narrow, purpose-named methods that validate record ownership. Use `WITH USER_MODE` / `AccessLevel.USER_MODE` by default. Add explicit sharing keywords to the 286 undeclared classes. Cross-reference: Security report.

**Effort** L

### [MEDIUM] ID A-11: Three domain / unit-of-work base layers, including a heavy vendored fflib

**Evidence**
- (1) A custom "trim down" `classes/SObjectDomain.cls` (header line 2) with 34 subclasses, most PVL and sc_ domains.
- (2) Full vendored fflib apex-common and apex-mocks plus the `fflibe_*` extension: 41 production classes / 10,580 LOC and 30 test classes / 10,502 LOC.
- Only about 17 non-fflib classes reference fflib, all in the CaseTeam and email slice (`CaseTeamAssignment*`, `CaseTeamMember*`, `EmailAlertTriggersSelector`, `UserRecordAccess*`, `RecordTypeUtil`, `SObjectUtil`).
- (3) `classes/SObjectDomainTriggerHandler.cls` (extends `fflib_SObjectDomain`) and the `classes/UnitOfWork.cls` wrapper.
- `fflibe_Application` binds domains and selectors at runtime from `fflibe_Selector__mdt` and `fflibe_Domain__mdt` (`classes/fflibe_Application.cls:4-6,56-82`). Those Custom Metadata records are not in the repo.
- The sc_ context duplicates its domains: `CardCacheDomain`/`sc_CardCacheDomain`, `CardMetaDataDomain`/`sc_CardMetaDataDomain`, `FieldMetaDataDomain`/`sc_FieldMetaDataDomain`.

**Impact** There are three idioms for the same job, about 21k lines of vendor code to keep patched and covered, and dependency wiring that cannot be seen from source.

**Recommendation** Decide on one domain layer. If fflib stays, migrate the `SObjectDomain` subclasses over time. If not, remove fflib and rewrite the roughly 17 CaseTeam classes. Remove the duplicate sc_ domains either way.

**Effort** L

### [MEDIUM] ID A-12: BREG and PVL share transactional objects without a clear ownership boundary

**Evidence**
- Production classes that write or query each shared object, by context:

| Object | BREG | PVL core | Payments | Other |
|---|---|---|---|---|
| `Transaction__c` | 5 | 6 | 27 | — |
| `TransactionLine__c` | 15 | 4 | 20 | — |
| `pymt__PaymentX__c` | 7 | 9 | 27 | — |
| Account | 68 | 13 | 10 | — |
| Case | 70 | — | — | Qual 3, util_closer 3 |

- BREG-specific fields sit on shared objects: `objects/Transaction__c/fields` has 9 `breg_*` fields and `objects/TransactionLine__c/fields` has 16 BREG fields.
- BREG creates PVL-style transactions directly through `NewTransaction` and `CreateTransaction` (`BREGAccountTriggerHandler`, `BREGR7ExpirationBatch`, `BREGCaseStatusHandlerReinstatement`, `BREGCaseStatusHandlerChangeNonComCRA`, `BREGTransactionUtils`).
- Record-type segregation is inconsistent. PVL uses the label-based lookup `getRecordTypeInfosByName('Business Account')` (`classes/AccountService.cls:29`, `classes/AccountDomain.cls:48-49`). BREG uses `getRecordTypeInfosByDeveloperName` (`classes/BREGAccountTriggerHandler.cls:10`, `classes/BREGCaseTriggerHandler.cls:28-29`).
- `classes/DocuSignAPI.cls` sits in the shared docs layer but depends on `BREGUtils`, which is a reverse dependency.

**Impact** A change to payment or transaction logic for one division can break the other. The label-based lookups break if record-type labels are renamed or translated. Ownership of shared objects is unclear, and that ownership question drives A-03.

**Recommendation** Name a single owner for the Payments/Transaction model and put a service interface in front of it that both BREG and PVL call. Route shared-object triggers by record type in one dispatcher. Switch to `DeveloperName` lookups everywhere.

**Effort** L

### [MEDIUM] ID A-13: Duplicated cross-cutting utilities (logging, lookup, constants, batch config, email)

**Evidence**
- **Logging:** at least 8 mechanisms. They are `CustomLogger` + `CustomLog__c` + `CustomLogEvent__e`; `ApplicationLogService` + `Application_Log__c` + `PVLErrorHandler__e`; `breg_Log__c` + `BREG_Handler_Error__e`; `BREGAmazonSesLogger` / `breg_Email_Log__c`; `breg_Search_Log__c`; `QualIntegrationLogger` + `qual_Integration_Log__c`; and `util_closer_Logger` + `util_closer_Batch_Log__c` / `util_closer_Case_Log__c`. There are also 561 `System.debug` calls in production classes.
- **Lookup controllers (5):**
  - `classes/LookUpController.cls` and `classes/sc_LookupController.cls` are identical except for a `MAX_RESULTS` constant (`diff` shows 3 lines changed). Both build dynamic SOQL from unescaped object and field parameters (`LookUpController.cls:8-13`); cross-reference Security.
  - The other three are `CATV_CustomLookUpController`, `InputLookupAuraController` (API v39) and `LookupService`.
- **Constants:** `ConstantsHelper`, `GlobalConstants` and `sc_GlobalConstants`. `classes/CustomMetadataHelper.cls` is an empty class.
- **Email:**
  - Template selectors: `EmailService`, `EmailTemplateService`, `EmailTemplateSelector` (7 lines) and `EmailTemplatesSelector` (30 lines).
  - Senders: `tkt_EmailNotificationService`, `BREGAmazonSesEmailService`, `PVL_SendPVLEmails`, `BREG_SendBREGEmails` and `util_closer_NotificationService`.
- **Batch configuration:** 3 Custom Metadata types plus a custom setting:
  - `BREG_Batch_Setting__mdt` (`BREGBatch.cls:18`, `Type.forName`);
  - `BREG_Batch_Job_Configuration__mdt` (`BREGBatchJobConfigurationController.cls:56`);
  - `BatchJob_Setting__mdt` (`BatchJobExecutionController.cls:50`);
  - `BREG_Annuals_Job_Settings__c`.
- **Renewals:** the board-specific `classes/BarberingCosmetologyRenewal.cls` acts as the shared renewal utility for 9 other boards (fan-in 10).

**Impact** Log data is spread over 8 stores with no single operational view. Fixes to one lookup or logger do not reach its copies, which duplicates the SOQL-injection exposure. Teams also keep inventing new helpers.

**Recommendation** Provide one platform-services package with a Logger (a single object plus an event), a secure Lookup service, Constants, an Email sender and a Batch registry. Deprecate the copies step by step. Rename the Barbering class to a neutral `RenewalCommonService`.

**Effort** M

### [MEDIUM] ID A-14: Integration inventory — inconsistent credential handling and runtime metadata writes

**Evidence** Outbound HTTP classes (14):

| Class | Target | Credential handling |
|---|---|---|
| `BREGAmazonSesEmailService` | Amazon SES | Named Credential `callout:Amazon_SES` |
| `DocuSignAPI` | DocuSign CLM | Named Credentials `callout:DocuSign*` |
| `IMLCCConnector` | IMLCC | Named Credential `callout:IMLCC` |
| `OracleGLBatchloadFlowService` | Oracle GL (ORDS) | Named Credential `callout:OracleGL` |
| `CreateRecordCont:55` | Salesforce UI API | Self-callout `callout:UI_API_Credentials` (v46.0), `OAuth {!$Credential.OAuthToken}` |
| `sc_AppMetaDataManagement:48,61` | Salesforce Tooling API | Self-callout that **creates/patches StaticResources at runtime** (v53.0) |
| `SpringCMConnector`, `SpringCMApiManager`, `SpringCMFileHelper` | SpringCM | URLs and secrets from Custom Metadata |
| `TaxClearanceApiHelper:114` | Hawaii tax clearance | Endpoint from `TaxClearanceApi__c.EndpointUrl__c` |
| `QualCalloutService:49` | Qualtrics | Endpoint from `qual_Config__mdt` |
| `DocuSignCallbackController:34`, `DocusignAuthProvider:97` | OAuth token endpoints | — |
| `UploadCaseFileToDocSignQueueable:56` | DocuSign | — |

Other points:
- `remoteSiteSettings/` has 31 entries, including `test`, `icanhazip`, `WordpressSiteTestServer` and `GoogleChartingApi` (these look stale, Unverified).
- Inbound APIs: 13 `@RestResource` classes, 8 of them `BREGExternalAPI*`, plus `LicenseSearchREST`, `PaymentREST`, `TransactionREST` and `PVLApplicationStatus*Resource`.
- Platform events: `PVLProcess__e` (14 publisher classes), `PVLErrorHandler__e`, `BREG_Handler_Error__e`, `CustomLogEvent__e`, `ppt_Toast__e` (2 flows and 1 LWC), and `EmailAlertEvent__e`, which has no publishers found.
- Managed packages: `pymt__` (PaymentConnect, 1,931 references), `dsfs__` (DocuSign eSignature), `UJET__`, `dlrs`.
- 166 `Test.isRunningTest()` branches in 85 production classes, 18 of them in `IMLCCConnector` alone. They stand in for proper `HttpCalloutMock` seams.

**Impact** Secrets sit in Custom Metadata or custom settings instead of External Credentials. Runtime Tooling API writes mutate metadata in production, which is hard to audit and can drift from source control. The test branches hide the callout paths from real test coverage.

**Recommendation** Move every callout to Named Credentials or External Credentials. Replace runtime StaticResource writes with a data object or Salesforce CMS. Clean up the Remote Site Settings. Keep an integration catalogue (owner, auth, retry, monitoring).

**Effort** M

### [MEDIUM] ID A-15: Dead and commented-out code, including an active no-op trigger

**Evidence**
- `triggers/StatusHistoryTrigger.trigger:3-44`: the whole body is inside `/* ... */`. The trigger is active (`StatusHistoryTrigger.trigger-meta.xml` status Active) and does nothing.
- `classes/AgeDaysSumCalculator.cls`: 91% comments, and its only method `calculate` is commented out.
- `classes/LicenseClassificationDeactivator.cls`: 366 lines, 84% commented out, including its `@InvocableMethod`.
- `classes/WebDocumentMutiExt.cls`: 78% commented, and its constructor does nothing.
- Delete branches are commented out in `triggers/PaymentAll.trigger:38-44`, `triggers/InvestigationAll.trigger` and `triggers/TimeAndExpensesHeaderAll.trigger`.
- 16,597 of 121,259 production lines (13.7%) are comment lines.
- 28 production classes have no static reference from any Apex class, trigger, LWC, Aura, VF page/component or flow, and are not an entry point. There are also 4 `@AuraEnabled` controllers with no UI consumer. See the Appendix list.
- `pages/Mass_Delete_*.page` (10 pages at API v38, including Lead, Opportunity, Solution and Campaign) come from the legacy Mass Delete sample. No references were found in the repo (Unverified: list buttons on standard objects are not in source).

**Impact** Dead code clutters the codebase, adds deployment and coverage overhead, and misleads developers. The no-op trigger still costs a trigger invocation on every insert.

**Recommendation** Delete the confirmed dead items after checking org usage (Setup › Apex Jobs and scheduled jobs, `ApexClass` last-used data, Event Monitoring for Aura and REST). Deactivate and remove `StatusHistoryTrigger`.

**Effort** S

### [MEDIUM] ID A-16: Wide API version spread with legacy v31–v39 components

**Evidence**
- Classes span 28 distinct major versions (v31–v66). 26 classes are below v40, and 9 are at v31 (the SpringCM SDK: `SpringCMService`, `SpringCMRestHelper`, `SpringCMWorkflow`, `SpringCMTriggerHandler`, `SpringCMApiManagerMock` and tests).
- Triggers span v39–v65. `TransactionAll` and `TransactionLineAll` are v39, and the 3 Payment triggers are v43.
- Pages go down to v34 (12 `SpringCM_EOS*` pages) and Aura to v38 (`CustomRecordCreateField*`).
- `sfdx-project.json` sets `sourceApiVersion` to 67.0.
- Full distribution is in the Appendix.

**Impact** Old API versions keep legacy runtime behaviour. Salesforce retired API versions 21–30 in 2025, and versions 31+ are expected to follow; exact dates are Unverified. Mixed versions make behaviour differ between classes.

**Recommendation** Raise every component below v50 to at least v60, starting with the SpringCM SDK or its replacement (A-09) and the Transaction and Payment triggers. Regression-test around sharing, `Schema` and JSON behaviour changes.

**Effort** M

### [LOW] ID A-17: Naming inconsistencies and near-duplicate class names

**Evidence**
- `classes/licenseService.cls` uses a lowercase class name.
- `classes/Transaction_Handler.cls` (the `TriggerFactory` handler) and `classes/TransactionHandler.cls` (static methods) both handle `Transaction__c` from the same trigger (`triggers/TransactionAll.trigger:25-40`).
- The `PVL_` and `PVL` prefixes are both used (37 and 22 classes).
- `BregCaseStatusHandlerRevocation` is capitalised differently from its 29 `BREGCaseStatusHandler*` siblings.
- Typos in class names: `RbEntityRbBrokerRnewalDependency`, `WebDocumentMutiExt`, `MassScanningLicenceController`, `calcualteOutStanding` (`ApplicationService`).
- Similar names for different things: `ApplicationCacheTrigger` and `DraftApplicationTrigger` (same object); `CardCacheDomain` and `sc_CardCacheDomain`.

**Impact** Classes are hard to find, and people edit the wrong one of two similar handlers.

**Recommendation** Publish a naming convention (context prefix, layer suffix). Fix the names during refactors that touch these classes.

**Effort** S

### [LOW] ID A-18: Test scaffolding embedded in production classes

**Evidence**
- `classes/SpringCMApiManagerMock.cls` (96 lines) is a production class, not `@isTest`, and is used only by tests.
- `classes/SObjectDomainTriggerHandler.cls:6-8,16,34` contains test-only switches (`skipIsTriggerActiveForTest`, `SObjectDomainTriggerHandlerTest.` name prefixing).
- `classes/DocuSignAPI.cls:10-13` returns fake Custom Metadata under `Test.isRunningTest()`.
- There are 166 `Test.isRunningTest()` branches in total (see A-14).

**Impact** Test-only code ships to production, counts against the org's Apex code size and coverage calculations, and can mask production paths.

**Recommendation** Move mocks into `@isTest` classes. Use dependency injection (`HttpCalloutMock`, `Stub API`, selector interfaces) instead of runtime test checks.

**Effort** M

## Appendix

### A. Context classification rules (applied in order, first match wins)
fflib: `^fflibe?_`. dlrs: `^dlrs_`. BREG: `^(BREG|Breg)`. Qual: `^(Qual|Voicecall)`. util_closer: `^util_closer`. sc_: `^(sc_|CardCache|CardMetaData|FieldMetaData|DraftCard|GeneratePicklistOptions|PVL_SC_)`. tkt_: `^tkt_`. CATV: `^CATV_`. IMLCC: `^IMLCC`. CaseTeam slice: `^(CaseTeam|CaseShares|UserRecordAccess|EmailAlertTrigger|IEmail*|ICaseTeam|IOrgWideEmail|IPostCommit|SObjectDomainTriggerHandler|UnitOfWork)`. Docs/CLM: `^(Spring|InvocableSpringCM|Docu|DocGenerator|DocumentGenerator|File|PullFileDetail|ContentDocumentLink|VFFileService|WebDocument|WebMultiDocument|UploadCaseFile|CLMFileFix|ScheduledGenerateFiles|ManagedContent|CustomUploadButton|PVLFolderFeed|ScreenSpringGen)`. Payments: `^(Payment|Transaction|Deposit|BatchTransaction|BatchChargeBack|BatchSummaryPDF|Collections|CashierCode|*CompletePayments*|Generic*Payment|GroupTransaction|NewTransaction|CreateTransaction|Reconciliation|OracleGL|JVForm|TDRForm|Fiscal|Recwkst|Franchise_|CTCheckout|SecurityPortalTransactions|DCCAFeeSchedule|GenerateListBuilderPayment|GenerateSubscriberPayment|Tax|CustomPaymentButton|D1D2Dependency|PVL_PaymentReceipt|PVL_ListBuilderReceipt)`. Enforcement: `^(Investigation|SEB|Sanction|StatusHistory|AgeDays|TimeandExpenses|TravelApproval|Filing)`. PVL Renewals: contains `Renewal|PushThru|PushThrough|RenewApp` or `^(AMD|Rb|RBE|Ct|CT|Forfeiture|CleanRenew|Rolling)`. PVL core: `^(License|Application|Associated|Exam|Insurance|Requirements|Eligible|CE|Certificate|Suspense|Draft|PVL|Batch|Account|Notification|…)`. Everything else goes to Shared.

### B. 25 largest non-vendor production classes

| # | Class | LOC | Context | Description |
|---|---|---|---|---|
| 1 | BREGCaseStatusHandlerBase | 2,288 | BREG | Base class for form-code-driven Case status transitions: required-field, payment, effective-date and entity validations (without sharing) |
| 2 | BREGBusinessDetailsController | 2,265 | BREG | **Controller**: LWC facade for entity, case, TN/TM/SM and transaction business details; 41 `@AuraEnabled`; without sharing |
| 3 | BREGPaymentController | 1,992 | BREG | **Controller**: BREG checkout (fees, transaction lines, PaymentConnect payment, receipts, CLM docs); 61 `@AuraEnabled`; without sharing |
| 4 | BREGUtils | 1,490 | BREG | Grab-bag utilities: form-code classification, dynamic handler instantiation, picklists, logs (fan-in 39) |
| 5 | BREGNameClearanceController | 1,415 | BREG | **Controller**: business-name availability search via SOQL/SOSL over Account, Case, TN/TM/SM and search logs |
| 6 | GenericCreatePaymentCtrl | 1,309 | Payments | **Controller**: generic layout-driven record create, file upload and payment wizard (PVL); without sharing |
| 7 | BREGCaseTriggerHandler | 1,278 | BREG | Case trigger handler: file numbers, filing contact, rejection-letter pagination, status-handler dispatch |
| 8 | licenseService | 1,181 | PVL core | `License__c` trigger service: postcards, renewal notices, suspenses, classifications, AMD inactivation |
| 9 | BREGCaseStatusHandlerAnnuals | 1,069 | BREG | Annual-report status handler: entity/GP/LLP updates, delinquency, stock handling |
| 10 | BREGSearchAndBuyController | 1,059 | BREG | **Controller**: public search-and-buy of entity documents/certificates |
| 11 | ApplicationService | 1,049 | PVL core | `Application__c` trigger service: requirements, classifications, renewal snapshot, PDFs, emails, IMLCC |
| 12 | util_closer_RuleEngine | 997 | util_closer | CMDT-driven rule engine for Case auto-close |
| 13 | QualIntegrationLogger | 953 | Qual | Qualtrics integration logging (success/retry/dead-letter) |
| 14 | tkt_EmailNotificationService | 902 | tkt_ | Ticket email notifications driven by `tkt_Email_Notification_Setting__mdt` |
| 15 | BREGCaseStatusHandlerHelper | 893 | BREG | Shared helpers for status handlers (fan-in 20) |
| 16 | BREGAnnualRobotRules | 889 | BREG | Planning rules for automated annual-report processing ("robot") |
| 17 | BREGAddressProtectionUtils | 887 | BREG | Protected-address masking; self-documented SOQL-in-loop |
| 18 | ApplicationDomain | 872 | PVL core | `Application__c` domain filters and helpers on custom `SObjectDomain` |
| 19 | DocuSignAPI | 836 | Docs/CLM | BREG DocuSign CLM REST client (folders, documents, workflows) via Named Credentials |
| 20 | BREGTransactionUtils | 813 | BREG | BREG transaction and fee creation utilities (fan-in 32) |
| 21 | LicenseSearchREST | 785 | PVL core | `@RestResource(urlMapping='/licenseSearch')` public license lookup API |
| 22 | BREGPortalUtils | 782 | BREG | Portal helpers: user type, form configuration, SSO URL, banners |
| 23 | CustomRecordCreate | 693 | Shared | (API v38) layout-driven generic record-create component controller |
| 24 | LicenseMassScannerController | 671 | PVL core | Barcode mass scanning of licenses and renewals |
| 25 | BREGWebFilingMapperInvocable | 669 | BREG | Invocable mapper from legacy `breg_WEB_*` staging objects to Case and affiliations |

Vendor classes over 900 LOC (excluded above): `fflib_MatcherDefinitions` (1,390), `fflib_SObjectDomain` (1,202), `fflib_Match` (1,158), `fflib_SObjectUnitOfWork` (924).

Controllers over 1,000 lines: BREGBusinessDetailsController, BREGPaymentController, BREGNameClearanceController, GenericCreatePaymentCtrl, BREGSearchAndBuyController.

### C. Highest fan-in production classes (number of distinct production classes referencing them)
BREGUtils 39 · SObjectDomain 36 · BREGTransactionUtils 32 · BREGCaseStatusHandlerBase 31 · SpringCMConnector 30 · ITrigger 24 · ApplicationDomain 23 · SpringCMDocument 23 · ApplicationSelector 22 · LicenseDomain 21 · AssociatedLicenseDomain 20 · BREGCaseStatusHandlerHelper 20 · AssociatedLicenseSelector 19 · BatchJobFinishNotification 15 · GlobalUtilities 14 · DocuSignAPI 13 · BREGStartDocusignWorkflow 12 · fflibe_ApplicationImpl 12 · ApplicationService 12 · ConstantsHelper 12 · BarberingCosmetologyRenewal 10 · BREGSObjectUpdaterWithoutSharing 10

### D. Likely-unused production classes
Sources checked: every other production Apex class (comments and strings stripped), all trigger tokens, LWC and Aura `@salesforce/apex/` imports, Aura/VF/component `controller=` and `extensions=`, flow `<actionName>` and `<apexClass>`, and Apex string literals (for `Type.forName`). Permission-set class access is not counted as usage.

| Class | LOC | Evidence / note |
|---|---|---|
| LicenseClassificationDeactivator | 366 | 84% commented out; `@InvocableMethod` commented (lines 18-19) |
| RenewalLicenseMassScannerController | 324 | `@AuraEnabled` but no LWC, Aura or flexipage consumer (the only mass-scanner Aura uses `LicenseMassScannerController`) |
| MassScanningLicenceController | 331 | same as above |
| A1LicenseMassScannerController | 249 | same as above |
| DocuSignJWT | 99 | no references |
| SpringCMApiManagerMock | 96 | production class used only by tests (4 test refs) |
| EmailService | 66 | no references; duplicates `EmailTemplateService` |
| util_closer_RuleViewerController | 65 | `@AuraEnabled`; no LWC imports it (only `util_closer_LogViewer` and `util_closer_schedulerManager` exist) |
| AgeDaysSumCalculator | 56 | method commented out; only caller `StatusHistoryTrigger` is commented out |
| CaseTeamMemberAssignmentEmailController | 32 | no VF, component or Apex refs (Unverified: may be used by a VF email template not in the repo) |
| LicenseTypeLoader | 31 | test-only reference |
| EmailTemplatesSelector | 30 | Unverified: may be bound via `fflibe_Selector__mdt` records |
| DocuSignAuthController | 20 | no references |
| LicenseRequirementsSelector | 20 | test-only reference |
| CaseTeamMemberService / ICaseTeamMemberService | 18 / 3 | test-only / none |
| CaseTeamAssignmentDomain | 39 | Unverified: may be bound via `fflibe_Domain__mdt` `.Constructor` |
| SpringCMTriggerHandler | 12 | test-only; no trigger uses it |
| SpringCMFeed | 11 | test-only |
| SpringCMAuthResponse / SpringCMAuthRequest | 7 / 6 | no references |
| EmailTemplateSelector | 7 | no references |
| IEmailAlertTriggerService | 5 | no references |
| CustomMetadataHelper | 3 | empty class body |
| CATV_Exception | 2 | no references |
| fflib_AccountDomain, fflib_AccountsSelector, fflib_ApexMocksUtils, fflib_System, fflib_QualifiedMethodAndArgValues, fflib_IDGenerator | — | vendor sample or unused parts, test-only references |
| WebDocumentMutiExt | 95 | referenced as a VF extension once, but its constructor body is a no-op (78% commented) |

Not statically referenced but entry points (123 classes, **not** flagged as dead; confirm in the org):
- 61 Schedulable/Batchable classes (for example `LicenseExpire`, `SuspenseDueDateProcessingBatch`, `BREGDBEDTReportScheduler`, `QualRetrySchedulable`);
- 13 `@RestResource` classes;
- 30 dynamically dispatched classes (`BREGCaseStatusHandler*` via `breg_Form_Configuration__c` data, `BREGIFormFieldValidation`, `BREGBatchInterface` subclasses via `BREG_Batch_Setting__mdt`);
- 4 `@InvocableMethod` classes (`PVL_RenewalDependencyFlowHelper`, `RbEntityRbBrokerRnewalDependency`, `RecordTypeUtil`, `ScreenSpringGen`);
- 3 Auth plugin/registration handlers;
- 7 `global` renewal push-thru classes.

### E. API version distribution (major version: count)
- **Classes (1,288):** 31:9 · 33:3 · 38:3 · 39:11 · 41:38 · 42:7 · 43:30 · 44:20 · 45:16 · 46:86 · 47:19 · 48:63 · 49:39 · 50:98 · 51:12 · 52:53 · 53:59 · 54:9 · 55:35 · 56:59 · 57:27 · 58:41 · 59:66 · 60:21 · 61:19 · 62:110 · 63:47 · 64:130 · 65:141 · 66:17
- **Triggers (61):** 39:2 · 41:3 · 43:3 · 44:5 · 45:1 · 46:6 · 47:3 · 48:6 · 49:2 · 50:2 · 52:2 · 55:1 · 56:3 · 58:2 · 59:2 · 60:2 · 61:3 · 62:3 · 63:1 · 64:5 · 65:4
- **VF pages (167):** 34:12 · 38:11 · 41:4 · 42:17 · 43:5 · 44:3 · 45:5 · 46:4 · 47:3 · 48:17 · 49:11 · 50:24 · 51:10 · 52:20 · 54:1 · 56:2 · 57:3 · 58:1 · 59:1 · 60:5 · 63:5 · 64:2 · 67:1
- **VF components:** 42:4 · 44:1 · 46:1 · 48:17 · 49:2 · 50:26 · 51:15 · 52:9 · 56:1 · 57:2 · 58:1 · 62:1
- **Aura (bundle files):** 38:2 · 39:9 · 40:2 · 41:5 · 43:5 · 44:6 · 45:12 · 46:40 · 47:5 · 48:3 · 49:4 · 50:1 · 52:2 · 55:38 · 56:2 · 57:4 · 59:3 · 63:1 · 64:1 · 65:2
- **LWC:** 48:4 · 49:3 · 50:2 · 52:2 · 55:5 · 56:7 · 58:13 · 59:10 · 60:4 · 61:1 · 62:15 · 63:95 · 64:44 · 65:22 · 66:5
- **Flows (266):** 49:64 · 50:6 · 51:2 · 52:10 · 53:18 · 54:3 · 55:4 · 56:9 · 57:16 · 58:6 · 59:20 · 60:20 · 61:4 · 62:2 · 63:8 · 64:27 · 65:31 · 66:12 · 67:4
- Components below v40: SpringCM SDK classes (v31/33), `SpringCM_EOS*` pages (v34), `Mass_Delete_*` pages and `MassDeleteExtension` (v38), `CustomRecordCreate` and its Aura components (v38), `InputLookup*` Aura and `InputLookupAuraController` (v39), `TransactionHandler`, `TransactionLineHandler` and their triggers (v39), `CustomPaymentButton*` and `CustomUploadButton*` (v39).

### F. Trigger inventory by object (61 triggers)
Objects with more than one trigger: `pymt__PaymentX__c` (PaymentAll, PaymentTrigger, BREGPaymentTrigger) · Account (AccountTrigger, BREGAccountTrigger) · Case (BREGCaseTrigger, QualCaseTrigger) · `Transaction__c` (TransactionAll, dlrs_TransactionTrigger) · `TransactionLine__c` (TransactionLineAll, BREGTransactionLineTrigger) · `Application_Cache__c` (ApplicationCacheTrigger, DraftApplicationTrigger).
Platform-event triggers: `PVLProcess__e`, `PVLErrorHandler__e`, `BREG_Handler_Error__e`.
No-op trigger: `StatusHistoryTrigger`.
