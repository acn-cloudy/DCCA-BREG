# DCCA Salesforce DX Project

> **Analysis folder:** [`analysis/`](analysis/) — full static code-review reports generated 2026-09-30. Read these before making significant changes. Health score: **31/100** (P0 issues open).

## Project Overview

**DCCA** (Department of Commerce and Consumer Affairs — Hawaii) is a large-scale Salesforce DX project hosting multiple government regulatory and licensing programs on a single shared Salesforce org.

- **Org alias:** `DCCA`
- **Active sandbox:** `hi-dcca--iscodfull.sandbox.my.salesforce.com`
- **Salesforce API version (source):** 67.0 (individual components range v31–v66)
- **Namespace:** none
- **Analysis date:** 2026-09-30 (static analysis only — no org runtime data)

## Directory Structure

```
DCCA/
├── force-app/main/default/        # All Salesforce metadata (source of truth)
│   ├── classes/                   # 1,288 Apex classes (730 prod / 558 test)
│   ├── triggers/                  # 61 Apex triggers
│   ├── lwc/                       # 233 Lightning Web Components
│   ├── aura/                      # 147 Aura components (legacy)
│   ├── flows/                     # 266 flows (233 active)
│   ├── objects/                   # 233 custom objects + standard obj metadata
│   ├── pages/                     # 167 Visualforce pages
│   ├── profiles/                  # 96 profiles
│   ├── permissionsets/            # 140 permission sets
│   ├── permissionsetgroups/       # 42 permission set groups
│   ├── sharingRules/              # ~300+ sharing rules
│   ├── staticresources/           # ~80 static resources
│   ├── flexipages/                # 50+ Lightning pages
│   ├── globalValueSets/           # 24 shared picklists
│   └── remoteSiteSettings/        # 31 entries (several stale/risky — see Security)
├── analysis/                      # Generated code-review reports (read-only reference)
│   ├── 00-executive-summary.html
│   ├── 00-master-report.md        # PRIMARY reference — 66 consolidated findings
│   ├── 01-architecture.md
│   ├── 02-apex-security.md
│   ├── 03-lwc-aura.md
│   ├── 04-automation.md
│   ├── 05-access-control.md
│   ├── 06-test-quality.md
│   └── remediation-backlog.csv    # Prioritized backlog (P0–P3)
├── config/
│   └── project-scratch-def.json   # Scratch org definition
├── manifest/
│   └── package.xml                # Full metadata retrieval manifest
├── scripts/
│   ├── apex/hello.apex
│   └── soql/account.soql
├── sfdx-project.json              # SFDX project manifest (API 67.0)
├── package.json                   # npm scripts for lint/test/format
├── jest.config.js                 # LWC Jest config (no tests exist yet)
├── eslint.config.js               # ESLint for Aura + LWC JS
├── .prettierrc                    # Prettier config (Apex + XML plugins)
└── .mcp.json                      # MCP server config (Salesforce CLI + hosted)
```

## Common Commands

```bash
# ── Deploy / retrieve ─────────────────────────────────────────────────────────
sf project deploy start
sf project retrieve start
sf project deploy start --source-dir force-app/main/default/classes/MyClass.cls

# ── Apex testing ──────────────────────────────────────────────────────────────
sf apex run test --test-level RunLocalTests
sf apex run test --class-names MyClassTest --result-format human

# ── Org management ────────────────────────────────────────────────────────────
sf org open                          # open connected org in browser
sf org login web                     # authenticate interactively
sf org display                       # show org alias/connection details

# ── LWC testing (Jest) ────────────────────────────────────────────────────────
npm test                             # alias for test:unit
npm run test:unit:coverage           # with coverage report
npm run test:unit:watch              # watch mode

# ── Linting & formatting ──────────────────────────────────────────────────────
npm run lint                         # ESLint all Aura + LWC JS
npm run prettier                     # format all Apex/HTML/JS/XML/JSON
npm run prettier:verify              # check-only (for CI)
```

The pre-commit Husky hook runs Prettier, ESLint, and LWC Jest automatically on changed files via `lint-staged`.

## MCP Servers

