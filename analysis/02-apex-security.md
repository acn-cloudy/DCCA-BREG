# 02 — Apex Security

> Scope: `force-app/main/default/classes/*.cls` (1,288 files; 743 non-test / ~122k lines analysed, 545 test classes excluded from vulnerability findings), `triggers/*.trigger` (61), and `pages/*.page` / `components/*.component` where they call Apex. Access reachability was derived from `profiles/*.profile-meta.xml` and `permissionsets/*.permissionset-meta.xml` (`<classAccesses>` / `<pageAccesses>`). All paths below are relative to the repo root; `classes/` = `force-app/main/default/classes/`.
>
> Method: grep/AST-lite triage across every non-test class (sharing keyword, entry points, dynamic SOQL, DML, FLS tokens, callouts, crypto, logging, literals), then the candidates were read in full. Site/Network metadata (`sites/`, `networks/`) is **not** in the repo, so "reachable by guest" means a Guest User License profile, or the `BREG_Site_Guest_User` permission set, has class/page access. Treat that as **Likely** until someone confirms the site's public pages and Apex REST settings in the org.
>
> Platform notes used in the verdicts:
> 1. `@AuraEnabled` methods in classes with **no** sharing keyword run *with sharing* (enforced critical update). VF controllers, REST and other entry points of such classes run **without** sharing.
> 2. Apex never enforces CRUD/FLS unless the code asks for it.
> 3. Custom metadata and custom settings have no record sharing, so any Apex that can be steered into querying them returns their values.

## Summary

- **Guest users can read the org's integration secrets and live OAuth tokens.**
  - `sc_LookupController.searchDB` (Digital Form guest profile) builds SOQL from a client-supplied object name, SELECT list and WHERE clause. It can read `SpringCLMSetting__mdt.Client_Secret__c`, `Org_Credential__mdt.Password__c/Key__c`, `breg_DocuSign_Auth__mdt.Request_Private_Key__c`, `TaxClearanceApi__c.Password__c` and `qual_Integration_Settings__c.qual_Api_Token__c`.
  - `SpringCMConnector.getToken()` returns the SpringCM bearer token to the browser.
  - The CATV AES key is committed in `labels/CustomLabels.labels-meta.xml`.
- **BREG portal payment integrity is broken for anonymous users.**
  - `BREGPaymentController.createPayment` trusts the client-side cart price and total. An `amount` of 0 creates a Completed Transaction, a Completed Payment and `Paid` transaction lines, and those drive fulfilment triggers.
  - `BREGCaseControllerWithoutSharing.updateCasesProcessingSpeed` marks any case Expedited without charging for it.
  - `PaymentREST` and `TransactionREST` let the pre-payment, securities and transcripts guest profiles insert payments and transactions with any amount and status.
- **Anonymous users can create, overwrite and delete arbitrary records (IDOR and mass assignment in `without sharing` controllers).**
  - `BREGPortalUtils.deleteCase(Id)` deletes any Case.
  - `BREGRegistrationFormController.saveFormData` deserializes a client Case, including its `Id`, and upserts it, which re-parents another filer's case to the attacker's contact.
  - `CustomRecordCreate.SaveRecord` updates any record of any object.
  - `CustomCommunityRegistrationController.finalizeRecords` provisions a portal user on a **client-chosen Account and Profile**.
- **Guest-reachable SOQL injection in 15 classes.** The worst is `CATV_CustomLookUpController`, which runs in `AccessLevel.SYSTEM_MODE`; the others are listed in S-07. Of the 235 dynamic-SOQL sites, 30 are rated injectable (Appendix A); the rest use binds, `escapeSingleQuotes` or internal constants.
- **The sharing model is systemically inverted for external users.**
  - 52 of 176 entry-point classes are `without sharing`, and 36 of those are reachable by guest profiles.
  - 73 guest-reachable entry-point classes exist. Only 4 contain any CRUD/FLS enforcement token, and even those use it only on some paths.
- **CRUD/FLS is almost never enforced.**
  - 8 of 97 `@AuraEnabled` classes (335 methods) contain any enforcement: `WITH SECURITY_ENFORCED`, `WITH USER_MODE`, `stripInaccessible`, `AccessLevel.USER_MODE`, `as user` or `isAccessible()`.
  - 43 of the 50 Aura classes that perform DML have none.
  - Across all 743 non-test classes there are 39 enforcement tokens against roughly 690 DML statements and 1,328 queries.
- **Guest profiles are over-provisioned.** The pre-payment, securities and transcripts guest profiles have access to internal cashier VF pages (`BatchTransaction`, `CompletePaymentsDeposit`, `RunReconciliationBatch`, `PaymentCutOffBatch`, `SendTo4Gov`, `TransactionRefundAuthFormPdf`) and to more than 60 back-office classes, including batch and REST classes.
- **Secrets and tokens are handled in plaintext.**
  - They are stored in public custom metadata, custom settings and a custom object (`SpringCLM_Session__c.AccessToken__c/RefreshToken__c`), and in plaintext user fields (`PVL_Portal_User__c.ProviderSchoolPassword__c`, `SecretAnswer__c`).
  - Tokens, session IDs and secret-bearing records are written to debug logs.
  - An RSA private key is embedded in two test classes.

| Severity | Count |
|---|---|
| Critical | 10 |
| High | 8 |
| Medium | 8 |
| Low | 4 |
| **Total** | **30** |

---

## Findings

### [CRITICAL] ID S-01: Guest-callable arbitrary-object SOQL exposes integration secrets (custom metadata / custom settings)
**Confidence:** Confirmed (code path). Reachability is Likely: the Digital Form guest profile has class access, and an Aura component calls the method.

**Evidence**
- `classes/sc_LookupController.cls:1-14` has no sharing keyword. Only `searchText` is escaped; the object name, SELECT fields and WHERE field come straight from the client:
  ```apex
  searchText='\'%' + String.escapeSingleQuotes(searchText.trim()) + '%\'';
  String query = 'SELECT '+fld_API_Text+' ,'+fld_API_Val+
                  ' FROM '+objectName+
                      ' WHERE '+fld_API_Search+' LIKE '+searchText+
                  ' LIMIT '+lim;
  List<sObject> sobjList = Database.query(query);
  ```
- Reachability: `aura/sc_Lookup/sc_Lookup.cmp` (`controller="sc_LookupController"`) and `aura/sc_Lookup/sc_LookupHelper.js:33` (`c.searchDB`), embedded by `aura/sc_FieldInput/sc_FieldInput.cmp:51`. The component even ships a default WHERE fragment: `sc_Lookup.cmp:15` `default=" IsActive=True and UserType='Standard' and  Name"`.
- Access: `profiles/Digital Form Profile.profile-meta.xml` (Guest User License) grants `sc_LookupController`.
- Secret-bearing objects, all `<visibility>Public</visibility>`:
  - `objects/Org_Credential__mdt/fields/Password__c`, `Key__c` (AES key and IV used by `classes/PVL_EncodingService.cls:7-26`)
  - `objects/SpringCLMSetting__mdt/fields/Client_Secret__c` (used by `classes/SpringCMConnector.cls:32`, `classes/DocuSignCallbackController.cls:25`)
  - `objects/SpringCMApiEnvironment__mdt/fields/Client_Secret__c`
  - `objects/breg_DocuSign_Auth__mdt/fields/Request_Private_Key__c` (JWT signing key, `classes/DocusignAuthProvider.cls:140`, `classes/DocuSignJWT.cls:75-77`)
  - `objects/TaxClearanceApi__c/fields/Password__c` (hierarchy setting; Basic auth at `classes/TaxClearanceApiHelper.cls:106-116`)
  - `objects/qual_Integration_Settings__c/fields/qual_Api_Token__c` (`classes/QualConfigSelector.cls:40`)
- The same unrestricted pattern (client-controlled object and fields) exists in `LookUpController`, `FilingController`, `RelatedListController`, `ListViewController`, `LookupService` and `InputLookupAuraController`. Those are reachable by the `DCCA BREG - CustomerCommunityLogin` community profile and about 25 internal profiles (see S-11).

**Attack scenario / Impact:** An anonymous visitor to the Digital Form site calls `searchDB` with a custom metadata or custom setting API name as the object. The records have no sharing and the class has no FLS check, so the stored values come back in the JSON response. This yields the SpringCM OAuth client secret, the DocuSign JWT private key (impersonate the integration user in DocuSign CLM), the Hawaii Tax clearance API credentials, the Qualtrics token, and the Digital Form AES key and IV (forge the `data=` tokens used by `PVL_EncodingService`). Setup objects (User, Profile, Organization, Group) can be enumerated too.

**Recommendation**
1. Remove `sc_LookupController` from `Digital Form Profile` now. Then rewrite it to take a **logical lookup key** that maps server-side to an allow-listed object and field set, for example a `Map<String, LookupConfig>` held in custom metadata that the client can't read. Validate every identifier with `Schema.getGlobalDescribe()` and the field map, and run `Database.queryWithBinds(q, binds, AccessLevel.USER_MODE)`.
2. Move all secrets out of CMT and custom settings into **Named Credentials / External Credentials**, using a JWT Bearer flow with certificate for DocuSign and OAuth for SpringCM. Where CMT has to stay, mark it **Protected** in a managed or unlocked package.
3. **Rotate every secret listed above.** Assume they are compromised, because the endpoint has been publicly reachable.

**Effort:** M (code), plus S for the secret rotation.

---

### [CRITICAL] ID S-02: SpringCM OAuth bearer token returned to guest browsers, and org-token callouts to client-supplied URLs
**Confidence:** Confirmed.

**Evidence**
- `classes/SpringCMConnector.cls:1` is `public without sharing class SpringCMConnector`. `:63-67`:
  ```apex
  @AuraEnabled
  public static String getToken() {
      String accessToken = getAccessToken();
      saveToken();
      return accessToken;
  ```
- The token is consumed client-side at `lwc/springFiles/springFiles.js:3` (`import getAccessToken from "@salesforce/apex/SpringCMConnector.getToken"`).
- The client passes an arbitrary URL, and the org bearer token is attached:
  - `:347-369` `updateDescription(fileURL, des)` does `req.setEndpoint(fileURL); req.setHeader('Authorization','bearer '+accesstoken)` with PUT.
  - `:469-486` `deleteDocument(url)` issues DELETE.
  - `:501-524` `updateFileDesAndFolder` and `updateFilesAndFolder` issue PUT; `:510` returns the raw response body.
- `:181-334` `getFolderURL(recordId)` creates a SpringCM folder for **any** record Id, reads that record's fields without sharing, and returns the upload href.
- Token logging: `:203` `System.debug('token: ' + token);`.
- Access: `Digital Form Profile` (guest), permission sets `External_CATV_Provider` and `External_CATV_Requestor`, and `DCCA BREG - CustomerCommunityLogin`.
- Refresh tokens persist in `SpringCLM_Session__c.AccessToken__c/RefreshToken__c` (custom object, `:336-345`). Every guest call upserts them.

**Attack scenario / Impact:** A guest calls `getToken()` and gets a valid SpringCM (DocuSign CLM) API token for the org's integration account. With it they can read, download, modify or delete **all** government documents in SpringCM directly, outside Salesforce. They can also use `deleteDocument`/`updateFilesAndFolder` as a proxy. Remote Site Settings allow `https://eod2cgfefmvt6uf.m.pipedream.net` and `http://44.232.202.215` (S-25), so the token can also be sent to those hosts. Repeated calls can store null tokens and break the integration (DoS; inferred).

