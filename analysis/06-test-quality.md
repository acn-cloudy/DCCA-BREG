# 06 — Test Coverage & Quality

Scope: `force-app/main/default/classes/` (1,288 classes), `force-app/main/default/triggers/` (61 triggers), LWC Jest under `force-app/main/default/lwc/**/__tests__/`. Static analysis only; nothing was run against an org. LOC = non-blank lines after comments are stripped. "Test class" means the `@isTest` annotation comes before the `class` keyword. The file name was not used to decide this.

## Summary

- **No real coverage data exists.** `.sfdx/tools/testresults/apex/00Dco000005RPU5EAO/` is an empty directory (created 2026-09-29 14:22). Org-wide and per-class coverage are unknown, so every coverage statement below comes from static test-to-class mapping (Unverified until an org run is done).
- **The volume of tests is fine; their quality is not.** 544 `@isTest` classes (526 with test methods), 3,708 test methods and a test:prod LOC ratio of 1.02:1. However, 499 methods (13.5%) contain no assertion at all, and **191 of 526 test classes (36%) contain no assertion anywhere**. Another 259 methods (7.0%) assert only trivial things (`!= null`, `assert(true)`). Median assertions per test method: 1.
- **Critical: `Test.isRunningTest()` changes production behaviour in 85 classes (173 sites).** This includes financial logic. `ReconciliationBatchJob` drops its entire WHERE clause in tests, `PaymentCutOffProcessingController` forces the "job completed" branch, `IMLCCQueueable` skips the `insert` and injects fake physician data, and 14 `|| Test.isRunningTest()` sites force branches purely for coverage.
- **Critical: payment and finance code is covered only by tests that assert nothing.** About 20 payment classes (~3,000 LOC) fall in this group, including `GenericCreatePaymentCtrl` (1,033 LOC, whose only test has its asserts commented out), `TransactionService` (414 LOC, 7-line test), `ReconciliationBatchJob`, `PaymentREST` and `TransactionREST`.
- **Critical: coverage-padding tests exist and are easy to prove.** Examples: `PVL_SelectorTest` (26 calls each wrapped in `try{}catch(Exception ex){}`), `JVFormControllerTest` (only runs a hard-coded dummy-data branch) and `IMLCCConnectorTest`. There are also 168 literal `System.assert(true…)` / `Assert.isTrue(true…)` statements in 53 classes.
- **High: date time-bomb tests will start blocking deployments soon.** `BREGAnnualRollOverJobTest` asserts filing dates fixed to 2026, but the job uses `DateTime.now()`, so it will fail from 2027-01-01. Several insurance-bond tests hard-code 2026-09-30 (today) and 2026-10-07 as "future" dates.
- **High: bulk and trigger testing is thin, and LWC has no Jest tests.** Only about 8 of 61 triggers get a 200+ record DML in any test, and those cases look incidental. There are 0 Jest tests for 232 LWC components, and the pre-commit hook runs Jest with `--passWithNoTests`.
- **Test data is fragmented.** There are 10 `@isTest` factories plus 3 factory/helper classes deployed as production code. Only 179 of 526 test classes (34%) use any factory; 213 test classes build `Account` records by hand.

| Severity | Count |
|---|---|
| Critical | 3 |
| High | 5 |
| Medium | 7 |
| Low | 3 |

| Headline metric | Value |
|---|---|
| Apex classes: test (`@isTest`) / production | 544 (526 with test methods + 18 utilities/mocks) / 744 |
| Test LOC : production LOC | 93,275 : 91,400 = **1.02 : 1** |
| Test methods | 3,708 |
| Test methods with zero assertions | 499 (**13.5%**); another 259 (7.0%) are trivial-only |
| Test classes with zero assertions anywhere | 191 / 526 (**36.3%**) |
| Production classes with no test path at all | 41 (1,508 LOC) |
| Production classes with no *direct* test reference | 210 (9,778 LOC) |
| Production classes referenced only by zero-assert tests | 175 (18,499 LOC, ~20% of prod LOC) |
| Org-wide coverage % | **Unknown**: cached test-results directory is empty |
| `Test.isRunningTest()` in prod | 173 occurrences / 85 classes + 1 trigger |
| `SeeAllData=true` | 5 classes / 8 annotations (Experience Cloud template boilerplate) |
| LWC components with Jest tests | 0 / 232 |

## Findings

### [CRITICAL] ID T-01: `Test.isRunningTest()` changes production behaviour, including financial logic
**Confidence**: Confirmed (occurrences and the cited examples were read). The category counts are Likely because they were classified by regex.

**Evidence** (173 occurrences in 85 classes; the full list is in Appendix A4):
- *The financial filter is removed in tests.* `force-app/main/default/classes/ReconciliationBatchJob.cls:61-72`: when `Test.isRunningTest()` is true the query is just `FROM CollectionsAllocation__c`. Otherwise it is `WHERE Reconciliation_Batch__c = null AND PaymentType__c IN (...) AND CutOffBatchDate__c = TODAY AND Payment__r.OwnerId = ... AND pymt__Status__c = 'Completed'`. The close-out selection logic that decides which money gets reconciled is never run by a test. Its test (`ReconciliationBatchJobTest.cls:78-116`) also has no assertions.
- *Forced branches (14 sites / 9 classes)*, for example:
  - `PaymentCutOffProcessingController.cls:30` `if(Test.isRunningTest() || job.Status == 'Completed')`
  - `PDGRenewal.cls:173,243,329,384`
  - `PestControlRenewal.cls:130,156`
  - `PestControlRenewalPushThru.cls:210,236`
  - `MotorVehicleIndustryRenewal.cls:170`
  - `BREGAnnualRobotRules.cls:149`
  - `BREGCaseHistoryBatch.cls:37`
  - `IMLCCSendEmailQueueable.cls:148`

  Each one runs a block whose real guard (a non-empty list, or a completed job) is false in the test. That inflates coverage without testing the real condition.
- *Fake data injected by production code (15 sites / 13 classes)*:
  - `IMLCCQueueable.cls:142-153` builds a fake `PhysicianDetails` record, and `:321-330` builds fake license data.
  - `IMLCCConnector.cls:32` returns a hard-coded app key in tests.
  - `ManagedContentController.cls:4`
  - `PVL_ListBuilderFileGenerationBatchJob.cls:44`
- *DML, async work and flows skipped in tests*:
  - `IMLCCQueueable.cls:264` `if(!Test.isRunningTest() && !appsForCreation.isEmpty()) insert appsForCreation;`, plus `:275,282,383,390`.
  - `BREGTransactionLineTriggerHandler.cls:114,132,509`: DocuSign workflows after payment never run.
  - `PaymentXBatch.cls:370`
  - `RealEstateLicensesInactivatorBatch.cls:165,172`
  - `force-app/main/default/triggers/PVLProcessTrigger.trigger:141`: flows are never started.
- *Test configuration swapped in*:
  - `BREGBatch.cls:12,209-214` uses in-memory metadata that points at the production dummy class `BREGBatchInterfaceExtTest`.
  - `SObjectDomainTriggerHandler.cls:34` makes `isTriggerActive()` always return true, so the `ProcessSwitches__c` kill switch is never tested.
- *Callouts short-circuited*: `IMLCCConnector.cls:40,46,59,65,78,84,97,103,122` (`return Test.isRunningTest() ? null : new Http().send(req)`), plus `SpringCMConnector.cls` (13 sites).

**Impact**: Reported coverage overstates what is verified. The code that runs in production (reconciliation filters, application inserts, status guards, response parsing) is not the code the tests run, so defects in those paths can only show up in production. The forced-branch pattern is coverage gaming in effect, whatever the intent.

**Recommendation**:
- Ban `Test.isRunningTest()` in new code with a PMD/Code Analyzer rule, and fail CI on new occurrences.
- Replace callout bypasses with `HttpCalloutMock`.
- Replace data and config bypasses with injectable seams: `@TestVisible` static overrides (the pattern already used in `QualConfigSelector.cls:27-157`) or `Test.createStub`.
- Remove every `|| Test.isRunningTest()` and build test data that meets the real condition.
- Refactor `ReconciliationBatchJob` first, so the test runs the real query against created data.

**Effort**: L

### [CRITICAL] ID T-02: Payment, transaction and reconciliation code is covered only by tests with no assertions
**Confidence**: Confirmed for the cited tests. The class list is Likely (static reference mapping; trigger paths may add more coverage, but still no assertions).