Configured in [.mcp.json](.mcp.json):
- **`sf-dx`** — Local Salesforce CLI MCP, targeting org alias `iscodfull`. Toolsets: `metadata, data, code-analysis, lwc-experts, testing, scale-products`
- **`salesforce-hosted`** — Remote Salesforce platform MCP at `https://api.salesforce.com/platform/mcp/v1/sandbox/sobject-all` for the iscodfull sandbox

## Domain Map (16 Bounded Contexts)

| Domain | Prefix | Prod Classes | Prod LOC | Key Objects |
|--------|--------|-------------|----------|-------------|
| **Business Registration** | `BREG` / `breg_*` | 152 | 43,798 | `breg_*__c` (~40 objects), Case, Account, `breg_Transaction__c` |
| **PVL Licensing core** | `PVL` / `pvl` | 185 | 22,911 | `Application__c`, `License__c`, `LicenseType__c`, `AssociatedLicense__c`, `Exam*__c`, `InsuranceBond__c`, `Notification__c`, `PVLProcess__e` |
| **PVL Renewals** | board-specific | 48 | 7,774 | `Application__c`, `License__c` |
| **Payments & Finance** | — | 71 | 10,953 | `Transaction__c`, `TransactionLine__c`, `pymt__PaymentX__c`, `CollectionsAllocation__c`, `Deposits__c` |
| **Docs & Integrations (SpringCM/DocuSign)** | — | 62 | 4,756 | `FileDetails__c`, `ContentDocumentLink`, `SpringCLM_Session__c` |
| **Enforcement** | `SEB` / `RICO` | 18 | 1,248 | `Investigation__c`, `SEBCase__c`, `Sanction__c`, `Filing__c`, `TravelApproval__c` |
| **Qualtrics CX** | `qual_` | 15 | 4,710 | `qual_Integration_Log__c`, `qual_Config__mdt` |
| **Case Auto-Close** | `util_closer_` | 17 | 4,117 | `util_closer_*__c/__mdt` |
| **Internal Ticketing** | `tkt_` | 6 | 1,901 | `tkt_Ticket__c`, `tkt_Ticket_Comment__c` |
| **Dynamic Form Builder** | `sc_` | 33 | 1,748 | `Application_Meta_Data__c`, `Card_Meta_Data__c`, `Field_Meta_Data__c` |
| **Cable TV portal** | `CATV` / `catv_` | 9 | 933 | `INET_Request__c`, `Account_Access_Request__c` |
| **IMLCC** | — | 5 | 1,010 | `IMLCCSettings__c`, `Application_Log__c` |
| **CaseTeam (fflib)** | — | 20 | 717 | `CaseTeam__c`, `CaseTeamMember__c` |
| **Communities / Identity** | — | 12 | 1,040 | User, Contact |
| **Shared framework / utilities** | — | 36 | 3,063 | `OrgConfiguration__c`, `ProcessSwitches__c`, `TriggerFactory` |
| **Vendor: fflib** | `fflib*` / `fflibe_*` | 41 | 10,580 | — (used only by CaseTeam) |
| **Total** | | **730** | **121,259** | |

### Cross-Domain Coupling (shared objects)
The real coupling is via **shared objects** — not class imports:
- `Transaction__c` — written by BREG (5 classes), PVL core (6), Payments (27)
- `TransactionLine__c` — written by BREG (15), PVL (4), Payments (20)
- `pymt__PaymentX__c` — written by BREG (7), PVL (9), Payments (27)
- `Account` — written by BREG (68), PVL (13), Payments (10)
- `Case` — written by BREG (70), Qual (3), util_closer (3)

## Trigger Frameworks (5 Coexist — Match the Domain)

When adding trigger logic, **match the existing framework for the domain you're in**. Do not mix frameworks.