**Recommendation**
1. Delete `getToken()` as an `@AuraEnabled` method. The browser must never hold the integration token; proxy the required operations server-side.
2. For the URL-taking methods, accept a **SpringCM document UID**, not a URL. Build the URL server-side from `callout:SpringCM/...` (Named Credential), and check that the document belongs to a Salesforce record the caller owns (`UserRecordAccess`).
3. Remove the class from the guest profile. Make the class `with sharing`.
4. Remove `System.debug` of tokens.
5. Revoke the current refresh token.

**Effort:** M

---

### [CRITICAL] ID S-03: BREG portal checkout trusts client-side prices; a zero-amount cart marks filings Paid and triggers fulfilment
**Confidence:** Confirmed (code). Guest reachability is Likely (`BREG Profile` and `BREG_Site_Guest_User` have class access).

**Evidence**
- `classes/BREGPaymentController.cls:285-334`. The status comes from the client `amount`; prices come from client cart JSON:
  ```apex
  public static Id createPayment(Double amount, String cartItemsJson, String deliveryDetailsJson, Boolean skipPaymentCreation) {
      String tliStatus = amount > 0 ? 'Pending' : 'Paid';
  ```
  - `:368-379` `trans.Status__c = amount > 0 ? 'Pending' : 'Completed';`
  - `:381-392` `payment.pymt__Status__c = amount > 0 ? 'In Process' : 'Completed';`
  - `:629-647` `Decimal unitPrice = cartItem.get('unitPrice') ...; transLineItem.Amount__c = unitPrice * quantity;` with no lookup of `breg_Fee__c.breg_Fee_Amount__c`.
  - `:582` `transLineItem.PaidStatus__c = tliStatus;`
- The client computes the total from `localStorage`: `lwc/breg_CheckoutPage/breg_CheckoutPage.js:122-124` (`reduce((total, item) => total + item.price, 0)`) and `:150-163`.
- Downstream effects: `classes/BREGTransactionLineTriggerHandler.cls:11-33` reacts to `Paid` lines on insert (case updates, payment reference, COGS document creation). `:131-146` starts document-copy DocuSign workflows. `BREGCaseStatusHandlerUtils.cls:217` and `BREGCaseTriggerHandler.cls:778` gate case progression on `PaidStatus__c = 'Paid'`.
- Expedite without payment: `classes/BREGCaseControllerWithoutSharing.cls:17-28`:
  ```apex
  public static void updateCasesProcessingSpeed(List<Id> caseIds){
      List<Case> casesToUpdate = [SELECT Id FROM Case WHERE Id IN :caseIds];
      for(Case c : casesToUpdate){ c.breg_Processing_Speed__c = EXPEDITED_SPEED; }
  ```
  This runs `without sharing` for any case Ids, and the LWC calls it (`breg_CheckoutPage.js:143`).

**Attack scenario / Impact:** An anonymous filer changes their cart in localStorage, or calls the Aura action directly, with `amount = 0` and `unitPrice = 0`. The system records a Completed payment and Paid lines. Certificates of Good Standing, certified copies and filing workflows are then produced with no money collected, and cashiering and GL reconciliation are corrupted. Any case can also be switched to Expedited without paying the expedite fee.

**Recommendation**
1. Re-price every cart line server-side from `breg_Fee__c` by `feeId`, rejecting unknown fees. Compute `amount` server-side; the client must never be able to set line status or amount.
2. Set `Paid` / `Completed` **only** from the payment-processor callback, with signature verification. Zero-amount carts are allowed only when every fee is legitimately zero.
3. Remove `updateCasesProcessingSpeed` from the client API. Set expedite in the trigger when a *paid* expedite fee line is inserted; `BREGTransactionLineTriggerHandler.updateRelatedCaseFields` already does this.

**Effort:** M

---

### [CRITICAL] ID S-04: Guest-reachable Apex REST endpoints create payments and transactions with caller-supplied amounts and status
**Confidence:** Confirmed (code). Reachability is Likely: the class is granted to three guest profiles, and Apex REST is callable on a Site at `/services/apexrest/...` when the guest profile has class access.

**Evidence**
- `classes/PaymentREST.cls:5-62`:
  ```apex
  @RestResource(urlMapping='/CreatePayment')
  global without sharing class PaymentREST {
  ...
  newPayment.pymt__Amount__c = jObject.PaymentAmount;
  newPayment.pymt__Status__c = jObject.Status;
  newPayment.pymt__Card_Type__c = jObject.CreditCardType;
  newPayment.pymt__Last_4_Digits__c = jObject.Last4Digits;
  insert newPayment;
  ...
  return '{"Status": "Error", "StatusCode": 400, "Message": "' + ex.getMessage() + '"}';
  ```
- `classes/TransactionREST.cls:5-120` (`urlMapping='/CreateTransaction'`, `without sharing`) inserts Accounts, Transactions and TransactionLines with caller-supplied amounts and paid status (`:55-109`). It echoes `ex.getMessage()` at `:119`.
- Access: `profiles/pre-payment Profile`, `securities Profile` and `transcripts Profile` (all Guest User License), plus `DCCA BREG - CustomerCommunityLogin`.
- Neither class checks the caller's identity, uses an API key or HMAC, or restricts to an integration user.

**Attack scenario / Impact:** An anonymous caller POSTs a JSON body to the site's `/services/apexrest/CreatePayment` naming a known Transaction external Id and `Status = Completed`. A forged, fully "paid" payment record is inserted against a real transaction, which bypasses Authorize.Net and poisons deposits and reconciliation. `/CreateTransaction` lets them fabricate accounts and ledger lines.

**Recommendation**
1. Remove `PaymentREST` and `TransactionREST` from **all** guest and community profiles.
2. Expose them only to a dedicated integration user (OAuth client-credentials, Connected App restricted to that user). Add an explicit check such as `FeatureManagement.checkPermission('Payment_API')`.
3. Validate the payload and never accept `Status` from the caller.
4. Return generic errors.

**Effort:** S

---

### [CRITICAL] ID S-05: Anonymous IDOR and mass assignment on BREG cases and documents (delete, overwrite, re-parent)
**Confidence:** Confirmed (code). Reachability is Likely (`BREG_Site_Guest_User` / `BREG Profile`; the LWCs import these methods).

**Evidence**
- `classes/BREGPortalUtils.cls:292-296` (`without sharing`) deletes any Case Id. It is used by `lwc/breg_MyDashboardPage/breg_MyDashboardPage.js:13`:
  ```apex
  @AuraEnabled
  public static void deleteCase(Id caseId) {
      Case caseToDelete = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
      delete caseToDelete;
  ```
- `classes/BREGRegistrationFormController.cls:102-169` (`without sharing`). A client JSON object becomes a Case, **including `Id`**, then `upsert`:
  ```apex
  newCase = (Case) JSON.deserialize(JSON.serialize(data.get(key)), Case.class);
  ...
  newCase.ContactId = currentUserContactId;
  ...
  upsert casesToUpsert;
  ```
  - Affiliations (`:45-56`) and stocks (`:79-93`) are built with `put(fieldName, value)` for any client field name, then upserted (`:203`, `:228`).
  - `:181-183` updates the `ParentId` of any client-named `breg_GP_Case__c`.
- `classes/BREGRegistrationFormController.cls:280-343` `saveRelatedFiles(recordId, …)` uploads to, and **deletes** documents from, any case Id.
- `classes/BREGCaseControllerWithoutSharing.cls:4-16` and `:31-41` update any Case's `ContactId` and subscription flag. `:44-64` returns the DocuSign document id for any case. The LWC imports are at `lwc/breg_AnnualReports/breg_AnnualReports.js:9`.

**Attack scenario / Impact:**
- Delete any business-registration case by Id. Salesforce Ids are sequential and are exposed in portal URLs, search results and `getSearchResults`.
- Submit a form payload carrying a victim's case `Id`. The victim's filing is overwritten (status, entity data, officers) and its `ContactId` is set to the attacker's contact, so the attacker now "owns" the filing in the portal.
- Remove supporting documents from other filers' cases.

**Recommendation**
1. For every method that takes an Id, enforce ownership server-side. For example: `[SELECT Id FROM Case WHERE Id = :caseId AND ContactId = :BREGUtils.getCommunityUserContactId() WITH USER_MODE]`. Guests must never delete; they can only act on records created in the same session, tracked with a signed, unguessable token.
2. Replace `JSON.deserialize(..., Case.class)` with an explicit DTO and an **allow-list** of writable fields. Discard `Id`, `Status`, `OwnerId`, `ContactId`, `breg_Bypass_Validation__c` and `breg_Processing_Speed__c` from client input. For updates, re-query the existing record under `USER_MODE` and confirm ownership.
3. Change these classes to `with sharing` or `inherited sharing`, and only elevate narrowly with `AccessLevel.SYSTEM_MODE` on specific, validated queries.

**Effort:** L

---

### [CRITICAL] ID S-06: Anonymous portal-user provisioning with a client-chosen Profile and an existing Account (account takeover)
**Confidence:** Confirmed (code). Reachability is Likely (pre-payment, securities and transcripts guest profiles).

**Evidence**
- `classes/CustomCommunityRegistrationController.cls` is `without sharing`.
- `finalizeRecords` (`:183-319`) accepts `Account account, Contact contact, string profileName`:
  ```apex
  else { accId = account.Id; }            // :222 existing Account chosen by client
  ...
  cnt.AccountId = accId; insert cnt;
  Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];  // :291
  u.ProfileId = profile.Id; u.ContactId = cntId; u.Username = contact.Email; ...
  insert u;
  ```
- `getExistingContact` (`:56-125`) matches `Email LIKE :email`, so the client controls the wildcard.
  - If the matched contact already has a user, it returns that contact's field-set PII (`:91-100`).
  - Otherwise it **creates a User** for the victim's contact with the client-supplied `profileName` (`:102-119`).
- PII is logged at `:74-77` (`System.debug(firstName); System.debug(email); System.debug(contacts);`).

**Attack scenario / Impact:** An attacker registers with their own email but supplies another company's Account Id and a community profile of their choice (for example a Customer Community *Plus* profile). They get a portal login attached to that business, and can see its filings, transactions and cases through account-based sharing. The contact-matching path also allows enumeration of contacts and their PII by wildcard, and unsolicited user creation for real people.

**Recommendation**
1. Hard-code the target profile server-side.
2. Never accept an Account Id from an unauthenticated client. Create a new account, or queue an access request for staff approval, as the CATV flow does.
3. Replace `LIKE` with exact, case-normalised equality, and return a uniform "check your email" response.
4. Use `Site.createExternalUser` with email verification.
5. Remove the PII debug statements.

**Effort:** M

---

### [CRITICAL] ID S-07: SOQL injection reachable by guest users (including one in SYSTEM_MODE)
**Confidence:** Confirmed for each site listed. Reachability is Likely (guest class access).

**Evidence** (all concatenate unescaped client input into the query; full list in Appendix A):
- `classes/CATV_CustomLookUpController.cls:22,28-30` (CATV Portal guest):
  ```apex
  String filterCriteria = inputWrapper.fieldApiName + ' LIKE ' + '\'' + String.escapeSingleQuotes(...) + '%\' LIMIT 10';
  ...
  for(SObject s : CATV_WithoutSharingUtility.queryRecords(query, bindMap)) {
  ```
  This goes to `classes/CATV_WithoutSharingUtility.cls:51`, `Database.queryWithBinds(query, bindMap, AccessLevel.SYSTEM_MODE)`. Sharing, CRUD and FLS are all bypassed.