**Evidence**:
- `GenericCreatePaymentCtrl` (1,033 LOC; creates payments, filings and file details) is referenced only by `force-app/main/default/classes/GenericCreatePaymentControllerTest.cls`. That test's only three asserts are commented out (`:159-187`, the block starting `/* // Verify results`).
- `TransactionService` (414 LOC) has `force-app/main/default/classes/TransactionServiceTest.cls:3-6`: a single 3-statement method that calls `reGenerateTransactionLines` and asserts nothing.
- `PaymentRESTTest.cls:9-125` builds about 110 lines of setup, calls `PaymentREST.createPayment()`, and checks neither the `RestResponse` nor any records.
- Other zero-assert tests over finance classes: `TransactionRESTTest`, `ReconciliationBatchJobTest`, `RunReconciliationBatchControllerTest`, `PaymentCutOffProcessingControllerTest`, `PaymentTerminalControllerTest` (empty `catch` at `:76,85`), `PaymentAdjustmentControllerTest`, `PaymentRecwkstCmpControllerTest`, `TransactionRefundAuthFormControllerTest`, `D1D2DependencyRefundNoticeTest`, `CollectionsAllocationDomainTest`, `CollectionsAllocationTriggerTest`, `CTCheckoutFormControllerTest`, `PVL_PaymentReceiptControllerTest`, `PaymentXBatchProgressTest`, `PaymentXBatchSchedulerTest`, `dlrs_TransactionTest`, `BatchChargeBackTest`.
- Finance-critical trigger handlers with no direct unit test, reached only through trigger DML: `BREGPaymentTriggerHandler` (150 LOC), `TransactionHandler` (92), `PaymentDeduplicator` (85), `Transaction_Handler` (62), `TransactionDomain` (62), `BREGTransactionTriggerHandler` (26), `TransactionLinePreventDeletion`, `TransactionPreventDeletion`.

**Impact**: Money-handling logic (payment creation, refunds, cut-off, reconciliation, transaction-line regeneration) can regress without any test failing. Coverage from these tests gives false confidence at deploy time. Deleting them would also remove roughly 3,000 LOC of coverage at once (see T-15).

**Recommendation**:
- Treat payment and reconciliation classes as a priority test backlog.
- For each public entry point, assert the records created or updated (amounts, statuses, allocations), the REST response code and body, and at least one negative path (declined payment, duplicate, missing transaction).
- Restore or rewrite the commented-out asserts in `GenericCreatePaymentControllerTest`.

**Effort**: L

### [CRITICAL] ID T-03: Coverage-padding tests and tautological assertions
**Confidence**: Confirmed

**Evidence**:
- `force-app/main/default/classes/PVL_SelectorTest.cls:36-61`: 26 consecutive `try {selector.<method>(...);} catch(Exception ex) {}` calls with no asserts. They sit over `PVL_Selector` (265 LOC, a dynamic-SOQL builder).
- `JVFormControllerTest.cls:3-5` only runs `new JVFormController();`. With no `recordId`, the constructor takes the `else` branch at `JVFormController.cls:13-60`, which is about 45 lines of hard-coded dummy data (`'99999.99'`, 14 identical `fundsList.add(dateFeed)` at `:37-50`, 6 identical `values.add(formFeed)`). The real branch (`:8-12`, query plus JSON parse) is never tested. `TDRFormController.cls:33+` has the same dummy branch.
- `IMLCCConnectorTest.cls:5-24` and later methods: every call is wrapped in `try{...}catch(Exception e){System.debug('Callouts not allowed on test');}`.
- `fflib_SObjectDomainTEST.cls:100,103,106` and more (7 empty catches), `fflib_ApplicationTEST` (6), `fflib_SObjectUnitOfWorkTEST` (3): trigger-event calls with no asserts.
- `LicenseServiceCoverageTest.cls:1-12`: the header states its purpose is "coverage uplift"; for example, `:57-66` calls four stub handler methods and then `System.assert(true, 'LicenseHandler stub methods callable')`.
- In total, 168 `System.assert(true…)` / `Assert.isTrue(true…)` statements across 53 classes. Examples:
  - `BREGCaseStatusHandlerNameReservationTest.cls:126,149,199,221,243`
  - `BREGCaseStatusHandlerChangeNonComCRATest.cls:136,149` ("Error message should indicate entity is not linked", asserted as `true`)
  - `BREGCaseValidatorTest.cls:90,110,163,194`
  - `AssociatedLicenseTriggerTest.cls:291,309`
- 65 empty or debug-only `catch` blocks in 18 test classes.
- Search for classic padding (`i++;` runs, dummy/coverage-named methods) in production: **none found**. The only hit was `QualIntegrationLogger.recoverStaleProcessingLogs`, a false positive. The gaming here takes the forms above plus the `|| Test.isRunningTest()` branches in T-01.

**Impact**: These tests exist to satisfy the 75% gate, not to catch defects. They hide real coverage gaps, and any exception, including a real regression, is swallowed and passes.

**Recommendation**:
- Add a CI rule (PMD `ApexUnitTestClassShouldHaveAsserts`, `ApexUnitTestShouldNotUseSeeAllDataTrue`, plus a custom rule banning `assert(true` and empty `catch` in tests).
- Rewrite `PVL_SelectorTest` to assert the SOQL strings and returned rows.
- Delete the dummy `else` branches in `JVFormController`/`TDRFormController` (render an empty state instead) and test the real branch.
- Where an exception is expected, use `try { ...; Assert.fail(); } catch (ExpectedException e) { Assert.areEqual(...) }`.

**Effort**: M

### [HIGH] ID T-04: Date time-bomb tests (one will fail on 2027-01-01)
**Confidence**: Confirmed for `BREGAnnualRollOverJobTest`; Likely for the bond and renewal tests.

**Evidence**:
- `force-app/main/default/classes/BREGAnnualRollOverJobTest.cls`:
  - `:101` and `:133` declare a local `referenceDateTime = DateTime.valueOfGmt('2026-02-01 …')` that is never passed to the job; it is only written to `System.debug`.
  - The job uses `private DateTime referenceDateTime = DateTime.now();` (`BREGAnnualRollOverJob.cls:18`) and derives `referenceYear` from it (`:60-61`).
  - The asserts at `:125` (`Date.newInstance(2026, 1, 1)`) and `:162` (`Date.newInstance(2026, 4, 1)`) will therefore fail once the calendar year changes.
- `InsuranceBondDomainTest.cls:77,83,94,97,115,119`, `ApplicationHcRenewalValidationTest.cls:30,38-41,52-67` and `ApplicationTriggerTest.cls:500-501,518,571` hard-code coverage and deadline dates of 2026-09-30 and bond term dates of 2026-10-07 / 2026-11-20. The production query at `ApplicationService.cls:117` filters `TermDate__c >= TODAY`, so any path that goes through it stops finding these bonds after the hard-coded date.
- 11 test classes hard-code dates in 2025-2027; 28 classes hard-code dates of any year. `BREGWebFilingInfo2CaseTest` alone has 19 (see Appendix A6).

**Impact**: A test that fails on a calendar date blocks every production deployment that uses `RunLocalTests`, including emergency fixes. Here the failure date is about 3 months away.

**Recommendation**:
- Make the job's reference date injectable (`@TestVisible DateTime referenceDateTime`) and set it in the test.
- Replace absolute dates with `Date.today().addDays(n)` relative dates.
- Add a scheduled CI run that uses a clock-shift or date-override seam.

**Effort**: S

### [HIGH] ID T-05: Zero-assertion tests are widespread
**Confidence**: Confirmed (regex over method bodies; counts ApexMocks `.verify(` as an assertion).

**Evidence**:
- 499 of 3,708 test methods (13.5%) have no assertion in their body. 377 of them sit in 191 test classes that have no assertion anywhere; the full list is in Appendix A3. The largest:
  - `PDGRenewalTest` (7 methods / 319 LOC)
  - `LicenseMassScannerControllerTest` (19/271)
  - `ContractorRenewalPushThroughTest`, `RealEstateRenewalTest`, `RboRenewalDependencyTest`, `TransactionRESTTest`, `PestControlRenewalPushThruTest`, `MassageTherapyRenewalTest`, `TDRFormControllerTest`, `ExamResultLoadTest`
- 259 more methods assert only trivial things (`assertNotEquals(null, x)`, `isNotNull`, `x != null`, `assert(true)`). Worst: `tkt_EmailNotificationServiceTest` (23), `LicenseServiceCoverageTest` (22), `BREGCaseStatusHandlerMergerTest` (14).
- 216 test classes have 50% or more of their methods with no assertions.
- 13 trigger tests assert nothing: `AccountTriggerTest.cls:3-11` (insert/update, no checks), `CollectionsAllocationTriggerTest.cls:3-28`, `EarnedCETriggerTest` (covers the 112-LOC `EarnedCETrigger`), `CertificateRequestTriggerTest`, `ContentDocumentLinkTriggerTest`, `ContentDocumentTriggerTest`, `EligibleCandidateLoadTriggerTest`, `LicenseConditionTriggerTest`, `LicenseTypeTriggerTest`, `NotificationTriggerTest`, `TravelApprovalTriggerTest`, `Test_CaseTeamAssignmentTrigger`, `dlrs_TransactionTest`.
- 70 zero-assert classes cover batches, triggers or payments (list in Appendix A5).
- The newer BREG-module tests are noticeably stronger than the legacy PVL tests. For example, `BREGCaseStatusHandlerBaseTest` has 106 asserts and `PaymentAllHandlerTest` has 36.

**Impact**: About 20% of production LOC (175 classes, 18,499 LOC) is directly referenced only by tests that check nothing. Regressions in renewals, license scanning and batch processing will not be caught.