| Framework | Domain | Key Files |
|-----------|--------|-----------|
| `TriggerFactory` + `ITrigger` + `SObjectDomain` | PVL (23 handlers) | `TriggerFactory.cls`, `ITrigger.cls`, `SObjectDomain.cls` |
| `BREGBaseTriggerHandler` with static recursion guard | BREG (10 handlers) | `BREGBaseTriggerHandler.cls` |
| `fflib_SObjectDomain.triggerHandler` | CaseTeam (1) | `SObjectDomainTriggerHandler.cls` |
| Static-method handlers | Qual, tkt_, CATV, Transactions | `QualCaseTriggerHandler`, `tkt_TicketTriggerHandler`, etc. |
| Inline trigger body logic | Enforcement, misc | `PVLProcessTrigger`, `EarnedCETrigger`, etc. |

### Bypass Mechanisms (7 total)
1. `OrgConfiguration__c.DisableTriggers__c` / `DisableAccountTriggers__c` / `DisableLicenseTriggers__c`
2. `BREG_Setting__c.Global_Data_Migration_Triggers_Disabled__c`
3. `ProcessSwitches__c` (via `SObjectDomainTriggerHandler`)
4. `tkt_Trigger_Control__c`
5. `util_closer_Settings__c`
6. Static flags: `TriggerHelper.cls`, `TriggerUtils.cls`, `SanctionService.skipTrigger`, `PaymentDeduplicator.disableTrigger`
7. Integration-profile check: `GlobalUtilities.getIntegrationProfileId()`

### Objects with Multiple Triggers (watch for ordering issues)
| Object | Triggers |
|--------|----------|
| `pymt__PaymentX__c` | `PaymentAll`, `PaymentTrigger`, `BREGPaymentTrigger` (all active, API v43) |
| Account | `AccountTrigger` (PVL TriggerFactory) + `BREGAccountTrigger` (BREG) |
| Case | `BREGCaseTrigger` + `QualCaseTrigger` |
| `Transaction__c` | `TransactionAll` + `dlrs_TransactionTrigger` |
| `TransactionLine__c` | `TransactionLineAll` + `BREGTransactionLineTrigger` |
| `Application_Cache__c` | `ApplicationCacheTrigger` + `DraftApplicationTrigger` |

## Key Apex Classes

### God Classes (over 1,000 LOC — high regression risk, change carefully)
| Class | LOC | Sharing | `@AuraEnabled` methods | Notes |
|-------|-----|---------|------------------------|-------|
| `BREGCaseStatusHandlerBase` | 2,288 | without | — | Base for 30 form-code–driven status handlers |
| `BREGBusinessDetailsController` | 2,265 | without | 41 | Portal LWC facade for entity/case/TN/TM details |
| `BREGPaymentController` | 1,992 | without | 61 | BREG checkout, fees, transaction lines, receipts |
| `BREGUtils` | 1,490 | — | — | Grab-bag; fan-in 39 (highest in org) |
| `BREGNameClearanceController` | 1,415 | with | 33 | Business-name availability search |
| `GenericCreatePaymentCtrl` | 1,309 | without | 83 | Generic layout-driven record create + payment |
| `BREGCaseTriggerHandler` | 1,278 | — | — | Case trigger handler |
| `licenseService` | 1,181 | — | — | License trigger service |

### Highest Fan-In Classes (changing these breaks the most things)
`BREGUtils` (39) · `SObjectDomain` (36) · `BREGTransactionUtils` (32) · `BREGCaseStatusHandlerBase` (31) · `SpringCMConnector` (30) · `ITrigger` (24) · `ApplicationDomain` (23) · `SpringCMDocument` (23) · `ApplicationSelector` (22) · `LicenseDomain` (21)

### Key Domain Classes by Area

**BREG (entry points):**
- `BREGCaseTriggerHandler` — Case trigger handler (file numbers, contact, status dispatch)
- `BREGAccountTriggerHandler` — Account trigger handler (creates transactions, affiliations)
- `BREGPaymentController` — `@AuraEnabled` checkout API (critical security issues — see below)
- `BREGPortalUtils` — Portal helpers (user type, form config, banners)
- `BREGRegistrationFormController` — Form save/upsert (mass assignment vulnerabilities)
- `BREGSearchAndBuyController` — Public entity search and document purchase
- `BREGCaseStatusHandlerBase` + 30 subclasses — Form-code–driven Case status state machine