- `classes/GenericCreatePaymentCtrl.cls:547,552,561,569` (`without sharing`, pre-payment, securities and transcripts guests): `'Name LIKE \'%'+accountName+'%\' '`, `'DBA__c LIKE \'%'+dbaVal+'%\' '`, `'BillingStreet LIKE \'%'+streetName+'%\' '`. Reached from `searchBusinessAccountsFromServer` (`:580`).
- `classes/CustomCommunityRegistrationController.cls:160` (`without sharing`): `') AND RecordType.DeveloperName = \'' + paramsMap.get('businessAccRecordTypeDeveloperName') + '\''`.
- `classes/BREGEntityListBuilderController.cls:109,120,123` (`without sharing`, BREG guest):
  ```apex
  accountQueryString += ' AND breg_Entity_Type__c IN (\'' + String.join(input.recordTypes, '\', \'') + '\')';
  accountQueryString += ' AND breg_Incorporation_Date__c > ' + input.startDate;
  ```
  The same `SearchInput` is stored by `upsertList` (`:64-80`) and later re-executed by `classes/BREGEntityListBuilderBatch.cls:33-38` (second-order injection), whose CSV output is emailed to the buyer.
- `classes/GroupTransactions2.cls:126,177-178`, `classes/NewTransaction.cls:94-95`, `classes/BatchTransaction.cls:298,322-330,353,466` (field names, values and select list from client).
- `classes/CustomPaymentButtonController.cls:24` and `classes/CustomUploadButtonController.cls:24`: `'SELECT Id, ' + checkboxApiName + ' FROM Filing__c ...'`.
- `classes/FilingController.cls:4`: `'SELECT '+ fields +' FROM ' + objectName + ' WHERE Id= :recordId'`.
- `classes/InputLookupAuraController.cls:50,110-124`: object, extra fields and `additionalFilter` concatenated into SOQL/SOSL.
- `classes/BatchSummaryPDF.cls:11-60` (`without sharing`, VF page `BatchSummaryPDF` enabled on the pre-payment, securities and transcripts **guest** profiles). The `printFields` URL parameter (JSON) is concatenated into the SELECT list, so any related-object field or child subquery can be pulled:
  ```apex
  printFields = ApexPages.currentPage().getParameters().get('printFields');
  ...
  queryFields += currentFields;            // raw, for key 'Transaction__c'
  String query = 'SELECT Id, BatchNumber__c, ' + queryFields + ' FROM Transaction__c WHERE BatchNumber__c = :batch';
  transactions = Database.query(query);
  ```
  Omitting `batch` binds `null`, so every un-batched transaction is returned. The values are rendered with `escape="false"` (`pages/BatchSummaryPDF.page:7`).

**Attack scenario / Impact:** An anonymous user can break out of the intended filter and list every Account, including Person Accounts with names and addresses. Semi-joins turn a count or row-returning query into a boolean oracle for any field on any object, for example `Id IN (SELECT AccountId FROM Contact WHERE …)`. In `CATV_CustomLookUpController` this works regardless of sharing. The entity-list case also makes a *paid* export return more data than was purchased.

**Recommendation**
1. Convert every value to a bind variable (`:var` or `Database.queryWithBinds`). Object and field identifiers are the exception: validate them against `Schema.describe` plus an allow-list, and never concatenate a raw identifier.
2. Parse dates with `Date.valueOf()` and bind them.
3. Run portal queries `WITH USER_MODE`.
4. Delete `CATV_WithoutSharingUtility.queryRecords`, which is a generic SYSTEM_MODE query sink, or restrict it to constant query templates.

**Effort:** M

---

### [CRITICAL] ID S-08: Guest-callable generic DML / mass assignment in the payment portal (any object, any record)
**Confidence:** Confirmed (code). Reachability is Likely (pre-payment, securities and transcripts guest profiles).

**Evidence**
- `classes/CustomRecordCreate.cls:70-104` (`without sharing`). The client picks the object, the fields and (via `Id`) the record:
  ```apex
  sObject sObj = Schema.getGlobalDescribe().get(sObjName).newSObject();
  ...
  if (!found) { sObj.put(key, recMap.get(key)); }
  if(sObj.Id != null ) { update sObj; } else { insert sObj; }
  ```
- `classes/GenericCommunityPaymentController.cls:50-83` (`without sharing`) runs `insert sObj;` on a client-supplied SObject of any type, then `transactionRecord.put(parentLookUpField, …)` with a client-chosen field name.
- `classes/CreateTransaction.cls:33-46` (`without sharing`) runs `upsert trns;` on a client-supplied Transaction (any Id). `AmountOverride__c` comes from the client.
- `classes/GroupTransactionController.cls:24-49` (`without sharing`) lists all open Transactions and updates a client-deserialized Transaction list.
- `classes/HPEAPRequestCreate.cls:53-109` (`without sharing`): the amount is the client `cashier.Amount__c` times quantity, and billing PII is copied to the payment.
- `classes/FileDetailCreatorController.cls:62-64,85` inserts client FileDetails, queues a SpringCM callout with a client `fileUrl`, and deletes by any Id.
- `classes/FilingController.cls:9-22` runs `update (SObject) JSON.deserialize(fieldsListString, SObject.class)` on any object the caller can see.

**Attack scenario / Impact:** Anonymous users can update arbitrary records in system mode. Examples: change a payment's status or amount, change the owner or email on Accounts or Contacts, or edit Transaction lines to zero. This is complete loss of integrity for payment and licensing data.

**Recommendation**
1. Remove these classes from the guest profiles.
2. Replace generic `SObject` parameters with typed DTOs and per-object field allow-lists.
3. Use `Security.stripInaccessible(AccessType.CREATABLE/UPDATABLE, …)` plus `insert as user` / `update as user`.
4. Never honour a client `Id` without an ownership check.

**Effort:** L

---

### [CRITICAL] ID S-09: Anonymous access to payment receipts, billing PII, case applicant data and draft applications by record Id or enumerable name
**Confidence:** Confirmed (code). Reachability is Likely.

**Evidence**
- `classes/BREGPaymentController.cls:202-240` `getPaymentConfirmation(Id paymentId)` (`without sharing`, BREG guest) returns billing name, email, full address, card type, last-4 and Authorize.Net transaction and authorization Ids for **any** payment. Only the contact block is suppressed for guests (`:226`).
- The same class at `:81-87` and `:192-199` returns transaction lines for any payment. `:5-15` `downloadDocument(docusignDocumentId)` streams any DocuSign document as base64. Ids come from `getInitialFilingDocument(caseId)` (`:18-47`) and `BREGCaseControllerWithoutSharing.getDocumentFromCase`.
- VF: `classes/BREGPaymentReceiptPdfController.cls:12-17` and `classes/PVL_PaymentReceiptController.cls:8-41` (both `without sharing`) read `ApexPages.currentPage().getParameters().get('id')` and render the payment with billing name, email, address and card last-4. The pages `BREG_PaymentReceipt` and `PVL_PaymentReceipt` are enabled on `PaymentConnect Profile` (guest). `BREGPaymentController.cls:265` builds `/pmtx/BREG_PaymentReceipt?id=`.
- `classes/BREGPortalUtils.cls:298-330` `getCaseWithRelations(Id)` returns about 100 applicant and filing fields for any case, with protected addresses stripped only by `BREGAddressProtectionUtils`. `:667-720` `getCasesForWithdrawal` works on any Ids.
- Digital Form guest:
  - `classes/sc_ApplicationController.cls:24-44` (`loadPreValues`, `loadCardValues`, `submit`) and `classes/DraftApplicationDetailCont.cls:3-5` (`getDraftApp`) look up `Application_Cache__c` by **Name**. Names are `DT` + year + sequential AutoNumber, so they can be enumerated.
  - These return every form answer and serialized Account/Application PII. `submit` force-submits another applicant's draft.
  - `classes/PaymentDisplayController.cls:3-31` returns the payment link and lines for any draft Id. `classes/DisplayBPIDController.cls:38-42` returns an Account name for any BPID.
- `classes/SEBSearchController.cls:46-56` (dcca guest, `without sharing`) `getContactSEBCases` has no `Public__c` filter, unlike `getCaseContactDocuments` at `:60-70`.
- More VF pages on the PaymentConnect **guest** profile render records by URL `id` without sharing:
  - `WebPDF` (`classes/WebDocumentExt.cls:19-20` takes `queryId`/`queryIds`, with `DocGeneratorDataSourceDomain` running `without sharing`). Any `DocGeneratorSettings__c` template can be rendered against any record.
  - `PVL_Pocket_ID_PDF` (`PVL_Pocket_ID_PDFController`, `without sharing`)
  - `CertificateOfInsurance` (`CertificateOfInsuranceController`, `without sharing`)
  - `RenewalNotification*` / `OnlineRenewalCopy*` (`RenewalNotificationController.cls:203-208`, `OnlineRenewalController.cls:159`; no keyword, so VF runs without sharing), which print licensee names and mailing addresses.

**Attack scenario / Impact:** Iterating sequential Ids or draft numbers discloses citizens' billing identities, partial card data, processor transaction Ids, pending licence applications and non-public enforcement case results, all without logging in. That is a reportable privacy breach for a state agency.

**Recommendation**
1. Bind every guest read to a secret the requester holds, for example a random 128-bit `Access_Token__c` stored on the Payment or Draft and emailed or returned only at creation, compared in constant time.
2. For authenticated users, filter on `ContactId = :currentContact` / `CreatedById = :UserInfo.getUserId()` `WITH USER_MODE`.
3. Remove card and processor fields from guest payloads.
4. Add `Public__c = true` to `getContactSEBCases`.

**Effort:** M

---

### [CRITICAL] ID S-10: Symmetric encryption keys in source control and client-reachable encrypt/decrypt oracles
**Confidence:** Confirmed.

**Evidence**
- `force-app/main/default/labels/CustomLabels.labels-meta.xml:5258-5264` has `CATV_EncryptionKey` = `4234****` (16-byte AES-128 key in plaintext, `protected=false`). Aura can fetch any label at runtime (`$A.get('$Label.c.…')`).
- The key is used by:
  - `classes/CATV_CustomLookUpController.cls:34-37` (`encryptWithManagedIV('AES128', key, …)`, which "protects" Account Ids sent to guests)
  - `classes/CATV_RegistrationHandler.cls:40`
  - `classes/CATV_SelfRegistrationController.cls:86-92`, an `@AuraEnabled` **decrypt oracle** on the CATV guest profile:
    ```apex
    @AuraEnabled
    public static String decrypt(String data){
        Blob key = Blob.valueOf(System.Label.CATV_EncryptionKey);
        ... Crypto.decryptWithManagedIV('AES128', key, encodedEncryptedBlob);
    ```
- `classes/PVL_EncodingService.cls:7-26` uses AES-128 with a **static IV taken from `Org_Credential__mdt.Password__c`**, and the key from `Key__c`.
  - It is exposed as `@RestResource('/Encoding')` `@HttpGet signItem` (an encryption oracle).
  - `classes/DraftApplicationDetailCont.cls:27-29` `decode()` is an `@AuraEnabled` decryption oracle on the Digital Form guest profile.
- `classes/CATV_SelfRegistrationController.cls:9,96` trusts `decrypt(registrationData.accountId)` to choose which Account a new CATV registrant is attached to.

**Attack scenario / Impact:** Anyone with repo access, or any guest via the decrypt oracle, can mint "encrypted" Account Ids. That lets them request access to any cable operator's account through CATV self-registration, and forge Digital Form `data=` tokens that identify portal users. A static IV plus an exception-leaking decrypt also allows padding-oracle attacks.

