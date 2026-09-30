# DCCA Salesforce Codebase — Deep Analysis Master Report

*Wave 2 synthesis of six specialist reviews (`analysis/01`–`06`). Prepared 2026-09-30. Static analysis of the `force-app` source only; see Limitations.*

## Executive Summary

**Context.** The DCCA org is several regulatory products on one Salesforce org: Business Registration (BREG), Professional & Vocational Licensing (PVL), Cable TV (CATV), cashiering and payments, a dynamic Digital Forms builder (`sc_`), complaints and enforcement, and a DocuSign CLM (SpringCM) document integration. Several public Experience Cloud sites let anonymous citizens search, file and pay.

**Scope and method.** Six specialist agents reviewed architecture, Apex security, LWC/Aura, automation, access control and test quality across 1,288 Apex classes, 61 triggers, 266 flows, 232 LWC and 147 Aura bundles, 96 profiles and 140 permission sets. This synthesis de-duplicated their 145 findings into 66 consolidated issues, spot-checked the Critical claims against source (all 17 Critical issues checked; 16 confirmed as written, 1 confirmed with a correction), and prioritised by severity × exposure × effort. **Limitation:** this is static analysis of source metadata. Live site configuration, guest-user permission-set assignments, active flow versions, scheduled jobs, record values of custom metadata and real test coverage are not in the repository and must be confirmed in the org (P0 action 1).

| Headline | Value |
|---|---|
| Raw findings (6 reports) | **145** (27 Critical, 44 High, 51 Medium, 23 Low) |
| Consolidated issues | **66** (17 Critical, 28 High, 17 Medium, 4 Low) |
| Priority tiers | P0 act this week: **13** · P1 next 30 days: **24** · P2 next quarter: **19** · P3 backlog: **10** |
| Overall health score | **31 / 100** (capped at 40 while P0 items are open; uncapped 31); projected **70** after P0 + P1 |
| Critical issues spot-verified in source | 17 of 17 (16 as written, 1 with correction) |
| Time-bound | `BREGAnnualRollOverJobTest` fails from **2027-01-01** and will block all deployments (fix by 2026-12-01); Process Builder support **ended 2025-12-31** (48 active PBs) |

**Top 5 risks in plain language**

1. **Anyone on the internet can obtain master keys.** A public page hands out the live access token for the agency's document repository (DocuSign CLM), and another public lookup can be pointed at the tables that store integration passwords and keys. (DCCA-001, 002, 010, 014)
2. **Online payments can be faked or zeroed.** The browser decides the price at BREG checkout and a $0 cart is recorded as paid; two public web services let anyone create 'Completed' payments and transactions. (DCCA-003, 004, 008)
3. **Members of the public can see and change other people's records.** Public pages can delete or take over other filers' cases, register onto someone else's business account, and read payer billing details, complainant identities, draft licence applications and pending enforcement names. (DCCA-005, 006, 007, 009, 011, 012)
4. **Core automation silently skips or drops work.** BREG trigger logic is skipped for records beyond the first 200 in a transaction; the PVL event processor can lose whole batches of licence letters and terminations; 48 Process Builders running core logic are past end of support. (DCCA-026, 027, 028)
5. **Tests do not prove the money code works, and a date bug will block releases.** Payment and reconciliation code is covered only by tests that check nothing, production code behaves differently under test, and a test will fail on 1 January 2027, blocking every deployment including emergency fixes. (DCCA-029, 030, 032)

**P0 actions this week** (detail in the P0 section):

1. Confirm live exposure (scope the blast radius) — *Salesforce Platform Admin (with Agency Security Officer)*
2. Remove guest and community Apex class access to the highest-risk classes — *Salesforce Platform Admin / Release Manager*
3. Rotate every exposed credential and revoke live tokens (after step 2) — *Integration Owners (CLM/DocuSign, Tax, Qualtrics) + Agency Security Officer*
4. Remove guest sharing rules and community Modify All on transactions — *Salesforce Platform Admin (data owner sign-off: Fiscal Office, Complaints/RICO)*
5. Payment-integrity hotfix: server-side pricing and no client-controlled 'Paid' — *BREG Development Lead + Fiscal Office product owner*
6. Close the anonymous delete / overwrite / account-takeover paths — *BREG Development Lead / Payments Development Lead*
7. Close outbound data-egress channels — *Salesforce Platform Admin + Privacy Officer*
8. Retrospective compromise assessment — *Agency Security Officer + Fiscal Office + BREG Operations*
9. Establish a test baseline and detect date-bomb failures — *Release Manager / QA Lead*

## Codebase at a Glance

| Area | Metric | Value | Source |
|---|---|---|---|
| Apex | Classes (production / test) | 1,288 (≈730-744 / ≈544-558 by classification method) | 01, 06 |
| Apex | Production LOC / total Apex LOC | ≈121k / ≈240k | 01 |
| Apex | Bounded contexts | 16 (BREG 152 prod classes, PVL ≈366, Payments 71, Docs/CLM 62 …) | 01 |
| Apex | SOQL statements / in Selector classes | 1,441 / 149 | 01 |
| Apex | Dynamic SOQL/SOSL sites / rated injectable | 235 / 30 | 02 |
| Apex | `without sharing` / undeclared production classes | ≈128 / ≈286-292 | 01, 02 |
| Apex | CRUD/FLS enforcement tokens vs DML / queries | 39 vs ≈690 / ≈1,328 | 02 |
| Apex | Apex REST resources | 14 (2 granted to guest profiles) | 02, 05 |
| Apex | `Test.isRunningTest()` in production | ≈166-173 sites in 85 classes | 01, 06 |
| Automation | Apex triggers / objects with >1 trigger | 61 / 6 (Payment has 3) | 01, 04 |
| Automation | Flow files (Active / Draft / Obsolete) | 266 (233 / 13 / 20) | 04 |
| Automation | Active Process Builders / elements | 48 / 1,039 (support ended 2025-12-31) | 04 |
| Automation | Active non-PB flows lacking fault paths | 159 of 185 | 04 |
| Automation | Batch / Queueable / Schedulable / @future | 89 / 18 / 59 / 32 | 04 |
| Front end | LWC bundles / Jest tests | 232 / 0 | 03, 06 |
| Front end | Aura bundles (easy / moderate / complex / events+apps) | 147 (54 / 40 / 37 / 16) | 03 |
| Front end | Visualforce pages | 167 | repo |
| Front end | Community-exposed LWC / Aura | 50 / 41 | 03 |
| Access | Profiles (custom / guest) / permission sets / custom PSGs | 96 (78 / 9) / 140 / 4 | 05 |
| Access | Guest sharing rules / admin-equivalent profiles | 20 / 9 | 05 |
| Access | Custom objects with Public Read/Write OWD | 90 of 166 | 05 |
| Access | Remote Site Settings / CSP trusted sites | 31 / 22 | 05 |
| Testing | Test methods / with zero assertions | 3,708 / 499 (13.5%) | 06 |
| Testing | Test classes with no assertion anywhere | 191 of 526 (36%) | 06 |
| Testing | Org-wide coverage | Unknown (no results cached, no CI) | 06 |
| Platform | API version range (source API) | v31-v66 (67.0) | 01 |

## Risk Heatmap

Rows are functional areas; columns are the six review dimensions. Each cell shows the highest severity and the number of consolidated issues in that area that draw on a source finding from that dimension's report (an issue can appear in more than one cell). **C** Critical · **H** High · **M** Medium · **L** Low · `—` none.

| Area | Security | Access Control | Automation | Architecture | Front End | Testing |
|---|---|---|---|---|---|---|
| BREG | **C** ×10 | **C** ×4 | **C** ×4 | **C** ×4 | **C** ×11 | H ×2 |
| CATV | **C** ×4 | — | — | **C** ×1 | **C** ×5 | H ×1 |
| PVL/Licensing | H ×3 | H ×1 | **C** ×8 | **C** ×1 | H ×3 | **C** ×5 |
| Payments/Transactions | **C** ×10 | **C** ×6 | H ×6 | H ×3 | **C** ×7 | **C** ×5 |
| Digital Forms sc_ | **C** ×4 | **C** ×2 | — | **C** ×2 | **C** ×2 | — |
| Cases/Complaints | **C** ×3 | **C** ×3 | H ×3 | — | **C** ×2 | — |
| Integrations CLM/DocuSign | **C** ×6 | H ×2 | — | **C** ×3 | **C** ×3 | **C** ×1 |
| Platform/Shared | **C** ×10 | **C** ×7 | H ×5 | H ×8 | H ×8 | H ×7 |

**Reading the map.** BREG (Critical in five of six dimensions) and Payments/Transactions (Critical in Security, Access Control, Front End and Testing; High in Automation and Architecture) are the hottest areas. Security is Critical in every functional area except PVL, which is instead dominated by Critical automation and testing risk. The Architecture column is Critical where report 01 raised issues that consolidated as Critical: the CLM token exposure (A-01), the BREG recursion guard (A-02) and the PVL event processor (A-05).

## P0 — Act This Week

Containment only: configuration changes, credential rotation and small guarded hotfixes that do not need refactoring. Sequence 1 → 2 → 3 matters (rotating before removing access would leak the new secrets).

### P0-1. Confirm live exposure (scope the blast radius)
- **Owner:** Salesforce Platform Admin (with Agency Security Officer)
- **Issues:** DCCA-004, DCCA-008, DCCA-016
- **Steps:**
  - List every active Experience Cloud site / Salesforce Site and its guest user (BREG, CATV, Digital_Form, PaymentConnect, dcca, pre-payment, securities, transcripts).
  - Confirm which permission sets are assigned to each guest user (in particular `BREG_Site_Guest_User`, `OmniStudio_Guest_User`) and whether Apex REST is enabled on each site.
  - Run the Guest User Access Report and save it as the pre-change baseline.
  - If the pre-payment, securities or transcripts sites are not in business use, deactivate them; this removes most of DCCA-004/008/011/016 at once.
- **Verification:** Signed-off inventory of live sites, guest users and their class/page/object grants; decision recorded for each unused site.

### P0-2. Remove guest and community Apex class access to the highest-risk classes
- **Owner:** Salesforce Platform Admin / Release Manager
- **Issues:** DCCA-001, DCCA-002, DCCA-004
- **Steps:**
  - Remove `SpringCMConnector` from `Digital Form Profile`, `DCCA BREG - CustomerCommunityLogin` and `External_CATV_Provider`/`External_CATV_Requestor` (accept temporary loss of browser-side CLM upload, or ship the server-side proxy first).
  - Remove `sc_LookupController` from `Digital Form Profile` and `LookUpController` from BREG community profiles.
  - Remove `PaymentREST` and `TransactionREST` from `pre-payment`, `securities`, `transcripts` and `DCCA BREG - CustomerCommunityLogin`.
  - Remove `DocuSignJWT` and `DocusignAuthProvider` from `BREG_Site_Guest_User`; remove the `BatchSummaryPDF` page from guest profiles.
  - Deploy as metadata-only change with a rollback package.
- **Verification:** Re-run the Guest User Access Report; as a guest, call each removed Aura action and `/services/apexrest/CreatePayment` and confirm access is denied; smoke-test the public sites.

### P0-3. Rotate every exposed credential and revoke live tokens (after step 2)
- **Owner:** Integration Owners (CLM/DocuSign, Tax, Qualtrics) + Agency Security Officer
- **Issues:** DCCA-001, DCCA-002, DCCA-010, DCCA-014
- **Steps:**
  - SpringCM/DocuSign CLM: revoke the refresh token, rotate the client secret, delete stored values in `SpringCLM_Session__c`.
  - DocuSign JWT: generate a new key pair; compare the PEM key embedded in `DocuSignJWTTest`/`DocusignAuthProviderTest` with the registered public key and treat it as compromised if it matches.
  - Rotate Hawaii Tax Clearance credentials (`TaxClearanceApi__c`), Qualtrics API token, `Org_Credential__mdt` AES key/IV and the CATV encryption key (`CATV_EncryptionKey` label); mark the label protected.
  - Store new values in Named/External Credentials where the integration already supports it; otherwise in Protected settings pending DCCA-014.
- **Verification:** Old tokens rejected by each provider; SpringCM/DocuSign audit logs reviewed for API use from unknown IPs since the classes were first granted.

### P0-4. Remove guest sharing rules and community Modify All on transactions
- **Owner:** Salesforce Platform Admin (data owner sign-off: Fiscal Office, Complaints/RICO)
- **Issues:** DCCA-005, DCCA-006
- **Steps:**
  - Delete `Transaction__c.Site_Guest_User` and `Filing__c.SiteGuestUser` (PaymentConnect).
  - Delete the four `GuestUserCaseAccess*Complaint` Case rules and `Account.ShareComplainantAccounts` (dcca).
  - Delete `Application_Cache__c.Enable_Guest_User` (Digital_Form).
  - Set `modifyAllRecords`, `viewAllRecords` and `allowDelete` to false on `Transaction__c` in the three BREG community profiles.
- **Verification:** As a guest user, record/list queries on Transaction__c, Case and Application_Cache__c return nothing; as a BREG portal user, only own transactions are visible; public payment and complaint intake still work end to end.

### P0-5. Payment-integrity hotfix: server-side pricing and no client-controlled 'Paid'
- **Owner:** BREG Development Lead + Fiscal Office product owner
- **Issues:** DCCA-003
- **Steps:**
  - In `BREGPaymentController.createPayment`, re-price each cart line from `breg_Fee__c` by fee Id, recompute the total, and reject the request if it differs from the client `amount`.
  - Only set `Paid`/`Completed` when the server-computed total is zero and every fee is zero-rated; otherwise leave Pending for the processor callback.
  - In `SecurityPortalTransactionsHelper.groupTransactions`, recompute `totalAmount` from the selected `Transaction__c` records.
  - Remove the client call to `updateCasesProcessingSpeed`; set expedite from a paid expedite fee line.
- **Verification:** Apex tests submitting a tampered cart ($0 and under-priced) fail with an error; UAT purchase of each fee type succeeds at the correct price.

### P0-6. Close the anonymous delete / overwrite / account-takeover paths
- **Owner:** BREG Development Lead / Payments Development Lead
- **Issues:** DCCA-007, DCCA-009, DCCA-011, DCCA-012
- **Steps:**
  - Add a guest-user and ownership guard (`UserInfo.getUserType()`, `ContactId = current contact`) to `BREGPortalUtils.deleteCase`, `BREGCaseControllerWithoutSharing.*`, and `BREGRegistrationFormController.saveRelatedFiles`.
  - Strip client-supplied `Id`, `ContactId`, `OwnerId`, `Status` and bypass fields in `BREGRegistrationFormController.saveFormData`.
  - In `CustomCommunityRegistrationController.finalizeRecords`, ignore client `profileName` and `account.Id` (fixed profile; existing-account joins go to staff approval).
  - In `CATV_CustomLookUpController`, ignore client field names (hard-code Name/Type); in `SEBSearchController`, require `Public__c = true`; strip card/processor fields from guest payloads in `getPaymentConfirmation`.
- **Verification:** Negative Apex tests run as guest/other-portal-user for each method; penetration re-test of the five methods.

### P0-7. Close outbound data-egress channels
- **Owner:** Salesforce Platform Admin + Privacy Officer
- **Issues:** DCCA-013, DCCA-025
- **Steps:**
  - Deactivate Remote Sites `test` (pipedream.net), `WordpressSiteTestServer` (raw IP, HTTP), `icanhazip` and `TaxClearanceApiStagingEndpoint`.
  - Remove CSP `Qualtrics_Wildcard`.
  - Remove former-vendor and personal Gmail addresses from PB fault emails and email-alert CCs (DCCA-025).
- **Verification:** Remote Site list reviewed and signed; test callout to pipedream fails; email alert recipients list contains only agency addresses.

### P0-8. Retrospective compromise assessment
- **Owner:** Agency Security Officer + Fiscal Office + BREG Operations
- **Issues:** DCCA-003, DCCA-004, DCCA-007, DCCA-001, DCCA-002
- **Steps:**
  - Query BREG payments/transactions with amount 0 or line totals below fee schedule and status Completed/Paid since the checkout went live.
  - Query `pymt__PaymentX__c`, `Transaction__c` and `Account` records created by site guest users (CreatedBy = guest) via the REST endpoints.
  - Review Case deletions (recycle bin / Field History / Event Monitoring) and Case ContactId changes made by guest or portal users.
  - If Event Monitoring is licensed, search ApexExecution/Aura request logs for guest calls to `getToken`, `searchDB`, `fetchRecords`, `deleteCase`, `getPaymentConfirmation`.
- **Verification:** Written findings memo; any confirmed abuse triggers the agency incident-response and breach-notification process.

### P0-9. Establish a test baseline and detect date-bomb failures
- **Owner:** Release Manager / QA Lead
- **Issues:** DCCA-032, DCCA-033
- **Steps:**
  - Run all local tests with coverage in a full-copy sandbox this week; store the per-class coverage JSON.
  - Record any failures, in particular `ApplicationTriggerTest` and `ApplicationHcRenewalValidationTest` (bond term dates 2026-10-07 and 2026-11-20) and `BREGAnnualRollOverJobTest` (fails from 2027-01-01).
  - Schedule the DCCA-032 fix with a hard deadline of 2026-12-01 and a code freeze exception if needed.
- **Verification:** Baseline report with org-wide and per-class coverage and a list of failing tests; DCCA-032 ticket committed to a sprint ending before 2026-12-01.

## Consolidated Findings

**Scoring.** Priority score = Severity (Critical 4, High 3, Medium 2, Low 1) × Exposure (guest/public 3, authenticated external 2, internal 1), range 1-12. Tier rules: **P0** = score ≥ 8 with a containment step that can ship in a week without refactoring, plus outbound-egress closures; **P1** = score ≥ 6, or any Critical, or time-bound (deadline passed or imminent), or active data egress, or a CI/test enabler; **P2** = score 3-5, or score 2 with effort S/M, or score ≥ 6 with effort XL; **P3** = everything else and all Low. Consolidated severity is the highest source severity unless a stated override applies. Effort: S ≤ 1 week, M 1-4 weeks, L 1-3 months, XL > 3 months (one team).

**Verification status.** *Verified* = claim re-checked in source by this synthesis (file/line cited). *Verified (sample)* = one representative instance re-checked. *Partially verified* = some sub-claims re-checked. *Not spot-checked* = evidence taken from the specialist report. No checked claim was found false; one was overstated (DCCA-011) and one sub-claim was weakened (DCCA-032).

### P0 — Act this week (13 issues: 12 Critical, 1 High)