**PVL (entry points):**
- `TriggerFactory` — Central dispatcher (closed if/else registry — add new handlers here)
- `ApplicationHandler` / `ApplicationService` / `ApplicationDomain` / `ApplicationSelector` — Application lifecycle
- `licenseService` — License trigger service (postcards, notices, suspensions, AMD inactivation)
- `PVLProcessTrigger` — Platform-event "command bus" (critical reliability issues — see below)

**Payments:**
- `PaymentREST` / `TransactionREST` — REST endpoints (`/CreatePayment`, `/CreateTransaction`) — **critical: accessible to guest profiles**
- `NewTransaction` / `CreateTransaction` — Transaction creation utilities
- `OracleGLBatchloadFlowService` — Oracle GL batch integration

**Integrations:**
- `SpringCMConnector` — DocuSign CLM client (OAuth refresh, session cache) — **fan-in 30, critical security issues**
- `SpringCMApiManager` / `SpringCMFileHelper` — Two additional CLM clients (3 total for same system)
- `DocuSignAPI` — DocuSign eSignature via Named Credentials (preferred pattern)
- `TaxClearanceApiHelper` — Hawaii Tax Clearance API (Basic auth from custom setting)
- `QualCalloutService` — Qualtrics REST callout
- `IMLCCConnector` — Interstate Medical Licensure Compact

## Integration Points

| System | Classes | Auth Pattern | Notes |
|--------|---------|--------------|-------|
| DocuSign CLM / SpringCM | `SpringCMConnector`, `SpringCMApiManager`, `SpringCMFileHelper` | Secrets in `SpringCLMSetting__mdt` (Public CMT) | 3 separate clients; `SpringCMConnector:399` hard-codes UAT endpoint |
| DocuSign eSignature | `DocuSignAPI` | Named Credentials `callout:DocuSign*` | Preferred pattern; JWT key in `breg_DocuSign_Auth__mdt` |
| Oracle GL | `OracleGLBatchloadFlowService` | Named Credential `callout:OracleGL` | |
| Qualtrics | `QualCalloutService` | `qual_Integration_Settings__c.qual_Api_Token__c` | Config in `qual_Config__mdt` |
| IMLCC | `IMLCCConnector` | Named Credential `callout:IMLCC` | Config in `IMLCCSettings__c` |
| Hawaii Tax Clearance | `TaxClearanceApiHelper` | Basic auth from `TaxClearanceApi__c` (hierarchy setting) | Prod + staging endpoints |
| Amazon SES | `BREGAmazonSesEmailService` | Named Credential `callout:Amazon_SES` | Bulk email |
| Google CCAI | — | — | CSP trusted sites for voice/chat |
| Chargent / PaymentConnect (Linvio) | `PaymentREST`, `TransactionREST`, `pymt__*` managed package | — | In-person + online payments |

### Named Credential Usage (good pattern — follow this)
```
callout:Amazon_SES     → BREGAmazonSesEmailService
callout:IMLCC          → IMLCCConnector
callout:OracleGL       → OracleGLBatchloadFlowService
callout:UI_API_Credentials → sc_AppMetaDataManagement (Tooling API self-callout)
callout:DocuSign*      → DocuSignAPI
```
**Bad pattern (do not copy):** Storing secrets in Public Custom Metadata (`Org_Credential__mdt`, `SpringCLMSetting__mdt`, `breg_DocuSign_Auth__mdt`) and custom settings (`TaxClearanceApi__c`).

## REST API Endpoints

| Class | Endpoint | Sharing | Guest-accessible? |
|-------|----------|---------|-------------------|
| `BREGExternalAPISearchBusinesses` | `/api/searchBusinesses` | — | No |
| `BREGExternalAPIGetDocument` | `/api/getBregDocument` | — | No |
| `BREGExternalAPIGetGoodStandingStatus` | — | without | No |
| `BREGExternalAPIGetStamps` | — | — | No |
| `BREGExternalAPIGetUserPermissions` | — | — | No |
| `BREGExternalAPIUpdateScannerStatus` | — | — | No |
| `BREGExternalAPIUploadDocument` | `/api/uploadBregDocument2` | with | No |
| `BREGExternalAPIUploadScannedDocument` | — | — | No |
| `LicenseSearchREST` | `/licenseSearch` | without | No |
| `PVLApplicationStatusCheckResource` | `/pvl/application-status/v1/individual/status-check` | — | No |
| `PVLApplicationStatusHealthResource` | — | — | No |
| `**PaymentREST**` | `/CreatePayment` | **without** | **YES — CRITICAL** |
| `**TransactionREST**` | `/CreateTransaction` | **without** | **YES — CRITICAL** |
| `PVL_EncodingService` | `/Encoding` | — | No (Admin/Integration only) |