**Recommendation**
1. Stop using encryption as an authorization token. Store a server-side, single-use random token (for example `Account_Access_Invite__c.Token__c`) and look it up.
2. If encryption must stay, keep keys in a Protected CMT or a Named Credential secret, use `encryptWithManagedIV` (random IV), and add a MAC (`Crypto.generateMac('hmacSHA256', …)`) that is verified before use.
3. Remove the `@AuraEnabled` `decrypt` / `decode` methods.
4. Rotate the CATV key and the `Org_Credential__mdt` key.

**Effort:** M

---

### [HIGH] ID S-11: Authenticated generic "query anything / write anything" Aura endpoints (community and internal users)
**Confidence:** Confirmed.

**Evidence** (none have a sharing keyword, so Aura runs with sharing; all skip CRUD/FLS):
- `classes/ListViewController.cls:10-17` concatenates the select list, object and ORDER BY. `:20-49` runs `Database.insert/update` on a client-deserialized `List<CustomRecord>` of **any** SObject type.
- `classes/RelatedListController.cls:44-60`: `'Select ' + fieldStr +',  ' + parentField + ' from '+ sobjectName + ' where '+parentField+' in: parentIds ' + otherConditions + sortBy`.
- `classes/LookUpController.cls:8-13` (identical to `sc_LookupController`).
- `classes/LookupService.cls:51-60` (`with sharing`): `'FIND \'' + searchTerm + '*\' IN ALL FIELDS RETURNING ' + sobjectName + ' ('+fieldList+ ' ' + extraCondition + ')'`. `searchTerm` is not escaped either.
- `classes/RelatedListTreeViewerController.cls:146` and `classes/FilingController.cls:3-22`.
- Access: `DCCA BREG - CustomerCommunityLogin` (Customer Community Login license) plus 20–40 internal profiles each (Appendix D).

**Attack scenario / Impact:** Any logged-in community user, or any internal clerk, can:
- read custom metadata and custom settings secrets (see S-01);
- read fields hidden from them by FLS on records they can see (for example SSN/EIN-type fields and investigation notes);
- insert or update records of object types their profile has no CRUD permission on.

**Recommendation**
1. Replace these utilities with purpose-built controllers, or with LDS / `lightning/uiRecordApi` (which enforces CRUD/FLS).
2. If generic endpoints must stay, allow-list objects and fields in CMT, run every query with `WITH USER_MODE`, and run every DML with `as user` after `Security.stripInaccessible`.
3. Remove community profile access.

**Effort:** M

---

### [HIGH] ID S-12: BREG / CATV portal authenticated IDOR, mass assignment and workflow triggering
**Confidence:** Confirmed (code). Reachable through `BREG_Portal_User` and the `External_CATV_*` permission sets.

**Evidence**
- `classes/BREGNotificationsHandler.cls:122-157` (`without sharing`):
  ```apex
  breg_Notification__c notification = new breg_Notification__c(Id = recordId);
  for (String fieldName : fields.keySet()) { notification.put(fieldName, fields.get(fieldName)); }
  ...
  update notificationsToUpdate;
  ```
  Any notification Id and any field.
- `classes/BREGCreateTransaction.cls:33-55` (`without sharing`) runs `upsert trns;` on a client Transaction (any Id) and accepts client `AmountOverride__c`.
- `classes/BREGAccountInfoController.cls:22` `saveInfo(String infoPayload)` (`without sharing`, 2 DML).
- `classes/BREGCaseController.cls:261-305` starts arbitrary DocuSign CLM workflows (`workflowName` from the client) for any Case or Account Id. It concatenates client text into XML: `params += '<customParameters>' + customParameters + '</customParameters>';` (XML injection).
- `classes/CATV_DashboardController.cls:136-146`: `'SELECT Id, Document_Href__c FROM ' + objectName + ' WHERE Id =: recordId'`, then downloads that URL with the org SpringCM token. `:95-130` `uploadFile` writes to a client-chosen object. `:45-55` lets a Requestor set Invoice `Status = 'Paid'`, relying only on `update as user`.
- `classes/CATV_WithoutSharingUtility.cls:4-15` `getParentId(feedItemId)` resolves the parent of any FeedItem.

**Attack scenario / Impact:** A registered portal user can change other users' notification subscriptions and emails, rewrite Transactions, trigger document-generation workflows (certificates or letters) on other entities, and mark CATV invoices paid.

**Recommendation**
1. Add an ownership predicate to every Id-taking method.
2. Replace `put(fieldName, …)` loops with a fixed field allow-list.
3. Allow-list `workflowName` values per record type and XML-escape parameters (`String.escapeXml`).
4. Enforce status transitions server-side, for example "Requestor may only set Accepted/Rejected".

**Effort:** M

---

### [HIGH] ID S-13: Guest profiles are over-provisioned with internal cashier pages and back-office classes
**Confidence:** Confirmed (metadata).

**Evidence**
- `profiles/pre-payment Profile`, `securities Profile` and `transcripts Profile` (Guest User License) enable internal pages: `BatchTransaction`, `GroupTransactions2`, `NewTransactionNoAccount`, `CompletePaymentsDeposit`, `DepositRollupsButton`, `PaymentCutOffBatch`, `PaymentXBatchProgress`, `PaymentAllocateBatchProgress`, `PaymentAutoCloserMonitor`, `RunReconciliationBatch`, `SendTo4Gov`, `TransactionRefundAuthFormPdf`, `TransactionPaymentCoverSheetPdf`, `InvoiceBatchTransaction` and `BatchSummaryPDF`.
- They also grant 64 classes, including batch/scheduler classes (`PaymentXBatch`, `ReconciliationBatchJob`, `DepositRollupsBatch`, `PaymentAutoCloserScheduler`) and REST classes. This pattern suggests the profiles were cloned from an internal cashier profile.
- Community profiles (`Customer Community Login User`, `DCCA BREG - CustomerCommunity*`, `Subscriber Login`) enable `Mass_Delete_Account`, `Mass_Delete_Case`, `Mass_Delete_Contact` and similar. Those pages use `classes/MassDeleteExtension.cls:16-19` (`delete setCon.getSelected();`), where DML ignores the profile's missing Delete permission.
- `classes/BatchSummaryPDF.cls` (`without sharing`, VF) renders transaction batches on a page enabled for guests.

**Attack scenario / Impact:** This multiplies every other finding. Each extra class or page is attack surface an anonymous user doesn't need. Some pages, such as `PaymentCutOffBatchController.yes()` (`:81`), start batch jobs; most are blocked for guests only incidentally, because the guest has no object permission.

**Recommendation**
1. Rebuild the guest profiles from a clean Guest profile.
2. Grant only the classes and pages that the public LWCs and VF pages actually use, via permission sets, and audit with the Guest User Access Report.
3. Remove `Mass_Delete_*` from external profiles.

**Effort:** M

---

### [HIGH] ID S-14: Systemic sharing and CRUD/FLS gaps across user-facing controllers
**Confidence:** Confirmed (static count).

**Evidence** (non-test classes, counts from automated scan, verified by sampling):

| Metric | Count |
|---|---|
| Non-test classes (excluding interfaces) | 724: `with` 264, `without` 128, `inherited` 40, **none 292** |
| Entry-point classes (Aura, REST, VF controller, webservice) | 176: without 52, none 64, with 59, inherited 1 |
| `@AuraEnabled` classes / methods | 97 / 335 |
| Aura classes with **any** CRUD/FLS enforcement | **8** (8.2%): BREGEditEntityButtonController, BREGPortalUtils, CATV_AccessRequestController, CATV_DashboardController, CustomCommunityRegistrationController, CustomRecordCreate, GenericCreatePaymentCtrl, tkt_TicketController. Even these apply it to only 1–8 queries each. |
| Aura classes doing DML without any enforcement | 43 of 50 |
| Guest-reachable entry-point classes | 73: **36 `without sharing`**, 21 none, 16 with. 4 have any FLS token. |
| Enforcement tokens across the whole codebase | 39, versus about 690 DML statements and 1,328 queries |

Examples of `without sharing` controllers that need no elevation: `BREGHelpCenterController` (Knowledge read), `BREGAnnualsController`, `BREGAccountAffiliationController`, `BREGSearchAndBuyController`. Appendix B lists all 52.

**Attack scenario / Impact:** Internal least-privilege (FLS on SSN/EIN/DOB fields, investigation data, payment data) is not honoured anywhere Apex is used. Any controller mistake immediately becomes cross-tenant data access.

**Recommendation**
1. Adopt a baseline: `public with sharing` (or `inherited sharing`) on every class; `WITH USER_MODE` on SOQL; `insert as user` / `Database.insert(recs, AccessLevel.USER_MODE)` on DML.
2. Isolate required elevation in small `*SystemMode` helpers with fixed queries.
3. Add PMD rules to CI (`ApexCRUDViolation`, `ApexSharingViolations`, `ApexSOQLInjection`) and fail the build on new violations.

**Effort:** XL (programme); S per class.

---

### [HIGH] ID S-15: Integration credentials stored in plaintext custom metadata, settings and objects instead of Named/External Credentials
**Confidence:** Confirmed (metadata and code).

**Evidence**
- `classes/TaxClearanceApiHelper.cls:106-116` builds Basic auth from a custom setting:
  ```apex
  TaxClearanceApi__c apiConfig = TaxClearanceApi__c.getOrgDefaults();
  Blob usernamePass = Blob.valueOf(apiConfig.Username__c + ':' + apiConfig.Password__c);
  req.setEndpoint(apiConfig.EndpointUrl__c);
  req.setHeader('Authorization', basicAuth);
  ```
- `classes/SpringCMConnector.cls:32` (`params.put('client_secret', api.Client_Secret__c)`), `:207` (endpoint from CMT `API_URL__c`). `classes/SpringCMApiManager.cls:54-149` sets `'oauth '+AccessToken` headers.
- `classes/DocuSignCallbackController.cls:23-44` puts `client_secret` in the POST body; the token endpoint comes from CMT.
- `classes/DocusignAuthProvider.cls:97,140` and `classes/DocuSignJWT.cls:75-77` load the RSA private key from `breg_DocuSign_Auth__mdt.Request_Private_Key__c`.
- `classes/QualCalloutService.cls:54-56` sends the `X-API-TOKEN` header from a custom setting.
- Tokens persisted in a data object: `objects/SpringCLM_Session__c/fields/AccessToken__c`, `RefreshToken__c`.
- Plaintext user secrets: `objects/PVL_Portal_User__c/fields/ProviderSchoolPassword__c` (Text), `SecretQuestion__c`, `SecretAnswer__c`.
- Good practice already present for comparison: `BREGAmazonSesEmailService` (`callout:Amazon_SES`), `IMLCCConnector` (`callout:IMLCC`), `OracleGLBatchloadFlowService` (`callout:OracleGL`), `sc_AppMetaDataManagement` (`callout:UI_API_Credentials`).

**Attack scenario / Impact:** These values are readable by any Apex path that queries them (S-01, S-11), by admins, and in sandbox refreshes. Secrets never rotate independently of data, and plaintext portal passwords and secret answers are exposed to anyone with read access to `PVL_Portal_User__c`.

**Recommendation**
1. Migrate SpringCM, DocuSign (JWT with certificate in Certificate and Key Management), Tax Clearance and Qualtrics to Named Credentials with External Credentials. Callouts then become `callout:TaxClearance/...` with no header code.
2. Delete `SpringCLM_Session__c` token storage; the Named Credential manages refresh.
3. Drop `ProviderSchoolPassword__c` and `SecretAnswer__c`, or at minimum make them Shield-encrypted and never readable. Migrate these users to Salesforce Identity.

**Effort:** L

---