| ID | Title | Sev | Exposure | Score | Effort | Sources |
|---|---|---|---|---|---|---|
| DCCA-001 | DocuSign CLM (SpringCM) org-wide OAuth bearer token returned to guest and community browsers; tokens stored in… | Critical | Guest / public | 12 | M | A-01, S-02, F-02 |
| DCCA-002 | Guest-callable arbitrary-object SOQL (sc_LookupController) can read integration secrets stored in Public custo… | Critical | Guest / public | 12 | M | S-01 |
| DCCA-003 | BREG checkout and Securities group payment trust browser-supplied prices and totals; a $0 cart is recorded as … | Critical | Guest / public | 12 | M | S-03, F-01, F-21 |
| DCCA-004 | Guest-reachable Apex REST endpoints /CreatePayment and /CreateTransaction insert payments and transactions wit… | Critical | Guest / public | 12 | S | S-04, P-02 |
| DCCA-005 | Guest sharing rules expose entire record populations: all Transactions (payer billing identity), Filings, comp… | Critical | Guest / public | 12 | M | P-01, P-05 |
| DCCA-006 | All three BREG community profiles hold Modify All / View All / Delete on Transaction__c (every division's tran… | Critical | Authenticated external | 8 | S | P-03 |
| DCCA-007 | Anonymous IDOR and mass assignment in BREG portal controllers: delete any Case, overwrite or re-parent other f… | Critical | Guest / public | 12 | L | S-05, F-03, P-04 |
| DCCA-008 | Guest-callable generic DML in the payment portal: create or update any record of any object (CustomRecordCreat… | Critical | Guest / public | 12 | L | S-08 |
| DCCA-009 | Anonymous self-registration provisions portal users on a client-chosen existing Account and client-chosen Prof… | Critical | Guest / public | 12 | M | S-06, S-26 |
| DCCA-010 | Symmetric encryption keys committed to source and used as authorisation tokens; guest-callable decrypt and enc… | Critical | Guest / public | 12 | M | S-10 |
| DCCA-011 | SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_MODE (CATV self-regis… | Critical | Guest / public | 12 | M | S-07, F-04, S-27, S-30 |
| DCCA-012 | Anonymous disclosure of payment receipts, billing PII, card last-4, draft licence applications and pending enf… | Critical | Guest / public | 12 | M | S-09, F-07, P-09 |
| DCCA-013 | Outbound perimeter: active Remote Site Settings to a pipedream.net request bin, a raw-IP HTTP host, icanhazip … | High | Internal | 3 | S | S-23, P-19, P-20 |

#### DCCA-001 — DocuSign CLM (SpringCM) org-wide OAuth bearer token returned to guest and community browsers; tokens stored in plaintext
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Integrations CLM/DocuSign, Digital Forms sc_, CATV · **Category:** Security
- **Source findings:** A-01 (Critical), S-02 (Critical), F-02 (Critical)
- **Verified:** Verified — SpringCMConnector.cls:1 is `without sharing`; :63-68 `@AuraEnabled getToken()` returns the access token and calls saveToken(); :336-345 upserts RefreshToken__c/AccessToken__c in plaintext into SpringCLM_Session__c; lwc/springFiles/springFiles.js:3,76 imports getToken and sets `Authorization: bearer`; `Digital Form Profile` (Guest User License) grants the class (profile line 4392).
- **Evidence:** `SpringCMConnector.getToken()` (`classes/SpringCMConnector.cls:63-68`) hands the integration account's CLM bearer token to the browser, where `lwc/springFiles` uploads directly to SpringCM. The class is granted to the guest `Digital Form Profile`, `DCCA BREG - CustomerCommunityLogin`, and the `External_CATV_Provider`/`External_CATV_Requestor` permission sets. The same class also attaches the org token to **client-supplied URLs** (`updateDescription`, `deleteDocument`, `updateFilesAndFolder`, `:347-524`), logs the token (`:203`), and every call re-persists the refresh token in `SpringCLM_Session__c` (Public Read/Write OWD, see DCCA-014).
- **Impact:** Any site visitor can obtain a token with read/write/delete rights over every government document in CLM, outside Salesforce sharing and audit. The URL-taking methods also let an attacker make the org send its token to any host allowed by Remote Site Settings (including the pipedream.net bin, DCCA-013).
- **Fix:** Remove `getToken` from the client API; proxy uploads server-side via a Named/External Credential (or short-lived pre-signed single-folder URLs); accept SpringCM document UIDs, not URLs; make the class `with sharing`; delete token logging; retire `SpringCLM_Session__c` token storage.
- **P0 containment:** Remove `SpringCMConnector` class access from `Digital Form Profile`, `DCCA BREG - CustomerCommunityLogin` and both `External_CATV_*` permission sets; revoke the SpringCM refresh token and rotate the client secret; review SpringCM audit logs.

#### DCCA-002 — Guest-callable arbitrary-object SOQL (sc_LookupController) can read integration secrets stored in Public custom metadata and settings
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Digital Forms sc_, Platform/Shared · **Category:** Security
- **Source findings:** S-01 (Critical)
- **Verified:** Verified — sc_LookupController.cls:1-14 has no sharing keyword and concatenates client-supplied object, SELECT fields and WHERE field into Database.query; `Digital Form Profile` (Guest) grants the class (line 5188); Org_Credential__mdt, SpringCLMSetting__mdt and breg_DocuSign_Auth__mdt are `<visibility>Public</visibility>` with Password__c/Key__c/Client_Secret__c fields. Record values are not in source, so which secrets are populated could not be verified.
- **Evidence:** `searchDB(objectName, fld_API_Text, fld_API_Val, lim, fld_API_Search, searchText)` escapes only `searchText`; the object name, SELECT list and WHERE field are raw client input (`classes/sc_LookupController.cls:4-14`). Custom metadata and custom settings have no record sharing and Apex does not enforce FLS, so an anonymous caller can name `SpringCLMSetting__mdt`, `Org_Credential__mdt`, `breg_DocuSign_Auth__mdt`, `TaxClearanceApi__c` or `qual_Integration_Settings__c` and receive `Client_Secret__c`, the AES key/IV, the DocuSign JWT private key, Tax Clearance credentials or the Qualtrics token. The same unrestricted pattern exists in `LookUpController` (identical copy) and other generic endpoints for community users (DCCA-017).
- **Impact:** Full compromise of every integration credential held in metadata (SpringCM, DocuSign JWT impersonation, Hawaii tax clearance, Qualtrics) and the ability to forge Digital Form `data=` tokens, all without logging in. Setup objects (User, Profile, Organization) can also be enumerated.
- **Fix:** Remove the class from the guest profile; rewrite as a config-key lookup with server-side allow-listed object/fields, `Schema` validation, binds and `AccessLevel.USER_MODE`. Treat all listed secrets as compromised (rotate, then move to External Credentials, DCCA-014).
- **P0 containment:** Remove `sc_LookupController` from `Digital Form Profile` (and `LookUpController` from community profiles); rotate all secrets listed.

#### DCCA-003 — BREG checkout and Securities group payment trust browser-supplied prices and totals; a $0 cart is recorded as Paid/Completed; expedite can be set without paying
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Payments/Transactions, BREG · **Category:** Security
- **Source findings:** S-03 (Critical), F-01 (Critical), F-21 (Low)
- **Verified:** Verified — BREGPaymentController.cls:284-289 `@AuraEnabled createPayment(Double amount, String cartItemsJson, ...)` sets `tliStatus = amount > 0 ? 'Pending' : 'Paid'`; :366-392 sets Transaction/Payment status and amount from `amount`; :630-647 takes `unitPrice` from cart JSON; lwc/breg_CheckoutPage/breg_CheckoutPage.js:123 totals the localStorage cart on the client; SecurityPortalTransactionsHelper.cls:88,114 copies client `totalAmount`; BREGCaseControllerWithoutSharing.cls:17-28 sets Expedited for any Case Ids.
- **Evidence:** The cart (with `unitPrice`/`price`) lives in `localStorage` and is re-implemented in 14 LWCs. `breg_CheckoutPage` sums it and calls `createPayment({amount, cartItemsJson,...})`; Apex never re-prices from `breg_Fee__c`. `amount = 0` produces a Completed Transaction, a Completed Payment and `Paid` TransactionLines, which drive fulfilment in `BREGTransactionLineTriggerHandler` (certificates, DocuSign document workflows). For $0 carts the LWC also calls `updateCasesProcessingSpeed`, which marks any Case Expedited. `makePaymenttoMultipleFilings` does the same for Securities group payments. Guest reachability: `BREG_Site_Guest_User` grants `BREGPaymentController` and `BREGCaseControllerWithoutSharing`.
- **Impact:** Direct revenue loss and corrupted cashiering/GL reconciliation: certificates of good standing, certified copies and expedited service can be obtained for free or underpaid by anyone who edits localStorage or calls the Aura action directly.
- **Fix:** Re-price every line server-side from `breg_Fee__c`/`Transaction__c`, compute the total in Apex, ignore client `amount`/`price`/`unitPrice`; set Paid/Completed only from the verified processor callback or when every fee is legitimately zero-rated; set expedite only from a paid expedite fee line; keep the cart server-side (also fixes F-21 shared-device leakage). Add tampered-cart Apex tests.
- **P0 containment:** Ship a server-side re-pricing hotfix to `BREGPaymentController.createPayment` and `SecurityPortalTransactionsHelper`; run a detection query for $0/under-priced Completed payments since go-live.

#### DCCA-004 — Guest-reachable Apex REST endpoints /CreatePayment and /CreateTransaction insert payments and transactions with caller-supplied amount and status
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** S · **Tier:** P0
- **Domain:** Payments/Transactions · **Category:** Security
- **Source findings:** S-04 (Critical), P-02 (Critical)
- **Verified:** Verified — PaymentREST.cls:5-8 `@RestResource(urlMapping='/CreatePayment') global without sharing`; :38 and :43 take PaymentAmount and Status from the body; :61 echoes ex.getMessage(); TransactionREST.cls:5-8 same pattern; both classes enabled in `pre-payment`, `securities` and `transcripts` profiles (Guest User License) at lines 3844/4624.
- **Evidence:** Neither class checks caller identity, a signature or a permission. With class access on a Site guest profile, Apex REST is reachable at `https://<site>/services/apexrest/CreatePayment`. `TransactionREST` also creates Person/Business Accounts and TransactionLines with caller-supplied paid status.
- **Impact:** Anonymous forging of 'Completed' payments against real transactions (bypassing Authorize.Net) and fabrication of accounts and ledger lines, poisoning deposits and reconciliation.
- **Fix:** Remove both classes from all guest and community profiles; expose only to a dedicated API-only integration user via Connected App (client credentials) plus a `FeatureManagement.checkPermission` gate; never accept Status from the caller; return generic errors.
- **P0 containment:** Remove class access from the three guest profiles and `DCCA BREG - CustomerCommunityLogin`; query payments/transactions created by site guest users for forgeries.

#### DCCA-005 — Guest sharing rules expose entire record populations: all Transactions (payer billing identity), Filings, complaint Cases, complainant Accounts, draft license applications, BREG entities, OmniStudio definitions
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Payments/Transactions, Cases/Complaints, BREG, Digital Forms sc_ · **Category:** Access Control
- **Source findings:** P-01 (Critical), P-05 (Critical)
- **Verified:** Verified — sharingRules/Transaction__c.sharingRules-meta.xml:349-363 `Site_Guest_User` Read to guestUser PaymentConnect where Status__c != ''; Case.sharingRules-meta.xml:429-475 four complaint rules to guestUser dcca; Application_Cache__c.sharingRules-meta.xml:4-8 `Enable_Guest_User` to Digital_Form. Effective guest Read on Case/Account depends on standard-object permissions that are not in source.
- **Evidence:** 20 guest sharing rules use effectively 'all records' criteria. `Transaction__c` is Private OWD, so the PaymentConnect rule is the only thing opening it, and the PaymentConnect guest profile has Read FLS on 48 Transaction fields including billing name and address. Complaint Cases and 'Complainant' person accounts identify members of the public who complained about licensees. `Application_Cache__c` holds in-progress licence application data.
- **Impact:** Reportable PII disclosure: anonymous enumeration of payer identities, complainants (retaliation risk) and draft applications through standard UI API / Aura record access on the sites.
- **Fix:** Delete the Transaction, Filing, four Case, ShareComplainantAccounts and Application_Cache rules; narrow BREG rules to publicly filed statuses; restrict Omni rules to the processes the site uses; serve single guest records via token-keyed user-mode Apex.
- **P0 containment:** Delete the Transaction__c, Filing__c, four Case, `ShareComplainantAccounts` and `Enable_Guest_User` guest rules; run the Guest User Access Report.

#### DCCA-006 — All three BREG community profiles hold Modify All / View All / Delete on Transaction__c (every division's transactions)
- **Severity:** Critical · **Exposure:** Authenticated external · **Priority score:** 8 · **Effort:** S · **Tier:** P0
- **Domain:** Payments/Transactions, BREG · **Category:** Access Control
- **Source findings:** P-03 (Critical)
- **Verified:** Verified — profiles/DCCA BREG - CustomerCommunityLogin.profile-meta.xml:33895-33904 allowCreate/Delete/Edit/Read, modifyAllRecords and viewAllRecords all true on Transaction__c. The other two profiles (CustomerCommunityUser, Subscriber Login) were not re-opened; report 05 cites identical blocks.
- **Evidence:** View All / Modify All bypass OWD and sharing. Every self-registered BREG portal user can read, edit and delete all `Transaction__c` records across PVL, INS, RICO, BREG and other divisions.
- **Impact:** Cross-tenant read of billing identities and tampering with outstanding balances by any member of the public who registers.
- **Fix:** Set modifyAllRecords, viewAllRecords and allowDelete to false on the three profiles; grant own-record access via sharing sets / account-based sharing.
- **P0 containment:** Deploy the three profile changes (metadata-only, no code).

#### DCCA-007 — Anonymous IDOR and mass assignment in BREG portal controllers: delete any Case, overwrite or re-parent other filers' Cases, change Case contact, expedite, delete supporting documents
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** L · **Tier:** P0
- **Domain:** BREG, Cases/Complaints · **Category:** Security
- **Source findings:** S-05 (Critical), F-03 (Critical), P-04 (Critical)
- **Verified:** Verified — BREGPortalUtils.cls:292-296 `@AuraEnabled deleteCase(Id)` deletes any Case (class is without sharing); BREGCaseControllerWithoutSharing.cls:1-28 updates any Case's subscription flag and processing speed with no ownership check; BREG_Site_Guest_User.permissionset grants BREGCaseControllerWithoutSharing (L24), BREGPaymentController (L60) and BREGPortalUtils (L64). Assignment of this permission set to the BREG guest user is inferred (assignments are not in source). BREGRegistrationFormController paths were not re-read.
- **Evidence:** `deleteCase`, `updateCasesProcessingSpeed`, `updateCaseContact`, `updateCaseSubscriptionCheckbox` accept any Id. `BREGRegistrationFormController.saveFormData` deserialises a client Case **including its Id** and upserts it (re-pointing ContactId to the attacker), builds affiliations/stocks with `put(anyField, value)`, and `saveRelatedFiles` deletes documents on any Case. `BREGContactControllerWithoutSharing.findExistingContact` is a PII existence oracle. 22 LWC-imported Apex classes are `without sharing` (F-20).
- **Impact:** Anonymous deletion of business-registration filings and complaints, takeover of other filers' cases in the portal, removal of supporting documents, and free expedited processing.
- **Fix:** Add ownership predicates (`ContactId = :currentContact` / session-bound random token for guests) to every Id-taking method; replace `JSON.deserialize(..., Case.class)` with DTOs and field allow-lists (drop Id, Status, OwnerId, ContactId, bypass/speed fields); move classes to `with sharing`/`inherited sharing` with narrow `SYSTEM_MODE` elevation.
- **P0 containment:** Hotfix: reject guest callers and non-owners in `deleteCase`, `updateCasesProcessingSpeed`, `updateCaseContact`, `updateCaseSubscriptionCheckbox`; strip client-supplied `Id` in `saveFormData`.

#### DCCA-008 — Guest-callable generic DML in the payment portal: create or update any record of any object (CustomRecordCreate, GenericCommunityPaymentController, CreateTransaction, GroupTransactionController, FilingController)
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** L · **Tier:** P0
- **Domain:** Payments/Transactions · **Category:** Security
- **Source findings:** S-08 (Critical)
- **Verified:** Verified — CustomRecordCreate.cls:14 `public without sharing`; :69-105 `@AuraEnabled` method builds `Schema.getGlobalDescribe().get(sObjName).newSObject()`, `put`s every client key and runs `update sObj` when an Id is supplied; granted on `pre-payment Profile` (L2252).
- **Evidence:** Client picks object, fields and record Id; all run in system mode. `CreateTransaction` upserts any Transaction and accepts `AmountOverride__c`; `GroupTransactionController` lists all open Transactions and updates a client list; `HPEAPRequestCreate` computes amount from client input; `FileDetailCreatorController` deletes by any Id and queues a callout to a client URL.
- **Impact:** Anonymous users can alter payments, amounts, Account/Contact ownership and email, or zero Transaction lines: complete loss of integrity of payment and licensing data.
- **Fix:** Remove from guest profiles (or take the pre-payment/securities/transcripts sites offline if unused); replace generic SObject parameters with typed DTOs, per-object allow-lists, `stripInaccessible` and `insert/update as user`; never honour a client Id without an ownership check.
- **P0 containment:** Confirm which of the pre-payment/securities/transcripts sites are live; deactivate unused sites; for live sites add a guest guard to the generic update path pending refactor.

#### DCCA-009 — Anonymous self-registration provisions portal users on a client-chosen existing Account and client-chosen Profile (account takeover); contact enumeration and orphan accounts
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Platform/Shared, Payments/Transactions · **Category:** Security
- **Source findings:** S-06 (Critical), S-26 (Medium)
- **Verified:** Verified — CustomCommunityRegistrationController.cls:17 `without sharing`; :183 `finalizeRecords(Account account, Contact contact, string profileName, ...)`; :222 `accId = account.Id`; :291 `[SELECT Id FROM Profile WHERE Name = :profileName]`; granted on `pre-payment Profile` (L2228).
- **Evidence:** An attacker registers with their own email while supplying another company's Account Id and any profile name; the user is created on that Account. `getExistingContact` matches `Email LIKE :email` with client wildcards and can create users for existing contacts. `CommunitiesSelfRegController` inserts Person Accounts before user creation (orphans on failure) and passes `startURL` unchecked; `CATV_SelfRegistrationController` overwrites existing Contacts.
- **Impact:** Portal login attached to someone else's business with account-based visibility of its filings, transactions and cases; PII enumeration; unsolicited user creation for real people.
- **Fix:** Hard-code the target profile server-side; never accept an Account Id from an unauthenticated client (create new, or queue a staff-approved access request); exact case-normalised email match with uniform responses; `Site.createExternalUser` inside a savepoint; remove PII debug lines.
- **P0 containment:** Hotfix `finalizeRecords` to ignore client `profileName` and `account.Id`; review recently created portal users for mismatched Account/Profile.

#### DCCA-010 — Symmetric encryption keys committed to source and used as authorisation tokens; guest-callable decrypt and encrypt oracles
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** CATV, Digital Forms sc_ · **Category:** Security
- **Source findings:** S-10 (Critical)
- **Verified:** Verified — labels/CustomLabels.labels-meta.xml:5259-5264 `CATV_EncryptionKey`, `<protected>false</protected>`, value 4234**** (masked); used as AES-128 key in CATV_CustomLookUpController.cls:34-37. The `CATV_SelfRegistrationController.decrypt` oracle and `PVL_EncodingService` static IV were not re-opened.
- **Evidence:** The CATV AES key is a plaintext, unprotected Custom Label readable by Aura at runtime. `CATV_SelfRegistrationController.decrypt` is an `@AuraEnabled` decrypt oracle on the CATV guest profile and its output chooses which Account a registrant joins. `PVL_EncodingService` uses AES-CBC with a static IV from `Org_Credential__mdt` and is exposed as REST `/Encoding` (encrypt oracle) and via `DraftApplicationDetailCont.decode()` (guest decrypt oracle).
- **Impact:** Anyone with repo access, or any guest via the oracle, can mint 'encrypted' Account Ids to request access to any cable operator's account, and forge Digital Form tokens; static IV plus error-leaking decrypt enables padding-oracle attacks.
- **Fix:** Stop using encryption as authorisation: issue single-use random server-side tokens; if encryption remains, keep keys in an External Credential/Protected CMT, use random IV plus HMAC verified before use; delete the `decrypt`/`decode` Aura methods; rotate both keys.
- **P0 containment:** Rotate the CATV key and `Org_Credential__mdt` key/IV; mark the label protected; disable the `decrypt`/`decode` methods.

#### DCCA-011 — SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_MODE (CATV self-registration lookup) and a second-order injection in a paid export
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** CATV, Payments/Transactions, BREG · **Category:** Security
- **Source findings:** S-07 (Critical), F-04 (Critical), S-27 (Low), S-30 (Low)
- **Verified:** Verified (with correction) — CATV_CustomLookUpController.cls:22 concatenates client `fieldApiName` into the WHERE clause and :35 runs it through CATV_WithoutSharingUtility.cls:51 `Database.queryWithBinds(..., AccessLevel.SYSTEM_MODE)`; `CATV Portal Profile` grants the class (L1856). Correction to F-04: the SELECT list is fixed to `Id, Type, Name` and the class itself is `with sharing`, so the caller cannot return 'any Account field' as F-04 states (un-queried fields throw); the injectable WHERE clause still allows enumeration of all Accounts in system mode and boolean-oracle extraction via semi-joins.
- **Evidence:** 30 of 235 dynamic-SOQL sites are injectable (02 Appendix A). Guest-reachable examples: `GenericCreatePaymentCtrl.cls:547-569` (LIKE values), `CustomCommunityRegistrationController.cls:160` (record-type name), `BREGEntityListBuilderController.cls:109-123` (IN list, dates; stored and re-executed by `BREGEntityListBuilderBatch`, whose CSV is emailed to the buyer), `BatchSummaryPDF.cls:11-60` (`printFields` URL parameter into the SELECT list, rendered with `escape="false"`). Minor variants: SOSL reserved characters unescaped (S-27) and `escapeSingleQuotes` misused on whole JSON payloads (S-30).
- **Impact:** Anonymous enumeration of Accounts (including Person Accounts), boolean-oracle reads of any field on any object, and paid exports returning more data than purchased.
- **Fix:** Bind every value (`:var` / `Database.queryWithBinds`); validate identifiers against `Schema` plus allow-lists; parse dates with `Date.valueOf`; run portal queries `WITH USER_MODE`; delete the generic `CATV_WithoutSharingUtility.queryRecords` SYSTEM_MODE sink; escape SOSL reserved characters.
- **P0 containment:** Hotfix `CATV_CustomLookUpController` to ignore client `fieldApiName`/`otherFieldApiName` (hard-code `Name`/`Type`); remove `BatchSummaryPDF` page from guest profiles.

#### DCCA-012 — Anonymous disclosure of payment receipts, billing PII, card last-4, draft licence applications and pending enforcement subjects by record Id or enumerable name
- **Severity:** Critical · **Exposure:** Guest / public · **Priority score:** 12 · **Effort:** M · **Tier:** P0
- **Domain:** Payments/Transactions, BREG, Digital Forms sc_, Cases/Complaints · **Category:** Security
- **Source findings:** S-09 (Critical), F-07 (High), P-09 (High)
- **Verified:** Verified — BREGPaymentController.cls:202-232 `@AuraEnabled getPaymentConfirmation(Id paymentId)` returns processor transaction/authorization Ids, card type, last-4 and billing email for any payment Id (only the contact block is hidden for guests); DraftApplicationDetailCont.cls:1-6 `without sharing getDraftApp(String name)` returns draft applications by Name (client userId ignored) and is granted to the guest Digital Form Profile. SEBSearchController and VF receipt pages were not re-opened.
- **Evidence:** `breg_PaymentConfirmation` reads `?pid=` from the URL. VF receipt pages on the PaymentConnect guest profile render any payment by `id`. `downloadDocument(docusignDocumentId)` streams any DocuSign document. Draft application names are `DT` + year + sequential AutoNumber; the Aura helper even trusts a `sessionStorage` override; card caches hold `socialSecurityNo`/`dob`. `SEBSearchController` (dcca guest, without sharing) returns contacts with *Pending* securities enforcement cases with no `Public__c` filter.
- **Impact:** Iterating sequential Ids discloses citizens' billing identities, partial card data, processor Ids, pending licence applications (possibly SSN/DOB) and names of people under pending enforcement: a reportable privacy breach.
- **Fix:** Bind every guest read to an unguessable per-record access token issued at creation; filter authenticated reads by owner `WITH USER_MODE`; remove card/processor fields from guest payloads; add `Public__c = true` and drop 'Pending' in SEB queries; look up drafts by server-issued token bound to the portal user; allow-list `cancel_url`.
- **P0 containment:** Hotfix `SEBSearchController` to require `Public__c = true`; strip card/processor fields from guest payloads in `getPaymentConfirmation`.

#### DCCA-013 — Outbound perimeter: active Remote Site Settings to a pipedream.net request bin, a raw-IP HTTP host, icanhazip and a staging tax endpoint; wildcard and all-directive CSP entries
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** S · **Tier:** P0
- **Domain:** Platform/Shared, Integrations CLM/DocuSign · **Category:** Security
- **Source findings:** S-23 (Medium), P-19 (Medium), P-20 (Medium)
- **Verified:** Verified — remoteSiteSettings/test.remoteSite-meta.xml: `isActive=true`, URL https://eod2cgfefmvt6uf.m.pipedream.net. Other entries not re-opened.
- **Evidence:** Active entries: `test` → pipedream request bin (unused in code), `WordpressSiteTestServer` → `http://44.232.202.215`, `icanhazip` (HTTP), `barcodes4.me` over HTTP (used by `DocGeneratorDataSourceDomain.cls:100`), `hitaxstaging.hawaii.gov` in production, QA SpringCM host. CSP: scheme-less `*.qualtrics.com`, `*.ccaiplatform.com`, trackers allowed all directives on Communities, three duplicate GTM entries.
- **Impact:** Ready-made exfiltration sinks for any Apex path that calls a client-supplied URL with the org's bearer token (DCCA-001) and for any anonymous-Apex user; taxpayer data possibly sent to staging; wider XSS/clickjacking blast radius on public portals.
- **Fix:** Delete `test`, `WordpressSiteTestServer`, `icanhazip`, staging and duplicate entries; move barcodes to HTTPS or on-platform; migrate remaining endpoints to Named Credentials; remove wildcard CSP entries and restrict trackers to Img/Connect.
- **P0 containment:** Deactivate the `test`, `WordpressSiteTestServer`, `icanhazip` and `TaxClearanceApiStagingEndpoint` Remote Sites; remove `Qualtrics_Wildcard`.
- **Scoring note:** Severity raised from Medium to High: combined with DCCA-001's arbitrary-URL callouts it is an active token-exfiltration channel. Pulled to P0 because containment is a zero-risk S-effort configuration change.

### P1 — Next 30 days (24 issues: 5 Critical, 14 High, 5 Medium)

| ID | Title | Sev | Exposure | Score | Effort | Sources |
|---|---|---|---|---|---|---|
| DCCA-014 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object and test classes inst… | High | Guest / public | 9 | L | S-15, P-17, S-25, A-14, P-31 |
| DCCA-015 | Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and PasswordNeverExpires; ven… | Critical | Internal | 4 | M | P-06, P-10, P-11, P-26 |
| DCCA-016 | Guest and community profiles over-provisioned: back-office cashier VF pages that start batches on page load, 6… | High | Guest / public | 9 | M | S-13, P-07, P-08, P-21, P-23, P-25 |
| DCCA-017 | Authenticated generic 'query anything / write anything' Aura endpoints and portal IDOR/mass assignment (notifi… | High | Authenticated external | 6 | M | S-11, S-12 |
| DCCA-018 | Tokens, session IDs, secret-bearing records and PII written to Apex debug logs and the browser console; OmniSc… | High | Authenticated external | 6 | S | S-16, F-13 |
| DCCA-019 | Public search and registration flows allow bulk harvesting and enumeration (unbounded limits, wildcard LIKE, e… | High | Guest / public | 9 | S | S-17 |
| DCCA-020 | CLM/DocuSign OAuth callback has no `state` (login CSRF binds the org integration to an attacker account); Sale… | High | Guest / public | 9 | M | S-18, S-22 |
| DCCA-021 | Exception messages and stack traces returned to guest and portal clients | Medium | Guest / public | 6 | S | S-19 |
| DCCA-022 | HTML/script injection: guest-influenced data unescaped into official PDFs, stored XSS via innerHTML in lookupS… | High | Guest / public | 9 | S | S-21, F-06, F-17 |
| DCCA-023 | Known-vulnerable jQuery 2.2.4, Bootstrap 3.3.6 and abandoned typeahead 0.10.5 loaded under community payment c… | High | Authenticated external | 6 | M | F-05 |
| DCCA-024 | Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisation (including a dev-s… | High | Guest / public | 9 | M | W-09, S-24, F-10, T-17 |
| DCCA-025 | Record details e-mailed to former vendor staff and a personal Gmail address (PB fault emails and email-alert C… | High | Internal | 3 | S | W-17 |
| DCCA-026 | BREG trigger framework 'once per transaction' guards silently skip handler logic for later 200-record chunks, … | Critical | Internal | 4 | M | A-02, W-02 |
| DCCA-027 | PVLProcess__e platform-event subscriber runs SOQL, DML, flows, enqueueJob, executeBatch and self-republishing … | Critical | Internal | 4 | L | A-05, W-01 |
| DCCA-028 | 48 active Process Builders (1,039 elements) and 1 Workflow Rule carry core Application, License, Payment and T… | High | Internal | 3 | XL | W-05, W-21 |
| DCCA-029 | Test.isRunningTest() changes production behaviour in 85 classes (~170 sites), including removal of the reconci… | Critical | Internal | 4 | L | T-01, T-09 |
| DCCA-030 | Payment, transaction and reconciliation code (~20 classes, ~3,000 LOC) is covered only by tests that assert no… | Critical | Internal | 4 | L | T-02 |
| DCCA-031 | Coverage-padding and zero-assertion tests: 36% of test classes assert nothing, 168 literal assert(true), swall… | High | Internal | 3 | M | T-03, T-05 |
| DCCA-032 | Date time-bomb tests: BREGAnnualRollOverJobTest fails from 2027-01-01 and will block every RunLocalTests deplo… | High | Internal | 3 | S | T-04 |
| DCCA-033 | No coverage baseline and no CI pipeline in the repo; 60% of production LOC depends on a single test class | Medium | Internal | 2 | S | T-15 |
| DCCA-034 | Fragile error handling on public payment and filing flows: Aura callbacks dereference null results, un-caught … | High | Guest / public | 9 | M | F-08, F-09 |
| DCCA-035 | Event-listener and interval leaks, broken popstate registration and a global Enter-key handler that can submit… | Medium | Guest / public | 6 | S | F-14 |
| DCCA-036 | Source references that break full-source deploys (missing Apex method, non-@AuraEnabled import, missing static… | Medium | Internal | 2 | S | F-11 |
| DCCA-037 | Accessibility gaps on the public portal (keyboard-inaccessible logout and payment-speed choice, missing alt te… | Medium | Guest / public | 6 | M | F-16 |

#### DCCA-014 — Integration secrets held in Public custom metadata, custom settings, a Public R/W object and test classes instead of Named/External Credentials; runtime Tooling API metadata writes
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** L · **Tier:** P1
- **Domain:** Integrations CLM/DocuSign, Platform/Shared · **Category:** Security
- **Source findings:** S-15 (High), P-17 (High), S-25 (Medium), A-14 (Medium), P-31 (Low)
- **Verified:** Partially verified — Public visibility confirmed for Org_Credential__mdt, SpringCLMSetting__mdt and breg_DocuSign_Auth__mdt; plaintext token persistence confirmed in SpringCMConnector.saveToken. TaxClearanceApi__c, qual_Integration_Settings__c, PVL_Portal_User__c fields and the test-class RSA key were not re-opened.
- **Evidence:** Secrets modelled as fields: `Org_Credential__mdt.Password__c/Key__c`, `SpringCLMSetting__mdt.Client_Secret__c`, `SpringCMApiEnvironment__mdt.Client_Secret__c`, `breg_DocuSign_Auth__mdt.Request_Private_Key__c` (JWT key; `DocuSignJWT` is granted to the BREG guest permission set), `TaxClearanceApi__c.Password__c` (Basic auth in `TaxClearanceApiHelper.cls:106-116`), `qual_Integration_Settings__c.qual_Api_Token__c`. OAuth tokens in `SpringCLM_Session__c` (Public R/W OWD; token FLS on external profiles). Plaintext `PVL_Portal_User__c.ProviderSchoolPassword__c`/`SecretAnswer__c`. A PEM RSA private key (value masked) sits in `DocuSignJWTTest.cls:3-4` and `DocusignAuthProviderTest.cls:133`. `sc_AppMetaDataManagement` creates/patches StaticResources at runtime through a Tooling API self-callout. Named Credentials, External Credentials and Connected Apps are not in source, so their configuration is unreviewable. Good practice already exists (`callout:Amazon_SES`, `callout:IMLCC`, `callout:OracleGL`).
- **Impact:** Secrets are readable by any Apex path that queries them (DCCA-002, DCCA-017), by admins and in every sandbox refresh; they cannot rotate independently of data; runtime metadata writes drift from source control.
- **Fix:** Migrate SpringCM, DocuSign (JWT with certificate in Certificate and Key Management), Tax Clearance and Qualtrics to Named + External Credentials; delete secret fields and `SpringCLM_Session__c` token storage; compare the test RSA key with the DocuSign app key and rotate if it matches; drop plaintext portal passwords/answers; add secret scanning (gitleaks) to CI; add Named/External Credentials and Connected Apps (secret-free) to the retrieve manifest; replace runtime StaticResource writes with a data object or CMS.

#### DCCA-015 — Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and PasswordNeverExpires; vendor profiles with org-wide read and metadata rights; no login IP ranges anywhere
- **Severity:** Critical · **Exposure:** Internal · **Priority score:** 4 · **Effort:** M · **Tier:** P1
- **Domain:** Platform/Shared · **Category:** Access Control
- **Source findings:** P-06 (Critical), P-10 (High), P-11 (High), P-26 (Medium)
- **Verified:** Verified — profiles/Integration.profile-meta.xml:38524-38525 and :38556-38557 enable ModifyAllData and PasswordNeverExpires; no ApiUserOnly element in the file; Wordpress Administrator :38598/:38634 same. User assignments are not in source.
- **Evidence:** `Integration`, `Wordpress Administrator`, `DCCA SEC/SEB System Administrator` and `DCCA System Administrator` can log in to the UI with never-expiring passwords and ModifyAllData (or Modify All on 91 objects). `DocuSign Integration`, `DCCA Integration1` and `Google Integration User` are API-only but hold ModifyAllData/ManageUsers/AssignPermissionSets. `Accenture User` has ViewAllData, AuthorApex, ModifyMetadata; `Pacxa User` has ViewAllData. None of 96 profiles has `loginIpRanges` or `loginHours`; `Security.settings` is not in source.
- **Impact:** A single phished or leaked integration credential gives full data and metadata control of the org from any network, including creating new admins; vendor access to all regulated data complicates breach attribution.
- **Fix:** Consolidate to one or two admin profiles; move integrations to the Salesforce Integration license with minimum API-only profiles plus scoped permission sets; remove PasswordNeverExpires from non-integration users; add IP ranges for admin, integration and vendor access; time-boxed vendor permission sets; enforce MFA; run Health Check.
- **Scoring note:** Critical kept despite Internal exposure: credential compromise of these accounts equals full org compromise. Tier P1 (Critical items are never below P1). Start the user-assignment audit during P0.

#### DCCA-016 — Guest and community profiles over-provisioned: back-office cashier VF pages that start batches on page load, 62 test classes, Create on 33 enforcement/fee/cash objects, sensitive FLS, Mass Delete pages, OmniStudio Designer
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** M · **Tier:** P1
- **Domain:** Payments/Transactions, Platform/Shared · **Category:** Access Control
- **Source findings:** S-13 (High), P-07 (High), P-08 (High), P-21 (Medium), P-23 (Medium), P-25 (Medium)
- **Verified:** Not spot-checked — Relies on reports 02 and 05 metadata evidence.
- **Evidence:** pre-payment/securities/transcripts guest profiles each grant 125 classes (62 `@isTest`) and 39 pages, including `CompletePaymentsDeposit` and `DepositRollupsButton` (batch starts on page load), `RunReconciliationBatch`, `PaymentCutOffBatch`, `SendTo4Gov`. PaymentConnect guest can Create on `Investigation__c`, `Sanction__c`, `LegalAction__c`, `FeeSchedule__c`, `CashierCode__c`, `Deposits__c` and more, reads 1,063 fields including `License__c.FEIN__c`, and has `EmailSingle`/`EditTask`. Community profiles expose `Mass_Delete_*` pages. `OmniStudio_Guest_User` grants Designer. External profiles hold dormant FLS on DOB/FEIN/SSN-template/token fields, and `BREG_Portal_User` can edit `breg_Bypass_Validation_Token__c`. `DCCA_Travel_Approval` grants 1,564 classes.
- **Impact:** Multiplies every other guest finding; cashier operations (deposit completion, reconciliation, 4Gov export) reachable from public URLs (DoS/integrity); dormant FLS turns one object-permission change into a PII leak; portal users can bypass affiliation validation rules.
- **Fix:** Rebuild guest profiles from a clean Guest profile with only the classes/pages the public components use (audit with the Guest User Access Report); remove test classes, back-office pages, Create on enforcement/config/cash objects, sensitive FLS, EmailSingle, Designer and Mass Delete; make the bypass token read-only; grant classes via feature permission sets.

#### DCCA-017 — Authenticated generic 'query anything / write anything' Aura endpoints and portal IDOR/mass assignment (notifications, transactions, DocuSign workflows, CATV invoices)
- **Severity:** High · **Exposure:** Authenticated external · **Priority score:** 6 · **Effort:** M · **Tier:** P1
- **Domain:** BREG, CATV, Platform/Shared · **Category:** Security
- **Source findings:** S-11 (High), S-12 (High)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `ListViewController`, `RelatedListController`, `LookUpController`, `LookupService`, `RelatedListTreeViewerController`, `FilingController` concatenate client object/field/WHERE/ORDER BY and some DML client-deserialised SObjects; granted to `DCCA BREG - CustomerCommunityLogin` and 20-40 internal profiles. Portal IDOR: `BREGNotificationsHandler.cls:122-157` updates any notification with any fields; `BREGCreateTransaction` upserts any Transaction with client `AmountOverride__c`; `BREGCaseController.cls:261-305` starts any DocuSign CLM workflow for any record and concatenates XML; `CATV_DashboardController` queries a client object name, downloads with the org SpringCM token, and lets a Requestor set an Invoice to Paid.
- **Impact:** Logged-in community users or clerks can read CMT secrets and FLS-hidden fields (SSN/EIN, investigation notes), write objects they lack CRUD on, alter other users' notifications and transactions, and trigger certificate/letter generation on other entities.
- **Fix:** Replace generic utilities with purpose-built controllers or LDS/`uiRecordApi`; if kept, allow-list via CMT, `WITH USER_MODE`, `as user` DML after `stripInaccessible`; add ownership predicates and fixed field allow-lists; allow-list `workflowName`; `String.escapeXml`; enforce status transitions server-side.

#### DCCA-018 — Tokens, session IDs, secret-bearing records and PII written to Apex debug logs and the browser console; OmniScript bundles ship admin identities
- **Severity:** High · **Exposure:** Authenticated external · **Priority score:** 6 · **Effort:** S · **Tier:** P1
- **Domain:** Platform/Shared, Integrations CLM/DocuSign · **Category:** Security
- **Source findings:** S-16 (High), F-13 (Medium)
- **Verified:** Not spot-checked — Relies on reports 02 and 03 evidence.
- **Evidence:** `SpringCMConnector.cls:203` logs the token; `SpringCMApiManager.cls:28` logs the full `SpringCLMSetting__mdt` record incl. client secret; `SpringCMRestHelper.cls:7,19` logs `UserInfo.getSessionId()`; registration and filing controllers log names, emails, officers and addresses (525 `System.debug` in prod). LWC/Aura: 429 `console.*` calls; `lwc/utils/utils.js` logs full filings; generated OmniScript `_def.js` files expose an admin username and User Id to anonymous users; `sc_testCardCaches.txt` is a Public static resource with employee emails.
- **Impact:** Anyone with debug-log or View All Data access (support vendors, every sandbox) can harvest bearer tokens, session IDs (session hijack) and the client secret; citizen PII persists on shared/public computers.
- **Fix:** Remove credential/session/full-record logging; route through the existing `CustomLogger` with redaction and level off by default; PMD `AvoidDebugStatements`; ESLint `no-console`; regenerate OmniScripts from a neutral integration user; delete `sc_test*` resources.

#### DCCA-019 — Public search and registration flows allow bulk harvesting and enumeration (unbounded limits, wildcard LIKE, existence oracles, internal Knowledge to guests)
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** S · **Tier:** P1
- **Domain:** BREG, Cases/Complaints, Platform/Shared · **Category:** Security
- **Source findings:** S-17 (High)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `BREGSearchAndBuyController.cls:67` accepts any client `queryLimit`; `SEBSearchController` matches everything on an empty term with unbounded `pageSize`; registration `LIKE` inputs accept client wildcards; `findExistingContact` returns Contact Ids; CATV registration returns distinct messages; `BREGHelpCenterController` returns internal-only Knowledge (no `IsVisibleInPkb`).
- **Impact:** Bulk harvesting of registrant, officer and agent data beyond the public-records design; enumeration feeds the IDOR attacks in DCCA-007/012.
- **Fix:** Clamp limits server-side, escape `%`/`_`, minimum search length, uniform registration responses, `IsVisibleInPkb = true` for guests, Platform Cache rate limiting.

#### DCCA-020 — CLM/DocuSign OAuth callback has no `state` (login CSRF binds the org integration to an attacker account); Salesforce session IDs forwarded to SpringCM; global SOAP `webservice` surface
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** M · **Tier:** P1
- **Domain:** Integrations CLM/DocuSign · **Category:** Security
- **Source findings:** S-18 (High), S-22 (Medium)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `DocuSignCallbackController.cls:7-11` reads `code` with no `state`, stores resulting tokens as org-wide integration tokens (`:57-59`) and renders provider error bodies. `InvocableSpringCMDocGen.cls:30` sends `UserInfo.getSessionId()` to SpringCM; the class is granted to the `dcca` guest profile and invoked from flows. `SpringCMRestHelper.cls:26-40` exposes `webservice` methods that accept a session Id.
- **Impact:** Tricking an admin into one URL routes generated government documents to an attacker's CLM tenant; a compromised SpringCM tenant or its logs yield live Salesforce sessions.
- **Fix:** Replace with a Named Credential/Auth Provider (native `state`); if kept, random `state` verified on return, URL-encode `code`, restrict page to an integration-admin permission set; replace session forwarding with an OAuth connected app; remove unused `webservice` methods.

#### DCCA-021 — Exception messages and stack traces returned to guest and portal clients
- **Severity:** Medium · **Exposure:** Guest / public · **Priority score:** 6 · **Effort:** S · **Tier:** P1
- **Domain:** BREG, Payments/Transactions · **Category:** Security
- **Source findings:** S-19 (Medium)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString())` at `BREGSearchAndBuyController.cls:149` (BREG guest) and similar; at least 55 raw `e.getMessage()` returns in 24 classes including both REST endpoints.
- **Impact:** Leaks class/method names, line numbers, field API names and query fragments, accelerating SOQL injection and mass-assignment attacks.
- **Fix:** Log server-side via `CustomLogger` with a correlation Id; return a generic message with the reference; fixed REST error JSON.

#### DCCA-022 — HTML/script injection: guest-influenced data unescaped into official PDFs, stored XSS via innerHTML in lookupSearchResult, aura:unescapedHtml on community record forms, DOM-XSS candidate
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** S · **Tier:** P1
- **Domain:** Payments/Transactions, PVL/Licensing · **Category:** Security
- **Source findings:** S-21 (Medium), F-06 (High), F-17 (Medium)
- **Verified:** Not spot-checked — Relies on reports 02 and 03 evidence.
- **Evidence:** 192 `escape="false"`; guest-influenced values reach `BatchSummaryPDF.page:7`, `TransactionPaymentReceiptPdf.page:153` (description settable via `TransactionREST`) and renewal PDFs. `lwc/lookupSearchResult/lookupSearchResult.js:8-22` writes record names via `innerHTML` with the ESLint rule disabled. `CustomRecordCreateField.cmp:72-75` renders read-only textareas with `aura:unescapedHtml`. `FilingOverride.page` passes `Filing__r.Name` into `jQuery.html()`.
- **Impact:** Phishing/spoofed content on DCCA-letterhead receipts and renewal letters; script execution in internal users' sessions able to call any `@AuraEnabled` method.
- **Fix:** Remove `escape="false"` unless values are built with `escapeHtml4`; render highlight via template (`{pre, match, post}`); use `lightning:formattedRichText`; `JSENCODE` + `.text()` in FilingOverride.

#### DCCA-023 — Known-vulnerable jQuery 2.2.4, Bootstrap 3.3.6 and abandoned typeahead 0.10.5 loaded under community payment components; stale public WordPress dump with legacy trackers
- **Severity:** High · **Exposure:** Authenticated external · **Priority score:** 6 · **Effort:** M · **Tier:** P1
- **Domain:** Payments/Transactions, Platform/Shared · **Category:** Front End
- **Source findings:** F-05 (High)
- **Verified:** Not spot-checked — Relies on report 03 evidence (versions from file headers).
- **Evidence:** `InputLookup`/`InputLookup2` `ltng:require` jQuery 2.2.4 (CVE-2015-9251, CVE-2019-11358, CVE-2020-11022/11023), Bootstrap 3.3.6 (CVE-2018-14040/1/2, CVE-2019-8331) and typeahead 0.10.5; used under `CustomRecordCreate` inside `GenericCommunityPayment`/`HPEAPRequestCreate`. `CustomTemplate` (Public cache) contains jQuery 1.12.4, Thickbox 3.1, legacy GA and `__MACOSX` files.
- **Impact:** Library-level XSS paths on community payment pages; every publicly served copy will be flagged by scanners and state auditors.
- **Fix:** Migrate `InputLookup`/`InputLookup2` to one LWC lookup (`lightning-record-picker`) and delete the resources; stop-gap upgrade to jQuery 3.7.x / Bootstrap 3.4.1.

#### DCCA-024 — Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisation (including a dev-sandbox payment checkout URL default on a community component)
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** M · **Tier:** P1
- **Domain:** Platform/Shared, Payments/Transactions, PVL/Licensing · **Category:** Security
- **Source findings:** W-09 (Medium), S-24 (Medium), F-10 (High), T-17 (Low)
- **Verified:** Not spot-checked — Relies on reports 02, 03, 04 and 06 evidence.
- **Evidence:** `CustomPaymentButton.cmp:24` defaults `paymentPageURL` to a `dev-hawaiidcca.cs33.force.com` sandbox checkout. RecordType Id `012t0000000PLy1AAG` in Apex, Aura and tests; 46 labels hold record Ids (some sandbox); 11 hard-coded Ids in 9 active flows (150 LicenseType Ids in one PB, queue/user/contact/cashier Ids, from at least two orgs); terminal devices mapped to named staff. Authorisation by profile **name** (`AccountDomain.cls:40-44` treats any profile containing 'Digital' - including the Digital Form guest profile - like PVL staff; `FilingService.cls:19-24` exempts a community profile). UAT endpoints in prod code (see DCCA-050).
- **Impact:** Citizens could be redirected to a sandbox checkout if the Builder property is blank; automation fails or writes bad references after refresh or in new orgs; renaming/cloning a profile grants or removes privileges.
- **Fix:** Move URLs and Ids to Custom Metadata/labels keyed by DeveloperName; resolve record types, queues and permission sets by DeveloperName; replace profile-name checks with Custom Permissions; derive site URLs server-side (reuse `getPaymentSiteBaseUrl`).

#### DCCA-025 — Record details e-mailed to former vendor staff and a personal Gmail address (PB fault emails and email-alert CCs)
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** S · **Tier:** P1
- **Domain:** PVL/Licensing, Platform/Shared · **Category:** Security
- **Source findings:** W-17 (Medium)
- **Verified:** Not spot-checked — Relies on report 04 evidence.
- **Evidence:** 'Process failed' emails from 7 PBs go to `@pacificpointcorp.com` staff; `ExamBranchNotificationofAddressChange` CCs a PacificPoint address and a personal `gmail.com` address; RICO and Requisition alerts CC vendor staff; a DFI sender is a Gmail address; 16 division mailboxes and production URLs hard-coded.
- **Impact:** Ongoing egress of regulated record data to non-agency and personal accounts - a privacy/compliance problem for a state regulator; notifications break as staff change.
- **Fix:** Remove external/personal addresses now; route fault emails to a monitored DCCA mailbox or a log object; use public groups/CMT for recipients and `URL.getOrgDomainUrl()` for links.
- **Scoring note:** Severity raised from Medium to High and tier pulled to P1: it is an active, ongoing PII egress that is S effort to stop.

#### DCCA-026 — BREG trigger framework 'once per transaction' guards silently skip handler logic for later 200-record chunks, later DML and partial-save retries; Case trigger globally disabled after first after-event
- **Severity:** Critical · **Exposure:** Internal · **Priority score:** 4 · **Effort:** M · **Tier:** P1
- **Domain:** BREG · **Category:** Automation
- **Source findings:** A-02 (Critical), W-02 (Critical)
- **Verified:** Verified — BREGBaseTriggerHandler.cls:9 `ALLOW_RECURSION_DEFAULT = false`; :13 static `Set<String> triggerHandlerAndOperation`; :172-189 `isFirstRun()` keyed only by handler name + operation, never cleared; BREGCaseTrigger.trigger:7-12 sets `TriggerUtils.disableTrigger = true` after the first after-event.
- **Evidence:** Nine BREG handlers (Account, AccountAffiliation, Document, Payment, TNTMSM, Task, Transaction, TxnBusInfo, TransactionLine) run at most once per operation per transaction. After the first Case after-trigger, every later Case DML skips both before and after BREG logic (including validations) until manually reset. Workarounds already exist: an invocable 'Reset Disable Trigger' called by `BREG_Transaction_Line_After`, and a manual reset in `BREGRegistrationFormController.cls:248`. Several BREG batches use `Database.update(list, false)`, whose retry path re-fires triggers with static state intact.
- **Impact:** Records 201+ in any DML, and any later DML in the same transaction, commit without status transitions, validations, file-number assignment, fee creation or DocuSign workflows - silent, hard-to-detect data inconsistency.
- **Fix:** Replace flag guards with record-level idempotency (static `Set<Id>` per operation or old/new comparison); scoped bypass with try/finally; add 201-record and partial-failure tests.
- **Scoring note:** Critical kept (silent data corruption); tier P1 by the 'Critical never below P1' rule.

#### DCCA-027 — PVLProcess__e platform-event subscriber runs SOQL, DML, flows, enqueueJob, executeBatch and self-republishing per event with no retry or checkpoint
- **Severity:** Critical · **Exposure:** Internal · **Priority score:** 4 · **Effort:** L · **Tier:** P1
- **Domain:** PVL/Licensing · **Category:** Automation
- **Source findings:** A-05 (High), W-01 (Critical)
- **Verified:** Verified — triggers/PVLProcessTrigger.trigger (264 lines): loop over Trigger.new at :6; DML at :57, :74, :88, :237; Flow.Interview at :137, :212, :225; EventBus.publish at :247; Database.executeBatch at :260; no RetryableException/setResumeCheckpoint found.
- **Evidence:** 12 command types dispatched by `Type__c` inside the per-event loop. Events are published one per `Notification__c` by `NotificationDomain` and by PBs that create up to 17 notifications each. Platform-event triggers receive up to 2,000 events per batch; report 01 estimates ~16 'DependencyFlow' events and report 04 ~50 events exhaust SOQL/enqueue limits (the exact threshold depends on the called flows).
- **Impact:** A mass-notification or renewal run can throw a limit exception and drop the whole event batch without retry: licence letters/PDFs not generated, licence terminations not applied, collection allocations lost, with only a log line.
- **Fix:** Group events by type and bulk-process (one query/DML per type, one Queueable/batch per type); `setResumeCheckpoint` and `EventBus.RetryableException`; `PlatformEventSubscriberConfig` batch size; replace per-application `Flow.Interview` with a collection-based invocable; log failed payloads durably.
- **Scoring note:** Critical kept; tier P1 by the 'Critical never below P1' rule.

#### DCCA-028 — 48 active Process Builders (1,039 elements) and 1 Workflow Rule carry core Application, License, Payment and Transaction logic after Salesforce end of support (2025-12-31)
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** XL · **Tier:** P1
- **Domain:** PVL/Licensing, Payments/Transactions · **Category:** Automation
- **Source findings:** W-05 (High), W-21 (Low)
- **Verified:** Verified — 48 flow files with processType Workflow/InvocableProcess and status Active counted in flows/.
- **Evidence:** Largest: `ApplicationProcesses` (203 elements), `LicenseImmediateActions` (141), `FilingImmediateActions` (76), `PaymentImmediateActions` (44). `TransactionConsolidatedProcessBuilder` and `InsuranceBondHandler` have recursion enabled. Known logic defect: `Account_Set_Contact_on_Person_Account` ANDs four `isChanged` conditions (probably meant OR). Five near-duplicate per-board renewal flows and 17 flows with `Copy_N_of_*` elements.
- **Impact:** No bug fixes or support cases for the automation behind every critical PVL object; poor bulk behaviour and undefined ordering with after-save flows; editing is increasingly hard in current tooling.
- **Fix:** Migrate by object, financial first (Transaction, Payment), then Application and License: Migrate to Flow tool as a start, then refactor same-record updates to before-save, cross-object DML to bulkified after-save or Apex, emails to actions; add fault paths during migration; retire the Account Workflow Rule.
- **Scoring note:** Pulled to P1 because the support deadline has already passed (time-bound); delivery is phased across Stabilize and Modernize.

#### DCCA-029 — Test.isRunningTest() changes production behaviour in 85 classes (~170 sites), including removal of the reconciliation filter; callouts bypassed instead of mocked
- **Severity:** Critical · **Exposure:** Internal · **Priority score:** 4 · **Effort:** L · **Tier:** P1
- **Domain:** Payments/Transactions, PVL/Licensing, Integrations CLM/DocuSign · **Category:** Testing
- **Source findings:** T-01 (Critical), T-09 (Medium)
- **Verified:** Verified — ReconciliationBatchJob.cls:61-72: under Test.isRunningTest() the query is just `FROM CollectionsAllocation__c`; otherwise it applies the Reconciliation_Batch__c/PaymentType/CutOffBatchDate/Owner/Status filters. Independent grep found ~167 occurrences in ~83 non-test classes (reports cite 166-173 in 85).
- **Evidence:** 14 forced `|| Test.isRunningTest()` branches (e.g. `PaymentCutOffProcessingController.cls:30`), 15 fake-data injections (`IMLCCQueueable.cls:142-153`), DML/async/flow skipped in tests (`BREGTransactionLineTriggerHandler.cls:114,132` skips DocuSign workflows after payment; `PVLProcessTrigger.trigger:141` never starts flows), callouts short-circuited in `IMLCCConnector`, `SpringCMConnector` (13 sites), `UploadCaseFileToDocSignQueueable`, `sc_AppMetaDataManagement`.
- **Impact:** Coverage overstates what is verified: the money-selection logic, application inserts, status guards and response parsing that run in production are not what tests run, so defects there can only appear in production.
- **Fix:** Ban new occurrences via Code Analyzer/PMD in CI; replace callout bypasses with `HttpCalloutMock`; replace data/config bypasses with `@TestVisible` seams or `Test.createStub`; remove every `|| Test.isRunningTest()`; refactor `ReconciliationBatchJob` first.
- **Scoring note:** Critical kept; tier P1 by the 'Critical never below P1' rule.

#### DCCA-030 — Payment, transaction and reconciliation code (~20 classes, ~3,000 LOC) is covered only by tests that assert nothing
- **Severity:** Critical · **Exposure:** Internal · **Priority score:** 4 · **Effort:** L · **Tier:** P1
- **Domain:** Payments/Transactions · **Category:** Testing
- **Source findings:** T-02 (Critical)
- **Verified:** Verified — PaymentRESTTest.cls contains 0 assertions; GenericCreatePaymentControllerTest.cls:159-187 has its only three asserts inside a comment block.
- **Evidence:** `GenericCreatePaymentCtrl` (1,033 LOC) has one test with commented-out asserts; `TransactionServiceTest` is a 3-statement method; `PaymentRESTTest` builds ~110 lines of setup and checks nothing; 17 more zero-assert finance tests. Finance trigger handlers (`BREGPaymentTriggerHandler`, `TransactionHandler`, `PaymentDeduplicator`, `Transaction_Handler`) have no direct unit test.
- **Impact:** Money-handling logic (payment creation, refunds, cut-off, reconciliation, line regeneration) can regress with every test green; deleting these tests would also remove ~3,000 LOC of coverage at once.
- **Fix:** Priority test backlog: for each public payment entry point assert records created/updated (amounts, statuses, allocations), REST response code/body, and at least one negative path; restore the commented asserts; include tampered-cart tests for DCCA-003.
- **Scoring note:** Critical kept; tier P1 by the 'Critical never below P1' rule.

#### DCCA-031 — Coverage-padding and zero-assertion tests: 36% of test classes assert nothing, 168 literal assert(true), swallowed exceptions
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** M · **Tier:** P1
- **Domain:** Platform/Shared, PVL/Licensing · **Category:** Testing
- **Source findings:** T-03 (Critical), T-05 (High)
- **Verified:** Verified (sample) — PVL_SelectorTest.cls:36-42 wraps each selector call in `try {...} catch(Exception ex) {}` with no assertion.
- **Evidence:** 499 of 3,708 test methods (13.5%) have no assertion; 191 of 526 test classes (36%) have none anywhere; 259 more assert only trivia; 168 `assert(true...)` in 53 classes; 65 empty/debug-only catches; `LicenseServiceCoverageTest` states its purpose is 'coverage uplift'; `JVFormControllerTest` only exercises a hard-coded dummy-data branch.
- **Impact:** Tests exist to satisfy the 75% gate rather than detect defects; ~20% of production LOC is referenced only by tests that check nothing.
- **Fix:** Turn on PMD `ApexUnitTestClassShouldHaveAsserts` plus a custom rule banning `assert(true` and empty catches (warn, then fail for new/modified tests); rewrite the worst offenders; delete dummy `else` branches in JV/TDR controllers.
- **Scoring note:** Severity lowered from Critical (T-03) to High: padding hides risk but does not itself change production behaviour; the production-impacting parts are DCCA-029 and DCCA-030. Kept in P1 as a CI enabler (the gate is S effort).

#### DCCA-032 — Date time-bomb tests: BREGAnnualRollOverJobTest fails from 2027-01-01 and will block every RunLocalTests deployment; other tests hard-code Oct-Nov 2026 dates
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** S · **Tier:** P1
- **Domain:** BREG, PVL/Licensing · **Category:** Testing
- **Source findings:** T-04 (High)
- **Verified:** Verified — BREGAnnualRollOverJobTest.cls:101/133 declare a 2026 referenceDateTime that is never passed to the job; asserts at :125 `Date.newInstance(2026,1,1)` and :162 `Date.newInstance(2026,4,1)`; BREGAnnualRollOverJob.cls:18 `referenceDateTime = DateTime.now()` and :60 derives the year from it. ApplicationTriggerTest.cls:501,518,571 use bond term 2026-10-07 and 2026-09-30 dates; whether those assertions depend on TODAY was not confirmed.
- **Evidence:** The job derives its reference year from `DateTime.now()`, the test asserts 2026 dates. `ApplicationTriggerTest` and `ApplicationHcRenewalValidationTest` build bonds with term dates of 2026-10-07 and 2026-11-20 that production code filters with `TermDate__c >= TODAY` (`ApplicationService.cls:117`). `InsuranceBondDomainTest` passes explicit coverage dates to the domain method and is probably not date-sensitive (correction to T-04).
- **Impact:** From 2027-01-01 (three months away) every production deployment running local tests fails, including emergency fixes; the bond-date tests may start failing as early as 2026-10-08.
- **Fix:** Make the job's reference date `@TestVisible` and set it in the test; replace absolute dates with `Date.today().addDays(n)`; add a scheduled clock-shift CI run.
- **Scoring note:** Pulled to P1 with a hard deadline of 2026-12-01 (time-bound). A full local test run is a P0 action to detect any earlier failures.

#### DCCA-033 — No coverage baseline and no CI pipeline in the repo; 60% of production LOC depends on a single test class
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** S · **Tier:** P1
- **Domain:** Platform/Shared · **Category:** Testing
- **Source findings:** T-15 (Medium)
- **Verified:** Not spot-checked — Relies on report 06 evidence (empty .sfdx testresults directory).
- **Evidence:** The cached test-results directory is empty; no CI configuration exists; 443 of 744 production classes are referenced by exactly one test class; removing the 191 zero-assert classes would put ~18,500 LOC of coverage at risk.
- **Impact:** Nobody knows the real margin above 75%; one failing or time-bombed test, or a well-meant clean-up, can block a production deployment without warning.
- **Fix:** Run `sf apex run test --code-coverage` in CI on every PR and store per-class baselines; alert within 5 points of 75%; replace padding tests before deleting them; add PMD/Code Analyzer and `sf project deploy validate` to the pipeline.
- **Scoring note:** Pulled to P1 as the enabler for every other test and refactor item.

#### DCCA-034 — Fragile error handling on public payment and filing flows: Aura callbacks dereference null results, un-caught awaits, console-only errors, frozen spinners and duplicate submissions
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** M · **Tier:** P1
- **Domain:** Payments/Transactions, BREG · **Category:** Front End
- **Source findings:** F-08 (High), F-09 (High)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** `GenericCreatePayment` has 11 callbacks and 0 `getState()`/ERROR branches (30 `getReturnValue().x` across Aura). `breg_CheckoutPage.createPaymentAndNavigate` awaits `createPayment` outside any `try`; expedite failures are only logged; `breg_Changes` has five un-caught awaits; `paymentDisplay` polls Apex every second forever on rejection.
- **Impact:** Citizens see frozen payment screens and retry, creating duplicate filings/payments; partial state (payment created, expedite not applied) that support cannot reproduce.
- **Fix:** Shared Promise-based `callApex` helper for Aura and `reduceErrors`/toast/logger for LWC; `try/catch/finally` around every imperative call; ESLint `promise/catch-or-return`; quick patch of the 11 GenericCreatePayment callbacks.

#### DCCA-035 — Event-listener and interval leaks, broken popstate registration and a global Enter-key handler that can submit applications more than once
- **Severity:** Medium · **Exposure:** Guest / public · **Priority score:** 6 · **Effort:** S · **Tier:** P1
- **Domain:** BREG, PVL/Licensing · **Category:** Front End
- **Source findings:** F-14 (Medium)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** `window.addEventListener('popstate', this.handlePopstate())` registers `undefined`; `ApplicationRecordsWizard` adds a new global keydown submit handler on every init; intervals never cleared; `renderedCallback` appends a `<style>` on every render.
- **Impact:** Broken back/forward navigation, duplicate licence application submissions, growing DOM and extra Apex traffic on long portal sessions.
- **Fix:** Bind handlers once, add in `connectedCallback`, remove in `disconnectedCallback`; clear intervals; guard `renderedCallback`; Aura `destroy` handler.

#### DCCA-036 — Source references that break full-source deploys (missing Apex method, non-@AuraEnabled import, missing static resource)
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** S · **Tier:** P1
- **Domain:** Platform/Shared, Integrations CLM/DocuSign · **Category:** Front End
- **Source findings:** F-11 (Medium)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** `util_closer_LogViewer` imports a non-existent `exportCaseLogsAsCsv`; `springFileFix` imports `SpringCMConnector.getAccessToken`, which is not `@AuraEnabled`; `CustomRecordCreateMap` references a missing `leaflet_1_0_2` resource.
- **Impact:** CI/CD and sandbox seeding from source fail, blocking the pipeline work in DCCA-033.
- **Fix:** Add or remove the missing method; delete `springFileFix`; add or remove the Leaflet reference; `sf project deploy validate` in CI.
- **Scoring note:** Pulled to P1 because it blocks CI (enabler).

#### DCCA-037 — Accessibility gaps on the public portal (keyboard-inaccessible logout and payment-speed choice, missing alt text and labels) against WCAG 2.1 AA
- **Severity:** Medium · **Exposure:** Guest / public · **Priority score:** 6 · **Effort:** M · **Tier:** P1
- **Domain:** BREG · **Category:** Front End
- **Source findings:** F-16 (Medium)
- **Verified:** Not spot-checked — Relies on report 03 evidence; legal applicability to be confirmed by agency counsel.
- **Evidence:** Clickable `div`/`p` elements with no role, tabindex or key handlers for Account Settings, Logout and the Expedited choice; 14 LWC and 7 Aura such elements; `<img>` without alt on public CMS tiles; 46 unlabeled inputs.
- **Impact:** Keyboard and screen-reader users cannot log out or choose processing speed; legal exposure under the DOJ ADA Title II web rule (report 03 cites an April 2026 compliance date for large public entities).
- **Fix:** Use buttons/`lightning-button-menu`/`lightning-radio-group`; add alt and labels; run axe/`@sa11y/jest` in the Jest suite.

### P2 — Next quarter (19 issues: 13 High, 6 Medium)

| ID | Title | Sev | Exposure | Score | Effort | Sources |
|---|---|---|---|---|---|---|
| DCCA-038 | Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; generic system-mode DML h… | High | Guest / public | 9 | XL | S-14, A-10, F-20, S-29 |
| DCCA-039 | Privilege-escalation paths: permission sets combining ManageUsers + AssignPermissionSets + ManageProfilesPermi… | High | Internal | 3 | S | P-12, P-14 |
| DCCA-040 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' permission sets with … | High | Internal | 3 | L | P-13, P-15, P-16, P-18, P-27 |
| DCCA-041 | Money-path save cascade: Transaction, TransactionLine and Payment re-save each other through 7 triggers, 6 PBs… | High | Internal | 3 | L | W-03 |
| DCCA-042 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus static/inline styles, … | High | Internal | 3 | XL | A-03, A-04, A-06, W-08, W-15 |
| DCCA-043 | Over-automated core objects with undefined order: Application (1 trigger, 15 after-save flows, 4 PBs), Case (2… | High | Internal | 3 | XL | W-04, W-11, W-20 |
| DCCA-044 | Batch jobs, @future and Queueables started per record from triggers; @future called from trigger context witho… | High | Internal | 3 | M | W-06, W-12 |
| DCCA-045 | DML, SOQL, subflows and email actions inside flow loops (21 loops in 14 active flows); scheduled bounceback fl… | High | Internal | 3 | M | W-07, W-22 |
| DCCA-046 | Silent failures: 577 of 609 flow DML/action elements lack fault paths (including Oracle GL and DocuSign screen… | Medium | Internal | 2 | M | W-10, W-14 |
| DCCA-047 | Payment batches self-schedule every 5 minutes (24 cron slots, 576 starts/day) with no overlap protection | Medium | Internal | 2 | M | W-13 |
| DCCA-048 | Flow version state disagrees with flowDefinitions (a Draft subflow called by an active PB); active 'Testing: E… | Medium | Internal | 2 | S | W-16 |
| DCCA-049 | Authenticated Apex REST resources lack server-side authorisation: forged 'public' BREG documents, any-document… | Medium | Authenticated external | 4 | M | S-20 |
| DCCA-050 | Three separate DocuSign CLM/SpringCM client stacks (one at API v31), with a hard-coded UAT endpoint called fro… | High | Internal | 3 | L | A-09 |
| DCCA-051 | God classes and oversized `without sharing` portal controllers; Domain/Service/Selector layering exists only i… | High | Internal | 3 | XL | A-07, A-08 |
| DCCA-052 | Dead code and test scaffolding deployed to production (active no-op trigger, commented-out classes, ~28 unrefe… | Medium | Internal | 2 | S | A-15, A-18, F-25, T-14 |
| DCCA-053 | Thin bulk, permission and negative-path testing: ~8 of 61 triggers ever see 200+ records; runAs in 7% of test … | High | Internal | 3 | M | T-07, T-11, T-12 |
| DCCA-054 | No LWC Jest tests (0 of 232 components); pre-commit hook passes with --passWithNoTests | High | Internal | 3 | L | F-12, T-08 |
| DCCA-055 | Production entry points with no test path (41 classes) or no direct test (210 classes), including flow Invocab… | High | Internal | 3 | M | T-06 |
| DCCA-056 | CATV uploads advertise 25 MB but send base64 through an Apex parameter (fails above ~3 MB); PDF type check is … | Medium | Authenticated external | 4 | S | F-19 |

#### DCCA-038 — Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; generic system-mode DML helpers
- **Severity:** High · **Exposure:** Guest / public · **Priority score:** 9 · **Effort:** XL · **Tier:** P2
- **Domain:** Platform/Shared, BREG · **Category:** Security
- **Source findings:** S-14 (High), A-10 (High), F-20 (Medium), S-29 (Low)
- **Verified:** Not spot-checked — Relies on reports 01, 02, 03 evidence; counts differ slightly by method (see Limitations).
- **Evidence:** ~128 `without sharing` and ~286-292 undeclared production classes; 52 of 176 entry-point classes are `without sharing`, 36 of them guest-reachable; 8 of 97 `@AuraEnabled` classes contain any CRUD/FLS token; 39 enforcement tokens vs ~690 DML and ~1,328 queries. Generic system-mode helpers: `BREGSObjectUpdaterWithoutSharing.selectRecordsByQuery(String)`, `CATV_WithoutSharingUtility`, `WithoutSharingDmlHelper`, `AccessLess`. Trigger handlers run in system mode for guest DML and amplify guest writes (COGS creation, DocuSign workflows).
- **Impact:** Internal least privilege (FLS on SSN/EIN/DOB, investigation, payment data) is not honoured wherever Apex is used; any controller mistake becomes cross-tenant data access.
- **Fix:** Baseline: `with sharing`/`inherited sharing` everywhere, `WITH USER_MODE` queries, `as user` DML; isolate elevation in small fixed-query `*SystemMode` helpers; replace generic helpers; PMD `ApexCRUDViolation`/`ApexSharingViolations`/`ApexSOQLInjection` failing the build on new violations; label each community `@AuraEnabled` method self-scoped/public/needs-check.
- **Scoring note:** Score 9 but XL effort: tiered P2 as a programme; the guest-reachable subset is handled by DCCA-007/008/011/012/017.

#### DCCA-039 — Privilege-escalation paths: permission sets combining ManageUsers + AssignPermissionSets + ManageProfilesPermissionsets; data-export profile with ModifyMetadata and Modify All on enforcement/payment objects
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** S · **Tier:** P2
- **Domain:** Platform/Shared · **Category:** Access Control
- **Source findings:** P-12 (High), P-14 (High)
- **Verified:** Not spot-checked — Relies on report 05 evidence.
- **Evidence:** `SEBSECAdministrator`, `Multi_Factor_Authentication_in_API` and its identical duplicate `JKEC_Manage_MFA_in_API` can assign themselves ModifyAllData. `DCCA ISCO Data Export` has DataExport, ModifyMetadata and Modify All on 27 objects including SEBCase, Investigation, Transaction, Deposits, FeeSchedule.
- **Impact:** Holders are effectively System Administrators; the export profile is an ideal exfiltration account.
- **Fix:** Replace with Delegated Administration scoped to SEB/SEC roles; delete the JKEC duplicate; strip the MFA set to ManageTwoFactor; replace the ISCO profile with the `DCCA_ISCO` permission set on a minimum profile.

#### DCCA-040 — Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' permission sets with View All (and Modify All on payments), staff Modify All, wide Export/API rights, open external sharing on 10 objects
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** L · **Tier:** P2
- **Domain:** Platform/Shared, PVL/Licensing, Payments/Transactions · **Category:** Access Control
- **Source findings:** P-13 (High), P-15 (High), P-16 (High), P-18 (Medium), P-27 (Medium)
- **Verified:** Not spot-checked — Relies on report 05 evidence.
- **Evidence:** Public R/W OWD on `License__c`, `Application__c`, `SEBCase__c`, `HPEAPRequest__c` (SSN last-4), `Deposits__c`, `BREG_ADDRESS_PROTECTION__c`, `Voice_Call_Session_Recording__c`, `SpringCLM_Session__c`. `Read_Only_DCCA_Payments` = View All on 264 objects plus Modify All/Delete on `pymt__PaymentX__c`; `Read_Only_BREG` = View All on 323; `QueryAllFiles` grants ViewAllData. Modify All on licensing/payment/enforcement objects for many staff profiles; ExportReport on 73 grants, ApiEnabled on 87. External Read/ReadWrite OWD on `Application_Cache__c`, `breg_TN_TM_SM__c`, `breg_Stock__c`.
- **Impact:** Division-based sharing rules are undone; clerical users can bulk-export org-wide PII; address-confidentiality records are open to all internal users.
- **Fix:** Private OWD for sensitive objects (start with BREG_ADDRESS_PROTECTION__c, HPEAPRequest__c, SEBCase__c, Voice_Call_Session_Recording__c, SpringCLM_Session__c) with criteria sharing; rebuild 'read-only' sets with Read not View All; remove payment Modify All/Delete; power-user permission set for Export/Transfer; Field History/Audit Trail on payment amount/status; external OWD Private where not needed.

#### DCCA-041 — Money-path save cascade: Transaction, TransactionLine and Payment re-save each other through 7 triggers, 6 PBs (one recursive) and several flows with no recursion guard or change detection
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** L · **Tier:** P2
- **Domain:** Payments/Transactions · **Category:** Automation
- **Source findings:** W-03 (High)
- **Verified:** Verified (sample) — TransactionLineHandler.cls:38 performs an unconditional `update transactionList`.
- **Evidence:** Every TransactionLine insert/update re-saves its parent Transaction even when nothing changed; Transaction automation updates group parents, children and Payments; Payment has three independent triggers (`PaymentAll`, `PaymentTrigger`, `BREGPaymentTrigger`) in undefined order that both recalculate totals; `TransactionAll` never subscribes to before-insert so `Transaction_Handler` before-insert hooks cannot run.
- **Impact:** Each payment edit multiplies SOQL/DML/CPU; lockbox imports, reconciliation and migrations risk `Too many SOQL`, CPU timeouts and `UNABLE_TO_LOCK_ROW` against the 5-minute payment batches (DCCA-047); totals may be computed from stale values.
- **Fix:** Change detection in `UpdateParentTotalAmount`; processed-Id guards in Transaction handlers; merge `PaymentAll` + `PaymentTrigger` (+ BREG) into one trigger; consolidate the three Transaction PBs and the TransactionLine PB; capture a debug log of one payment to confirm cascade depth.

#### DCCA-042 — Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus static/inline styles, 7 bypass mechanisms, 37 triggers with no bypass, fat triggers with broken guards
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** XL · **Tier:** P2
- **Domain:** Platform/Shared, Payments/Transactions · **Category:** Automation
- **Source findings:** A-03 (High), A-04 (High), A-06 (High), W-08 (High), W-15 (Medium)
- **Verified:** Verified (sample) — EarnedCETrigger.trigger:9 declares `isUpdateLicenseOnce` as a local variable checked at :55, so the guard has no effect.
- **Evidence:** Multiple triggers on `pymt__PaymentX__c` (3), Account, Case, `Transaction__c`, `TransactionLine__c`, `Application_Cache__c`. Frameworks: `TriggerFactory`/`ITrigger` (22-23 handlers, per-record dispatch, no recursion guard, closed if/else registry), `BREGBaseTriggerHandler` (10), `fflib_SObjectDomain` (1), plus static-method and inline styles (report 01 counts these as five frameworks, report 04 as three). Bypasses via OrgConfiguration__c, BREG_Setting__c, ProcessSwitches__c, tkt/util_closer settings, static flags and integration-profile checks. `EarnedCETrigger` issues two separate License updates; `DraftApplicationTrigger` self-updates in after-save.
- **Impact:** No single switch disables automation for data loads; each framework has different recursion, bulk and ordering semantics, multiplying defects such as DCCA-026 and DCCA-041.
- **Fix:** One trigger per object with a dispatcher routing to BREG/PVL handlers; one framework (fixed `BREGBaseTriggerHandler` or a metadata-driven one) with record-Id recursion guard and one Custom-Permission/hierarchy-setting bypass; move inline trigger logic to handlers; migrate shared money objects first; delete the no-op `StatusHistoryTrigger`.
- **Scoring note:** XL effort; kept at P2 because it is the foundation for DCCA-026/041/043 fixes.

#### DCCA-043 — Over-automated core objects with undefined order: Application (1 trigger, 15 after-save flows, 4 PBs), Case (2 triggers, 24 flows), License, Payment; 28 after-save flows update their own record
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** XL · **Tier:** P2
- **Domain:** PVL/Licensing, Cases/Complaints · **Category:** Automation
- **Source findings:** W-04 (High), W-11 (Medium), W-20 (Low)
- **Verified:** Not spot-checked — Relies on report 04 evidence.
- **Evidence:** None of 67 active record-triggered flows on 13 multi-flow object/event pairs sets `triggerOrder`. License ↔ Application cross-object cycle via PBs. 28 after-save flows update `$Record`; `Exams_Required_Validation` and `DO_Referral_Case_Close_Case_Status` do so on every edit. Approval field updates with `reevaluateOnChange=true` re-run triggers and PBs on Exam/Investigation.
- **Impact:** Outcomes can differ between releases; each self-update re-runs the full save order including a 203-element PB; likely source of CPU timeouts during renewal batches and data loads; duplicate emails/status-history rows.
- **Fix:** Per object: at most one before-save flow plus a few ordered after-save flows (or Apex); move same-record updates to before-save; entry criteria 'only when updated to meet criteria'; replace flow-based validation with before-save errors; review approval re-evaluation during PB migration.

#### DCCA-044 — Batch jobs, @future and Queueables started per record from triggers; @future called from trigger context without isBatch()/isFuture() guards
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** M · **Tier:** P2
- **Domain:** PVL/Licensing, BREG · **Category:** Automation
- **Source findings:** W-06 (High), W-12 (Medium)
- **Verified:** Not spot-checked — Relies on report 04 evidence.
- **Evidence:** `Database.executeBatch` per License/LicenseType/Notification from per-record handler methods (12 sites in `LicenseTypeHandler`); per-record `@future(callout=true)` in `CertificateRequestService`; per-iteration insert plus `System.enqueueJob` in BREG Document/TransactionLine handlers; `@future` from `ApplicationService`, `licenseService`, CATV handlers and a BREG 'urgent hotfix 13 April 2026' without guards.
- **Impact:** 51+ certificate requests, 50+ BREG documents or 100+ flagged licences in one transaction throw LimitException; any batch touching these records fails with 'Future method cannot be called from a future or batch method'.
- **Fix:** Collect Ids per transaction and launch one job in `andFinally`/`bulkAfter`; bulk log inserts (`createWorkflowLogsSafely` exists); replace `@future` with a single guarded Queueable; permanent fix for the BREG hotfix.

#### DCCA-045 — DML, SOQL, subflows and email actions inside flow loops (21 loops in 14 active flows); scheduled bounceback flow fails at ~75 bounced emails a day
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** M · **Tier:** P2
- **Domain:** PVL/Licensing, BREG · **Category:** Automation
- **Source findings:** W-07 (High), W-22 (Low)
- **Verified:** Not spot-checked — Relies on report 04 evidence.
- **Evidence:** `Express_Change_Broker_Email_Bouncebacks` runs one interview over 24h of EmailMessage with 1 SOQL + 2 DML per iteration; renewal flows run 3 Gets, 5 Updates and 2 subflows per associated CPA licence; cashier batch upload does Get/Create per iteration; email actions in loops in 6 flows. Scheduled flows filter broadly and rely on in-flow date checks.
- **Impact:** Renewals for firms with many associated licences hit 100-SOQL/150-DML limits, especially when started from PVLProcessTrigger; duplicate emails on retry.
- **Fix:** Assign in loop, single DML after; one Get before loop with IN filter; collection-based `Create_License_History`; send email once to a collection; move date conditions into scheduled-flow start filters.

#### DCCA-046 — Silent failures: 577 of 609 flow DML/action elements lack fault paths (including Oracle GL and DocuSign screen flows); 39 batches with empty finish(), no BatchApexErrorEvent handling, 49 schedulers untraceable in source
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** M · **Tier:** P2
- **Domain:** Platform/Shared, Payments/Transactions · **Category:** Automation
- **Source findings:** W-10 (Medium), W-14 (Medium)
- **Verified:** Not spot-checked — Relies on report 04 evidence.
- **Evidence:** 151 active flows have no fault handling at all; 11 screen flows call Apex without fault paths; only 2 batch classes implement `Database.RaisesPlatformEvents`; 25 classes chain jobs from `finish()`; 49 Schedulable classes have no scheduling code in source.
- **Impact:** Integration failures to Oracle GL and DocuSign are not durably logged; licence expiry/forfeiture jobs can partially fail unnoticed; schedule inventory cannot be rebuilt after refresh.
- **Fix:** Shared error-logging subflow on every DML/Apex/callout element (payments/integrations first); `RaisesPlatformEvents` + one `BatchApexErrorEvent` subscriber writing to the common log; check `AsyncApexJob.NumberOfErrors` in finish; schedules in CMT with a post-deploy script.

#### DCCA-047 — Payment batches self-schedule every 5 minutes (24 cron slots, 576 starts/day) with no overlap protection
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** M · **Tier:** P2
- **Domain:** Payments/Transactions · **Category:** Automation
- **Source findings:** W-13 (Medium)
- **Verified:** Not spot-checked — Relies on report 04 evidence; actual CronTrigger list not visible in source.
- **Evidence:** `PaymentXBatch.schedule5min()` and `PaymentAllocateTransactionLinesBatch` create 12 jobs each with hard-coded crons and start a new batch on every fire without checking for a running instance; `PaymentXBatch.finish()` chains `DCCAFeeScheduleBatch` at scope 2000.
- **Impact:** Overlapping runs can double-allocate payments and cause row-lock errors against user payment saves (DCCA-041); consumes 24 of 100 scheduled-Apex slots.
- **Fix:** Single scheduler that checks `AsyncApexJob` before starting, or self-rescheduling via `System.scheduleBatch` from finish; crons in CMT; consider event-driven processing.

#### DCCA-048 — Flow version state disagrees with flowDefinitions (a Draft subflow called by an active PB); active 'Testing: Email Functions' flow emails staff; 33 Draft/Obsolete flows in source
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** S · **Tier:** P2
- **Domain:** Cases/Complaints, PVL/Licensing · **Category:** Automation
- **Source findings:** W-16 (Medium)
- **Verified:** Not spot-checked — Relies on report 04 evidence; org active versions not visible.
- **Evidence:** Four flows are Draft/Obsolete in the flow file while the flowDefinition sets an active version; `SEBCaseContact_UpdateName` (Draft) is called by active PB `SEBCaseContact_ImmediateActions`; `Testing_Email_Functions` is an active after-save Case flow sending real emails in loops.
- **Impact:** A deploy can activate or deactivate the wrong version; the PB subflow call may fail; staff receive test emails.
- **Fix:** Reconcile with org active versions; delete obsolete flows via destructiveChanges; deactivate the test flow; CI check for status/definition mismatch.

#### DCCA-049 — Authenticated Apex REST resources lack server-side authorisation: forged 'public' BREG documents, any-document download, IVR status check brute-forceable by SSN last-4
- **Severity:** Medium · **Exposure:** Authenticated external · **Priority score:** 4 · **Effort:** M · **Tier:** P2
- **Domain:** BREG, PVL/Licensing · **Category:** Security
- **Source findings:** S-20 (Medium)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `BREGExternalAPIUploadDocument` honours `IsPublic` from the body without checking `BREG_Publish_Documents`; `BREGExternalAPIGetDocument` returns any document via integration credentials without `breg_Is_Public__c`/UserRecordAccess check; `PVLApplicationStatusCheckResource` authenticates the subject by phone + SSN last-4 with no attempt limiting; most endpoints echo `ex.getMessage()`; unsanitised `queueName` in DocuSign folder paths.
- **Impact:** A low-privilege BREG staff/integration account can publish forged certificates or pull any document; IVR callers can confirm SSN digits by brute force.
- **Fix:** `FeatureManagement.checkPermission` before honouring IsPublic; record-access checks before returning documents; Platform Cache throttling and lockout for status checks; sanitise path segments; fixed error bodies.

#### DCCA-050 — Three separate DocuSign CLM/SpringCM client stacks (one at API v31), with a hard-coded UAT endpoint called from a production batch
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** L · **Tier:** P2
- **Domain:** Integrations CLM/DocuSign · **Category:** Architecture
- **Source findings:** A-09 (High)
- **Verified:** Verified (sample) — SpringCMConnector.cls:399 hard-codes `https://apiuatna11.springcm.com/v2/folders?search=`.
- **Evidence:** Legacy SpringCM SDK (v31-33), `SpringCMConnector` (own OAuth and session cache, fan-in 30) and `DocuSignAPI` (Named Credentials, depends on `BREGUtils`). `PVL_ListBuilderFileDeletionBatchJob.cls:72` calls the UAT search path; `https://test.salesfor.com` and UAT workflow URLs in `DocuSignAPI.cls:587` and `BREGUtils.cls:1252`.
- **Impact:** Three auth/error/retry semantics and three places to rotate credentials; a production batch touching the UAT tenant fails or leaks data (whether it is scheduled is unverified).
- **Fix:** Standardise on `DocuSignAPI` with Named Credentials; migrate `SpringCMConnector` consumers; retire the v31 SDK and SpringCM_EOS pages; remove hard-coded UAT/dummy endpoints immediately.

#### DCCA-051 — God classes and oversized `without sharing` portal controllers; Domain/Service/Selector layering exists only in PVL
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** XL · **Tier:** P2
- **Domain:** BREG, Payments/Transactions, Platform/Shared · **Category:** Architecture
- **Source findings:** A-07 (High), A-08 (High)
- **Verified:** Not spot-checked — Relies on report 01 evidence.
- **Evidence:** 11 non-vendor classes over 1,000 lines (largest 2,288); 5 controllers over 1,000 lines with 33-83 `@AuraEnabled` members, 4 of them `without sharing`; `BREGUtils` fan-in 39. BREG has no Domain/Selector classes (445 inline SOQL in 111 classes); 80 of 128 controllers run SOQL/DML directly; only 149 of 1,441 SOQL statements live in Selectors.
- **Impact:** Change hotspots with large regression surface and large `without sharing` attack surface; inconsistent sharing/FLS handling and duplicated queries; hard to test and mock.
- **Fix:** Split by responsibility (selector, domain rules, thin `@AuraEnabled` facade), starting with `BREGPaymentController` (fee logic duplicates `BREGTransactionUtils`) and `BREGBusinessDetailsController`; Selectors for Case, Account, `breg_Transaction__c`; document one layering standard and enforce in CI.

#### DCCA-052 — Dead code and test scaffolding deployed to production (active no-op trigger, commented-out classes, ~28 unreferenced classes, prod mocks, a helper that updates any Account)
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** S · **Tier:** P2
- **Domain:** Platform/Shared · **Category:** Architecture
- **Source findings:** A-15 (Medium), A-18 (Low), F-25 (Low), T-14 (Medium)
- **Verified:** Not spot-checked — Relies on reports 01, 03, 06 evidence; org usage (Apex last-used, Event Monitoring) should be checked before deletion.
- **Evidence:** `StatusHistoryTrigger` is active with its whole body commented out; 13.7% of production lines are comments; `BREGAnnualRobotTestHelper.prepareEntity()` selects any Account and updates it; `ApplicationGenerateLicense` is a production-named class annotated `@isTest` with a commented body; `SpringCMApiManagerMock` and 6 `fflibe_Test*` classes ship as production code; `Mass_Delete_*` pages and front-end test artefacts.
- **Impact:** Deployment and coverage overhead, misleading code, and a production-callable helper that silently modifies real Accounts.
- **Fix:** Delete confirmed dead items after checking org usage; move mocks/helpers to `@isTest`; deactivate and remove `StatusHistoryTrigger`.

#### DCCA-053 — Thin bulk, permission and negative-path testing: ~8 of 61 triggers ever see 200+ records; runAs in 7% of test classes; async not wrapped in start/stopTest
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** M · **Tier:** P2
- **Domain:** Platform/Shared, Payments/Transactions · **Category:** Testing
- **Source findings:** T-07 (High), T-11 (Medium), T-12 (Medium)
- **Verified:** Not spot-checked — Relies on report 06 evidence.
- **Evidence:** No named bulk tests for ApplicationTrigger, LicenseAll, the Payment triggers, BREGCaseTrigger, CollectionsAllocationTrigger or EarnedCETrigger; only 10 of 40 `without sharing` `@AuraEnabled` classes tested under `runAs`; 'negative' tests assert `true` in the catch; 14 test classes run async work without `Test.startTest()`; no test DML for `sc_FieldMetaDataTrigger`/`PVLErrorHandlerTrigger`.
- **Impact:** Governor-limit defects (DCCA-026, 041, 044) surface only in data loads and integrations; sharing/FLS regressions on public portals are not caught.
- **Fix:** 200-record insert/update/delete tests per trigger object (Payment, Transaction, TransactionLine, Application, License, Case first); guest/community `runAs` allow/deny tests for every portal controller; expected-exception assertions; wrap async in start/stopTest and assert after.

#### DCCA-054 — No LWC Jest tests (0 of 232 components); pre-commit hook passes with --passWithNoTests
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** L · **Tier:** P2
- **Domain:** BREG, CATV, Platform/Shared · **Category:** Testing
- **Source findings:** F-12 (Medium), T-08 (High)
- **Verified:** Not spot-checked — Relies on reports 03 and 06 evidence.
- **Evidence:** No `__tests__` directories or `*.test.js`; `package.json` lint-staged runs `sfdx-lwc-jest -- --bail --findRelatedTests --passWithNoTests`.
- **Impact:** Cart/checkout pricing, URL parsing and the dynamic form engine have no regression net, making the Aura migration and de-duplication high-risk.
- **Fix:** Jest for `utils`, cart/checkout, `breg_BaseFormComponent`, `catv_custom_lookup` first with mocked Apex; remove `--passWithNoTests`; coverage thresholds; `@sa11y/jest`.

#### DCCA-055 — Production entry points with no test path (41 classes) or no direct test (210 classes), including flow Invocables, batches and payment controllers
- **Severity:** High · **Exposure:** Internal · **Priority score:** 3 · **Effort:** M · **Tier:** P2
- **Domain:** PVL/Licensing, Payments/Transactions · **Category:** Testing
- **Source findings:** T-06 (High)
- **Verified:** Not spot-checked — Relies on report 06 static reference graph.
- **Evidence:** `PVL_ListBuilderFileGenerationBatchJob` (400 LOC, global batch touching payments), `PaymentDisplayController`, `Franchise_CheckoutController` and 9 flow Invocables have no test path; `LicenseCreateRecordsTest` never calls its class.
- **Impact:** Flows, schedulers and LWC controllers run in production with no regression safety net.
- **Fix:** Tests for each A1 class starting with Invocables used by active flows and the payment controllers; delete unused ones; CI check that new/modified classes have a referencing test.

#### DCCA-056 — CATV uploads advertise 25 MB but send base64 through an Apex parameter (fails above ~3 MB); PDF type check is client-only
- **Severity:** Medium · **Exposure:** Authenticated external · **Priority score:** 4 · **Effort:** S · **Tier:** P2
- **Domain:** CATV · **Category:** Front End
- **Source findings:** F-19 (Medium)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** `MAX_FILE_SIZE_MB = 25` then `FileReader` base64 into `uploadFile({fileContent})`; `CATV_DashboardController.cls:95-106` decodes and pushes to SpringCM.
- **Impact:** Uploads over ~3 MB fail with a generic error; MIME check bypassable by renaming.
- **Fix:** `lightning-file-upload` (ContentVersion) then async push to CLM, or cap the UI at 3 MB; validate `%PDF` magic bytes server-side.

### P3 — Backlog (10 issues: 6 Medium, 4 Low)

| ID | Title | Sev | Exposure | Score | Effort | Sources |
|---|---|---|---|---|---|---|
| DCCA-057 | BREG and PVL share Transaction, TransactionLine, Payment, Account and Case with no ownership boundary; label-b… | Medium | Internal | 2 | L | A-12 |
| DCCA-058 | Duplicated cross-cutting utilities (8 logging stores, 5 lookup controllers, 3 constants classes, 5 email sende… | Medium | Internal | 2 | L | A-11, A-13 |
| DCCA-059 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identical to Admin), dupli… | Medium | Internal | 2 | XL | P-22, P-24, P-28, P-29, P-30 |
| DCCA-060 | Wide API version spread (v31-v66): SpringCM SDK at v31, money-path triggers at v39-43, 55 active flows at API … | Medium | Internal | 2 | L | A-16, F-22, W-18 |
| DCCA-061 | Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10 uploaders, cart log… | Medium | Internal | 2 | L | F-15, F-18, F-23, F-26 |
| DCCA-062 | Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, SeeAllData, fragmented… | Medium | Internal | 2 | L | T-10, T-13, T-16, T-18 |
| DCCA-063 | 10 flows run in SystemModeWithoutSharing (8 screen flows, 2 autolaunched) | Low | Internal | 1 | S | W-19 |
| DCCA-064 | Naming inconsistencies and near-duplicate class names (Transaction_Handler vs TransactionHandler on the same t… | Low | Internal | 1 | S | A-17 |
| DCCA-065 | User-facing strings hard-coded instead of Custom Labels (about 60 of 232 LWCs use labels) | Low | Guest / public | 3 | M | F-24 |
| DCCA-066 | MD5 used for change-detection hashes | Low | Internal | 1 | S | S-28 |

#### DCCA-057 — BREG and PVL share Transaction, TransactionLine, Payment, Account and Case with no ownership boundary; label-based record-type lookups
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** L · **Tier:** P3
- **Domain:** Payments/Transactions, BREG · **Category:** Architecture
- **Source findings:** A-12 (Medium)
- **Verified:** Not spot-checked — Relies on report 01 evidence.
- **Evidence:** `Transaction__c` written by 38 classes across contexts; 9 `breg_*` fields on `Transaction__c` and 16 on `TransactionLine__c`; BREG creates PVL-style transactions directly; PVL uses `getRecordTypeInfosByName('Business Account')`; `DocuSignAPI` depends on `BREGUtils`.
- **Impact:** A payment change for one division can break the other; label-based lookups break on rename/translation; ownership ambiguity drives the trigger sprawl.
- **Fix:** Name one owner for the Payments/Transaction model behind a service interface both divisions call; route shared-object triggers by record type in one dispatcher; DeveloperName lookups everywhere.

#### DCCA-058 — Duplicated cross-cutting utilities (8 logging stores, 5 lookup controllers, 3 constants classes, 5 email senders, 4 batch-config stores) and three domain/unit-of-work layers including 21k LOC of vendored fflib
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** L · **Tier:** P3
- **Domain:** Platform/Shared, Digital Forms sc_ · **Category:** Architecture
- **Source findings:** A-11 (Medium), A-13 (Medium)
- **Verified:** Not spot-checked — Relies on report 01 evidence.
- **Evidence:** `LookUpController` and `sc_LookupController` differ by 3 lines (so the injection in DCCA-002 is duplicated); logging split across `CustomLog__c`, `Application_Log__c`, `breg_Log__c` and five more; fflib used by ~17 classes with bindings in CMT not in source; duplicate `sc_` domain classes; `BarberingCosmetologyRenewal` is the shared renewal utility for nine boards.
- **Impact:** Fixes do not reach copies; no single operational log view; ~21k lines of vendor code to patch and cover; hidden wiring.
- **Fix:** One platform-services layer (Logger, secure Lookup, Constants, Email, Batch registry); decide on one domain layer; remove duplicate `sc_` domains; rename the shared renewal utility.

#### DCCA-059 — Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identical to Admin), duplicate/empty permission sets, person-specific sharing rules, little Custom Permission use in Apex
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** XL · **Tier:** P3
- **Domain:** Platform/Shared · **Category:** Access Control
- **Source findings:** P-22 (Medium), P-24 (Medium), P-28 (Medium), P-29 (Low), P-30 (Low)
- **Verified:** Not spot-checked — Relies on report 05 evidence.
- **Evidence:** Only 4 custom permission set groups and no muting sets; `DCCA PVL Admin` = `DCCA PVL Limited Admin` (Jaccard 1.0); 10 `Complaints_*` sets reduce to 2 grant sets; 4 empty sets; sharing rules keyed to named users' Ids; 412 of 435 sharing-rule files are empty stubs; only 2 Apex `FeatureManagement.checkPermission` calls.
- **Impact:** Access cannot be granted temporarily or audited per capability; clones propagate dangerous permissions; access tied to individuals drifts.
- **Fix:** Target model: minimum profile per licence plus persona permission set groups and muting sets; merge clones; collapse `Complaints_*`; replace person-specific rules with role/group criteria; gate privileged Apex with Custom Permissions.

#### DCCA-060 — Wide API version spread (v31-v66): SpringCM SDK at v31, money-path triggers at v39-43, 55 active flows at API <= 50, 91 Aura bundles at v46 or lower
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** L · **Tier:** P3
- **Domain:** Platform/Shared · **Category:** Architecture
- **Source findings:** A-16 (Medium), F-22 (Low), W-18 (Low)
- **Verified:** Not spot-checked — Relies on reports 01, 03, 04 evidence.
- **Evidence:** 26 classes below v40; triggers v39-v65; VF pages down to v34; 23 LWCs below v58; `sourceApiVersion` 67.0.
- **Impact:** Legacy runtime behaviour differs between classes; upgrade testing accumulates; old versions will eventually be retired.
- **Fix:** Raise components below v50 to at least v60 as they are touched in the refactors above, with regression testing.

#### DCCA-061 — Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10 uploaders, cart logic in 14 LWCs, Apex calls in loops, legacy idioms, style injection into base components
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** L · **Tier:** P3
- **Domain:** BREG, CATV · **Category:** Front End
- **Source findings:** F-15 (Medium), F-18 (Medium), F-23 (Low), F-26 (Low)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** 4,276 of 32,776 significant lines duplicated; `catv_provider_tabs`/`catv_requestor_tabs` and `CreateTransaction`/`breg_CreateTransaction` are near-copies; a copy-pasted `JSON.parse(storedCart) !== "[]"` bug; per-record un-awaited Apex calls with a race in `generatePicklistOptions`; 300 `@track`, 425 `if:true`; `document.createElement('style')` into `lightning-tabset`. Positive: `breg_BaseFormComponent` is a genuine base class used by 64 components.
- **Impact:** Security and bug fixes must be applied in many places; extra Apex and callout load.
- **Fix:** `c/bregCart` service; merge CATV tabs and the transaction components during migration; standardise on `lightning-record-picker`, `LightningModal`, `ShowToastEvent`, `lightning-file-upload`; debounce lookups; styling hooks; codemods for legacy idioms. Expected removal 3,000-4,000 LOC.

#### DCCA-062 — Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, SeeAllData, fragmented factories, deprecated testMethod, commented asserts
- **Severity:** Medium · **Exposure:** Internal · **Priority score:** 2 · **Effort:** L · **Tier:** P3
- **Domain:** Platform/Shared · **Category:** Testing
- **Source findings:** T-10 (Medium), T-13 (Medium), T-16 (Low), T-18 (Low)
- **Verified:** Not spot-checked — Relies on report 06 evidence.
- **Evidence:** Tests query named users/sites and profiles by name; two tests skip themselves when org metadata is missing; 978 `LIMIT 1` queries without ORDER BY; 10 factories used by only 34% of test classes; `createCompletedPayment` copy-pasted into 9 tests; 5 `SeeAllData=true` classes; `testMethod` in 96 classes; 26 classes with commented-out asserts.
- **Impact:** Tests pass in one org and fail in another, making deployments to new sandboxes/scratch orgs nondeterministic; schema changes break hundreds of tests.
- **Fix:** One factory per domain behind a shared builder API; users created in `@TestSetup`; stable profile helper; replace self-skips with data or `Assert.fail`; remove SeeAllData; bulk-replace `testMethod` and raise API versions.

#### DCCA-063 — 10 flows run in SystemModeWithoutSharing (8 screen flows, 2 autolaunched)
- **Severity:** Low · **Exposure:** Internal · **Priority score:** 1 · **Effort:** S · **Tier:** P3
- **Domain:** Cases/Complaints, BREG · **Category:** Automation
- **Source findings:** W-19 (Low)
- **Verified:** Not spot-checked — Relies on report 04 evidence; site placement unverified.
- **Evidence:** Includes `License_Certificate_Request` (creates Transaction and TransactionLine) and `ApplicationRenewalDependencyCheck`.
- **Impact:** Low if internal only; a sharing bypass if any are embedded in a portal.
- **Fix:** Confirm placement; default to user context and elevate specific elements via checked invocable Apex.

#### DCCA-064 — Naming inconsistencies and near-duplicate class names (Transaction_Handler vs TransactionHandler on the same trigger)
- **Severity:** Low · **Exposure:** Internal · **Priority score:** 1 · **Effort:** S · **Tier:** P3
- **Domain:** Platform/Shared · **Category:** Architecture
- **Source findings:** A-17 (Low)
- **Verified:** Not spot-checked — Relies on report 01 evidence.
- **Evidence:** Two Transaction handlers called from the same trigger; `PVL_`/`PVL` prefixes; typos (`RbEntityRbBrokerRnewalDependency`, `calcualteOutStanding`).
- **Impact:** Developers edit the wrong one of two similar classes.
- **Fix:** Publish a naming convention; rename during refactors.

#### DCCA-065 — User-facing strings hard-coded instead of Custom Labels (about 60 of 232 LWCs use labels)
- **Severity:** Low · **Exposure:** Guest / public · **Priority score:** 3 · **Effort:** M · **Tier:** P3
- **Domain:** BREG · **Category:** Front End
- **Source findings:** F-24 (Low)
- **Verified:** Not spot-checked — Relies on report 03 evidence.
- **Evidence:** Hard-coded error and UI strings; all Aura toasts.
- **Impact:** Translation for state language-access requirements and wording changes need code deploys.
- **Fix:** Extend the existing `labels.js` pattern.

#### DCCA-066 — MD5 used for change-detection hashes
- **Severity:** Low · **Exposure:** Internal · **Priority score:** 1 · **Effort:** S · **Tier:** P3
- **Domain:** BREG, Integrations CLM/DocuSign · **Category:** Security
- **Source findings:** S-28 (Low)
- **Verified:** Not spot-checked — Relies on report 02 evidence.
- **Evidence:** `BREGUtils.cls:1483` and `DocuSignAPI.cls:444` use `Crypto.generateDigest('MD5', ...)`.
- **Impact:** Low: change detection only; must not be used for document authenticity.
- **Fix:** Use SHA-256.

## Cross-Cutting Themes

### 1. Payments are the single biggest hotspot

26 of 66 consolidated issues touch Payments/Transactions, including 10 Critical. The same money path fails in every dimension at once:
- **Security:** browser-trusted prices (DCCA-003), guest REST endpoints that forge payments (DCCA-004), guest generic DML (DCCA-008), receipt/billing-PII IDOR (DCCA-012), SOQL injection in payment search (DCCA-011).
- **Access control:** guest sharing rule over all Transactions (DCCA-005), community Modify All on Transactions (DCCA-006), `Read_Only_DCCA_Payments` granting Modify All/Delete on payments (DCCA-040), guest cashier pages that start deposit/reconciliation batches (DCCA-016).
- **Automation:** three unordered Payment triggers, a Transaction ↔ TransactionLine ↔ Payment save cascade with no recursion guard and a recursive PB (DCCA-041), 5-minute payment batches with no overlap guard (DCCA-047), Transaction/Payment PBs past end of support (DCCA-028).
- **Testing:** ~20 finance classes (~3,000 LOC) covered only by zero-assert tests (DCCA-030); the reconciliation filter is removed under test (DCCA-029).
- **Ownership:** BREG and PVL both write the shared transaction objects with no owning team or service boundary (DCCA-057).
**Implication:** do not refactor payment code until DCCA-030 asserting tests exist; fix in the order contain (P0-4/5) → test harness → trigger consolidation → PB migration.

### 2. The guest attack surface is systemic, not a few bugs

Nine guest profiles for about five sites; 73 guest-reachable Apex entry-point classes, 36 of them `without sharing`, only 4 with any CRUD/FLS check; 20 guest sharing rules with 'all records' criteria; guest profiles cloned from internal cashier profiles (62 test classes, back-office pages). Eleven of the thirteen P0 issues are guest-exposed. Containment (P0) removes the worst doors; the durable fix is DCCA-016 (rebuild guest profiles from zero) plus DCCA-038 (user mode by default) so that a future controller mistake cannot become a cross-tenant breach.

### 3. Trigger and automation fragmentation

Three trigger frameworks plus static and inline styles, seven bypass mechanisms (37 triggers with none), six objects with multiple triggers, 67 record-triggered flows with no defined order, 28 after-save self-updates and 48 retired Process Builders. Each framework has different recursion semantics, which is why the BREG guard skips work (DCCA-026) while PVL handlers have no guard at all (DCCA-041). Consolidation (DCCA-042) and PB migration (DCCA-028/043) should be planned as one programme, object by object, starting with Payment, Transaction and TransactionLine.

### 4. Test integrity

Test volume looks healthy (1.02:1 test:prod LOC) but quality does not: 13.5% of methods and 36% of classes assert nothing, ~170 `Test.isRunningTest()` branches change production behaviour, 0 LWC Jest tests, ~8 of 61 triggers ever see 200 records, and there is no coverage baseline or CI. Coverage therefore overstates safety, and cleaning up padding tests could drop coverage below 75% without warning. The P0 baseline run and a CI gate (DCCA-033/031) come before any large refactor.

## Remediation Roadmap

Aligned to the Salesforce Well-Architected pillars: **Trusted** (Secure, Compliant, Reliable), **Easy** (Intentional, Automated, Engaging), **Adaptable** (Resilient, Composable).

| Phase | Window | Well-Architected focus | Key outcomes | Issues |
|---|---|---|---|---|
| **Contain** | 0-2 weeks | Trusted: Secure, Compliant | • All P0 actions (live-exposure inventory, guest class removal, credential rotation, guest sharing-rule removal, payment hotfix, IDOR/takeover guards, egress closure, compromise assessment, test baseline). | DCCA-001..013, DCCA-025 (emails), DCCA-032/033 (baseline) |
| **Stabilize** | 1-3 months | Trusted: Secure, Reliable, Compliant; Easy: Automated | • Secrets to Named/External Credentials; delete secret fields and token object (DCCA-014).<br>• Rebuild the 9 guest profiles from a clean baseline; integration users on the Salesforce Integration licence; remove PasswordNeverExpires; login IP ranges (DCCA-015/016).<br>• Fix BREG record-level recursion guard; rewrite PVLProcessTrigger as a bulk, retryable dispatcher (DCCA-026/027).<br>• CI pipeline: test runs with coverage baseline, Code Analyzer/PMD (CRUD, sharing, SOQL injection, asserts, debug statements, Test.isRunningTest), secret scanning, deploy validate (DCCA-031/033/036).<br>• Fix date-bomb tests before 2026-12-01; asserting tests for every payment entry point; start removing Test.isRunningTest from ReconciliationBatchJob and payment classes (DCCA-029/030/032).<br>• Begin Process Builder migration with the Transaction and Payment PBs (DCCA-028).<br>• Front-end: error handling on payment/filing flows, listener leaks, XSS fixes, vulnerable jQuery/Bootstrap lookups, accessibility on public BREG pages (DCCA-022/023/034/035/037). | DCCA-014..037 |
| **Modernize** | 3-9 months | Adaptable: Resilient, Composable; Easy: Intentional, Engaging, Automated; Trusted: Secure | • Sharing/FLS programme: `with sharing`/`inherited sharing` by default, `WITH USER_MODE` / `AccessLevel.USER_MODE`, retire generic system-mode helpers (DCCA-038).<br>• Trigger framework consolidation: one trigger per object, one framework, record-Id recursion guard, one bypass; money-path objects first (DCCA-041/042).<br>• Complete Process Builder to Flow/Apex migration (48 PBs, 1,039 elements) with fault paths and explicit trigger order; bulkify flow loops and async launches (DCCA-028/043/044/045/046).<br>• Aura to LWC migration (147 bundles: 16 events/apps, 54 easy, 40 moderate, 37 complex; 3 theme layouts and 2 action overrides stay Aura until LWR). Security-driven first: InputLookup, Lookup/sc_Lookup, CustomRecordCreateField, CustomPaymentButton, community payment components.<br>• Test remediation: remove remaining Test.isRunningTest branches, bulk (201-record) and runAs tests, LWC Jest suite (DCCA-053/054/055).<br>• Composable services: one CLM client on Named Credentials; payment/transaction service owned by one team; split BREG god classes behind selectors (DCCA-050/051/057).<br>• Least-privilege data model: Private OWD for sensitive objects, rebuilt read-only permission sets, minimum profiles plus permission set groups (DCCA-040/059). | DCCA-038..066 |

**Well-Architected mapping of the main workstreams**

| Workstream | Pillar / sub-pillar | Phase | Issues |
|---|---|---|---|
| Guest surface containment and rebuild | Trusted › Secure | Contain → Stabilize | DCCA-001-012, 016 |
| Secrets → Named/External Credentials; credential rotation | Trusted › Secure | Contain → Stabilize | DCCA-001, 002, 010, 014, 020 |
| Sharing/FLS enforcement (`with sharing`, `WITH USER_MODE`, `AccessLevel.USER_MODE`) | Trusted › Secure | Stabilize → Modernize | DCCA-017, 038, 040 |
| Privacy and accessibility (PII egress, logs, WCAG 2.1 AA) | Trusted › Compliant; Easy › Engaging | Contain → Stabilize | DCCA-018, 025, 037 |
| Payment integrity and money-path reliability | Trusted › Reliable | Contain → Modernize | DCCA-003, 030, 041, 047 |
| Trigger framework consolidation (one trigger per object, one bypass, record-level guards) | Adaptable › Resilient | Stabilize → Modernize | DCCA-026, 042 |
| Process Builder → Flow/Apex migration with fault paths and trigger order | Adaptable › Resilient; Easy › Automated | Stabilize → Modernize | DCCA-028, 043, 045, 046 |
| Bulk-safe async (platform events, @future, per-record jobs) | Trusted › Reliable | Stabilize → Modernize | DCCA-027, 044 |
| Test remediation: remove `Test.isRunningTest()`, asserting payment tests, bulk/runAs tests, Jest, CI gates | Easy › Automated | Contain → Modernize | DCCA-029-033, 053-055, 062 |
| Aura → LWC (147 bundles; security-driven first) | Easy › Intentional | Modernize | DCCA-023, 060, 061 |
| Composable services (one CLM client, payment service owner, BREG selectors, shared platform services) | Adaptable › Composable | Modernize | DCCA-050, 051, 057, 058 |

## Health Score & Rubric

| Dimension | Weight | Issue load W | Current score | Projected after P0 + P1 |
|---|---|---|---|---|
| Security | 25% | 155 | **21** | 83 |
| Access Control | 20% | 87 | **31** | 77 |
| Automation | 15% | 69 | **37** | 54 |
| Architecture | 10% | 64 | **38** | 58 |
| Front End | 15% | 100 | **29** | 68 |
| Testing | 15% | 56 | **42** | 68 |
| **Overall** | 100% | | **31** (uncapped 31) | **70** |

**Rubric (transparent and reproducible).**
1. Each consolidated issue carries a weight by severity: Critical 10, High 5, Medium 2, Low 1.
2. An issue counts against every dimension whose specialist report contributed at least one source finding (e.g. DCCA-003 counts against Security and Front End).
3. Dimension score = 100 × K / (K + W), where W is the dimension's issue load and K = 40 (four open Critical issues halve a dimension's score; the curve never reaches zero, so progress remains visible).
4. Overall = weighted mean of dimension scores (Security 25, Access Control 20, Automation 15, Front End 15, Testing 15, Architecture 10).
5. Gate: while any P0 issue is open the overall score is capped at 40, because open guest-exposed Critical issues dominate risk regardless of other strengths.
6. Projection removes P0 and P1 issues from the load; it assumes they are closed, not just contained.

Score bands: 0-39 *At risk*, 40-59 *Needs significant remediation*, 60-79 *Fair*, 80-100 *Healthy*.

**Strengths worth keeping** (from the specialist reports): the newer BREG and Qual code has much stronger tests (`BREGCaseStatusHandlerBaseTest` 106 asserts, `PaymentAllHandlerTest` 36); `breg_BaseFormComponent` is a genuine reusable base class; Qualtrics, util_closer and tkt_ contexts are self-contained; several integrations already use Named Credentials (`Amazon_SES`, `IMLCC`, `OracleGL`); five Queueables use Finalizers; custom permissions are not over-granted.

## Limitations & Items Requiring Org Verification

Static analysis cannot see the following; each should be confirmed in the production org (read-only) before or during P0:

| Item | Why static analysis cannot confirm it | Where it matters |
|---|---|---|
| Site and network configuration | No `sites/`, `networks/` or `experiences/` metadata in source. Which sites are active, their public pages and whether Apex REST is enabled for each guest user. | P0-1 |
| Guest-user permission-set assignments | Assignments (e.g. `BREG_Site_Guest_User` to the BREG guest user) are not metadata; reachability of 22 BREG classes depends on it. | P0-1 |
| Standard and managed object permissions | Profiles in source omit standard (Account, Contact, Case) and managed (`pymt__*`) object permissions; guest Read on Case/Account for the complaint sharing rules is unverified. | P0-1, P0-4 |
| Custom metadata and custom setting record values | No `customMetadata/` folder; which secrets are actually populated (and so exposed by DCCA-002) is unknown. Assume populated. | P0-3 |
| Named/External Credentials, Connected Apps, Auth Providers | Not in source; OAuth policies, principals and IP relaxation unreviewable. | DCCA-014 |
| Session, password and MFA policy | `Security.settings`/`Session.settings` not in source. | DCCA-015 |
| User counts per profile/permission set | Blast radius of admin-equivalent and View All grants depends on assignments. | DCCA-015, 040 |
| Active flow versions | Flow file status vs flowDefinition disagrees for 4 flows; the org's active versions decide what runs. | DCCA-048 |
| Scheduled jobs (CronTrigger) and platform-event subscriber config | 49 Schedulable classes have no scheduling code; payment batch overlap and the UAT-calling batch depend on what is scheduled. | DCCA-047, 050 |
| Real test coverage and current failures | No cached results and no CI; coverage and date-bomb failures are inferred. | P0-9 |
| Evidence of exploitation | Event Monitoring, audit trail and provider logs are needed to know whether any exposure has been used. | P0-8 |
| Tooling not run | No ESLint, PMD/Code Analyzer, Jest or Apex test execution was performed; counts come from scripted static scans and differ slightly between reports (e.g. `without sharing` 128 vs 135, undeclared 286 vs 292, `Test.isRunningTest` 166 vs 173, trigger frameworks 5 vs 3). | DCCA-033 |
| Legal applicability | ADA Title II / WCAG dates and breach-notification obligations should be confirmed by agency counsel. | DCCA-037, P0-8 |

**Corrections and overstatements found during synthesis**

- **F-04 (→ DCCA-011) overstated:** `CATV_CustomLookUpController` selects a fixed `Id, Type, Name` list and the class is `with sharing`; the caller cannot return 'any Account field' (un-queried fields throw). The injectable WHERE clause still runs in `SYSTEM_MODE` via `CATV_WithoutSharingUtility.queryRecords`, so enumeration and boolean-oracle reads remain Critical.
- **T-04 (→ DCCA-032) partly weakened:** `InsuranceBondDomainTest` passes explicit coverage dates to the domain method and is probably not date-sensitive; the confirmed time bomb is `BREGAnnualRollOverJobTest`, and the `ApplicationTriggerTest`/`ApplicationHcRenewalValidationTest` bond dates are a Likely risk to confirm in the P0 test run.
- **T-03 (→ DCCA-031) severity lowered** from Critical to High: coverage padding hides risk but does not itself change production behaviour.
- **S-23/P-19 and W-17 severity raised** to High (DCCA-013, DCCA-025): the request-bin Remote Site is an exfiltration channel for the token exposure, and vendor/personal Gmail CCs are ongoing PII egress.
- **PVLProcessTrigger thresholds differ** (A-05 ~16 events, W-01 ~50 events before limits); both are estimates that depend on the called flows. The conclusion (not bulk-safe, no retry) is verified.
- **Counting differences** between reports (trigger frameworks, sharing declarations, `Test.isRunningTest` sites) come from classification rules, not contradictions.

## Appendix: Finding Cross-Reference (original ID → consolidated ID)

| Original ID | Report | Original severity | Consolidated ID | Consolidated severity | Tier | Consolidated title |
|---|---|---|---|---|---|---|
| A-01 | 01-architecture | Critical | DCCA-001 | Critical | P0 | DocuSign CLM (SpringCM) org-wide OAuth bearer token returned to guest and community browse… |
| A-02 | 01-architecture | Critical | DCCA-026 | Critical | P1 | BREG trigger framework 'once per transaction' guards silently skip handler logic for later… |
| A-03 | 01-architecture | High | DCCA-042 | High | P2 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus st… |
| A-04 | 01-architecture | High | DCCA-042 | High | P2 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus st… |
| A-05 | 01-architecture | High | DCCA-027 | Critical | P1 | PVLProcess__e platform-event subscriber runs SOQL, DML, flows, enqueueJob, executeBatch an… |
| A-06 | 01-architecture | High | DCCA-042 | High | P2 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus st… |
| A-07 | 01-architecture | High | DCCA-051 | High | P2 | God classes and oversized `without sharing` portal controllers; Domain/Service/Selector la… |
| A-08 | 01-architecture | High | DCCA-051 | High | P2 | God classes and oversized `without sharing` portal controllers; Domain/Service/Selector la… |
| A-09 | 01-architecture | High | DCCA-050 | High | P2 | Three separate DocuSign CLM/SpringCM client stacks (one at API v31), with a hard-coded UAT… |
| A-10 | 01-architecture | High | DCCA-038 | High | P2 | Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; gener… |
| A-11 | 01-architecture | Medium | DCCA-058 | Medium | P3 | Duplicated cross-cutting utilities (8 logging stores, 5 lookup controllers, 3 constants cl… |
| A-12 | 01-architecture | Medium | DCCA-057 | Medium | P3 | BREG and PVL share Transaction, TransactionLine, Payment, Account and Case with no ownersh… |
| A-13 | 01-architecture | Medium | DCCA-058 | Medium | P3 | Duplicated cross-cutting utilities (8 logging stores, 5 lookup controllers, 3 constants cl… |
| A-14 | 01-architecture | Medium | DCCA-014 | High | P1 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object a… |
| A-15 | 01-architecture | Medium | DCCA-052 | Medium | P2 | Dead code and test scaffolding deployed to production (active no-op trigger, commented-out… |
| A-16 | 01-architecture | Medium | DCCA-060 | Medium | P3 | Wide API version spread (v31-v66): SpringCM SDK at v31, money-path triggers at v39-43, 55 … |
| A-17 | 01-architecture | Low | DCCA-064 | Low | P3 | Naming inconsistencies and near-duplicate class names (Transaction_Handler vs TransactionH… |
| A-18 | 01-architecture | Low | DCCA-052 | Medium | P2 | Dead code and test scaffolding deployed to production (active no-op trigger, commented-out… |
| S-01 | 02-apex-security | Critical | DCCA-002 | Critical | P0 | Guest-callable arbitrary-object SOQL (sc_LookupController) can read integration secrets st… |
| S-02 | 02-apex-security | Critical | DCCA-001 | Critical | P0 | DocuSign CLM (SpringCM) org-wide OAuth bearer token returned to guest and community browse… |
| S-03 | 02-apex-security | Critical | DCCA-003 | Critical | P0 | BREG checkout and Securities group payment trust browser-supplied prices and totals; a $0 … |
| S-04 | 02-apex-security | Critical | DCCA-004 | Critical | P0 | Guest-reachable Apex REST endpoints /CreatePayment and /CreateTransaction insert payments … |
| S-05 | 02-apex-security | Critical | DCCA-007 | Critical | P0 | Anonymous IDOR and mass assignment in BREG portal controllers: delete any Case, overwrite … |
| S-06 | 02-apex-security | Critical | DCCA-009 | Critical | P0 | Anonymous self-registration provisions portal users on a client-chosen existing Account an… |
| S-07 | 02-apex-security | Critical | DCCA-011 | Critical | P0 | SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_M… |
| S-08 | 02-apex-security | Critical | DCCA-008 | Critical | P0 | Guest-callable generic DML in the payment portal: create or update any record of any objec… |
| S-09 | 02-apex-security | Critical | DCCA-012 | Critical | P0 | Anonymous disclosure of payment receipts, billing PII, card last-4, draft licence applicat… |
| S-10 | 02-apex-security | Critical | DCCA-010 | Critical | P0 | Symmetric encryption keys committed to source and used as authorisation tokens; guest-call… |
| S-11 | 02-apex-security | High | DCCA-017 | High | P1 | Authenticated generic 'query anything / write anything' Aura endpoints and portal IDOR/mas… |
| S-12 | 02-apex-security | High | DCCA-017 | High | P1 | Authenticated generic 'query anything / write anything' Aura endpoints and portal IDOR/mas… |
| S-13 | 02-apex-security | High | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| S-14 | 02-apex-security | High | DCCA-038 | High | P2 | Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; gener… |
| S-15 | 02-apex-security | High | DCCA-014 | High | P1 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object a… |
| S-16 | 02-apex-security | High | DCCA-018 | High | P1 | Tokens, session IDs, secret-bearing records and PII written to Apex debug logs and the bro… |
| S-17 | 02-apex-security | High | DCCA-019 | High | P1 | Public search and registration flows allow bulk harvesting and enumeration (unbounded limi… |
| S-18 | 02-apex-security | High | DCCA-020 | High | P1 | CLM/DocuSign OAuth callback has no `state` (login CSRF binds the org integration to an att… |
| S-19 | 02-apex-security | Medium | DCCA-021 | Medium | P1 | Exception messages and stack traces returned to guest and portal clients |
| S-20 | 02-apex-security | Medium | DCCA-049 | Medium | P2 | Authenticated Apex REST resources lack server-side authorisation: forged 'public' BREG doc… |
| S-21 | 02-apex-security | Medium | DCCA-022 | High | P1 | HTML/script injection: guest-influenced data unescaped into official PDFs, stored XSS via … |
| S-22 | 02-apex-security | Medium | DCCA-020 | High | P1 | CLM/DocuSign OAuth callback has no `state` (login CSRF binds the org integration to an att… |
| S-23 | 02-apex-security | Medium | DCCA-013 | High | P0 | Outbound perimeter: active Remote Site Settings to a pipedream.net request bin, a raw-IP H… |
| S-24 | 02-apex-security | Medium | DCCA-024 | High | P1 | Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisatio… |
| S-25 | 02-apex-security | Medium | DCCA-014 | High | P1 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object a… |
| S-26 | 02-apex-security | Medium | DCCA-009 | Critical | P0 | Anonymous self-registration provisions portal users on a client-chosen existing Account an… |
| S-27 | 02-apex-security | Low | DCCA-011 | Critical | P0 | SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_M… |
| S-28 | 02-apex-security | Low | DCCA-066 | Low | P3 | MD5 used for change-detection hashes |
| S-29 | 02-apex-security | Low | DCCA-038 | High | P2 | Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; gener… |
| S-30 | 02-apex-security | Low | DCCA-011 | Critical | P0 | SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_M… |
| F-01 | 03-lwc-aura | Critical | DCCA-003 | Critical | P0 | BREG checkout and Securities group payment trust browser-supplied prices and totals; a $0 … |
| F-02 | 03-lwc-aura | Critical | DCCA-001 | Critical | P0 | DocuSign CLM (SpringCM) org-wide OAuth bearer token returned to guest and community browse… |
| F-03 | 03-lwc-aura | Critical | DCCA-007 | Critical | P0 | Anonymous IDOR and mass assignment in BREG portal controllers: delete any Case, overwrite … |
| F-04 | 03-lwc-aura | Critical | DCCA-011 | Critical | P0 | SOQL injection reachable by guest users in ~15 classes, including one executed in SYSTEM_M… |
| F-05 | 03-lwc-aura | High | DCCA-023 | High | P1 | Known-vulnerable jQuery 2.2.4, Bootstrap 3.3.6 and abandoned typeahead 0.10.5 loaded under… |
| F-06 | 03-lwc-aura | High | DCCA-022 | High | P1 | HTML/script injection: guest-influenced data unescaped into official PDFs, stored XSS via … |
| F-07 | 03-lwc-aura | High | DCCA-012 | Critical | P0 | Anonymous disclosure of payment receipts, billing PII, card last-4, draft licence applicat… |
| F-08 | 03-lwc-aura | High | DCCA-034 | High | P1 | Fragile error handling on public payment and filing flows: Aura callbacks dereference null… |
| F-09 | 03-lwc-aura | High | DCCA-034 | High | P1 | Fragile error handling on public payment and filing flows: Aura callbacks dereference null… |
| F-10 | 03-lwc-aura | High | DCCA-024 | High | P1 | Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisatio… |
| F-11 | 03-lwc-aura | Medium | DCCA-036 | Medium | P1 | Source references that break full-source deploys (missing Apex method, non-@AuraEnabled im… |
| F-12 | 03-lwc-aura | Medium | DCCA-054 | High | P2 | No LWC Jest tests (0 of 232 components); pre-commit hook passes with --passWithNoTests |
| F-13 | 03-lwc-aura | Medium | DCCA-018 | High | P1 | Tokens, session IDs, secret-bearing records and PII written to Apex debug logs and the bro… |
| F-14 | 03-lwc-aura | Medium | DCCA-035 | Medium | P1 | Event-listener and interval leaks, broken popstate registration and a global Enter-key han… |
| F-15 | 03-lwc-aura | Medium | DCCA-061 | Medium | P3 | Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10… |
| F-16 | 03-lwc-aura | Medium | DCCA-037 | Medium | P1 | Accessibility gaps on the public portal (keyboard-inaccessible logout and payment-speed ch… |
| F-17 | 03-lwc-aura | Medium | DCCA-022 | High | P1 | HTML/script injection: guest-influenced data unescaped into official PDFs, stored XSS via … |
| F-18 | 03-lwc-aura | Medium | DCCA-061 | Medium | P3 | Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10… |
| F-19 | 03-lwc-aura | Medium | DCCA-056 | Medium | P2 | CATV uploads advertise 25 MB but send base64 through an Apex parameter (fails above ~3 MB)… |
| F-20 | 03-lwc-aura | Medium | DCCA-038 | High | P2 | Systemic `without sharing` and near-absent CRUD/FLS enforcement across entry points; gener… |
| F-21 | 03-lwc-aura | Low | DCCA-003 | Critical | P0 | BREG checkout and Securities group payment trust browser-supplied prices and totals; a $0 … |
| F-22 | 03-lwc-aura | Low | DCCA-060 | Medium | P3 | Wide API version spread (v31-v66): SpringCM SDK at v31, money-path triggers at v39-43, 55 … |
| F-23 | 03-lwc-aura | Low | DCCA-061 | Medium | P3 | Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10… |
| F-24 | 03-lwc-aura | Low | DCCA-065 | Low | P3 | User-facing strings hard-coded instead of Custom Labels (about 60 of 232 LWCs use labels) |
| F-25 | 03-lwc-aura | Low | DCCA-052 | Medium | P2 | Dead code and test scaffolding deployed to production (active no-op trigger, commented-out… |
| F-26 | 03-lwc-aura | Low | DCCA-061 | Medium | P3 | Front-end duplication and chatty patterns: 13% duplicated lines, 11 lookups, 10 modals, 10… |
| W-01 | 04-automation | Critical | DCCA-027 | Critical | P1 | PVLProcess__e platform-event subscriber runs SOQL, DML, flows, enqueueJob, executeBatch an… |
| W-02 | 04-automation | Critical | DCCA-026 | Critical | P1 | BREG trigger framework 'once per transaction' guards silently skip handler logic for later… |
| W-03 | 04-automation | High | DCCA-041 | High | P2 | Money-path save cascade: Transaction, TransactionLine and Payment re-save each other throu… |
| W-04 | 04-automation | High | DCCA-043 | High | P2 | Over-automated core objects with undefined order: Application (1 trigger, 15 after-save fl… |
| W-05 | 04-automation | High | DCCA-028 | High | P1 | 48 active Process Builders (1,039 elements) and 1 Workflow Rule carry core Application, Li… |
| W-06 | 04-automation | High | DCCA-044 | High | P2 | Batch jobs, @future and Queueables started per record from triggers; @future called from t… |
| W-07 | 04-automation | High | DCCA-045 | High | P2 | DML, SOQL, subflows and email actions inside flow loops (21 loops in 14 active flows); sch… |
| W-08 | 04-automation | High | DCCA-042 | High | P2 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus st… |
| W-09 | 04-automation | Medium | DCCA-024 | High | P1 | Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisatio… |
| W-10 | 04-automation | Medium | DCCA-046 | Medium | P2 | Silent failures: 577 of 609 flow DML/action elements lack fault paths (including Oracle GL… |
| W-11 | 04-automation | Medium | DCCA-043 | High | P2 | Over-automated core objects with undefined order: Application (1 trigger, 15 after-save fl… |
| W-12 | 04-automation | Medium | DCCA-044 | High | P2 | Batch jobs, @future and Queueables started per record from triggers; @future called from t… |
| W-13 | 04-automation | Medium | DCCA-047 | Medium | P2 | Payment batches self-schedule every 5 minutes (24 cron slots, 576 starts/day) with no over… |
| W-14 | 04-automation | Medium | DCCA-046 | Medium | P2 | Silent failures: 577 of 609 flow DML/action elements lack fault paths (including Oracle GL… |
| W-15 | 04-automation | Medium | DCCA-042 | High | P2 | Trigger architecture fragmentation: 6 objects with multiple triggers, 3 frameworks plus st… |
| W-16 | 04-automation | Medium | DCCA-048 | Medium | P2 | Flow version state disagrees with flowDefinitions (a Draft subflow called by an active PB)… |
| W-17 | 04-automation | Medium | DCCA-025 | High | P1 | Record details e-mailed to former vendor staff and a personal Gmail address (PB fault emai… |
| W-18 | 04-automation | Low | DCCA-060 | Medium | P3 | Wide API version spread (v31-v66): SpringCM SDK at v31, money-path triggers at v39-43, 55 … |
| W-19 | 04-automation | Low | DCCA-063 | Low | P3 | 10 flows run in SystemModeWithoutSharing (8 screen flows, 2 autolaunched) |
| W-20 | 04-automation | Low | DCCA-043 | High | P2 | Over-automated core objects with undefined order: Application (1 trigger, 15 after-save fl… |
| W-21 | 04-automation | Low | DCCA-028 | High | P1 | 48 active Process Builders (1,039 elements) and 1 Workflow Rule carry core Application, Li… |
| W-22 | 04-automation | Low | DCCA-045 | High | P2 | DML, SOQL, subflows and email actions inside flow loops (21 loops in 14 active flows); sch… |
| P-01 | 05-access-control | Critical | DCCA-005 | Critical | P0 | Guest sharing rules expose entire record populations: all Transactions (payer billing iden… |
| P-02 | 05-access-control | Critical | DCCA-004 | Critical | P0 | Guest-reachable Apex REST endpoints /CreatePayment and /CreateTransaction insert payments … |
| P-03 | 05-access-control | Critical | DCCA-006 | Critical | P0 | All three BREG community profiles hold Modify All / View All / Delete on Transaction__c (e… |
| P-04 | 05-access-control | Critical | DCCA-007 | Critical | P0 | Anonymous IDOR and mass assignment in BREG portal controllers: delete any Case, overwrite … |
| P-05 | 05-access-control | Critical | DCCA-005 | Critical | P0 | Guest sharing rules expose entire record populations: all Transactions (payer billing iden… |
| P-06 | 05-access-control | Critical | DCCA-015 | Critical | P1 | Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and Passw… |
| P-07 | 05-access-control | High | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| P-08 | 05-access-control | High | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| P-09 | 05-access-control | High | DCCA-012 | Critical | P0 | Anonymous disclosure of payment receipts, billing PII, card last-4, draft licence applicat… |
| P-10 | 05-access-control | High | DCCA-015 | Critical | P1 | Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and Passw… |
| P-11 | 05-access-control | High | DCCA-015 | Critical | P1 | Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and Passw… |
| P-12 | 05-access-control | High | DCCA-039 | High | P2 | Privilege-escalation paths: permission sets combining ManageUsers + AssignPermissionSets +… |
| P-13 | 05-access-control | High | DCCA-040 | High | P2 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' p… |
| P-14 | 05-access-control | High | DCCA-039 | High | P2 | Privilege-escalation paths: permission sets combining ManageUsers + AssignPermissionSets +… |
| P-15 | 05-access-control | High | DCCA-040 | High | P2 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' p… |
| P-16 | 05-access-control | High | DCCA-040 | High | P2 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' p… |
| P-17 | 05-access-control | High | DCCA-014 | High | P1 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object a… |
| P-18 | 05-access-control | Medium | DCCA-040 | High | P2 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' p… |
| P-19 | 05-access-control | Medium | DCCA-013 | High | P0 | Outbound perimeter: active Remote Site Settings to a pipedream.net request bin, a raw-IP H… |
| P-20 | 05-access-control | Medium | DCCA-013 | High | P0 | Outbound perimeter: active Remote Site Settings to a pipedream.net request bin, a raw-IP H… |
| P-21 | 05-access-control | Medium | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| P-22 | 05-access-control | Medium | DCCA-059 | Medium | P3 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identi… |
| P-23 | 05-access-control | Medium | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| P-24 | 05-access-control | Medium | DCCA-059 | Medium | P3 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identi… |
| P-25 | 05-access-control | Medium | DCCA-016 | High | P1 | Guest and community profiles over-provisioned: back-office cashier VF pages that start bat… |
| P-26 | 05-access-control | Medium | DCCA-015 | Critical | P1 | Nine admin-equivalent profiles; UI-login integration profiles with ModifyAllData and Passw… |
| P-27 | 05-access-control | Medium | DCCA-040 | High | P2 | Over-broad internal data access: Public Read/Write OWD on 90 custom objects, 'Read-Only' p… |
| P-28 | 05-access-control | Medium | DCCA-059 | Medium | P3 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identi… |
| P-29 | 05-access-control | Low | DCCA-059 | Medium | P3 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identi… |
| P-30 | 05-access-control | Low | DCCA-059 | Medium | P3 | Profile-centric access model with clone sprawl (78 custom profiles, 'Limited Admin' identi… |
| P-31 | 05-access-control | Low | DCCA-014 | High | P1 | Integration secrets held in Public custom metadata, custom settings, a Public R/W object a… |
| T-01 | 06-test-quality | Critical | DCCA-029 | Critical | P1 | Test.isRunningTest() changes production behaviour in 85 classes (~170 sites), including re… |
| T-02 | 06-test-quality | Critical | DCCA-030 | Critical | P1 | Payment, transaction and reconciliation code (~20 classes, ~3,000 LOC) is covered only by … |
| T-03 | 06-test-quality | Critical | DCCA-031 | High | P1 | Coverage-padding and zero-assertion tests: 36% of test classes assert nothing, 168 literal… |
| T-04 | 06-test-quality | High | DCCA-032 | High | P1 | Date time-bomb tests: BREGAnnualRollOverJobTest fails from 2027-01-01 and will block every… |
| T-05 | 06-test-quality | High | DCCA-031 | High | P1 | Coverage-padding and zero-assertion tests: 36% of test classes assert nothing, 168 literal… |
| T-06 | 06-test-quality | High | DCCA-055 | High | P2 | Production entry points with no test path (41 classes) or no direct test (210 classes), in… |
| T-07 | 06-test-quality | High | DCCA-053 | High | P2 | Thin bulk, permission and negative-path testing: ~8 of 61 triggers ever see 200+ records; … |
| T-08 | 06-test-quality | High | DCCA-054 | High | P2 | No LWC Jest tests (0 of 232 components); pre-commit hook passes with --passWithNoTests |
| T-09 | 06-test-quality | Medium | DCCA-029 | Critical | P1 | Test.isRunningTest() changes production behaviour in 85 classes (~170 sites), including re… |
| T-10 | 06-test-quality | Medium | DCCA-062 | Medium | P3 | Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, Se… |
| T-11 | 06-test-quality | Medium | DCCA-053 | High | P2 | Thin bulk, permission and negative-path testing: ~8 of 61 triggers ever see 200+ records; … |
| T-12 | 06-test-quality | Medium | DCCA-053 | High | P2 | Thin bulk, permission and negative-path testing: ~8 of 61 triggers ever see 200+ records; … |
| T-13 | 06-test-quality | Medium | DCCA-062 | Medium | P3 | Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, Se… |
| T-14 | 06-test-quality | Medium | DCCA-052 | Medium | P2 | Dead code and test scaffolding deployed to production (active no-op trigger, commented-out… |
| T-15 | 06-test-quality | Medium | DCCA-033 | Medium | P1 | No coverage baseline and no CI pipeline in the repo; 60% of production LOC depends on a si… |
| T-16 | 06-test-quality | Low | DCCA-062 | Medium | P3 | Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, Se… |
| T-17 | 06-test-quality | Low | DCCA-024 | High | P1 | Hard-coded environment-specific record IDs, URLs, user names and profile-name authorisatio… |
| T-18 | 06-test-quality | Low | DCCA-062 | Medium | P3 | Test flakiness and hygiene: dependence on org users/profiles/data, self-skipping tests, Se… |