## Custom Metadata–Driven Configuration

Nearly all runtime behavior is driven by `__mdt` records, not hardcoded values:

| Domain | Key CMT types |
|--------|---------------|
| BREG batch | `BREG_Batch_Job_Configuration__mdt`, `BREG_Batch_Setting__mdt` |
| BREG forms | `BREG_Form_Setting__mdt`, `BREG_Case_Owner_Reassignment__mdt` |
| BREG DocuSign | `BREG_Docusign_Templates_Setting__mdt`, `BREG_Stamp__mdt` |
| BREG email | `BREG_MassEmailSettings__mdt` |
| PVL | `PVLSettings__mdt`, `LicenseSetting__mdt`, `LicenseNumberAssignment__mdt`, `LicenseTypeSetting__mdt` |
| Integrations | `SpringCMApiEnvironment__mdt`, `SpringCLMSetting__mdt`, `qual_Config__mdt` |
| Email | `EmailAlertTypesToTemplate__mdt`, `Case_Record_Type__mdt` |
| Case auto-close | `util_closer_Case_Status_Rule__mdt` |
| Ticketing | `tkt_Email_Notification_Setting__mdt`, `tkt_Ticket_Routing_Rule__mdt` |
| Dynamic forms | Batch: `BatchJob_Setting__mdt`, `NewBatchTransactionComponentConfig__mdt` |
| fflib bindings | `fflibe_Selector__mdt`, `fflibe_Domain__mdt` (not in source — configured in org) |

### Global Value Sets (shared picklists across domains)
`ApplicationStatuses`, `LicenseStatuses`, `Entity_Type`, `Countries`, `USStates`, `Island`, `FeeTypes`, `Form_Codes`, `Division`, `TNTMSM_Classifications`, `breg_Entity_Type_Codes`, `breg_Entity_Statuses`, and others.

## Testing

### Apex Tests
- 558 test classes (43% of all 1,288 classes)
- Test LOC (~119,100) ≈ Production LOC (~121,259)
- Naming convention: `*Test.cls` or files containing `@isTest`
- Run: `sf apex run test --test-level RunLocalTests`
- **Problems:** 36% of test classes have zero assertions (191 of 526); 499 of 3,708 test methods assert nothing; `Test.isRunningTest()` changes production behavior in 85 classes (~166 sites)
- **Date bomb:** `BREGAnnualRollOverJobTest` will fail from **2027-01-01**, blocking all deployments. Fix by 2026-12-01.

### LWC Jest
- Jest configured and enforced by pre-commit hook, but **zero `.test.js` files exist**
- Pre-commit hook runs Jest with `--passWithNoTests` so it doesn't block commits
- Config: [jest.config.js](jest.config.js) extends `@salesforce/sfdx-lwc-jest/config`

## Automation Overview

| Type | Count | Notes |
|------|-------|-------|
| Flows (active) | 233 | 159 of 185 non-PB active flows lack fault paths |
| Flows (draft) | 13 | |
| Process Builders (active) | 48 | 1,039 elements; **support ended 2025-12-31** — migrate to Flows |
| Batch/Schedulable/Queueable/`@future` | 89/59/18/32 | 75+ async classes total |
| Platform events | `PVLProcess__e`, `PVLErrorHandler__e`, `BREG_Handler_Error__e`, `CustomLogEvent__e`, `ppt_Toast__e`, `EmailAlertEvent__e` | |

## Profiles and Access Control