### [HIGH] ID S-16: Tokens, session IDs, secret-bearing records and PII written to debug logs
**Confidence:** Confirmed.

**Evidence**
- `classes/SpringCMConnector.cls:203` `System.debug('token: ' + token);`
- `classes/SpringCMApiManager.cls:28` `System.debug(apiEnvironment);`. This is the whole `SpringCLMSetting__mdt` record, including `Client_Secret__c`. `:166` logs the request body on 401.
- `classes/SpringCMRestHelper.cls:7,19` `System.debug(UserInfo.getSessionId());`
- `classes/CustomCommunityRegistrationController.cls:74-77` logs the query, first name, email and contacts.
- `classes/sc_ApplicationController.cls:72` and `classes/sc_FormBuilderController.cls:28` log full application form answers.
- `classes/BREGRegistrationFormController.cls:41-241` logs members, stocks, cases and affiliations (officer names and addresses).
- `classes/CreateTransaction.cls:42-43`, `classes/BREGCreateTransaction.cls:48-49` (amounts).
- Response bodies logged: `DocuSignAPI.cls:288,324,342`, `BREGAmazonSesQueueable.cls:131`, `OracleGLBatchloadFlowService.cls:124` (GL CSV), `CreateRecordCont.cls:63`.
- 525 `System.debug` statements in total across non-test classes.

**Attack scenario / Impact:** Anyone with "View All Data" or debug-log access, including support vendors and admins in every sandbox, can harvest bearer tokens, session IDs and the client secret. Session IDs in logs allow session hijack of the running user. Guest-site debug logs (set up while troubleshooting the portals) capture citizen PII.

**Recommendation**
1. Remove all logging of credentials, session IDs and full records.
2. Introduce a logger that redacts known sensitive keys and is off by default (the `CustomLogger` / `CustomLogLevelSettings__c` framework already exists; route through it).
3. Add a PMD `AvoidDebugStatements` rule for production classes.

**Effort:** S

---

### [HIGH] ID S-17: Guest / portal flows expose other citizens' data through unbounded search and oracles
**Confidence:** Confirmed.

**Evidence**
- `classes/BREGSearchAndBuyController.cls:67` `Integer queryLimit = searchInputs.queryLimit != null ? searchInputs.queryLimit : DEFAULT_QUERY_LIMIT;` accepts any client limit (`:236`, `:542`). Values are bound, so this is a scraping risk, not injection.
- `classes/SEBSearchController.cls:11-42`: an empty term matches everything, and `pageSize` has no upper bound.
- `classes/CustomCommunityRegistrationController.cls:132` (`nameFuzzy = '%' + accountName + '%'`) and `:71` (`Email LIKE :email` with client wildcards) enumerate Accounts and Contacts.
- `classes/BREGContactControllerWithoutSharing.cls:29-60` `findExistingContact` is an existence oracle on Contacts, returning the Id.
- `classes/CATV_SelfRegistrationController.cls:21-58` returns distinct messages, so user enumeration is possible.
- `classes/BREGHelpCenterController.cls:34-45` (`without sharing`) filters only `PublishStatus = 'Online'`, not channel visibility (`IsVisibleInPkb`). Internal-only Knowledge articles are returned to guests.

**Attack scenario / Impact:** Bulk harvesting of registrant, officer and agent data and contact identities, beyond what the public-records design intends. Enumeration also helps the IDOR attacks in S-05 and S-09.

**Recommendation**
1. Clamp `queryLimit` and `pageSize` server-side (for example `Math.min(x, 50)`) and escape `%` and `_` in LIKE input.
2. Require a minimum search length.
3. Return uniform responses from registration flows.
4. Add `AND IsVisibleInPkb = true` for guest Knowledge queries, and rate-limit using a Platform Cache counter per IP or session.

**Effort:** S

---

### [HIGH] ID S-18: DocuSign/SpringCM OAuth callback lacks `state` (login CSRF / token binding) and reflects provider errors
**Confidence:** Likely.

**Evidence**
- `classes/DocuSignCallbackController.cls:7-11` reads `code` and `error` from URL parameters. No `state` is generated or validated, and the code is POSTed un-encoded (`:40` `'&code=' + code`).
- `:57-59` stores the resulting tokens as **org-wide** integration tokens (`SpringCMConnector.cacheSession(...)`, `saveToken()`).
- `:63` `message = 'Error getting access token: ' + res.getBody();` and `:66` `'Error: ' + e.getMessage()` are rendered on `pages/docucallback.page` (`{!error}`, `{!message}`).

**Attack scenario / Impact:** An attacker who gets an admin to open `/apex/docucallback?code=<attacker's code>` binds the org's document integration to the **attacker's** SpringCM account. Generated government documents then flow to the attacker. Token-endpoint error bodies are also shown to the user.

**Recommendation**
1. Generate a random `state`, store it in Platform Cache or the session, and verify it on return.
2. URL-encode `code`.
3. Restrict page access to one integration-admin permission set.
4. Better still, replace this flow with a Named Credential / Auth Provider, which handles `state` natively.

**Effort:** S

---

### [MEDIUM] ID S-19: Exception messages and stack traces returned to guest and portal clients
**Confidence:** Confirmed.

**Evidence**
- Stack traces returned to the client:
  - `classes/BREGSearchAndBuyController.cls:149` `throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString());` (BREG guest)
  - `classes/BREGBusinessDetailsController.cls:90` (BREG guest)
  - `classes/BREGMyDashboardController.cls:16,78`
  - `classes/GroupTransactions2.cls:104` (`ex.getMessage() + ex.getStackTraceString()`, guest)
- Raw `e.getMessage()` to the client: at least 55 sites in 24 classes, including `PaymentREST.cls:61`, `TransactionREST.cls:119`, `CustomRecordCreate.cls:116`, `BREGPaymentController.cls:13-337` (every method), `BREGRegistrationFormController.cls:266-275` (DML messages), `LookupService.cls:28`, `PaymentCutOffBatchController.cls:91-96` (type, message and line number).

**Attack scenario / Impact:** Leaks class and method names, line numbers, field API names, validation-rule text and query fragments. This makes it much faster to develop the SOQL injections in S-07 and to map the mass-assignment attacks in S-05 and S-08.

**Recommendation**
1. Log the full exception server-side through `CustomLogger` with a correlation Id.
2. Throw `new AuraHandledException('Something went wrong (ref ' + correlationId + ')')`.
3. For REST, return a fixed error JSON.

**Effort:** S

---

### [MEDIUM] ID S-20: Apex REST resources rely on platform login only; missing server-side authorization and weak caller verification
**Confidence:** Confirmed (code). No guest profile grants these classes except PaymentREST and TransactionREST (S-04).

**Evidence** (14 `@RestResource` classes; full matrix in Appendix F):
- `classes/BREGExternalAPIUploadDocument.cls` (`/api/uploadBregDocument2`, `with sharing`) takes `IsPublic` from the request body (`:70`) and clones any readable `breg_Document__c` with caller-supplied content.
  - The publish permission (`BREG_Publish_Documents`) is only *reported* to the client by `BREGExternalAPIGetUserPermissions`. The upload endpoint never calls `FeatureManagement.checkPermission`.
  - Any `BREG_Standard_User` can therefore publish a forged public document.
- `classes/BREGExternalAPIGetDocument.cls:34` (`/api/getBregDocument`) returns any document's DocuSign content by Id, using the integration's system credentials. It doesn't check `breg_Is_Public__c` or the record's sharing beyond the SOQL row.
- `classes/BREGExternalAPIUploadScannedDocument.cls:99` elevates through `BREGSObjectUpdaterWithoutSharing` to update Case and `breg_Annual__c`. `queueName` from the request goes unsanitised into the DocuSign folder path (`classes/DocuSignAPI.cls:127`).
- `classes/PVLApplicationStatusCheckResource.cls` (`/pvl/application-status/v1/individual/status-check`) authenticates the *subject* only by phone number plus SSN last-4 (10,000 combinations) and has no attempt limiting in code.
- `classes/LicenseSearchREST.cls` (`/licenseSearch`, `without sharing`) uses a username allow-list in `License_REST_API_Setting__mdt` (`:35-49`), which is the one resource with explicit authorization. It returns licensee email, phone and addresses (`:70-77`) and echoes `ex.getMessage()` (`:297`).
- `classes/PVL_EncodingService.cls:3-17` (`/Encoding` GET, no sharing keyword) is an encryption oracle for Digital Form tokens (see S-10). Access: Admin, Google Integration User, Wordpress Administrator.
- Most BREG endpoints echo `ex.getMessage()` in the response body (GetDocument `:41,51,60`; UpdateScannerStatus `:50`; UploadDocument `:62,88,97`; UploadScannedDocument `:52,84`).
- `classes/BREGExternalAPIGetGoodStandingStatus.cls` (`without sharing`) throws an NPE on a null body. Its data is public.

**Attack scenario / Impact:** A compromised or low-privilege BREG staff or integration account can publish forged "public" certificates and documents, or pull any document from DocuSign. An IVR caller who knows a licensee's phone number can brute-force SSN last-4 to learn application status, and a hit confirms the SSN digits.

**Recommendation**
1. Enforce `FeatureManagement.checkPermission('BREG_Publish_Documents')` server-side before honouring `IsPublic`.
2. Check `breg_Is_Public__c` or `UserRecordAccess` before returning a document.
3. Throttle PVL status checks per phone number and caller-ID using Platform Cache counters, and lock out after N failures.
4. Sanitise folder path segments.
5. Return fixed error bodies.

**Effort:** M

---

### [MEDIUM] ID S-21: Visualforce `escape="false"` on user-influenced data (PDF HTML injection) and one DOM-XSS candidate
**Confidence:** Likely. Browser XSS was not confirmed; PDF injection was confirmed.

**Evidence**
- **192** `escape="false"` occurrences: 57 in 21 pages and 135 in 39 components. Every host page is `renderAs="PDF"` or msword (`WordDocument.page`), or is a site error page that outputs only `$Label.site.*`. **None is a browser XSS.**
- User-influenced values rendered unescaped into guest-reachable PDFs:
  - `pages/BatchSummaryPDF.page:7` `<apex:outputText value="{!trans}" escape="false"/>`. The content comes from attacker-chosen fields (S-07).
  - `pages/TransactionPaymentReceiptPdf.page:153` `{!transtn.Description__c}`. The description can be set by the unauthenticated `TransactionREST`.
  - `components/OnlineRenewalCopy.component:180` `{!app.OnlineRenewalAnswers__c}` and `components/OnlineRenewalAddress.component:10-83` (applicant-entered portal data; the pages are enabled for the PaymentConnect guest).
  - `components/JV.component:133` and `components/TDR.component:219` (internal remarks).
- DOM-XSS candidate: `pages/FilingOverride.page:3-4,17` does `var franchiseName = "{!overrideDesc}";` followed by `jQuery(this).html(franchiseName)`. HTML-encoding by VF does not stop `<…` JS escapes from turning into markup under `.html()`. The source is `Filing__r.Name`, assembled as HTML in `classes/Franchise_CheckoutController.cls:11,37,54` (`without sharing`, `pid` URL parameter). The page isn't granted to guest profiles.
- Safe: `pages/BREG_CompanyInfoPdf.page:9` (`{!pdfHtml}`; builder escapes every value); `$CurrentPage.parameters` are used only in `language=` / boolean contexts; there are no iframes; `startURL` handling (`SiteLoginController.cls:9`, `CommunitiesLoginController.cls:10`, `LightningLoginFormController.cls:8-11`, `CommunitiesSelfRegController.cls:118`) is validated by the platform. **No open redirect via `new PageReference(param)` was found.**