**Recommendation**:
- Turn on the PMD assertion rule in CI, warning-only at first, then failing for new or modified tests.
- Backfill in this order: triggers and payments (T-02), then renewal batches.

**Effort**: XL (backlog), S (gate)

### [HIGH] ID T-06: Production classes with no test, or no direct test, including batch, Invocable and @AuraEnabled entry points
**Confidence**: Likely (static reference graph; reachability through dynamic `Type.forName` strings, trigger DML and transitive calls was taken into account).

**Evidence**:
- **41 classes (1,508 LOC) have no test path at all** (Appendix A1). Examples:
  - `PVL_ListBuilderFileGenerationBatchJob.cls` (400 LOC; `global` Batchable + Schedulable + AllowsCallouts; handles `pymt__PaymentX__c`)
  - `GeneratePicklistOptionsCont.cls` (87, @AuraEnabled, used by the `generatePicklistOptions` LWC)
  - `PaymentDisplayController.cls` (45, @AuraEnabled, used by the `paymentDisplay` LWC)
  - `Franchise_CheckoutController.cls` (43, `without sharing`, payment VF controller used by `pages/FilingOverride.page`)
  - `InvocableSpringCMDocGen` (72), `LicenseCreateRecords` (62), `AMDInactivationLetterNoticeController` (51), `RecordAccessUtil` (28), `RecordTypeUtil`, `BatchFlagMultipleLicenseForAudit`, `PVL_RenewalDependency1wayFlowHelper`, `PVL_RenewalDependencyFlowHelperAsync`, `LicenseUpdateTransactionRecords`: Invocables called from flows such as `flows/Nurse_Application_DocGen.flow-meta.xml` and `flows/LicenseImmediateActions.flow-meta.xml`.
  - `PublicGroupMembershipScheduled` / `PublicGroupMembershipBatch`, `LicenseConditionOverdueFinderScheduler`, `AssociatedLicensesStatusUpdate`
- **210 classes (9,778 LOC) have no direct test reference**; 86 of them are critical types (Appendix A2). Examples:
  - `DraftApplicationService` (234, @AuraEnabled + Queueable)
  - `AccountService` (140)
  - `TriggerFactory` (109)
  - `BREGAccountAffiliationTriggerHandler` (107)
  - `CATV_InetTriggerHandler` (97), `CATV_UserTriggerHandler` (93)
  - `ExamHandler` (91)
- Some tests are named for a class but never call it. `LicenseCreateRecordsTest.cls:17-26` inserts an Account and a License and never calls `LicenseCreateRecords`.
- There are 277 production classes with no convention-named test. This includes interfaces and DTOs, so it is informational only.

**Impact**: These entry points (flows, schedulers, LWC controllers) run in production with no regression safety net. Untested `global` batch classes cannot be refactored safely.

**Recommendation**:
- Create a test for each class in A1, starting with Invocables used by active flows and the two payment controllers.
- Confirm whether `PVL_ListBuilderFileGenerationBatchJob` and `Franchise_CheckoutController` are still used. Delete them if not.
- Add a CI check that every new or modified production class has a referencing test.

**Effort**: M

### [HIGH] ID T-07: Triggers have almost no bulk (200+) tests; several objects have multiple triggers
**Confidence**: Likely (loop and factory-count detection; the 200-record cases were confirmed by reading).

**Evidence**:
- Only 9 test classes create 200 or more records. The ones that hit triggers:
  - `PaymentAllHandlerTest.cls:138-160`: 200 `Transaction__c` + 200 `TransactionLine__c`, reaching `TransactionAll`, `TransactionLineAll`, `BREGTransactionLineTrigger`, `dlrs_TransactionTrigger`
  - `tkt_TicketSharingServiceTest.cls:457` (tkt_Ticket__c)
  - `BREGAmazonSesQueueableTest.cls:202` (Task → `BREGTaskTrigger`)
  - `BREGGoodStandingCheckJobTest.cls:6` (200 Accounts, incidental)
- So about 8 of 61 triggers ever see a 200-record DML. None of these is a named bulk test for `ApplicationTrigger`, `LicenseAll`, `PaymentTrigger` / `PaymentAll` / `BREGPaymentTrigger`, `BREGCaseTrigger`, `CollectionsAllocationTrigger` (52 LOC of logic in the trigger body) or `EarnedCETrigger` (112 LOC in the trigger body).
- Multiple triggers on one object, where execution order is undefined:
  - `pymt__PaymentX__c`: `PaymentAll`, `PaymentTrigger`, `BREGPaymentTrigger`
  - `Account`: `AccountTrigger`, `BREGAccountTrigger`
  - `Case`: `BREGCaseTrigger`, `QualCaseTrigger`
  - `Transaction__c`: `TransactionAll`, `dlrs_TransactionTrigger`
  - `TransactionLine__c`: `TransactionLineAll`, `BREGTransactionLineTrigger`
  - `Application_Cache__c`: `ApplicationCacheTrigger`, `DraftApplicationTrigger`
- No test DML at all was found for `Field_Meta_Data__c` (`sc_FieldMetaDataTrigger`) or `PVLErrorHandler__e` (`PVLErrorHandlerTrigger`). Coverage for these depends on incidental paths (`sc_TestDataFactory` → `sc_AppMetaDataManagement.parseResource`; `ApplicationLogService` publishing events). Unverified. A trigger with 0% coverage blocks production deployment.

**Impact**: Governor-limit defects (SOQL or DML inside loops) in trigger handlers will surface only during data loads, integrations (Talend, IMLCC) or batch runs.

**Recommendation**:
- Add a 200-record insert/update/delete test for each trigger object, starting with Payment, Transaction, TransactionLine, Application, License and Case.
- Move to one trigger per object (coordinate with the architecture report).
- Add explicit tests for `sc_FieldMetaDataTrigger` and `PVLErrorHandlerTrigger` (`EventBus.publish` + `Test.getEventBus().deliver()`).

**Effort**: M

### [HIGH] ID T-08: No LWC Jest tests; the pre-commit gate passes when no tests exist
**Confidence**: Confirmed

**Evidence**:
- 232 LWC bundles under `force-app/main/default/lwc/`, with 0 `__tests__` directories and 0 `*.test.js` files.
- 147 Aura bundles, which have no JS test harness.
- `package.json:41`: lint-staged runs `sfdx-lwc-jest -- --bail --findRelatedTests --passWithNoTests`.
- `jest.config.js` and `@salesforce/sfdx-lwc-jest` are configured.
- `.forceignore:12` excludes `**/__tests__/**`, which is correct, but nothing is there.

**Impact**: UI logic is completely unverified: payment display, portal forms, picklist generators. That includes the LWCs backed by untested Apex (`paymentDisplay`, `generatePicklistOptions`). The pre-commit hook gives the impression that tests pass.

**Recommendation**:
- Remove `--passWithNoTests` once a baseline exists.
- Start with Jest tests for the LWCs that call payment or submission Apex, mocking the Apex with `jest.mock('@salesforce/apex/...')`.
- Add `test:unit:coverage` to CI with an initial threshold.

**Effort**: L

### [MEDIUM] ID T-09: Callouts bypassed instead of mocked
**Confidence**: Confirmed

**Evidence**:
- 14 production classes make HTTP callouts. 23 `HttpCalloutMock` implementations exist and 32 test classes call `Test.setMock`; there is no `System.StubProvider` usage outside `fflib_ApexMocks`.
- 4 callout classes rely on `Test.isRunningTest()` instead of mocks:
  - `IMLCCConnector.cls:122` (its test `IMLCCConnectorTest` also swallows exceptions)
  - `SpringCMConnector.cls:46,91,172,311,327-328,363,403,432,441,452,479,537`
  - `UploadCaseFileToDocSignQueueable.cls:52,63` (`Test.isRunningTest() ? new HttpResponse() : client.send(req)`)
  - `sc_AppMetaDataManagement.cls:76`
- `UploadCaseFileToDocSignQueueable` has no direct test.

**Impact**: Response parsing, status-code handling and error paths for the IMLCC (medical licensing compact), SpringCM and DocuSign integrations never run in tests.

**Recommendation**: Remove the bypasses and add `HttpCalloutMock` classes for success, 4xx/5xx and malformed-body cases. `QualCalloutMock` and `SpringCMApiManagerMock` already exist as patterns to follow.

**Effort**: M

### [MEDIUM] ID T-10: Tests that depend on org data, users or ordering (flakiness)
**Confidence**: Confirmed for the cited lines; Likely for the "flaky in practice" judgement.

**Evidence**:
- *Named org users*:
  - `RealEstateRenewalBatchTest.cls:184` `[... FROM User WHERE Name = 'PaymentConnect Site Guest User' LIMIT 1]`
  - `SecurityPortalTransactionsHelperTest.cls:43,51` (any existing user with profile `DCCA BREG - CustomerCommunityLogin`)
  - `BREGTestDataFactory.cls:385,389` (users by alias and profile)

  These fail in scratch orgs or sandboxes where those users or sites don't exist.