### Key Integration/API Profiles
- `Payment API Only`, `License API Only`, `Salesforce API Only System Integrations` — integration-only
- `Integration`, `Wordpress Administrator` — **ModifyAllData + PasswordNeverExpires + UI login** (critical risk)

### Key External Portal Profiles
- `DCCA BREG - CustomerCommunityLogin` / `CustomerCommunityUser` / `Subscriber Login` — BREG portal
- `CATV Community Profile` / `CATV Portal Profile` — CATV provider portal
- `Digital Form Profile` — Guest (public) for sc_ forms
- `pre-payment Profile`, `securities Profile`, `transcripts Profile` — Payment portal guests (**over-provisioned**)

### Key Internal Staff Profiles (domain-scoped)
`DCCA PVL Admin`, `DCCA PVL Manager`, `DCCA PVL Applications Staff`, `DCCA PVL Records Staff` | `DCCA BREG Standard User`, `DCCA BREG Deputy Commissioner` | `CATV Staff` | `DCCA SEB Administrator`, `DCCA SEB Attorney` | `DCCA Cashier`, `DCCA Manager`

### Key Permission Sets
- `BREG_Admin_User`, `BREG_Standard_User`, `BREG_Supervisor_User`, `BREG_Portal_User`, `BREG_Site_Guest_User`
- `DCCA_PVL`, `DCCAPVLExamBranch`, `PVL_Board_Assignment_Manager`
- `Payment_App`, `Create_Transactions_Permissions`
- `External_CATV_Provider`, `External_CATV_Requestor`
- `Multi_Factor_Authentication_Required`, `Multi_Factor_Authentication_in_API`

## Vendored Libraries

- **fflib (apex-common + apex-mocks + fflibe):** 41 prod classes, 10,580 LOC — used only by CaseTeam domain (~17 consumer classes). Only real consumers: `CaseTeamAssignment*`, `CaseTeamMember*`, `EmailAlertTriggersSelector`, `UserRecordAccess*`.
- **dlrs (Declarative Lookup Rollup Summaries):** 3 generated triggers (`dlrs_AllegationTrigger`, `dlrs_LegalActionTrigger`, `dlrs_TransactionTrigger`)
- **Client-side JS (stale):** jQuery 2.2.4, Bootstrap 3.3.6, typeahead.js 0.10.5 loaded in `InputLookup`/`InputLookup2` Aura components under payment pages — all have known CVEs

## Known Dead / Unused Code

Before referencing or touching these, verify they're still needed in the org:
- `StatusHistoryTrigger` — active no-op (entire body is `/* commented out */`)
- `AgeDaysSumCalculator` — method commented out
- `LicenseClassificationDeactivator` — 84% commented, `@InvocableMethod` commented
- `DocuSignJWT`, `SpringCMTriggerHandler`, `SpringCMFeed` — no references
- `EmailService` — no references, duplicates `EmailTemplateService`
- `CustomMetadataHelper` — empty class body
- `RenewalLicenseMassScannerController`, `MassScanningLicenceController`, `A1LicenseMassScannerController` — `@AuraEnabled` but no UI consumer
- `WebDocumentMutiExt` — constructor is no-op (78% commented)
- **Mass Delete VF pages** (`Mass_Delete_Account`, `Mass_Delete_Case`, etc.) — granted to community profiles (security risk)

## Critical Security Issues (from analysis/00-master-report.md)

**DO NOT ignore these when making changes. See [analysis/02-apex-security.md](analysis/02-apex-security.md) for full details.**

### P0 — Act This Week (13 issues, 12 Critical)