**Attack scenario / Impact:**
- Anonymous users can inject HTML into official-looking receipts and renewal PDFs (content spoofing, phishing letters on DCCA letterhead).
- If `Filing__c.Name` can be influenced by a franchise filer, script can run in internal users' sessions on `FilingOverride`.

**Recommendation**
1. Remove `escape="false"` unless the value is built server-side with `String.escapeHtml4()` on every interpolated field.
2. In `FilingOverride.page` use `{!JSENCODE(overrideDesc)}` and `.text()` instead of `.html()`.
3. Build HTML fragments in Apex only from escaped values.

**Effort:** S

---

### [MEDIUM] ID S-22: Salesforce session ID forwarded to a third party (SpringCM) and a global `webservice` surface
**Confidence:** Confirmed.

**Evidence**
- `classes/InvocableSpringCMDocGen.cls:30` `SpringCMRestHelper.startWorkflow('InvocableDocGen', w.getXmlString(), UserInfo.getSessionId());`. The running user's full-privilege Salesforce session is sent to SpringCM so it can call back. This class is granted to the `dcca Profile` guest and is invoked from flows.
- `classes/SpringCMRestHelper.cls:26-40` exposes `webservice static StartWorkflow(...)` and `StartWorkflowWithRecordType(...)` (SOAP API; any API-enabled user) that take `sId` from the caller.

**Attack scenario / Impact:** A compromised or malicious SpringCM tenant, or anyone with access to its workflow logs, gets live Salesforce sessions for internal users, and potentially the guest user.

**Recommendation**
1. Use the SpringCM EOS / Salesforce connector with an OAuth connected app instead of forwarding session IDs.
2. Remove the `webservice` methods if they are unused (check for callers outside Salesforce).

**Effort:** M

---

### [MEDIUM] ID S-23: Remote Site Settings permit callouts to a request bin, a raw IP and plaintext HTTP hosts
**Confidence:** Confirmed (metadata).

**Evidence:** `remoteSiteSettings/*.remoteSite-meta.xml` include:
- `https://eod2cgfefmvt6uf.m.pipedream.net` (request-inspection bin, `test.remoteSite`)
- `http://44.232.202.215` (`WordpressSiteTestServer`)
- `http://icanhazip.com`
- `http://barcodes4.me`, used by `classes/DocGeneratorDataSourceDomain.cls:100`: `'http://barcodes4.me/barcode/c39/'` over plaintext HTTP.

Combined with the arbitrary-URL callouts in S-02 and S-12 (`SpringCMConnector`, `FileDetailCreatorController`, `CATV_DashboardController`), these give an attacker ready-made exfiltration sinks for the org's bearer tokens.

**Recommendation**
1. Delete the test and bin entries. Require HTTPS.
2. Move remaining endpoints to Named Credentials, which also removes the need for Remote Site Settings.

**Effort:** S

---

### [MEDIUM] ID S-24: Hard-coded record IDs, environment-specific endpoints and profile-name authorization
**Confidence:** Confirmed.

**Evidence**
- Record type Id literals: `classes/NewTransaction.cls:179` and `classes/GroupTransactions2.cls:259` `'012t0000000PLy1AAG'`. Literal record Ids at `classes/PVL_SC_GeneratePicklistValues.cls:22-23` `'a3dHv0000000CDYIA2'`, `'a3dHv0000000CDZIA2'`.
- 46 custom labels hold record Ids: 24 RecordType, 18 custom-object, 3 User, 1 Account. They include `CustomRegistrationAccountOwner` / `UserIdForGenericCreatePayment` = `005t00000022GqI` (owner of all guest-created Accounts and Contacts, `CustomCommunityRegistrationController.cls:199,236`), `SEC_Staff_Account_ID` = `001t000000FKv0RAAT` and `Wordpress_Integration_User_ID`. Some are **sandbox** Ids (`012cs00000JA6k…`), so behaviour differs by environment.
- UAT or dummy endpoints in production code:
  - `classes/SpringCMConnector.cls:399` `'https://apiuatna11.springcm.com/v2/folders?search='`
  - `:435` `'https://test.salesfor.com'`
  - `classes/DocuSignAPI.cls:587` and `classes/BREGUtils.cls:1252` `'https://uatna11.springcm.com/atlas/workflow/…'`
  - `classes/CATV_DashboardController.cls:102` `'https://test.com'`
- Authorization by profile **name**:
  - `classes/TransactionPreventDeletion.cls:12` and `TransactionLinePreventDeletion.cls:18` (`Name='System Administrator'`)
  - `classes/FilingService.cls:19-24` exempts `'DCCA BREG - CustomerCommunityLogin'` (a community profile) from the filing-edit restriction
  - `classes/AccountDomain.cls:40-44` treats any profile whose name contains `form` or `Digital` (which includes the **Digital Form guest profile**) like PVL staff
  - Magic contact name `classes/BREGPaymentController.cls:1418` `WHERE Name = 'BREG Portal Guest User Contact'`

**Attack scenario / Impact:** Authorization bypass if a profile is renamed or cloned (for example a clone named "Digital Forms Clerk" gains PVL bypass). Broken behaviour after sandbox refresh, and callouts to UAT from production.

**Recommendation**
1. Resolve record types with `Schema.SObjectType.X.getRecordTypeInfosByDeveloperName()`.
2. Move owners and Ids to CMT keyed by DeveloperName, or better, query by unique name.
3. Replace profile-name checks with Custom Permissions (`FeatureManagement.checkPermission`).
4. Move endpoints to Named Credentials.

**Effort:** M

---

### [MEDIUM] ID S-25: RSA private key committed in test classes
**Confidence:** Unverified. Test-only code, but the key material is real PEM-format RSA.

**Evidence:** `classes/DocuSignJWTTest.cls:3-4` `RSA_PRIVATE_KEY = 'MIIE****'…` and `classes/DocusignAuthProviderTest.cls:133` (the same key, used as `Request_Private_Key__c`).

**Attack scenario / Impact:** If this is, or ever was, the key registered with the DocuSign integration key, then anyone with repo access can impersonate the DocuSign integration user.

**Recommendation**
1. Compare it with the DocuSign app's public key. If it matches, rotate immediately.
2. Replace it with a key generated at test time, or a clearly synthetic fixture.
3. Add secret scanning (gitleaks / trufflehog) to CI.

**Effort:** S

---

### [MEDIUM] ID S-26: Self-registration controllers create orphan accounts and pass an unvalidated `startURL`
**Confidence:** Likely.

**Evidence**
- `classes/CommunitiesSelfRegController.cls` (`without sharing`; `CommunitiesSelfReg` page enabled on 9 external profiles):
  - `:5` hard-codes profile `'DCCA BREG - CustomerCommunityUser'`
  - `:52` inserts a Person Account *before* user creation succeeds, so an Account is orphaned on every failure
  - `:80` logs the email
  - `:118` `Site.login(..., startURL)` uses the request parameter unchecked
- `classes/CATV_SelfRegistrationController.cls:35-49` overwrites an existing CATV Contact's name, phone and `Type__c` if the email matches and no User exists (`without sharing`, guest).

**Attack scenario / Impact:** Unauthenticated junk-account creation (data pollution and storage DoS). Tampering with staff-visible contact records. `startURL` limits redirects to the site's domain, but it should still be allow-listed.

**Recommendation**
1. Use `Site.createExternalUser(u, accountId, password, sendEmail)` inside a savepoint and roll back on failure.
2. Never overwrite existing Contacts from unauthenticated input; create an access-request record instead.
3. Validate that `startURL` starts with `/` and not `//`.

**Effort:** S

---

### [LOW] ID S-27: SOSL built with `escapeSingleQuotes` only; SOSL reserved characters are not escaped
**Confidence:** Confirmed.

**Evidence:** `classes/BREGNameClearanceController.cls:195-234,1051` (`escapedTerm = String.escapeSingleQuotes(normalizedSearchTerm)`, then `'FIND \'' + soslSearch + '\' IN ALL FIELDS …'`). `classes/InputLookupAuraController.cls:128`.

**Impact:** Only the search-expression semantics can be manipulated, for example forcing wildcards or OR terms. There is no break-out beyond `FIND`. It can still cause `SearchException` errors (noise) or over-broad matches.

**Recommendation:** Escape the SOSL reserved set `? & | ! { } [ ] ( ) ^ ~ * : \ " ' + -` with a helper, or use `Search.find` with a bound term.

**Effort:** S

---

### [LOW] ID S-28: Weak hashing used for integrity/dedup (MD5)
**Confidence:** Confirmed.

**Evidence:** `classes/BREGUtils.cls:1483` `Crypto.generateDigest('MD5', targetBlob)`; `classes/DocuSignAPI.cls:444` (MD5 hex of document blobs).

**Impact:** Low; these appear to be change-detection hashes, not security controls. They should not be used to verify document authenticity.

**Recommendation:** Use `SHA-256`.

**Effort:** S

---

### [LOW] ID S-29: Triggers and handlers run in system mode with implicit (none) sharing
**Confidence:** Confirmed.

**Evidence:**
- 6 of 61 triggers hold inline SOQL/DML (`triggers/PVLProcessTrigger.trigger`: 264 lines, `EarnedCETrigger.trigger`: 123, `PaymentTrigger.trigger`: 73, …).
- Most handlers are `without sharing` or have no keyword: `BREGCaseTriggerHandler`, `BREGTransactionLineTriggerHandler`, `TransactionHandler`, `PaymentAllHandler`.
- These handlers run under the guest user when guests perform DML (S-03, S-05, S-08). They amplify guest writes, for example COGS creation and DocuSign workflow enqueueing.

**Recommendation:** Move trigger logic into handlers. Declare `inherited sharing` where no elevation is needed. Add guest-user guards (`UserInfo.getUserType() == 'Guest'`) for side-effecting automation such as workflow enqueueing.

**Effort:** M

---

### [LOW] ID S-30: Business-logic bugs in security-adjacent code
**Confidence:** Confirmed.

**Evidence:**
- `classes/CATV_AccessRequestController.cls:21` runs `String.escapeSingleQuotes` over a whole JSON payload before parsing. This corrupts valid JSON and shows `escapeSingleQuotes` being misused as generic sanitisation.
- `classes/CATV_CustomLookUpController.cls:18` does the same on `selectedOrg`.
- `classes/BREGEntityListBuilderController.cls:104` escapes the zip list *before* splitting, but the quotes are then added around the escaped items. Harmless, but it indicates copy-paste sanitisation.

**Recommendation:** Validate by type, not by escaping; use binds.

**Effort:** S

---

## Appendix

### A. Dynamic SOQL/SOSL sites (235 call sites in non-test classes)

**A.1 Injectable: client-controlled input concatenated (30 sites)**