- *Self-skipping tests*: `BREGCaseStatusHandlerBaseTest.cls:363` ("No active country without states found in org metadata; skipping assertion.") and `:2267` ("Queue "Office Services" does not exist in this org. Skipping test."). These pass without testing anything.
- *Production code that picks arbitrary org records in tests*:
  - `TransactionService.cls:30-33` (any other active user in place of the Talend user)
  - `licenseService.cls:984-997` (any active `EmailTemplate`)
  - `ManagedContentController.cls:4-6` (Network named 'dcca')
- *Profiles by name*: 30 test classes query `Profile WHERE Name = '...'` (e.g. `BREGCheckoutControllerTest.cls:55`). This breaks if profiles are renamed.
- *Ordering*: 978 `[SELECT ... LIMIT 1]` queries without `ORDER BY` on business objects, across 161 test classes (e.g. `ApplicationDocReviewControllerTest.cls:9`). Mostly harmless while setup creates a single record, but fragile once setup creates more.
- *Randomness*: 15 uses of `Math.random`/`Crypto.getRandom*` for unique usernames (e.g. `TestDataFactory.cls:6`). There is a small collision risk.
- `System.now`/`Date.today` appear in 223 test classes. That is normal, but combined with T-04 it is a risk.

**Impact**: Tests pass in one org and fail in another, which makes deployments nondeterministic, especially to new sandboxes and scratch orgs.

**Recommendation**:
- Create users in `@TestSetup` using factory methods.
- Query profiles and permission sets by a stable name through one helper.
- Replace self-skipping `Assert.isTrue(true)` with created test data, or `Assert.fail` with a clear message.
- Add `ORDER BY` or select records by a unique key.

**Effort**: M

### [MEDIUM] ID T-11: Little permission, sharing or negative-path testing
**Confidence**: Likely

**Evidence**:
- `System.runAs` appears in only 39 of 526 test classes (7.4%).
- Of 105 production classes with `@AuraEnabled` methods, only 16 have a referencing test that uses `runAs`.
- Of the 40 `@AuraEnabled` classes declared `without sharing`, only 10 are tested under `runAs`.
- Negative-path patterns (asserting inside `catch`, `Assert.fail`, expected-exception flags) appear in about 70 test classes (13%).
- Many "negative" tests only assert `true` in the catch block, e.g. `BREGCaseControllerWithoutSharingTest.cls:57,91` `System.assert(true, 'Caught expected AuraHandledException')`.

**Impact**: This is a public-facing regulatory portal (guest and community users for BREG and CATV). Sharing leaks, missing FLS/CRUD checks and error handling are not covered by regression tests.

**Recommendation**:
- For each portal-facing controller, add tests that run as a community or guest user and assert allowed versus denied access.
- For each validation, add one "expect exception with this message" test.

**Effort**: L

### [MEDIUM] ID T-12: Async jobs started without `Test.startTest/stopTest`, and their results not checked
**Confidence**: Confirmed

**Evidence**:
- 14 test classes call `Database.executeBatch` / `System.enqueueJob` / `System.schedule` with no `Test.startTest()` anywhere:
  - `BatchLicenseResetAuditTest`, `BatchUpdateActiveEmployeeLicenseNumTest`, `DocumentGeneratorProcessBatchTest`, `FixRequirementBatchTest`
  - `GenerateListBuilderPaymentDailyTest`, `GenerateListBuilderPaymentTest`, `GeneratePostCardBatchTest` (`:40-43`), `GenerateRenewalNotificationBatchTest`, `GenerateSubscriberPaymentTest`
  - `InvestigationCallsBatchTest` (`:39-49`), `InvestigationNotesBatchTest`, `LicenseTypeBatchUpdateLicenseTest`, `ScheduledGenerateFilesTest`, `SendLetterToPrinterBatchJobTest` (`:3-26`)
- Most of these also have no assertions.
- Across the suite, 366 of 526 test classes (70%) use `Test.startTest`.

**Impact**: Batch `execute`/`finish` results are never checked. Without `stopTest` there is no point at which the async work is guaranteed complete, so any assertions added later would be unreliable.

**Recommendation**: Wrap async calls in `Test.startTest()/Test.stopTest()` and assert on the records after `stopTest`.

**Effort**: S

### [MEDIUM] ID T-13: Test data factories are fragmented and inconsistently used
**Confidence**: Confirmed

**Evidence**:
- `@isTest` factories and their direct users:

  | Factory | LOC | Referencing test classes |
  |---|---:|---:|
  | `TestDataFactory` | 728 | 96 |
  | `BREGTestDataFactory` | 345 | 36 |
  | `util_closer_TestDataFactory` | 194 | 14 |
  | `QualTestDataFactory` | 615 | 10 |
  | `CATV_TestClassUtility` | 116 | 9 |
  | `tkt_TestDataFactory` | 206 | 5 |
  | `sc_TestDataFactory` | 18 | 4 |
  | `PVLApplicationStatusTestFactory` | 143 | 3 |
  | `TestHelper` | 79 | 1 |

- Production-deployed helpers: `BREGAnnualRobotTestHelper` (184 LOC, 6 users) and `SpringCMTestDataFactory` (120, 1 user).
- Only 179 of 526 test classes (34%) use any factory.
- Hand-built records in test classes: `new Account(` in 213, `new Case(` in 95, `new Contact(` in 83, `new Transaction__c(` in 71, `new pymt__PaymentX__c(` in 56.
- `create*Account*` helpers are defined in 21 different classes and `create*User*` in 11. `createCompletedPayment` is copy-pasted into 9 BREG case-status handler tests.
- `@TestSetup` is used in 294 of 526 test classes (56%).

**Impact**: Adding a required field or validation rule breaks many tests independently, and fixes have to be repeated across hundreds of files. Inconsistent data also makes results hard to compare.

**Recommendation**:
- Pick one factory per domain (PVL, BREG, CATV, Qual, tkt) behind one shared entry point, with a builder-style API.
- Move `BREGAnnualRobotTestHelper` and `SpringCMTestDataFactory` to `@isTest`.
- Migrate the duplicated `createCompletedPayment` and `createUser` helpers.

**Effort**: L

### [MEDIUM] ID T-14: Test-support and dead code deployed as production code, and a production-shaped class marked `@isTest`
**Confidence**: Confirmed

**Evidence**:
- Test-support code shipped as production Apex. It counts in the coverage denominator and can be called in production:
  - `force-app/main/default/classes/BREGAnnualRobotTestHelper.cls:14-27`: `prepareEntity()` selects **any** Account (`LIMIT 1`, no filter) and updates its status and entity type.
  - `BREGBatchInterfaceExtTest.cls` is a production class that exists only for `BREGBatch.getTestMetadata()` (`BREGBatch.cls:209-214`).
  - `SpringCMTestDataFactory.cls`
  - 6 `fflibe_Test*` classes (`fflibe_TestAccountService`, `fflibe_TestAccountsDomain`, `fflibe_TestAccountsSelector`, `fflibe_TestContactService`, `fflibe_TestContactsDomain`, `fflibe_TestContactsSelector`)
- `ApplicationGenerateLicense.cls:18-19` is annotated `@isTest` although it is the "Application Generate License" service. Its whole body is commented out, so it is dead code that is excluded from coverage.
- Test classes with no test methods: `ApplicationGenerateLicenseTest.cls:5-6` (all methods commented out) and `ApplicationRenewalPushThruTest.cls:1-6` (constructor only).

**Impact**:
- A production user or anonymous Apex could run `prepareEntity` and silently modify a real Account.
- The dead classes add confusion and maintenance cost.

**Recommendation**:
- Annotate the helpers `@isTest`. `BREGBatchInterfaceExtTest` can become an inner class of `BREGBatchTest`, injected via `@TestVisible`.
- Delete `ApplicationGenerateLicense`, `ApplicationGenerateLicenseTest` and `ApplicationRenewalPushThruTest`.

**Effort**: S

### [MEDIUM] ID T-15: No coverage baseline, and coverage concentrated on single tests
**Confidence**: Unverified (no coverage data; estimate based on LOC)

**Evidence**:
- `.sfdx/tools/testresults/apex/00Dco000005RPU5EAO/` is empty, and there is no CI pipeline config in the repo.
- 443 of 744 production classes (55,002 LOC, 60% of production LOC) are directly referenced by exactly one test class.
- The largest single-test dependencies, as a share of production LOC (the actual effect on coverage depends on the executable-line count):

  | Production class | LOC | Share | Only test |
  |---|---:|---:|---|
  | `BREGBusinessDetailsController` | 1,708 | 1.87% | `BREGBusinessDetailsControllerTest` |
  | `GenericCreatePaymentCtrl` | 1,033 | 1.13% | `GenericCreatePaymentControllerTest` (zero asserts) |
  | `BREGCaseStatusHandlerAnnuals` | 924 | 1.01% | `BREGCaseStatusHandlerAnnualsTest` |
  | `BREGSearchAndBuyController` | 893 | 0.98% | `BREGSearchAndBuyTest` |
  | `BREGCaseStatusHandlerHelper` | 752 | 0.82% | `BREGCaseStatusHandlerHelperTest` |
  | `QualIntegrationLogger` | 743 | 0.81% | `QualIntegrationLoggerTest` |
  | `fflib_SObjectDomain` | 713 | 0.78% | `fflib_SObjectDomainTEST` (zero asserts) |
  | `BREGAddressProtectionUtils` | 699 | 0.76% | `BREGAddressProtectionUtilsTest` |
  | `LicenseSearchREST` | 671 | 0.73% | `LicenseSearchRESTTest` (zero asserts) |

  The largest shared dependencies are `BREGCaseStatusHandlerBase` (1,742 LOC, 4 tests) and `BREGPaymentController` (1,734 LOC, 2 tests).