| ID | Summary | Key Classes |
|----|---------|-------------|
| DCCA-001 | DocuSign CLM OAuth bearer token returned to guest browsers | `SpringCMConnector.getToken()` → `lwc/springFiles` |
| DCCA-002 | Guest-callable arbitrary-object SOQL can read integration secrets | `sc_LookupController.searchDB()` (Digital Form guest profile) |
| DCCA-003 | BREG checkout trusts browser prices; $0 cart marks filing Paid | `BREGPaymentController.createPayment()`, `breg_CheckoutPage.js` |
| DCCA-004 | Guest-reachable REST endpoints create payments/transactions with any amount | `PaymentREST`, `TransactionREST` (pre-payment/securities/transcripts profiles) |
| DCCA-005 | Guest sharing rules expose all Transactions, Filings, complaint Cases, draft apps | 20 guest sharing rules in `sharingRules/` |
| DCCA-006 | BREG community profiles have Modify All / View All / Delete on `Transaction__c` | Profile metadata |
| DCCA-007 | Anonymous IDOR: delete any Case, overwrite other filers' Cases, delete their documents | `BREGPortalUtils.deleteCase()`, `BREGRegistrationFormController.saveFormData()` |
| DCCA-008 | Guest-callable generic DML: create/update any record of any object | `CustomRecordCreate.SaveRecord()`, `GenericCommunityPaymentController` |
| DCCA-009 | Self-registration attaches user to client-chosen Account/Profile (account takeover) | `CustomCommunityRegistrationController.finalizeRecords()` |
| DCCA-010 | AES encryption keys in source control; guest-callable encrypt/decrypt oracles | `CATV_EncryptionKey` Custom Label, `CATV_SelfRegistrationController.decrypt()` |
| DCCA-011 | SOQL injection in ~15 guest-reachable classes (one runs in SYSTEM_MODE) | `CATV_CustomLookUpController` → `CATV_WithoutSharingUtility.queryRecords()` |
| DCCA-012 | Anonymous disclosure of payment receipts, billing PII, card data, draft applications | `BREGPaymentController.getPaymentConfirmation()`, VF receipt pages |
| DCCA-013 | Active Remote Sites to pipedream.net request bin, raw IP, icanhazip, staging tax endpoint | `remoteSiteSettings/test.remoteSite-meta.xml` |

### Systemic Security Patterns (apply to all new code)

**Sharing:**
- 128 `without sharing` classes, 286 classes with no sharing declaration
- Only 8 of 97 `@AuraEnabled` classes enforce any CRUD/FLS
- 39 enforcement tokens versus ~690 DML statements and 1,328 queries
- **Rule:** Default to `with sharing` (or `inherited sharing`). Use `WITH USER_MODE` on SOQL. Use `insert as user` / `AccessLevel.USER_MODE` on DML. Isolate required system-mode elevation in narrow, named helpers.

**SOQL injection:**
- 235 dynamic-SOQL sites; 30 rated injectable
- **Rule:** Bind every value (`:var` or `Database.queryWithBinds`). Validate field/object identifiers against `Schema.describe` + allow-list. Never concatenate client-supplied field names or object names.

**Mass assignment:**
- Multiple `without sharing` controllers accept `JSON.deserialize(..., SObject.class)` with client-controlled `Id`, `Status`, `OwnerId`
- **Rule:** Use typed DTOs with explicit field allow-lists. Never honor a client-supplied `Id` without an ownership check.

**Credential storage:**
- Secrets in Public Custom Metadata, custom settings, and `SpringCLM_Session__c`
- **Rule:** Use Named/External Credentials. Do not store secrets in CMT, custom settings, or custom objects.

## Architecture Issues to Be Aware Of

### Known Problem: BREG Trigger Recursion Guard (DCCA-026)
`BREGBaseTriggerHandler.isFirstRun()` is keyed by handler name + operation only — never by record IDs and never cleared. This means:
- Records 201+ in any DML silently skip all BREG trigger logic (status transitions, validations, fee creation, DocuSign workflows)
- Any later DML in the same transaction (from Apex, Flow, or batch) also skips
- Workaround flows exist (`BREG_Transaction_Line_After` calls "Reset Disable Trigger") but don't cover all cases
- **Always add 201-record bulk tests when touching BREG trigger handlers**

### Known Problem: PVLProcess__e Command Bus (DCCA-027)
`PVLProcessTrigger` (264 lines) dispatches 12 command types inside a per-event loop with SOQL, DML, Flow, `enqueueJob`, `executeBatch`, and self-republishing — all in one trigger with no `RetryableException` or checkpoint. ~50 events in one batch exhaust governor limits, dropping entire batches of license terminations, PDF generation, and allocations silently.