| File:line | Entry point / reachability | Verdict |
|---|---|---|
| classes/sc_LookupController.cls:14 | Aura, Digital Form **guest** | Injectable (object, fields, WHERE) |
| classes/LookUpController.cls:13 | Aura, community + internal | Injectable (object, fields, WHERE) |
| classes/FilingController.cls:5 | Aura, pre-payment/securities/transcripts **guest**, community | Injectable (object, fields) |
| classes/ListViewController.cls:17 | Aura, community + internal | Injectable (object, fields, ORDER BY) |
| classes/RelatedListController.cls:60 | Aura, community + internal | Injectable (object, fields, WHERE, ORDER BY) |
| classes/RelatedListTreeViewerController.cls:146 | Aura, community + internal | Injectable (object/relationship names) |
| classes/LookupService.cls:22,24 | Aura, internal | Injectable (SOSL term, object, fields, condition) |
| classes/InputLookupAuraController.cls:52,128 | Aura, guest (sharing-limited) | Injectable (object, fields, filter) |
| classes/CATV_CustomLookUpController.cls:22→CATV_WithoutSharingUtility.cls:51 | Aura, CATV **guest**, SYSTEM_MODE | Injectable (WHERE field) |
| classes/GenericCreatePaymentCtrl.cls:592,595 (built at :547-569) | Aura, **guest**, without sharing | Injectable (LIKE values) |
| classes/CustomCommunityRegistrationController.cls:162 (built at :160) | Aura, **guest**, without sharing | Injectable (record type name) |
| classes/BREGEntityListBuilderController.cls:87 (built at :109,120,123) | Aura, BREG **guest**, without sharing | Injectable (IN list, dates) |
| classes/BREGEntityListBuilderBatch.cls:38 | Batch re-executing stored guest input | Second-order injectable |
| classes/GroupTransactions2.cls:158,236,245 | Aura, **guest** | Injectable (LIKE values) |
| classes/NewTransaction.cls:155,165 | Aura, **guest** | Injectable (LIKE values) |
| classes/BatchTransaction.cls:368,379,469 | Aura, **guest** | Injectable (field names, values, select list) |
| classes/CustomPaymentButtonController.cls:26 | Aura, **guest**, without sharing | Injectable (field name) |
| classes/CustomUploadButtonController.cls:26 | Aura, **guest**, without sharing | Injectable (field name) |
| classes/FileDetailCreatorController.cls:78 | Aura, **guest** | Injectable (field name) |
| classes/CATV_DashboardController.cls:137 | Aura, CATV community | Injectable (object name) |
| classes/BREGGetFeeForService.cls:150 | Aura, BREG **guest** | Partially injectable (SELECT list, ORDER BY not allow-listed; values escaped) |
| classes/BatchSummaryPDF.cls:60 | VF, pre-payment/securities/transcripts **guest**, without sharing | Injectable (SELECT list from URL parameter) |

**A.2 Safe: bind variables or escaped values; identifiers are constants (reviewed)**

AccountRecordsSearchCreate.cls:78,142; BREGAgentSearchController.cls:66; BREGBigObjectRelatedListController.cls:131; BREGExternalAPISearchBusinesses.cls:124,129 (see REST addendum); BREGHelpCenterController.cls:45; BREGNameClearanceController.cls:185,687,715,735,751 (SOSL :234,1051, see S-27); BREGPaymentController.cls:151 (escaped values from DB); BREGPortalUtils.cls:108 (`WITH USER_MODE`, binds); BREGSearchAndBuyController.cls:237,298,364,432,543,574,599,646 (binds; limit Integer, see S-17); CEPassCertificateController.cls:60; CTCheckoutFormController.cls:120; CustomCommunityRegistrationController.cls:73 (binds, but client wildcards, see S-17); CustomRecordCreate.cls:495-496; FiscalFormsController.cls:200; TDRFormController.cls:266; RenewalNotification*Controller (4 classes); RunReconciliationBatchController.cls:43 (Id-typed); SecurityPortalTransactionsHelper.cls:49; SpringCMConnector.cls:251,290,297 (bound Id; object from Id prefix); CATV_DashboardController.cls:72,81 (Id-typed); util_closer_LogViewerController.cls:99-463 (admin-only permission set; typed filters).

**A.3 Internal: batch, scheduler, selector or trigger code; query built from constants, config or CMT (155 sites in 117 classes; no user input path found)**

AMDInactivationBatch, AgeDaysSumCalculator, ApplicationRenewalPushThru, ApplicationSelector, AssociatedInsuranceSuspenseBatch, AssociatedLicenseExpire, AssociatedLicenseSelector (5), AssociatedLicensesStatusUpdate, AsyncCompletePaymentsDeposit (2), AttestToMailingNoticesBatch, BREGAccountAffiliationTriggerHandler, BREGAccountStatus2DissolutionBatch, BREGAnnualRobotValidationBatch, BREGAnnualRollOverJob, BREGBackfill*Batch (2), BREGBatch, BREGCaseHistoryBatch, BREGCaseStatusHandler* (4), BREGCleanTestAnnualsAndRunRolloverJob, BREGDelinquencyStatusUpdateBatchJob, BREGDocumentPublicVisibilityBatch, BREGDocumentTriggerHandler, BREGDocusignTemplatesUpdateBatch, BREGEntityListWeeklyJob, BREGR7ExpirationBatch, BREGSObjectUpdaterWithoutSharing (generic `selectRecordsByQuery(String)` sink; callers pass constants, but it is a dangerous helper), BREGTNTMSMExpirationBatch, BREGTransactionUtils (2), BREGWebDataItemMapper, BREGWebFilingMapperInvocable, BatchChargeBack, BatchFlagLicense* (2), BatchLicenseResetAudit, BatchUpdateActiveEmployeeLicenseNum, CaseSharesSelector, CaseTeamAssignmentsSelector (2), CaseTeamMembersSelector, CleanRenewApplicationJob, ClearAuditInformation, CollectionAgencyRenewal (2), ContractorRenewalPushThrough, CourseStatusUpdateBatch, CtEntitySolePrmePushThroughBatch, CtRmePushThroughBatch, D1D2DependencyRefundNotice, DCCAFeeScheduleBatch, DeleteUnPaidAppsBatch, DepositRollupsBatch, DocGeneratorDataSourceDomain (4), DocumentGeneratorProcessBatch, EmailAlertTriggersSelector, EmailTemplatesSelector, EmployeeLicenseStatus, FixRequirementBatch, ForfeitureLicense, GenerateListBuilderPayment, GeneratePostCardBatch, GenerateRenewalApplicationBatch, GenerateRenewalNotificationBatch, GenerateSubscriberPayment, IMLCCSendEmailQueueable (2), Insurance*Batch (4), Investigation*Batch (2), LicenseConditionOverdueFinderScheduler, LicenseCurrentAndValidFinderScheduler, LicenseEmployerAddressUpdateBatch, LicenseExpire, LicenseRMELoseBatch, LicenseSelector, LicenseTermination, LicenseType* (4), LicenseUpdateStatusScheduler, MVRRenewalPushThruBatch, MassageTherapyRenewal, Notification*DeletionBatch (2), PVLErrorHandlerBatch, PVL_ListBuilderFile*BatchJob (3), PVL_MassEmailBatch, PVL_PDFGenerator (3), PVL_Selector (17; `String.format` with caller-supplied `filterCriteria`, where callers are batch constants. Treat it as a latent sink), PaymentAllocateTransactionLinesBatch, PaymentAutoCloserBatch, PaymentXBatch, PersonAccountInvalidAddressFinder, PublicGroupMembershipBatch, QualCalloutQueueable, QualCaseTriggerHandler, RealEstate*Batch (2), ReconciliationBatchJob, SEBCasePenaltyBatch, ScheduledClearEarnedCEBatch, ScheduledGenerateFiles, SendLetterToPrinterBatchJob, StatusHistoryAux, SuspenseSelector, TaxClearanceCheckBatch, TransactionService, UserRecordAccessSelector, fflib_SObjectSelector (2), util_closer_CaseDataAccess (6), util_closer_CaseStatusBatch (2).

### B. `without sharing` classes with exposed entry points (52)

Columns: class | entry type (Aura method count / REST / VF) | DML statements | guest principals | community principals.

**B.1 Reachable by guest principals (36)**

| Class | Entry | DML | Guest | Community |
|---|---|---|---|---|
| ApplicationLicenseValidatorController | aura:1 | 0 | Digital Form | – |
| BatchSummaryPDF | VF | 0 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| BREGAccountAffiliationController | aura:4 | 0 | BREG Profile, BREG_Site_Guest_User | BREG community ×3, BREG_Portal_User |
| BREGAgentSearchController | aura:3 | 1 | BREG_Site_Guest_User | BREG_Portal_User |
| BREGAnnualsController | aura:4 | 0 | BREG Profile, BREG_Site_Guest_User | BREG community ×3 |
| BREGBusinessDetailsController | aura:3 | 1 | BREG Profile, BREG_Site_Guest_User | BREG community ×3 |
| BREGCaseControllerWithoutSharing | aura:4 | 3 | BREG_Site_Guest_User | BREG_Portal_User |
| BREGContactControllerWithoutSharing | aura:2 | 1 | BREG_Site_Guest_User | BREG_Portal_User |
| BREGEntityListBuilderController | aura:2 | 1 | BREG_Site_Guest_User | BREG_Portal_User |
| BREGHelpCenterController | aura:1 | 0 | BREG Profile, BREG_Site_Guest_User | BREG community ×3 |
| BREGPaymentController | aura:12 | 11 | BREG Profile, BREG_Site_Guest_User | BREG_Portal_User |
| BREGPortalUtils | aura:9 | 1 | BREG_Site_Guest_User | BREG community ×3 |
| BREGRegistrationFormController | aura:4 | 8 | BREG Profile, BREG_Site_Guest_User | BREG community ×3 |
| BREGSearchAndBuyController | aura:3 | 0 | BREG Profile, BREG_Site_Guest_User | BREG community ×3 |
| CATV_SelfRegistrationController | aura:2 | 3 | CATV Portal | – |
| CommunitiesSelfRegController | VF | 1 | pre-payment/securities/transcripts | BREG community ×3 |
| CreateTransaction | aura:4 | 3 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| CustomCommunityRegistrationController | aura:5 | 5 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| CustomPaymentButtonController | aura:1 | 0 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| CustomRecordCreate | aura:3 | 4 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| CustomUploadButtonController | aura:1 | 0 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| DisplayBPIDController | aura:2 | 0 | Digital Form | – |
| DraftApplicationDetailCont | aura:4 | 0 | Digital Form | – |
| DraftApplicationService | aura:2 | 9 | Digital Form | – |
| GenericCommunityPaymentController | aura:4 | 4 | pre-payment/securities/transcripts | – |
| GenericCreatePaymentCtrl | aura:12 | 9 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| GroupTransactionController | aura:3 | 3 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| HPEAPRequestCreate | aura:4 | 4 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| PaymentDisplayController | aura:3 | 0 | Digital Form | – |
| PaymentREST | REST /CreatePayment | 1 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |
| PVL_PaymentReceiptController | VF | 0 | PaymentConnect (page) | Customer Community Login, BREG ×3 |
| sc_ApplicationController | aura:14 | 6 | Digital Form | – |
| sc_FormBuilderController | aura:1 | 0 | Digital Form | – |
| SEBSearchController | aura:3 | 0 | dcca Profile | – |
| SpringCMConnector | aura:5 | 0 | Digital Form | BREG CustomerCommunityLogin, External_CATV_Provider/Requestor |
| TransactionREST | REST /CreateTransaction | 4 | pre-payment/securities/transcripts | BREG CustomerCommunityLogin |

"BREG community ×3" = `DCCA BREG - CustomerCommunityLogin`, `DCCA BREG - CustomerCommunityUser`, `DCCA BREG - Subscriber Login`.

**B.2 Community-only or internal (16):**
- Community (via BREG_Portal_User or CATV permission sets): BREGAccountInfoController (aura:2, dml 2), BREGCreateTransaction (aura:4, dml 4), BREGMyDashboardController (aura:3), BREGNotificationsHandler (aura:8, dml 2), CATV_WithoutSharingUtility (aura:1, dml 8), FieldUtils (aura:1; community ×4).
- VF pages reached via page access: BREGPaymentReceiptPdfController (page `BREG_PaymentReceipt` on PaymentConnect **guest**), CertificateOfInsuranceController (page on community + PaymentConnect guest), WebDocumentExt.
- Internal: Franchise_CheckoutController, PVL_ListBuilderReceiptController, PVL_Pocket_ID_PDFController, PVL_Wall_Certificate_PDFController, TransactionRefundAuthFormController.
- REST (see addendum): BREGExternalAPIGetGoodStandingStatus, LicenseSearchREST.