- If the three largest single-test dependencies failed together, coverage would fall by roughly 4 points. Deleting the 191 zero-assert test classes (a natural clean-up step) would put up to 18,499 LOC (about 20 points) at risk.

**Impact**: Nobody knows the real margin above 75%. One failing or time-bombed test (T-04), or a well-meant clean-up of padding tests (T-03, T-05), could push a production deployment below the threshold without warning.

**Recommendation**:
- Run `sf apex run test --code-coverage --result-format json` in CI on every PR and store the per-class baseline.
- Alert when org-wide coverage falls within 5 points of 75%, or when any class drops below 75%.
- Before deleting padding tests, replace them with real tests over the same lines.

**Effort**: S

### [LOW] ID T-16: `SeeAllData=true` in Experience Cloud template tests
**Confidence**: Confirmed

**Evidence**: 5 classes, 8 annotations:
- `ChangePasswordControllerTest.cls:5`
- `LightningLoginFormControllerTest.cls:1`
- `ManagedContentControllerTest.cls:3,11,16,21`
- `MicrobatchSelfRegControllerTest.cls:3`
- `MyProfilePageControllerTest.cls:7`

These are standard Salesforce community-template tests; none of the core business tests use `SeeAllData`.

**Impact**: Low. They depend on org Network and user data and can fail in fresh sandboxes.

**Recommendation**: Remove `SeeAllData` and create the required data, or delete the tests if the template controllers are unused.

**Effort**: S

### [LOW] ID T-17: Hard-coded record IDs shared by production code and tests
**Confidence**: Confirmed

**Evidence**:
- Production:
  - `GroupTransactions2.cls:259` and `NewTransaction.cls:179`: `if (accType == '012t0000000PLy1AAG')` (a RecordType Id)
  - `PVL_SC_GeneratePicklistValues.cls:22-23` (`'a3dHv0000000CDYIA2'`)
  - `SiteRegisterController.cls:7` (`'001x000xxx35tPN'`, template placeholder)
- The tests repeat the literal: `GroupTransactions2Test.cls:42`, `NewTransactionTest.cls:36`.
- The other 57 hard-coded IDs in 25 test classes are synthetic fake IDs for mocks (fflib, util_closer). That is acceptable.

**Impact**: The tests only exercise the matching branch because they pass the same literal. In any org where the RecordType Id differs, production behaviour differs from what was tested.

**Recommendation**: Resolve IDs through `Schema...getRecordTypeInfosByDeveloperName()`, and use the same lookup in tests.

**Effort**: S

### [LOW] ID T-18: Legacy test hygiene
**Confidence**: Confirmed

**Evidence**:
- The deprecated `testMethod` keyword is used in 96 test classes.
- 49 test classes (and 121 classes overall) are on API versions below 45. The project `sourceApiVersion` is 67.0.
- 26 test classes contain commented-out assertions (56 in total). 6 of them have no live assertion left: `GenericCreatePaymentControllerTest`, `CleanRenewApplicationJobTest`, `ApplicationGenerateLicenseTest`, `EligibleCandidateLoadTriggerTest`, `LicenseActiveClassesValidationTest`, `LicenseUpdateStatusTest`.
- Poor method names such as `testMethod1` (`GenericCreatePaymentControllerTest.cls:20`) and `tesCreatAccount` (`AccountTriggerTest.cls:3`).
- `LicenseServiceCoverageTest.cls:5-9` documents that coverage tracking is intermittently lost for the old API-v48 `LicenseAllTest`.

**Impact**: Maintenance cost, and odd coverage-tracking behaviour on old API versions.

**Recommendation**:
- Replace `testMethod` with `@isTest` and raise test classes to the current API version in bulk.
- Restore or delete the commented-out asserts.

**Effort**: S

## Appendix

Method notes:
- Parsing used Python over stripped source (comments removed, string contents masked).
- Test methods are methods marked `@isTest` or with the `testMethod` modifier.
- Assertions are `System.assert*`, `Assert.*`, `assert*(`, and fflib `mocks.verify(`.
- Class-to-test mapping uses identifier tokens in test sources, class names inside string literals (dynamic `Type.forName`), trigger DML on the trigger's SObject, and transitive production→production references.
- Script sources are in `/private/tmp/claude-501/dcca06/` (throwaway).

### A0. Coverage table
Not available. `.sfdx/tools/testresults/apex/00Dco000005RPU5EAO/` exists but is empty (directory timestamp 2026-09-29 14:22). No per-class or org-wide coverage could be extracted.

### A1. Production classes with no test path (no direct test reference, not reachable from any tested class or exercised trigger) — 41 classes, 1,508 LOC

| LOC | Class | Kind |
|---:|---|---|
| 400 | force-app/main/default/classes/PVL_ListBuilderFileGenerationBatchJob.cls | Batch, Schedulable |
| 87 | force-app/main/default/classes/GeneratePicklistOptionsCont.cls | AuraEnabled |
| 72 | force-app/main/default/classes/InvocableSpringCMDocGen.cls | Invocable |
| 68 | force-app/main/default/classes/PublicGroupMembershipScheduled.cls | Schedulable |
| 67 | force-app/main/default/classes/PVL_SC_GeneratePicklistValues.cls | AuraEnabled |
| 62 | force-app/main/default/classes/LicenseCreateRecords.cls | Invocable |
| 54 | force-app/main/default/classes/PublicGroupMembershipBatch.cls | Batch |
| 52 | force-app/main/default/classes/EmailService.cls | - |
| 51 | force-app/main/default/classes/AMDInactivationLetterNoticeController.cls | Invocable |
| 45 | force-app/main/default/classes/PaymentDisplayController.cls | AuraEnabled, Payment/Finance |
| 43 | force-app/main/default/classes/Franchise_CheckoutController.cls | Payment/Finance |
| 37 | force-app/main/default/classes/ApplicationNoticeSignatureController.cls | - |
| 37 | force-app/main/default/classes/EmailAlertTriggersSelector.cls | TriggerHandler |
| 30 | force-app/main/default/classes/ApplicationLicenseValidatorController.cls | AuraEnabled |
| 28 | force-app/main/default/classes/DraftApplicationDetailCont.cls | AuraEnabled |
| 28 | force-app/main/default/classes/RecordAccessUtil.cls | AuraEnabled, Invocable |
| 27 | force-app/main/default/classes/CaseTeamMemberAssignmentEmailController.cls | - |
| 26 | force-app/main/default/classes/PVL_EncodingService.cls | REST |
| 26 | force-app/main/default/classes/UserRecordAccessSelector.cls | - |
| 25 | force-app/main/default/classes/EmailTemplatesSelector.cls | - |
| 24 | force-app/main/default/classes/CaseTeamAssignmentDomain.cls | - |
| 23 | force-app/main/default/classes/RecordTypeUtil.cls | Invocable |
| 22 | force-app/main/default/classes/UserRecordAccessesDomain.cls | - |
| 21 | force-app/main/default/classes/LicenseConditionOverdueFinderScheduler.cls | Batch, Schedulable |
| 20 | force-app/main/default/classes/LicenseUpdateTransactionRecords.cls | Invocable, Payment/Finance |
| 19 | force-app/main/default/classes/AssociatedLicensesStatusUpdate.cls | Batch |
| 18 | force-app/main/default/classes/BatchFlagMultipleLicenseForAudit.cls | Invocable |
| 18 | force-app/main/default/classes/PVL_RenewalDependency1wayFlowHelper.cls | Invocable |
| 16 | force-app/main/default/classes/DocuSignAuthController.cls | - |
| 15 | force-app/main/default/classes/PVL_RenewalDependencyFlowHelperAsync.cls | Invocable |
| 8 | force-app/main/default/classes/AuraExceptionUtil.cls | - |
| 6 | force-app/main/default/classes/SpringCMAuthRequest.cls | - |
| 6 | force-app/main/default/classes/SpringCMAuthResponse.cls | - |
| 5 | force-app/main/default/classes/EmailTemplateSelector.cls | - |
| 5 | force-app/main/default/classes/IEmailAlertTriggerService.cls | interface, TriggerHandler |
| 4 | force-app/main/default/classes/IEmailService.cls | interface |
| 3 | force-app/main/default/classes/ICaseTeamMemberService.cls | interface |
| 3 | force-app/main/default/classes/IEmailTemplatesSelector.cls | interface |
| 3 | force-app/main/default/classes/IOrgWideEmailAddressSelector.cls | interface |
| 2 | force-app/main/default/classes/CustomMetadataHelper.cls | - |
| 2 | force-app/main/default/classes/LicenseClassificationDeactivator.cls | - |