### Known Problem: Three SpringCM Clients (DCCA, A-09)
Three separate clients (`SpringCMConnector`, `SpringCMApiManager`/`SpringCMService`/`SpringCMRestHelper`, `DocuSignAPI`) connect to the same DocuSign CLM/SpringCM repository with different auth, error handling, and retry semantics. `SpringCMConnector:399` hard-codes a UAT endpoint (`apiuatna11.springcm.com`) called from production batch code.

### Known Problem: Profile-Name Authorization (DCCA-024)
Several classes check `profile.Name.contains(...)` for authorization decisions:
- `AccountDomain.cls:40-44` — any profile containing `'form'` or `'Digital'` (including the guest Digital Form profile) gets PVL staff privileges
- `FilingService.cls:19-24` — exempts `'DCCA BREG - CustomerCommunityLogin'` by name
- `TransactionPreventDeletion.cls:12` — allows `'System Administrator'` by name
- **Rule:** Use Custom Permissions (`FeatureManagement.checkPermission`) instead.

## Logging Infrastructure

**8 parallel logging mechanisms** (use `CustomLogger` for new code):

| Logger | Object | Domain |
|--------|--------|--------|
| `CustomLogger` + `CustomLog__c` + `CustomLogEvent__e` | `CustomLog__c` | Shared (preferred) |
| `ApplicationLogService` + `Application_Log__c` + `PVLErrorHandler__e` | `Application_Log__c` | PVL |
| `breg_Log__c` + `BREG_Handler_Error__e` | `breg_Log__c` | BREG |
| `BREGAmazonSesLogger` | `breg_Email_Log__c` | BREG email |
| `breg_Search_Log__c` | — | BREG search |
| `QualIntegrationLogger` + `qual_Integration_Log__c` | `qual_Integration_Log__c` | Qualtrics |
| `util_closer_Logger` | `util_closer_Batch_Log__c` | util_closer |

**Do not** log credentials, session IDs, or full sObject records. `SpringCMConnector:203` logs the bearer token — this is a bug, not a pattern to follow.

## LWC Components (Key Examples)

| Component | Domain | Purpose |
|-----------|--------|---------|
| `breg_Home` | BREG Portal | Home page with business search |
| `breg_StartNewBusinessWizard` | BREG | Multi-step business registration wizard |
| `breg_SearchAndBuy` | BREG | Public business search and document purchase |
| `breg_CheckoutPage` | BREG | Payment checkout (**client-side pricing — DCCA-003**) |
| `breg_MyBusinesses` | BREG Portal | Authenticated user's business list |
| `breg_RegistrationDynamicForm` | BREG | Dynamic form rendering |
| `catv_dashboard` | CATV | Cable TV provider portal dashboard |
| `springFiles` | Docs | DocuSign CLM file viewer (**exposes bearer token — DCCA-001**) |
| `loggerService` | Shared | Client-side logging |
| `utils` | Shared | Shared utility functions |
| `pvlMultiSelectPicklist` | PVL | Multi-select picklist |
| `tktMyTickets` / `tktCreateTicket` | tkt_ | Internal ticketing UI |

## Lightning Apps (Key)

| App | Domain |
|-----|--------|
| `BREG.app` | Business Registration internal |
| `PVL.app` | PVL internal |
| `DCCAPayments.app` | Payments/Finance |
| `DCCA_CATV.app` | Cable TV |
| `DCCA_COMPLAINTS.app` | Complaints |
| `SEB.app` / `SEC.app` | Enforcement |
| `Travel_Approval.app` | Travel |
| `PVL_Call_Center.app` | Call center |
| `Cases_and_Complaints_v2.app` | Complaints v2 |

## Remediation Backlog

See [analysis/remediation-backlog.csv](analysis/remediation-backlog.csv) for the full prioritized list. Summary:

| Priority | Count | When |
|----------|-------|------|
| **P0** | 13 | Act this week (containment) |
| **P1** | 24 | Next 30 days |
| **P2** | 19 | Next quarter |
| **P3** | 10 | Backlog |

**Projected health score after P0+P1:** 70/100 (current: 31/100)