**B.3 No sharing keyword but guest-reachable (21):** AgeDaysSumCalculator, ApplicationDomain, BatchJobsProgress, BatchTransaction (aura:24), CEPassCertificateController (VF), CashierCodeLookup, CompletePaymentsDeposit (VF), DepositRollupsButton (VF), FileDetailCreatorController (aura:9), GroupTransactions2 (aura:14), InputLookupAuraController (aura:2), LightningLoginFormController, ManagedContentController, NewTransaction (aura:14), OnlineRenewalController (VF), PaymentAllocateBatchProgress (VF), PaymentAutoCloserMonitorController (VF), PaymentXBatchProgress (VF), RenewalNotificationController (VF), TransactionPaymentCoverSheetExtCtrl (VF), sc_LookupController (aura:1). VF entry points of these run **without** sharing; Aura entry points run with sharing.

### C. Hard-coded IDs, endpoints and names

| Location | Literal | Note |
|---|---|---|
| classes/NewTransaction.cls:179 | `012t0000000PLy1AAG` | RecordType Id |
| classes/GroupTransactions2.cls:259 | `012t0000000PLy1AAG` | RecordType Id |
| classes/PVL_SC_GeneratePicklistValues.cls:22-23 | `a3dHv0000000CDYIA2`, `a3dHv0000000CDZIA2` | custom-object record Ids |
| classes/SendTo4GovController.cls:70 | `00XQ0000000QULj` (commented) | EmailTemplate Id |
| classes/SiteRegisterController.cls:7 | `001x000xxx35tPN` | placeholder Account Id (boilerplate) |
| labels/CustomLabels.labels-meta.xml (46 labels) | 24 × `012…`, 14 × `a2x…`, 4 × `a0S…`, 3 × `005…`, 1 × `001…` | e.g. `CustomRegistrationAccountOwner`/`UserIdForGenericCreatePayment`=`005t00000022GqI`, `SEC_Staff_Account_ID`=`001t000000FKv0RAAT`, `Wordpress_Integration_User_ID`=`005t0000006Z5QTAA0`; sandbox-style `012cs00000JA6k…` present |
| labels/CustomLabels.labels-meta.xml:5263 | `CATV_EncryptionKey` = `4234****` | **secret** (S-10) |
| classes/SpringCMConnector.cls:399 | `https://apiuatna11.springcm.com/v2/folders?search=` | UAT endpoint in prod code |
| classes/SpringCMConnector.cls:435 | `https://test.salesfor.com` | dummy endpoint |
| classes/DocuSignAPI.cls:587, classes/BREGUtils.cls:1252 | `https://uatna11.springcm.com/atlas/workflow/monitorworkflowactivity?aid=` | UAT URL |
| classes/CATV_DashboardController.cls:102 | `https://test.com` | dummy |
| classes/DocGeneratorDataSourceDomain.cls:100-103 | `http://barcodes4.me/...`, `https://barcode.tec-it.com/...`, `https://barcode.design/...` | third-party barcode services (data leakage of barcode content; one over HTTP) |
| classes/ApplicationLicenseValidatorController.cls:20 | `https://mypvl.dcca.hawaii.gov/public-license-search/` | benign |
| classes/BREGPaymentController.cls:256 | `.salesforce.com` → `.salesforce-sites.com` string rewrite | brittle domain derivation |
| classes/BREGPaymentController.cls:1418 | Contact `Name = 'BREG Portal Guest User Contact'` | magic record |
| classes/TransactionPreventDeletion.cls:12, TransactionLinePreventDeletion.cls:18, AccountDomain.cls:44, AccountService.cls:131, ExamService.cls:19-20, FilingService.cls:19-24, GlobalConstants.cls:6-8 | `'System Administrator'`, `'DCCA SEC/SEB System Administrator'`, `'DCCA BREG - CustomerCommunityLogin'` | profile-name authorization |
| classes/CommunitiesSelfRegController.cls:5, BREGPortalRegistrationHandler.cls:2, CATV_AccessRequestController.cls:67, CATV_InetTriggerHandler.cls:11, BREGAgentSearchController.cls:5 | community profile names | profile-name coupling |
| remoteSiteSettings/ | `https://eod2cgfefmvt6uf.m.pipedream.net`, `http://44.232.202.215`, `http://icanhazip.com`, `http://barcodes4.me` | S-23 |

### D. Callout inventory

| Class | Endpoint source | Auth | Notes |
|---|---|---|---|
| BREGAmazonSesEmailService / BREGAmazonSesQueueable | `callout:Amazon_SES` | Named Credential | OK. Response bodies logged (:131, :195-197). |
| IMLCCConnector | `callout:IMLCC` | Named Credential | OK. Payload stored in `Application_Log__c.Integration_Payload__c` (IMLCCSendEmailQueueable.cls:260-271, IMLCCQueueable.cls:407); review for PII retention. |
| OracleGLBatchloadFlowService | `callout:OracleGL/...` | Named Credential | OK. GL CSV body logged (:124). |
| sc_AppMetaDataManagement, CreateRecordCont | `callout:UI_API_Credentials` | Named Credential (loopback to own org Tooling/UI API) | Loopback with elevated credential reachable from Aura (`CreateRecordCont.getPickListValuesIntoList`); object/field path concatenated into URL. |
| QualCalloutService | Named Credential from `qual_Config__mdt` | Header `X-API-TOKEN` from custom setting | Move token into External Credential. Bodies stored in `qual_Integration_Log__c` (truncated). |
| TaxClearanceApiHelper | `TaxClearanceApi__c.EndpointUrl__c` | Basic auth from custom setting | S-15 |
| SpringCMConnector / SpringCMApiManager / SpringCMFileHelper / UploadCaseFileToDocSignQueueable | CMT `API_URL__c` and **client-supplied URLs** | Bearer token in custom object / static | S-02, S-15, S-16 |
| DocuSignAPI / DocusignAuthProvider / DocuSignJWT / DocuSignCallbackController | Named Credential prefix plus CMT token endpoint | JWT signed with CMT private key; client secret in CMT | S-01, S-15, S-18 |
| SpringCMRestHelper / InvocableSpringCMDocGen | SpringCM | Forwards `UserInfo.getSessionId()` | S-22 |

No `setClientCertificateName` (mutual TLS) is used anywhere. No callout disables certificate validation (not possible in Apex).

### E. Guest principal → class access summary

- **BREG Profile + BREG_Site_Guest_User:** 24 classes, including BREGPaymentController, BREGRegistrationFormController, BREGPortalUtils, BREGCaseControllerWithoutSharing, BREGSearchAndBuyController, BREGEntityListBuilderController, BREGBusinessDetailsController, DocuSignAPI, DocuSignJWT and DocusignAuthProvider.
- **pre-payment / securities / transcripts Profiles:** 64 classes (payment portal, cashier batch jobs, PaymentREST, TransactionREST) plus about 40 internal VF pages.
- **Digital Form Profile:** 15 classes (sc_*, DraftApplication*, SpringCMConnector, PaymentDisplayController).
- **PaymentConnect Profile:** 20 classes plus about 70 renewal-notice, receipt and certificate VF pages.
- **CATV Portal Profile:** CATV_SelfRegistrationController, CATV_CustomLookUpController.
- **dcca Profile:** SEBSearchController, ManagedContentController, InvocableSpringCMDocGen, UploadCaseFileToDocSignQueueable.

### F. Apex REST and `webservice` matrix

| Class | urlMapping / verb | Sharing | Dynamic SOQL | AuthZ beyond session | DML | Returns | Error leak | Who has access |
|---|---|---|---|---|---|---|---|---|
| PaymentREST | `/CreatePayment` POST | without | no (binds) | **none** | insert payment | status JSON | yes :61 | **3 guest profiles**, BREG community, Payment API Only, ~30 internal |
| TransactionREST | `/CreateTransaction` POST | without | no (binds) | **none** | insert Account/Transaction/Lines | status JSON | yes :119 | **3 guest profiles**, internal |
| BREGExternalAPIGetDocument | `/api/getBregDocument` GET | with | no | none (no `Is_Public` check) | – | base64 doc | yes | Admin, BREG_Standard_User |
| BREGExternalAPIGetGoodStandingStatus | `/api/getGoodStandingStatus` POST | without | no | none | – | public status | NPE | Admin, BREG_Standard_User, BREG_API |
| BREGExternalAPIGetStamps | `/api/getBregStamps` GET | with | no | user/profile scoped | – | stamp images | yes :64 | Admin, BREG_Standard_User |
| BREGExternalAPIGetUserPermissions | `/api/getBregUserPermissions` GET | with | no | FeatureManagement | – | flags | no | Admin, BREG_Standard_User |
| BREGExternalAPISearchBusinesses | `/api/searchBusinesses` POST | with | yes, all binds (safe) | none | – | names/addresses ≤2000 | no | Admin, BREG_Standard_User, BREG_API |
| BREGExternalAPIUpdateScannerStatus | `/api/updateScannerStatus` POST | with | no | none | insert staging | Id | yes :50 | Admin, BREG_Standard_User |
| BREGExternalAPIUploadDocument | `/api/uploadBregDocument2` POST | with | no | **publish permission not enforced** | insert doc, DocuSign upload | Id | yes | Admin, BREG_Standard_User |
| BREGExternalAPIUploadScannedDocument | `/api/uploadScannedDocument` POST | with (+ without-sharing updater) | no | none | insert/update Case, Annual | Id | yes | Admin, BREG_Standard_User |
| LicenseSearchREST | `/licenseSearch` POST | without | no (binds) | username allow-list CMT; RICO profile for BPID search | – | licensee PII | yes :297 | PVL/SEC staff, License API Only, RICO API |
| PVLApplicationStatusCheckResource | `/pvl/application-status/v1/individual/status-check` POST | with | no | phone + SSN last-4 (no throttling) | – | status | no | Admin, PVL_Application_Status_IVR_API |
| PVLApplicationStatusHealthResource | `/pvl/application-status/v1/health` GET | with | – | – | – | static | no | same |
| PVL_EncodingService | `/Encoding` GET | none (runs without sharing) | no | none | – | encrypted token (oracle) | unhandled | Admin, Google Integration, Wordpress Admin |
| SpringCMRestHelper (`webservice`) | SOAP `StartWorkflow*` | none | no | none | – | – | – | ~65 internal/community profiles; XML built unescaped (:75); session Id logged (:7,19,82) |

### G. Method notes and limits

- Guest and community reachability comes from profile and permission-set metadata. The permission-set *assignment* to site guest users (e.g. `BREG_Site_Guest_User`) and each Site's enabled pages and Apex REST setting are not in source control, so confirm them in Setup → Sites / Digital Experiences → Guest User Access Report.
- The FLS and sharing counts in S-14 come from a regex scan over non-test classes with comments stripped. Entry points are `@AuraEnabled static` methods, `@RestResource`, `webservice` and VF controllers/extensions referenced by `pages/` or `components/`. `@InvocableMethod` (flow-reachable) classes were not counted as entry points.
- Secrets are masked throughout (first 4 characters + `****`). No secret values from custom metadata records are in the repo (there is no `customMetadata/` folder); only the CATV key (label) and a test RSA key are present in source.