### A2. Critical production classes (trigger handler / batch / queueable / @AuraEnabled / REST / Invocable / payment) with NO direct test reference — top 60 by LOC

"indirect" = only reached transitively via another tested class or via trigger DML; "NO PATH" = see A1.

| LOC | Class | Kind | Reach |
|---:|---|---|---|
| 400 | PVL_ListBuilderFileGenerationBatchJob | Batch, Schedulable | NO PATH |
| 234 | DraftApplicationService | AuraEnabled, Queueable | indirect |
| 150 | BREGPaymentTriggerHandler | TriggerHandler, Payment/Finance | indirect |
| 140 | AccountService | TriggerHandler | indirect |
| 130 | SObjectDomainTriggerHandler | TriggerHandler | indirect |
| 109 | TriggerFactory | TriggerHandler | indirect |
| 107 | BREGAccountAffiliationTriggerHandler | TriggerHandler | indirect |
| 100 | sc_SummaryFeeds | AuraEnabled, Payment/Finance | indirect |
| 97 | CATV_InetTriggerHandler | TriggerHandler | indirect |
| 95 | LicenseTypeRenewalEmailSender | Batch | indirect |
| 93 | CATV_UserTriggerHandler | TriggerHandler | indirect |
| 92 | TransactionHandler | TriggerHandler, Payment/Finance | indirect |
| 91 | ExamHandler | TriggerHandler | indirect |
| 87 | GeneratePicklistOptionsCont | AuraEnabled | NO PATH |
| 85 | PaymentDeduplicator | Payment/Finance | indirect |
| 85 | QualCasePayload | Payment/Finance | indirect |
| 77 | ApplicationHandler | TriggerHandler | indirect |
| 74 | InsuranceBondHandler | TriggerHandler | indirect |
| 73 | ApplicationClassificationsService | AuraEnabled | indirect |
| 72 | InvocableSpringCMDocGen | Invocable | NO PATH |
| 69 | ApplicationRequirementService | TriggerHandler | indirect |
| 68 | FileDetailDomain | TriggerHandler | indirect |
| 68 | PublicGroupMembershipScheduled | Schedulable | NO PATH |
| 67 | PVL_SC_GeneratePicklistValues | AuraEnabled | NO PATH |
| 62 | LicenseCreateRecords | Invocable | NO PATH |
| 62 | TransactionDomain | Payment/Finance | indirect |
| 62 | Transaction_Handler | TriggerHandler, Payment/Finance | indirect |
| 58 | FilingHandler | TriggerHandler | indirect |
| 57 | UploadCaseFileToDocSignQueueable | Queueable, Callout | indirect |
| 54 | PublicGroupMembershipBatch | Batch | NO PATH |
| 53 | tkt_TicketTriggerHandler | TriggerHandler | indirect |
| 51 | AMDInactivationLetterNoticeController | Invocable | NO PATH |
| 51 | ExamResultsHandler | TriggerHandler | indirect |
| 48 | InvestigationAllHandler | TriggerHandler | indirect |
| 46 | ApplicationRenewalPushThru | Batch | indirect |
| 46 | TimeandExpensesAllHandler | TriggerHandler | indirect |
| 45 | PaymentDisplayController | AuraEnabled, Payment/Finance | NO PATH |
| 43 | Franchise_CheckoutController | Payment/Finance | NO PATH |
| 38 | AMDInactivationBatch | Batch | indirect |
| 38 | ContentDocumentLinkService | TriggerHandler | indirect |
| 37 | EmailAlertTriggersSelector | TriggerHandler | NO PATH |
| 35 | FileDetailHandler | TriggerHandler | indirect |
| 35 | LicenseRequirementHandler | TriggerHandler | indirect |
| 35 | PVLRenewApp | Queueable | indirect |
| 35 | PVL_VFPDFGenerator | Queueable | indirect |
| 35 | SanctionHandler | TriggerHandler | indirect |
| 30 | ApplicationLicenseValidatorController | AuraEnabled | NO PATH |
| 28 | ContentDocumentLinkHandler | TriggerHandler | indirect |
| 28 | DraftApplicationDetailCont | AuraEnabled | NO PATH |
| 28 | RecordAccessUtil | AuraEnabled, Invocable | NO PATH |
| 28 | TransactionLinePreventDeletion | Payment/Finance | indirect |
| 26 | BREGTransactionTriggerHandler | TriggerHandler, Payment/Finance | indirect |
| 26 | BREGTxnBusInfoTriggerHandler | TriggerHandler | indirect |
| 26 | NotificationHandler | TriggerHandler | indirect |
| 26 | PVL_EncodingService | REST | NO PATH |
| 25 | LicenseConditionHandler | TriggerHandler | indirect |
| 24 | ApplicationClassificationsHandler | TriggerHandler | indirect |
| 24 | ApplicationRequirementHandler | TriggerHandler | indirect |
| 24 | LicenseClassificationHandler | TriggerHandler | indirect |
| 24 | MassScanningLicenseDto | AuraEnabled | indirect |

### A3. Test classes containing ZERO assertions anywhere (191 classes, 377 test methods, 10118 LOC)

Format: ClassName (test methods / LOC). All under force-app/main/default/classes/.

PDGRenewalTest (7/319), LicenseMassScannerControllerTest (19/271), ContractorRenewalPushThroughTest (2/195), RealEstateRenewalTest (5/183), RboRenewalDependencyTest (3/179), TransactionRESTTest (4/176), PestControlRenewalPushThruTest (4/175), MassageTherapyRenewalTest (3/173), TDRFormControllerTest (5/168), ExamResultLoadTest (7/165), CollectionAgencyRenewalTest (4/155), ContractorRenewalTest (3/155), RealEstateRenewalBatchTest (2/152), MVRRenewalTest (6/151), BarberingCosmetologyRenewalTest (7/146), RbEntityRbBrokerRnewalDependencyTest (3/140), CtEntitySolePrmePushThroughBatchTest (1/138), LicenseTerminationTest (3/133), RealEstateLicensesInactivatorBatchTest (1/122), RunReconciliationBatchControllerTest (2/121), fflib_SObjectDomainTEST (2/120), LicenseSearchRESTTest (3/114), ReconciliationBatchJobTest (4/107), VeterinarianRenewalTest (2/106), PaymentRESTTest (1/105), ExamDomainTest (3/102), SpringCMConnectorTest (8/101), TaxClearanceApiHelperTest (1/100), FiscalFormFeedTest (2/99), fflib_SObjectsTest (1/96), GenericCreatePaymentControllerTest (1/95), Test_CaseTeamAssignmentTrigger (3/95), fflib_ApplicationTEST (4/95), CollectionsAllocationDomainTest (4/94), CTCheckoutFormControllerTest (3/93), MVRRenewalPushThruBatchTest (1/93), BarberingCosRenewalPushThruTest (1/85), PVL_PDFGeneratorTest (4/84), AssociatedApplicationSuspenseCheckTest (1/83), PaymentRecwkstCmpControllerTest (2/83), SendTo4GovControllerTest (1/75), PaymentTerminalControllerTest (3/74), MassageTherapyRenewalPushThroughTest (1/73), MotorVehicleIndustryRenewalPushThruTest (1/73), PDGRenewalPushThruTest (1/72), PVL_Pocket_ID_PDFControllerTest (2/71), EarnedCETriggerTest (3/65), IMLCCQueueableTest (4/65), PVL_PaymentReceiptControllerTest (1/65), OracleGLBatchloadFlowServiceTest (2/64), PaymentCutOffProcessingControllerTest (5/64), CtRmePushThroughBatchTest (1/62), LicenseTaxClearancerControllerTest (4/62), PVL_SelectorTest (1/61), WebDocumentExtTest (1/61), CE_FutureCoursesControllerTest (2/60), LicenseClassificationDomainTest (1/60), PVL_ListBuilderReceiptControllerTest (1/58), BatchFlagLicenseBeforeAuditTest (4/55), ExamResultsServiceTest (2/53), ContentDocumentLinkTriggerTest (2/52), PVL_SendPVLEmailsTest (1/52), LicenseCurrentAndValidFinderTest (1/51), PaymentXBatchProgressTest (1/49), DocumentGeneratorProcessBatchTest (1/48), GenerateRenewalNotificationBatchTest (1/48), TransactionRefundAuthFormControllerTest (1/48), AgeDaysSumCalculatorTest (1/47), RecwkstPdfControllerTest (1/47), SuspenseDeletionBatchJobTest (1/47), LicenseUpdateStatusTest (2/46), SEBCasePenaltyBatchTest (2/46), GeneratePostCardBatchTest (1/45), LicenseSelectorTest (7/45), TaxClearanceCheckBatchTest (3/45), PVLProcessFlowTest (2/44), ForfeitureLicenseTest (1/43), IMLCCConnectorTest (4/43), SpringCMItemTest (1/43), fflib_SObjectUnitOfWorkTEST (1/43), BREGMetadataDeployCallbackTest (2/42), LicenseNoticeSignatureControllerTest (1/42), CertificateRequestTriggerTest (3/41), LicenseTypeExpireTest (3/41), PaymentAutoCloserMonitorControllerTest (2/41), WebMultiDocumentExtTest (1/41), MassScanningLicenceControllerTest (4/39), EligibleCandidateLoadTriggerTest (1/38), OnlineRenewalControllerTest (1/38), PVL_Wall_Certificate_PDFControllerTest (1/38), D1D2DependencyRefundNoticeTest (2/36), InvestigationNotesControllerTest (2/36), LicenseCreateRecordsTest (2/36), PVL_SendListBuilderEmailsTest (1/36), PVL_SendListBuilderURLEmailsTest (1/36), UploadCaseFileToDocSignQueueableTest (1/36), ApplicationBatchJobTest (1/35), CLMFileFixControllerTest (2/35), CourseStatusUpdateBatchTest (2/35), PVL_ListBuilderFileDeletionBatchJobTest (1/35), TransactionPaymentCoverSheetExtCtrlTest (1/35), PaymentAdjustmentControllerTest (1/33), InvestigationCallsControllerTest (2/32), SendLetterToPrinterBatchJobTest (1/31), AssociatedLicenseSelectorTest (1/30), ClearAuditInformationTest (2/30), InsuranceNotificationBatchTest (2/30), RequirementsDomainTest (1/30), BatchLicenseResetAuditTest (1/29), InvestigationNotesBatchTest (2/29), StatusHistoryAuxTest (1/29), AttestToMailingNoticesBatchTest (1/28), DeleteUnPaidAppsBatchTest (2/28), LicenseTypeSelectorTest (4/27), LicenseTypeTriggerTest (1/27), SEBSearchControllerTest (3/27), ScheduledGenerateFilesTest (1/27), LicenseHistoryDomainTest (1/26), LicenseNumberAssignmentDomainTest (1/26), A1LicenseMassScannerControllerTest (3/25), ApplicationRecordsCreationTest (4/25), CEPassCertificateControllerTest (2/25), CleanRenewApplicationJobTest (1/25), InvestigationCallsBatchTest (2/25), NotificationTriggerTest (1/25), CECourseRosterControllerTest (1/24), CollectionsAllocationTriggerTest (1/24), DisplayBPIDControllerTest (1/24), LicenseTypeRenewalEmailSenderTest (1/24), RelatedListTreeViewerControllerTest (4/24), sc_ApplicationCacheServiceTest (2/24), AssociatedInsuranceSuspenseBatchTest (1/23), AttestToMailingNoticesControllerTest (2/23), LicenseConditionTriggerTest (2/23), LicenseUpdateTransactionRecordsTest (1/22), ManagedContentControllerTest (4/22), RenewalLicenseMassScannerControllerTest (3/22), CaseTeamMemberServiceTest (1/21), ExamNoticeControllerTest (1/21), PVL_PrelicensePassCertControllerTest (1/21), ScreenSpringGenTest (1/21), AccountRecordsSearchCreateTest (4/20), CreateRecordContTest (1/20), GenerateRenewalApplicationBatchTest (1/20), LicenseDomainTest (1/20), ScheduledClearEarnedCEBatchTest (2/20), VFFileServiceTest (1/20), ApplicationDocEmailControllerTest (1/19), BatchChargeBackTest (2/19), ContentDocumentTriggerTest (1/19), LicenseTypeBatchUpdateLicenseTest (1/19), PullFileDetailFilesControllerTest (1/19), AppDeficiencyEmailAppReqsControllerTest (1/18), LicenseActiveClassesValidationTest (1/18), PVL_DoorCertControllerTest (1/18), ApplicationDocCreateControllerTest (1/17), ApplicationDocReviewControllerTest (1/17), CEPrelicCourseRosterControllerTest (1/17), InsuranceStatusBatchTest (2/17), LicenseEmployerAddressUpdateBatchTest (1/17), LicenseScannerResultControllerTest (1/17), AssociatedLicenseExpireTest (1/15), BatchSummaryPDFTest (1/15), LicensePostCardControllerTest (1/15), WithoutSharingDmlHelperTest (1/15), AssociatedLicenseDomainTest (1/14), GlobalUtilitiesTest (1/14), LicNoticeClassificationsTblCtrlTest (1/14), sc_AppMetaDataManagementTest (1/14), BatchUpdateActiveEmployeeLicenseNumTest (1/13), CertificateOfInsuranceControllerTest (1/13), FixRequirementBatchTest (1/13), AccountTriggerTest (1/12), FilingControlerTest (1/12), WebDocumentMutiExtTest (1/12), IMLCCBatchJobTest (1/11), IMLCCPushBatchJobTest (1/11), PaymentXBatchSchedulerTest (1/11), TravelApprovalTriggerTest (1/11), DocusignNavigationTest (1/10), RelatedListControllerTest (1/9), dlrs_AllegationTest (1/9), dlrs_LegalActionTest (1/9), dlrs_TransactionTest (1/9), TransactionServiceTest (1/8), sc_CardMetaDataSelectorTest (1/8), BarCodeUtilTest (1/7), CounterServiceTest (1/7), EligibleCandidateLoadServiceTest (1/7), sc_CardCacheSelectorTest (1/7), JVFormControllerTest (1/6)

### A4. `Test.isRunningTest()` in production code, by category (173 occurrences, 85 classes + 1 trigger `force-app/main/default/triggers/PVLProcessTrigger.trigger:141`)

Auto-categorised by regex on the surrounding 4 lines; "OTHER" was hand-sampled and is mostly error-message stubbing, test-metadata substitution, or skipping async/flows. Format: Class:line. All under force-app/main/default/classes/.

- **FORCED_BRANCH (|| isRunningTest)** (14 occurrences / 9 classes): BREGAccountStatus2DissolutionBatch:185, BREGAnnualRobotRules:149, BREGCaseHistoryBatch:37, IMLCCSendEmailQueueable:148, MotorVehicleIndustryRenewal:170, PDGRenewal:173, PDGRenewal:243, PDGRenewal:329, PDGRenewal:384, PaymentCutOffProcessingController:30, PestControlRenewal:130, PestControlRenewal:156, PestControlRenewalPushThru:210, PestControlRenewalPushThru:236
- **FAKE DATA injected in prod code** (15 occurrences / 13 classes): BREGHelpCenterController:35, BREGPortalUtils:267, DocuSignAPI:12, DocuSignAPI:26, IMLCCConnector:32, IMLCCPushBatchJob:26, IMLCCQueueable:142, IMLCCQueueable:321, ManagedContentController:4, MassScanningLicenceController:229, PVL_ListBuilderFileDeletionBatchJob:32, PVL_ListBuilderFileGenerationBatchJob:44, QualRetrySchedulable:114, ReconciliationBatchJob:61, SpringCMApiEnvironment:17
- **SKIP DML in tests** (5 occurrences / 5 classes): AMDInactivationBatch:57, IMLCCQueueable:264, PaymentXBatch:370, RealEstateLicensesInactivatorBatch:172, util_closer_LogCleanupBatch:158
- **SKIP ASYNC/FLOW in tests** (23 occurrences / 13 classes): BREGAgentSearchBatch:141, BREGBatch:138, BREGCaseController:263, BREGCaseController:308, BREGCaseHistoryBatch:74, BREGCaseHistoryBatch:109, BREGCaseHistoryBatch:117, BREGCaseHistoryBatch:123, BREGCaseHistoryBatch:135, BREGCaseStatusHandlerMerger:204, BREGCaseTriggerHandler:1184, BREGCaseTriggerHandler:1191, BREGDelinquencyStatusUpdateBatchJob:567, BREGEntityListBuilderBatch:153, BREGEntityListWeeklyJob:46, BREGExternalAPIUploadScannedDocument:107, BREGTransactionLineTriggerHandler:114, BREGTransactionLineTriggerHandler:132, BREGTransactionLineTriggerHandler:509, IMLCCQueueable:282, IMLCCQueueable:383, IMLCCQueueable:390, RealEstateLicensesInactivatorBatch:165
- **SKIP EMAIL** (6 occurrences / 5 classes): ApplicationService:728, BREG_SendBREGEmails:287, IMLCCSendEmailQueueable:223, IMLCCSendEmailQueueable:247, RealEstateLicensesInactivatorBatch:215, licenseService:1012
- **CALLOUT bypass** (30 occurrences / 10 classes): BREGAgentSearchBatch:58, BREGEntityListBuilderBatch:56, BREGEntityListWeeklyJob:38, BREGExternalAPIUploadDocument:83, BREGExternalAPIUploadScannedDocument:44, CATV_DashboardController:100, IMLCCConnector:40, IMLCCConnector:46, IMLCCConnector:59, IMLCCConnector:65, IMLCCConnector:78, IMLCCConnector:84, IMLCCConnector:97, IMLCCConnector:103, IMLCCConnector:122, SpringCMConnector:46, SpringCMConnector:172, SpringCMConnector:311, SpringCMConnector:327, SpringCMConnector:328, SpringCMConnector:363, SpringCMConnector:403, SpringCMConnector:432, SpringCMConnector:441, SpringCMConnector:452, SpringCMConnector:479, SpringCMConnector:537, UploadCaseFileToDocSignQueueable:52, UploadCaseFileToDocSignQueueable:63, sc_AppMetaDataManagement:76
- **TEST HOOK (injectable override)** (9 occurrences / 5 classes): BREGPaymentController:401, QualConfigSelector:27, QualConfigSelector:67, QualConfigSelector:77, QualConfigSelector:157, QualUjetSessionTriggerHandler:30, SObjectDomainTriggerHandler:34, SiteRegisterController:57, SiteRegisterController:62
- **PDF/Blob stub** (35 occurrences / 28 classes): A1LicenseMassScannerController:52, ApplicationDocCreateController:17, ApplicationService:703, BREGBusinessDetailsController:2251, BREGEntityListWeeklyJob:65, BREGExternalAPIGetDocument:49, BREGExternalAPIGetStamps:61, BREGPaymentController:270, CATV_DashboardController:97, CATV_DashboardController:146, CertificateRequestService:29, CertificateRequestService:42, D1D2DependencyRefundNotice:200, D1D2DependencyRefundNotice:244, DocumentGeneratorProcessBatch:71, DocumentGeneratorProcessBatch:105, FiscalFormsController:27, FiscalFormsController:55, GeneratePostCardBatch:94, GenerateRenewalApplicationBatch:37, GenerateRenewalNotificationBatch:132, InvestigationCallsBatch:32, InvestigationNotesBatch:32, LicenseMassScannerController:48, LicenseSearchREST:46, PVL_PDFGenerator:321, PVL_PDFGenerator:438, PVL_SendListBuilderEmails:77, PVL_SendPVLEmails:168, PVL_VFPDFGenerator:7, PaymentRecwkstCmpController:66, RenewalLicenseMassScannerController:58, TDRFormController:111, TDRFormController:118, VFFileService:20
- **OTHER** (36 occurrences / 25 classes): AMDInactivationBatch:35, AMDInactivationBatch:42, BREGAmazonSesQueueable:199, BREGBatch:12, BREGDBEDTReportScheduler:103, BREGNotificationsHandler:505, BREGPaymentController:1359, BREGSearchAndBuyController:146, CATV_DashboardController:148, CLMFileFixController:12, DocusignAuthProvider:87, IMLCCConnector:47, IMLCCConnector:50, IMLCCConnector:66, IMLCCConnector:69, IMLCCConnector:85, IMLCCConnector:88, IMLCCConnector:104, IMLCCConnector:107, IMLCCQueueable:275, IMLCCSendEmailQueueable:162, PVL_SendListBuilderEmails:84, PVL_SendPVLEmails:297, QualCallSessionQueueable:140, QualCalloutQueueable:190, QualConfigSelector:63, RecwkstPdfController:25, SObjectDomainTriggerHandler:16, SpringCMConnector:91, TransactionService:30, fflib_SObjectDomain:66, fflib_SObjectDomain:456, fflibe_Application:23, licenseService:984, licenseService:996, licenseService:1086
### A5. Zero-assert test classes covering triggers, batches or payments (70 classes; name-matched)
AccountTriggerTest, ApplicationBatchJobTest, AssociatedInsuranceSuspenseBatchTest, AttestToMailingNoticesBatchTest, BatchChargeBackTest, BatchFlagLicenseBeforeAuditTest, BatchLicenseResetAuditTest, BatchSummaryPDFTest, BatchUpdateActiveEmployeeLicenseNumTest, CTCheckoutFormControllerTest, CertificateRequestTriggerTest, CollectionAgencyRenewalTest, CollectionsAllocationDomainTest, CollectionsAllocationTriggerTest, ContentDocumentLinkTriggerTest, ContentDocumentTriggerTest, CourseStatusUpdateBatchTest, CtEntitySolePrmePushThroughBatchTest, CtRmePushThroughBatchTest, D1D2DependencyRefundNoticeTest, DeleteUnPaidAppsBatchTest, DocumentGeneratorProcessBatchTest, EarnedCETriggerTest, EligibleCandidateLoadTriggerTest, FiscalFormFeedTest, FixRequirementBatchTest, GeneratePostCardBatchTest, GenerateRenewalApplicationBatchTest, GenerateRenewalNotificationBatchTest, GenericCreatePaymentControllerTest, IMLCCBatchJobTest, IMLCCPushBatchJobTest, InsuranceNotificationBatchTest, InsuranceStatusBatchTest, InvestigationCallsBatchTest, InvestigationNotesBatchTest, LicenseConditionTriggerTest, LicenseEmployerAddressUpdateBatchTest, LicenseTypeBatchUpdateLicenseTest, LicenseTypeTriggerTest, LicenseUpdateTransactionRecordsTest, MVRRenewalPushThruBatchTest, NotificationTriggerTest, OracleGLBatchloadFlowServiceTest, PVL_ListBuilderFileDeletionBatchJobTest, PVL_PaymentReceiptControllerTest, PaymentAdjustmentControllerTest, PaymentAutoCloserMonitorControllerTest, PaymentCutOffProcessingControllerTest, PaymentRESTTest, PaymentRecwkstCmpControllerTest, PaymentTerminalControllerTest, PaymentXBatchProgressTest, PaymentXBatchSchedulerTest, RealEstateLicensesInactivatorBatchTest, RealEstateRenewalBatchTest, ReconciliationBatchJobTest, RunReconciliationBatchControllerTest, SEBCasePenaltyBatchTest, ScheduledClearEarnedCEBatchTest, SendLetterToPrinterBatchJobTest, SuspenseDeletionBatchJobTest, TaxClearanceCheckBatchTest, Test_CaseTeamAssignmentTrigger, TransactionPaymentCoverSheetExtCtrlTest, TransactionRESTTest, TransactionRefundAuthFormControllerTest, TransactionServiceTest, TravelApprovalTriggerTest, dlrs_TransactionTest.

**Payment/finance production classes whose only direct test references come from zero-assert tests** (LOC):
- GenericCreatePaymentCtrl 1033, TransactionService 414, ReconciliationBatchJob 293, D1D2DependencyRefundNotice 219
- PaymentRecwkstCmpController 151, CollectionsAllocationDomain 128, CTCheckoutFormController 118, TransactionREST 114
- PVL_PaymentReceiptController 62, PaymentREST 60, PaymentTerminalController 50, TransactionPaymentCoverSheetExtCtrl 45, PaymentCutOffProcessingController 44
- TransactionRefundAuthFormController 41, RunReconciliationBatchController 39, PaymentAutoCloserMonitorController 29, PaymentXBatchProgress 23, PaymentAdjustmentController 23, PVL_ListBuilderReceiptController 14, PaymentXBatchScheduler 6

### A6. Test classes with hard-coded dates in 2025–2027 (possible time bombs)
| Test class | # dates 2025-27 | Sample lines |
|---|---:|---|
| BREGWebFilingInfo2CaseTest | 19 | 23, 24, 37, 38, 47, 48 |
| ApplicationTriggerTest | 14 | 500, 501, 518, 571, 747, 748 |
| InsuranceBondDomainTest | 11 | 77, 83, 94, 97, 115, 119 |
| ApplicationHcRenewalValidationTest | 9 | 30, 38-41, 52-67 |
| BREGAccountAffiliationTriggerHandlerTest | 4 | 49, 112, 124, 211 |
| BREGAnnualRollOverJobTest | 4 | 102-103, 125, 162 (**Confirmed failure from 2027-01-01**) |
| BREGXMLGeneratorTest | 3 | 11, 40, 63 |
| BREGAmazonSesAnnualsDataProviderTest | 1 | 10 |
| BREGBatchCronInterpreterTest | 1 | 76 |
| BREGCaseStatusHandlerTNTMSMRenewalTest | 1 | 17 |
| BREGCaseTriggerHandlerTest | 1 | 257 |

Line numbers are approximate (±few lines) for rows other than BREGAnnualRollOverJobTest, InsuranceBondDomainTest, ApplicationHcRenewalValidationTest and ApplicationTriggerTest, which were verified by reading.

### A7. SeeAllData=true
| File | Line(s) |
|---|---|
| force-app/main/default/classes/ChangePasswordControllerTest.cls | 5 |
| force-app/main/default/classes/LightningLoginFormControllerTest.cls | 1 (class-level) |
| force-app/main/default/classes/ManagedContentControllerTest.cls | 3, 11, 16, 21 |
| force-app/main/default/classes/MicrobatchSelfRegControllerTest.cls | 3 |
| force-app/main/default/classes/MyProfilePageControllerTest.cls | 7 |

### A8. Test practice prevalence (526 test classes with test methods)
| Practice | Classes | % |
|---|---:|---:|
| `Test.startTest` | 366 | 70% |
| `@TestSetup` | 294 | 56% |
| Uses a shared factory | 179 | 34% |
| Async execution (`executeBatch`/`enqueueJob`/`schedule`) | 96 | 18% |
| Negative-path pattern | ~70 | 13% |
| `System.runAs` | 39 | 7% |
| `Test.setMock` | 32 | 6% |
| fflib ApexMocks | 21 | 4% |
| 200+ record loop | 9 | 2% |
| `SeeAllData=true` | 5 | 1% |
