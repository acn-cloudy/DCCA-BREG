# 03 — LWC & Aura Front End

Scope: `force-app/main/default/lwc/` (232 bundles, 284 JS files, about 55,000 LOC of JS and HTML; 6 of the JS files are generated OmniScript `_def.js`), `force-app/main/default/aura/` (147 bundles, about 25,400 LOC), JS libraries in `staticresources/`, and the 5 Visualforce pages that host Lightning Out. Method: grep and Node-script triage over every file, then close reading of the community-exposed and payment components. Every front-end call path in this report was traced into the Apex it calls, and into the profile and permission-set class access, so that exposure claims rest on evidence. ESLint was **not** run because `node_modules/` does not exist.

Cross-references: **05** = `analysis/05-access-control.md` (P-xx), **06** = `analysis/06-test-quality.md` (T-xx). The Apex report may repeat some Apex-side root causes. Here they are written from the front-end attack-surface point of view.

## Summary

- **The browser decides what the customer pays.** The BREG cart lives in `localStorage`. `breg_CheckoutPage` totals it on the client and sends `amount` plus `unitPrice`/`quantity` to `BREGPaymentController.createPayment`, which trusts both. An amount of 0 makes the payment `Completed` and the line items `Paid`. The Securities group-payment LWC has the same flaw (`totalAmount` is computed on the client). Both are on public sites.
- **A live DocuSign CLM (SpringCM) OAuth bearer token is handed to the browser.** `springFiles` and `springFileFix` do this through `SpringCMConnector.getToken()`. That class is enabled on the **guest** `Digital Form Profile` and on community profiles, so an unauthenticated visitor can obtain an org-level CLM API token.
- **Public LWCs call `without sharing` Apex with record Ids the caller controls, and nothing checks ownership.** Examples: payment confirmation by `?pid=` (billing name, email, address, card last 4), any DocuSign document by Id, delete any Case, and expedite any Case for free. The guest permission set `BREG_Site_Guest_User` grants all of these classes.
- **Generic "lookup" components send object, field and WHERE fragments from the client into dynamic SOQL.** On the public CATV self-registration page, `fieldApiName` is concatenated straight into the query and run `without sharing` (guest `CATV Portal Profile`). This is SOQL injection and Account enumeration from an unauthenticated page.
- **XSS and vulnerable libraries:**
  - `lookupSearchResult` writes record names into the page through `innerHTML` (stored XSS, internal users).
  - `aura:unescapedHtml` renders field values.
  - jQuery 2.2.4, Bootstrap 3.3.6 and typeahead 0.10.5 are loaded in Aura lookups that sit under community payment components.
- **Error handling on the payment and filing flows is fragile.** 30 Aura callbacks read `getReturnValue().x` without checking `getState()`; `GenericCreatePayment` has 11 callbacks and none handles errors. Checkout `await createPayment()` is outside any `try`. Many failures are only sent to `console.error`.
- **There are no Jest tests (0 of 232 LWCs).** About 13% of meaningful front-end lines sit in copy-pasted 6-line blocks (about 4,300 lines). There is one genuine base class, `breg_BaseFormComponent` (64 of 160 `breg_` components use it). The cart and `localStorage` logic is re-implemented in 14 components.
- **Aura migration: 147 bundles.** 16 are events or apps and 54 are easy. 40 are moderate. 37 are complex; this group includes 3 Aura theme layouts and the `sc_` form builder, which must move together.

| Severity | Count |
|---|---|
| Critical | 4 |
| High | 6 |
| Medium | 10 |
| Low | 6 |
| **Total** | **26** |

## Findings

### [CRITICAL] ID F-01: Payment amount and unit prices come from browser `localStorage` and are trusted by Apex (BREG checkout and Securities group payment)
**Confidence**: Confirmed (code path read end to end on both sides)

**Evidence**
- `lwc/breg_Shopping_Cart/breg_Shopping_Cart.js:29-31,165,267`: the cart, including `unitPrice` and `price`, is read from and written to `localStorage` (`"breg_shopping_cart"`). The price is recomputed on the client: `price: item.unitPrice * quantity`.
- `lwc/breg_CheckoutPage/breg_CheckoutPage.js:108-124`: `this.cartItems = JSON.parse(localStorage.getItem(...))`. `get totalPrice() { return this.cartItems.reduce((t, i) => t + i.price, 0) }`.
- `lwc/breg_CheckoutPage/breg_CheckoutPage.js:62-67,154`: `createPaymentAndNavigate({ amount: this.totalPrice, cartItemsJson: JSON.stringify(this.cartItems), ... })` leads to `await createPayment(details)`.
- `lwc/breg_CheckoutPage/breg_CheckoutPage.js:156-162`: if `details.amount === 0`, the component calls `updateCasesProcessingSpeed` (expedite) for every cart item whose `id` starts with `exp-fee` and `price > 0`, then jumps to `/payment-confirmation`.
- `classes/BREGPaymentController.cls:285-288` (`without sharing`): `createPayment(Double amount, String cartItemsJson, ...)` sets `String tliStatus = amount > 0 ? 'Pending' : 'Paid';`
- `BREGPaymentController.cls:368-392`: `trans.TotalAmount__c = amount; trans.Status__c = amount > 0 ? 'Pending' : 'Completed'; payment.pymt__Status__c = amount > 0 ? 'In Process' : 'Completed'; payment.pymt__Amount__c = amount;`
- `BREGPaymentController.cls:630-647`: `Decimal unitPrice = (Decimal) cartItem.get('unitPrice'); Decimal amount = unitPrice * quantity; transLineItem.Amount__c = amount;`. The unit price is taken from the client JSON, not from `breg_Fee__c`.
- `lwc/makePaymenttoMultipleFilings/makePaymenttoMultipleFilings.js:236-249` (community page): `total += parseFloat(currentItem.TotalAmount__c)` is summed on the client, then `groupTransactions({transactionIDs: ids, accId: this.accId, totalAmount: total})`. On the server, `classes/SecurityPortalTransactionsHelper.cls:88,114` sets `trans.TotalAmount__c = totalAmount; pymt.pymt__Amount__c = totalAmount;`.
- Exposure: `BREG_Site_Guest_User` and `BREG_Portal_User` permission sets enable `BREGPaymentController` and `BREGCaseControllerWithoutSharing`. `DCCA BREG - CustomerCommunityLogin` enables `SecurityPortalTransactionsHelper`. See P-02/P-04 in 05.

**Impact**: Anyone can edit `localStorage` in DevTools, or call the `@AuraEnabled` method directly, and:
- set `unitPrice: 0` / `amount: 0` to get filings, certified copies and expedite service recorded as **Paid/Completed** for free;
- underpay any fee;
- for Securities, pay one small total for a group of large transactions.

This is direct revenue loss and a record-integrity problem on a state payment portal.

**Recommendation**:
- Treat the cart only as a list of `{feeId/documentId, caseId, quantity, options}`.
- In `createPayment` and `groupTransactions`, re-derive every unit price from `breg_Fee__c`/`Transaction__c` on the server, recompute the total, and ignore `amount`, `price` and `unitPrice` from the client.
- Only set `Paid` or `Completed` when the server-computed total is 0 *and* each fee is zero-rated.
- Move the expedite flag into the same server transaction and remove the client call to `updateCasesProcessingSpeed`.
- Add Apex tests that submit a tampered cart.

**Effort**: M

---

### [CRITICAL] ID F-02: DocuSign CLM (SpringCM) OAuth access token is returned to the browser, including to guest users
**Confidence**: Confirmed (code, and the class is enabled on a Guest User License profile)

**Evidence**
- `lwc/springFiles/springFiles.js:3,72,76`: `import getAccessToken from "@salesforce/apex/SpringCMConnector.getToken"` … `this.accessToken = await getAccessToken();` … `xhReq.setRequestHeader('Authorization',"bearer " + this.accessToken);`. The browser then uploads directly to SpringCM.
- `lwc/springFileFix/springFileFix.js:3,103,110,130,191`: the same pattern. It imports `SpringCMConnector.getAccessToken`, which is **not** `@AuraEnabled` (see F-11).
- `classes/SpringCMConnector.cls:1,63-81`: `public without sharing class`. `@AuraEnabled public static String getToken() { String accessToken = getAccessToken(); saveToken(); return accessToken; }`. The token comes from the org-level SpringCM integration credentials (`initiateConnection()`).
- Consumers on community pages:
  - `aura/FileDetailCreator/FileDetailCreator.cmp:89` (`forceCommunity:availableForAllPageTypes`);
  - `aura/CustomFileDetailUploader/CustomFileDetailUploader.cmp:19`;
  - `aura/sc_FormField/sc_FormField.cmp:188,320` → `c:clmFiles` → `c-spring-files` (the `sc_` form builder is community-exposed).
- Class access: `profiles/Digital Form Profile.profile-meta.xml` (userLicense **Guest User License**) enables `SpringCMConnector`. So do `DCCA BREG - CustomerCommunityLogin`, the `External_CATV_Provider` and `External_CATV_Requestor` permission sets, and 8 internal PVL profiles.

**Impact**: Any site visitor, logged in or not, can call `SpringCMConnector.getToken` through the Aura endpoint and receive a bearer token for the DCCA SpringCM/CLM account. With it they can list, download, overwrite or delete contract and licensing documents for every record, not just their own. 05 P-17 notes that OAuth tokens are also stored in a Public R/W object.

**Recommendation**:
- Remove `getToken` from `@AuraEnabled` and **rotate the SpringCM client secret and refresh token now**.
- Upload server-side: either use a Named Credential in a Queueable/Continuation, or have Apex mint a per-upload, pre-signed, single-folder upload URL, and never return the bearer token.
- Remove `SpringCMConnector` from the guest profile.
- Add a check that the caller may write to `recordId` before generating the folder URL (`getFolderURL(recordId)` is also callable by guests).

**Effort**: M

---

### [CRITICAL] ID F-03: Public LWCs pass URL- or client-supplied record Ids to `without sharing` Apex with no ownership check (IDOR: payment PII, documents, delete and expedite any Case)
**Confidence**: Confirmed (LWC call sites, Apex bodies, and guest permission set `BREG_Site_Guest_User` granting `BREGPaymentController`, `BREGPortalUtils` and `BREGCaseControllerWithoutSharing`)

**Evidence**

| Front-end call site (community-exposed) | Apex (all `without sharing`) | What the caller controls |
|---|---|---|
| `lwc/breg_PaymentConfirmation/breg_PaymentConfirmation.js:35-45`: `this.paymentId = urlParams.get("pid"); getPaymentConfirmation({ paymentId })` | `classes/BREGPaymentController.cls:202-250`: loads `pymt__PaymentX__c WHERE Id = :paymentId` (line 1447+) and returns billing first/last name, email, street/city/state/zip, card type, **last 4 digits**, and transaction lines | any `pid` in the URL |
| `lwc/breg_Payment/breg_Payment.js:14-26`: `getPaymentTransactionLineWrappers({ paymentId: this.getParamFromUrl('pid') })` | `BREGPaymentController.cls:192-199` | any `pid` |
| `lwc/breg_AuthenticateCertificate/breg_AuthenticateCertificate.js:3` (guest page); `breg_PaymentConfirmation.js:243`; `breg_MyDashboardPage.js:180`; `breg_AnnualsSubmissionChoice.js:510` | `BREGPaymentController.cls:6-15`: `downloadDocument(String docusignDocumentId)` returns the base64 of **any** DocuSign document, with no link to the caller | any DocuSign document Id |
| `lwc/breg_MyDashboardPage/breg_MyDashboardPage.js:13,374`: `await deleteCase({ caseId: recordId })` | `classes/BREGPortalUtils.cls:293-296`: `Case caseToDelete = [SELECT Id FROM Case WHERE Id = :caseId]; delete caseToDelete;` | any Case Id |
| `lwc/breg_CheckoutPage/breg_CheckoutPage.js:5,143` | `classes/BREGCaseControllerWithoutSharing.cls:18-28`: `updateCasesProcessingSpeed(List<Id> caseIds)` sets Expedited | any Case Ids |
| `lwc/breg_AnnualReports/breg_AnnualReports.js:9,333` | `BREGCaseControllerWithoutSharing.cls:31-38`: `updateCaseContact(caseId, contactId)` | any Case and Contact |

**Impact**:
- Guest or portal users can read other payers' identity and billing data (Salesforce Ids are sequential and easy to enumerate, and `pid` values leak in URLs, browser history and referrers).
- They can download other companies' filed documents, delete arbitrary Cases (filings, complaints) in the org, and get expedited processing without paying.

05 P-04 covers the DML half from the permissions side. This finding adds the front-end entry points and the read and delete IDORs.

**Recommendation**:
- In each method, verify ownership against `UserInfo.getUserId()`/`ContactId`. For payments, check `pymt__Contact__c`/`CreatedById`. For guest checkout, add a random `confirmationToken` column and look up by that, not by Id.
- Run `with sharing` or `WITH USER_MODE` wherever possible.
- Remove `deleteCase` and `updateCasesProcessingSpeed` from the guest permission set.
- For `downloadDocument`, accept a `breg_Document__c` Id, check access to it, and resolve the DocuSign Id on the server.

**Effort**: M

---

### [CRITICAL] ID F-04: Client-controlled object, field and condition strings flow into dynamic SOQL from lookup components, including an unauthenticated page
**Confidence**: Confirmed for the CATV public page (code plus guest profile access). Likely for the others (code confirmed; reachability depends on page placement).

**Evidence**
- **Public CATV self-registration** (`lwc/catv_registration_page`, target `lightningCommunity__Page`):
  - `catv_registration_page.html:85-88` puts `<c-catv_custom_lookup object-api-name="Account" field-api-name="Name" other-field-api-name="Type" ...>` on the page.
  - `lwc/catv_custom_lookup/catv_custom_lookup.js:44-54` sends `fieldApiName`, `otherFieldApiName`, `selectedOrg` and `searchString` to Apex.
  - `classes/CATV_CustomLookUpController.cls:22`: `String filterCriteria = inputWrapper.fieldApiName + ' LIKE ' + '\'' + String.escapeSingleQuotes(...) + '%\' LIMIT 10';`. `fieldApiName` is not escaped or allow-listed.
  - Lines 35-40: the query runs through `CATV_WithoutSharingUtility.queryRecords(query, bindMap)` and returns `s.get(inputWrapper.otherFieldApiName)`, **any Account field the caller names**.
  - `profiles/CATV Portal Profile.profile-meta.xml` (Guest User License) enables `CATV_CustomLookUpController`.
- **Aura `Lookup` and `sc_Lookup`** (both `forceCommunity:availableForAllPageTypes`):
  - `classes/LookUpController.cls:8-13` and `classes/sc_LookupController.cls:9-14` build `'SELECT '+fld_API_Text+' ,'+fld_API_Val+' FROM '+objectName+' WHERE '+fld_API_Search+' LIKE '+searchText` → `Database.query`.
  - `LookUpController` is enabled on `DCCA BREG - CustomerCommunityLogin`. `sc_LookupController` is enabled on the guest `Digital Form Profile`.
- **`xLookup` → `LookupService.getSearchResults(searchTerm, fieldList, sobjectName, extraCondition, fieldsToSearch)`**: `lwc/xLookup/xLookup.js:2,95-102` passes a raw `extraCondition`. `classes/LookupService.cls:5-45` concatenates it. Used internally by `createAppClassification`, which is `lightning__RecordPage` only.
- The lookup has no debounce (`catv_custom_lookup.html:18` fires `onchange` straight to Apex), so enumeration is cheap.

**Impact**: An unauthenticated visitor to the CATV portal can set `fieldApiName` to something like `Name != null OR Name` and `otherFieldApiName` to `Phone`, `BillingStreet` or a custom PII field, then page through every Account in the org without sharing. On the community lookups, callers pick any object and field that their CRUD/FLS allows. With `without sharing`/implicit sharing and the broad guest sharing rules in 05 P-05, that exposes whole record populations.

**Recommendation**:
- Replace the generic lookups with **one** LWC lookup (`lightning-record-picker` where possible) backed by Apex that takes a *config key*.
- Resolve object and fields on the server from a Custom Metadata allow-list, validate with `Schema.getGlobalDescribe()`, use bind variables and `WITH USER_MODE`, and never accept a WHERE fragment from the client.
- For the CATV registration page, hard-code `Account.Name`/`Type` on the server and return only the encrypted Id and name.

**Effort**: M

---

### [HIGH] ID F-05: Known-vulnerable jQuery, Bootstrap and typeahead loaded by Aura lookups used under community payment components
**Confidence**: Confirmed (versions from file headers and `ltng:require` references). Likely reachable from community pages.

**Evidence**
- `aura/InputLookup/InputLookup.cmp:2` and `aura/InputLookup2/InputLookup2.cmp:17`: `<ltng:require scripts="/resource/Lgt_InputLookup/js/jquery-2.2.4.min.js, /resource/Lgt_InputLookup/js/bootstrap.min.js, /resource/Lgt_InputLookup/js/typeahead.js" ...>`
- `InputLookup` is used by `CustomRecordCreateField:69` and `CustomRecordCreateField2:84`. These sit under `CustomRecordCreate` (`forceCommunity:availableForAllPageTypes`), which is embedded in the community components `GenericCommunityPayment:46` and `HPEAPRequestCreate:44`. `InputLookup2` is used by `RelatedListTreeViewerCell` and `CustomRecordCreateField3`.
- Versions:
  - `staticresources/Lgt_InputLookup/js/jquery-2.2.4.min.js`: jQuery v2.2.4. CVE-2015-9251, CVE-2019-11358 (prototype pollution in `$.extend`), CVE-2020-11022 and CVE-2020-11023 (XSS in `.html()` and related methods).
  - `staticresources/Lgt_InputLookup/js/bootstrap.min.js`: Bootstrap v3.3.6. CVE-2018-14040/14041/14042, CVE-2019-8331 (XSS through `data-*` tooltip/popover attributes).
  - `staticresources/Lgt_InputLookup/js/typeahead.js` and `staticresources/typeahead.js`: typeahead.js 0.10.5, abandoned in 2015. Its suggestion templates render HTML.
- Unused but publicly cached (`cacheControl=Public`): `staticresources/CustomTemplate/` holds a scraped WordPress page. It includes jQuery v1.12.4 (same CVEs), jQuery Migrate 1.4.1, Thickbox 3.1 (2007), jQuery Cookie 1.3, Nivo Slider 3.2, legacy Google Analytics `ga.js`/`analytics.js`, and YouTube `embed_data/*.js`. `AGRCustomTheme` loads only `style.css` from it.
- `Lgt_InputLookup/__MACOSX/` resource-fork files were zipped into the resource.

**Impact**: Lookup search results come from record names, which are user-controlled, and they pass through typeahead/jQuery HTML rendering. Old jQuery `.html()` parsing bugs (CVE-2020-11022/3) can turn "sanitised" strings into script. Locker Service reduces DOM reach but does not fix library-level XSS inside the component's own namespace. Security scanners (and state auditors) will flag every publicly served copy.

**Recommendation**: Migrate `InputLookup`/`InputLookup2` to a single LWC lookup (see F-04 and the Aura migration table), then delete `Lgt_InputLookup`, both `typeahead` resources and `CustomTemplate`. If the migration has to wait, upgrade to jQuery 3.7.x and Bootstrap 3.4.1 as a stopgap.

**Effort**: M

---

### [HIGH] ID F-06: Stored XSS: record names written with `innerHTML` in `lookupSearchResult`
**Confidence**: Confirmed

**Evidence**
- `lwc/lookupSearchResult/lookupSearchResult.js:8-22`: in `renderedCallback()`, `// eslint-disable-next-line @lwc/lwc/no-inner-html` then `nameNode.innerHTML = this._highlightSubstring(this.record.title, this.searchTerm);` and the same for `subtitle`.
- `_highlightSubstring` (lines 30-43) only wraps a `<b>` around the match. There is no escaping.
- `lookupSearchResult.html:8-10` uses `lwc:dom="manual"`.
- `title` is `record.Name` and `subtitle` joins every other queried field (`lwc/xLookup/xLookup.js:118-130`).
- Used by `xLookup` → `createAppClassification` (`lightning__RecordPage`, Classification__c lookup). API version 48.0.

**Impact**: Anyone who can set a `Classification__c.Name` (or any field in `field-list`) to `<img src=x onerror=...>` gets script running in the session of every internal user who searches that lookup. The ESLint rule was deliberately switched off. LWS/Locker limits cross-namespace access, but the script still runs as the victim user in the `c` namespace and can call any `@AuraEnabled` method.

**Recommendation**: Render highlighting in the template instead: split the string into `{pre, match, post}` and output `<b>{match}</b>` with no manual DOM. Remove `lwc:dom="manual"`. This also removes an unguarded `renderedCallback`. Better still, fold it into the consolidated lookup (F-04).

**Effort**: S

---

### [HIGH] ID F-07: Draft license applications on the guest Digital Form site can be loaded by name, including through a `sessionStorage` override
**Confidence**: Likely (code and guest class access confirmed; how guessable `Application_Cache__c.Name` values are has not been verified)

**Evidence**
- `aura/sc_ApplicationCreation/sc_ApplicationCreationHelper.js:14-22`: `let name = formData.app_no; if (sessionStorage && sessionStorage.getItem("sc_Application_ExistingForm_app_no")) { name = sessionStorage.getItem(...); }` then `showApplicationDetail(component, name, userId)`.
- Lines 29-35: `c.getDraftApp` with `{ name, userId }`, then `component.set("v.formData", app.FormData__c)`.
- `classes/DraftApplicationDetailCont.cls:1-6`: `public without sharing class DraftApplicationDetailCont { @AuraEnabled public static string getDraftApp(String name) { ... getApplicationCacheByName(name) ...` The `userId` sent by the client is **ignored**.
- Lines 18-23: `getUserInfo(String recordId)` returns `PVL_Portal_User__c.Email__c` for any Id.
- `classes/sc_ApplicationCacheSelector.cls:6-8` returns `FormData__c` and `AppDataBeforeSubmit__c`. Application card caches hold `socialSecurityNo` and `dob` keys (see sample data in `staticresources/sc_testCardCaches.txt`).
- `profiles/Digital Form Profile.profile-meta.xml` (Guest User License) enables `DraftApplicationDetailCont`.
- `sc_ApplicationCreationController.js:11`: `window.location.href = formData.cancel_url;` redirects to a URL taken from the decrypted `data` parameter. `PVL_EncodingService.decode` uses AES-CBC with a static IV and no MAC, so it gives no integrity protection. This is a secondary open-redirect risk.

**Impact**: A guest who knows or guesses another applicant's draft name can call `getDraftApp` directly, or set the `sessionStorage` key, and read that application's form data (identity, contact, licensure, possibly SSN and DOB). 05 P-05 notes that guest sharing rules also share draft applications.

**Recommendation**:
- Look up drafts by a server-issued, unguessable token bound to the portal user.
- Check `PVL_Portal_User__c` ownership in Apex, and switch to `with sharing` or user mode.
- Stop trusting `sessionStorage` for record selection.
- Allow-list `cancel_url`/`finish_url` hosts, or use relative paths only.
- Replace AES-CBC with a static IV with AES-GCM or HMAC-signed payloads.

**Effort**: M

---

### [HIGH] ID F-08: Aura payment and record-creation callbacks dereference `getReturnValue()` without checking state; failures leave the user stuck with no message
**Confidence**: Confirmed

**Evidence**
- `aura/GenericCreatePayment/GenericCreatePaymentHelper.js`: 11 `setCallback` handlers and **0** `getState()`/`ERROR` branches.
  - Line 144: `action.setCallback(self, function(a) { if (a.getReturnValue().errorMessage == "") { ... window.open(component.get("v.paymentPageURL") + "?pid=" + ...`
  - Line 269: `if (a.getReturnValue().errorMessage == "") { component.set("v.serverResponse.filingId", ...`
  - The component is `forceCommunity:availableForAllPageTypes`, 1,963 LOC.
- `aura/CustomPaymentButton/CustomPaymentButtonHelper.js:13-15`: `action.setCallback(self, function(a) { if(a.getReturnValue().errorMessage == '')`
- `aura/CustomRecordCreate/*`: 3 callbacks, 0 error branches (community).
- 30 occurrences of `getReturnValue().<prop>` across Aura JS.

**Impact**: When the Apex method throws (for example an `AuraHandledException`, a governor limit, or a lost session), the action state is `ERROR` and `getReturnValue()` is `null`. The callback then throws a `TypeError`, the spinner never clears, and the citizen sees a frozen payment screen. They often retry, which creates duplicate filings or payments.

**Recommendation**: Add a shared helper `callApex(cmp, name, params)` that returns a Promise and handles SUCCESS, ERROR (via `reduceErrors`) and INCOMPLETE uniformly, and use it everywhere. In the short term, add `if (a.getState() !== 'SUCCESS') { showError(...); hideSpinner(); return; }` to the 11 `GenericCreatePayment` callbacks and to `CustomPaymentButton`.

**Effort**: S (patch) / M (helper rollout)

---

### [HIGH] ID F-09: Unhandled or swallowed Apex errors in LWC submission and checkout flows
**Confidence**: Confirmed

**Evidence** (grouped; full list in Appendix D)
- `lwc/breg_CheckoutPage/breg_CheckoutPage.js:151-168`: `async createPaymentAndNavigate(details) { this.isLoading = true; const paymentId = await createPayment(details); ...`. There is no try/catch. On failure the promise rejection goes unhandled, `isLoading` stays true (spinner forever) and there is no message. The caller in `getParamsFromUrl` (line 48, 62) does not await it.
- `breg_CheckoutPage.js:141-148`: `setExpeditedSpeedForCases` catches and only runs `console.error`, so the payment goes on as if expedite had been applied.
- `lwc/breg_Changes/breg_Changes.js:39-92`: five `await` Apex calls in `connectedCallback` and its handlers, with **no** `try`. This is on the public "change form" flow.
- `lwc/jVForm/jVForm.js:129,176-178` and `lwc/tDRForm/tDRForm.js` (3 `.then`, 0 `.catch`): `submit(...).then(... generateFile(...).then(...))`. Filing submission has no failure path, and `showLoading` never resets.
- `lwc/paymentDisplay/paymentDisplay.js:32-50`: `getTransactionInProgress(...).then(...)` has no `.catch`. On rejection `count` never increments and the interval polls Apex once a second **forever** (see F-14).
- `lwc/syncApp/syncApp.js`, `lwc/springFileFix/springFileFix.js` (2 `.then`, 0 `.catch`), `lwc/sc_appBackup/sc_appBackup.js:8` (`recordIds.map(this.backupAppRecord)`, with async results never awaited or caught).
- Errors surfaced only to the console: `lwc/breg_Payment/breg_Payment.js:27`, `lwc/breg_CheckoutPage/breg_CheckoutPage.js:103`, `lwc/breg_Shopping_Cart/breg_Shopping_Cart.js:415`, and others.
- Wires with no `error` branch: `breg_MyFilings.js` (`caseMetadata`, `formConfigMetadata`, `statusValues`), `util_closer_schedulerManager.js` (`wiredSettings`), `cmsIconLink.js` and `cmsIconWithBgImg.js` (`setContent1`), `sebSearchResult.js` (`handlePageRef`).

**Impact**: Users on the most important flows (checkout, business filings, JV/TDR fiscal submissions) get frozen spinners and silent partial state, for example a payment created but the expedite not applied. Support cannot reproduce these problems because the only trace is in the user's browser console.

**Recommendation**:
- Wrap every imperative Apex call in `try/catch/finally`, with `finally { this.isLoading = false; }`.
- Add a shared `c/utils.reduceErrors()` plus a toast/LMS error publisher (`breg_constants.MESSAGE_TYPE_TOAST` already exists), and route errors through `loggerService` so they reach the server.
- Make `createPaymentAndNavigate` return a promise that the caller awaits.
- Add an ESLint rule (`@lwc/lwc/no-async-await` is not relevant; use `promise/catch-or-return`).

**Effort**: M

---

### [HIGH] ID F-10: Sandbox URLs and org-specific record type Ids hardcoded in production components
**Confidence**: Confirmed (values). Likely impact (depends on whether Builder properties override the defaults).

**Evidence**
- `aura/CustomPaymentButton/CustomPaymentButton.cmp:24`: `<aura:attribute name="paymentPageURL" type="String" default="https://dev-hawaiidcca.cs33.force.com/pmtx/pymt__SiteCheckout" />`. The payment redirect defaults to a **dev sandbox** (community-exposed component; used at `CustomPaymentButtonController.js:24`).
- `aura/AGRCustomTheme/AGRCustomTheme.cmp:8,10,14,18,19`: images and the home link point at `https://agrdev3-agrdev3-hawaii-agr.cs14.force.com/resource/1502793301000/CustomTemplate/...` and `.../s/`. `cs14` is a retired sandbox instance.
- `aura/NewTransactionNoAccount/NewTransactionNoAccount.cmp:156,161` and `aura/GroupTransactions2/GroupTransactions2.cmp:172,177`: `<aura:if isTrue="{!v.createType == '012t0000000PLy1AAG'}">`, with hardcoded RecordType Ids that differ between orgs and sandboxes.
- `lwc/cmsNewsList/cmsNewsList.html:41-44`: hardcoded pagination links to `https://cca.hawaii.gov/blog/category/news-releases/page/52/`.
- `lwc/breg_NavigateEverywhere/breg_NavigateEverywhere.js:28`: commented `https://salesforce.com` placeholder.

**Impact**: If a page's Builder property is empty, citizens are sent to a sandbox checkout page, where payments are lost or test gateways are used, and phishing risk rises. Hardcoded RecordType Ids break these forms in every sandbox refresh or new org, which leads to environment-specific hotfixes.

**Recommendation**:
- Move payment and site base URLs to Custom Metadata or `$Label`, or derive them on the server (`BREGPaymentController.getPaymentSiteBaseUrl` already does this for BREG; reuse it).
- Resolve RecordTypes by DeveloperName through `getObjectInfo`/`Schema`.
- Delete `AGRCustomTheme` if the AGR site has been decommissioned.

**Effort**: S

---

### [MEDIUM] ID F-11: Source references that break deploys or runtime (missing Apex method, non-`@AuraEnabled` import, missing static resource)
**Confidence**: Confirmed at repository level. The org may hold different metadata.

**Evidence**
- `lwc/util_closer_LogViewer/util_closer_LogViewer.js:7`: `import exportCaseLogsAsCsv from '@salesforce/apex/util_closer_LogViewerController.exportCaseLogsAsCsv';`. No such method exists in `classes/util_closer_LogViewerController.cls` (it has `getCaseLogExportQuery` at line 218), yet it is called at line 639.
- `lwc/springFileFix/springFileFix.js:3`: imports `SpringCMConnector.getAccessToken`, which is `public static` but **not** `@AuraEnabled` (`SpringCMConnector.cls:70`).
- `aura/CustomRecordCreateMap/CustomRecordCreateMap.cmp:3`: `{!$Resource.leaflet_1_0_2 + '/leaflet.js'}`. No `leaflet_1_0_2` resource exists in `staticresources/`.

**Impact**: A full-source deploy (CI/CD, sandbox seeding) fails on these LWC bundles, or the components fail at runtime. That blocks the pipeline improvements recommended elsewhere.

**Recommendation**: Add the missing Apex method or remove the import. Delete `springFileFix` (a one-off fix utility on a Tab), or fix it as part of F-02. Add or remove the Leaflet resource. Run `sf project deploy validate` in CI.

**Effort**: S

---

### [MEDIUM] ID F-12: No LWC Jest tests at all (0 of 232) despite Jest being configured
**Confidence**: Confirmed

**Evidence**
- `find . -name __tests__` and `*.test.js` return nothing.
- `jest.config.js` extends `@salesforce/sfdx-lwc-jest/config`.
- `package.json` runs `"**/lwc/**": ["sfdx-lwc-jest -- --bail --findRelatedTests --passWithNoTests"]`, so the pre-commit gate always passes.

Cross-reference: 06 T-08.

**Impact**: The pricing, cart and checkout logic (F-01), URL-parameter parsing (`c/utils`), and the dynamic-form engine (`breg_BaseFormComponent`, `breg_RegistrationDynamicForm` at 1,377 LOC, `breg_MembersChange` at 1,378 LOC) have no automated regression safety net. Refactors such as the Aura migration and de-duplication carry high risk.

**Recommendation**: Start with `c/utils`, `breg_Shopping_Cart`, `breg_CheckoutPage`, `breg_BaseFormComponent`, `breg_StartNewBusinessWizard` and `catv_custom_lookup`, using mocked Apex. Remove `--passWithNoTests` once a baseline exists, and add coverage thresholds in `jest.config.js`.

**Effort**: L

---

### [MEDIUM] ID F-13: Verbose console logging of form data and PII on public pages; generated OmniScript bundles ship admin identities
**Confidence**: Confirmed

**Evidence**
- 222 `console.log` calls in LWC and 127 in Aura (429 and 137 `console.*` in total).
- Examples on public flows:
  - `lwc/utils/utils.js:356,453,524,565-571,620`: `console.log("Form data set:", JSON.stringify(formData));` logs full business filings, including member names and addresses.
  - `lwc/catv_registration_page/catv_registration_page.js:71`: `console.log('this.registrationObj'+JSON.stringify(this.registrationObj));` logs self-registration name, email and phone.
  - `lwc/breg_VerifyCompanyInfo/breg_VerifyCompanyInfo.js:217`: `console.log("accountData", JSON.stringify(this.accountData));`
  - `lwc/breg_Payment/breg_Payment.js:26`: `console.log('Transaction lines:', this.transactionLines);`
  - `lwc/breg_DeliveryMethod/breg_DeliveryMethod.js:98` (delivery address) and `lwc/breg_AccountInfo/breg_AccountInfo.js:189` (`console.debug("Saving contact data: ", ...)`).
  - `lwc/makePaymenttoMultipleFilings/makePaymenttoMultipleFilings.js:101-102,169-170,254` log the user and transaction results.
- Generated OmniScript definitions under community-exposed `lwc/case*English/*_def.js` embed `"userProfile":"System Administrator","userName":"doug.nagel++dcca@pacificpointcorp.com.dccaweb","userId":"0053R000002nqNgQAI"` (and `collin.wong++dcca@...` in `caseDCAComplaintEnglish_def.js`).
- `staticresources/sc_testCardCaches.txt` (`cacheControl=Public`) holds realistic test application data with employee emails.

**Impact**: PII ends up in the browser console on shared or public computers, in browser extensions, and in screen recordings during support sessions. Admin usernames and Ids handed to anonymous users help social engineering and password spraying.

**Recommendation**:
- Remove `console.log` of data objects and use `loggerService` with a level switch that is off in production.
- Enable ESLint `no-console` as an error, with an exception for `console.error` routed through the logger.
- Regenerate and re-activate the OmniScripts from a neutral integration user.
- Delete the `sc_test*` static resources.

**Effort**: S

---

### [MEDIUM] ID F-14: Event-listener and interval leaks, a broken `popstate` registration, and unguarded `renderedCallback` DOM growth
**Confidence**: Confirmed

**Evidence**
- `lwc/breg_Manage/breg_Manage.js:83`: `window.addEventListener("popstate", this.handlePopstate());`. The handler is **invoked** immediately and its return value (`undefined`) is registered, so Back/Forward never re-syncs the page state.
- `lwc/breg_AnnualReports/breg_AnnualReports.js:78`: `window.addEventListener("popstate", this.getParamsFromUrl());` has the same bug. Neither component has a `disconnectedCallback`.
- `aura/ApplicationRecordsWizard/ApplicationRecordsWizardController.js:6-20`: `window.addEventListener("keydown", function (e) { ... if (key === 13) ... applicationCreationCmp.submit();` is never removed. Each time the component is initialised another global Enter-key handler is added, so the application can be **submitted more than once** and destroyed components are kept alive.
- `lwc/paymentDisplay/paymentDisplay.js:32`: `setInterval` polls Apex; the interval is not cleared on disconnect or on error (see F-09).
- `lwc/breg_SearchAndBuy/breg_SearchAndBuy.js:366-381` and `lwc/breg_SearchAndBuy_BusinessDetails/breg_SearchAndBuy_BusinessDetails.js:171-190`: `renderedCallback()` creates a new `<style>` element and appends it into `lightning-tabset` on **every render**, with no guard. The BusinessDetails version also re-navigates to the active tab on every render.
- `lwc/makePaymenttoMultipleFilings/makePaymenttoMultipleFilings.js:124-126`: `renderedCallback(){ console.log(document.getElementsByClassName('slds-scrollable_y')); }` does global DOM access on every render.

**Impact**: Browser history navigation is broken on the Manage and Annual Reports pages. Duplicate submissions are possible on the application wizard. DOM nodes keep growing and extra Apex traffic hits the org on long-lived portal sessions.

**Recommendation**:
- Store a bound handler (`this._onPop = this.handlePopstate.bind(this)`), add it in `connectedCallback` and remove it in `disconnectedCallback`.
- Clear intervals in `disconnectedCallback`.
- Guard `renderedCallback` with a `hasRendered` flag and move the tab font size into a styling hook or a static resource stylesheet (`loadStyle`).
- In Aura, remove the listener in an `unrender` override or use `aura:handler name="destroy"`.

**Effort**: S

---

### [MEDIUM] ID F-15: Heavy duplication. One good base class, but copy-pasted twins and 10+ competing lookup, modal, file-upload and toast implementations
**Confidence**: Confirmed (duplicate detection by Node script: 6-line sliding windows over trimmed lines longer than 25 characters, across LWC and Aura JS, HTML and CMP)

**Evidence**
- Overall, 4,276 of 32,776 significant lines (**13.0%**) sit in blocks duplicated elsewhere.
- **Positive:** `lwc/breg_BaseFormComponent/breg_BaseFormComponent.js` (545 LOC) is a genuine base class, with `@api config/formConfig/formData`, validation, dependent-field reset, address copy and edit-section modal. **64 of 160** `breg_` components `extends BaseFormComponent`, and 3 extend `StartNewBusinessWizardComponent`. The other 93 `breg_` components are page and container components, not form fields.
- Top duplicated pairs (shared 6-line windows):

  | Pair | Shared windows |
  |---|---|
  | `aura/CreateTransaction` ⇄ `aura/breg_CreateTransaction` (.cmp / Helper / Controller) | 256 / 228 / 40 |
  | `lwc/catv_provider_tabs` ⇄ `lwc/catv_requestor_tabs` (.html / .js; 1,576 and 1,858 LOC) | 198 / 127 |
  | `aura/GroupTransactions2` ⇄ `aura/NewTransactionNoAccount` (Helper / cmp) | 108 / 88 |
  | `aura/Lookup` ⇄ `aura/sc_Lookup`; `MultiPicklist` ⇄ `sc_MultiPicklist`; `FieldInput` ⇄ `sc_FieldInput`; `SelectListViewItem` ⇄ `sc_SelectListViewItem` | 100; 84+66; 38+38; 32 |
  | `aura/GenericCommunityPayment` ⇄ `aura/HPEAPRequestCreate` | 84 |
  | `aura/InputLookup` ⇄ `aura/InputLookup2` | 74 |
  | 6 × `lwc/case*English` OmniScript wrappers (generated) | 58 each pair |
  | `aura/CustomRecordCreateField` ⇄ `CustomRecordCreateField2` ⇄ `CustomRecordCreateField3` | 56 / 24 |

- The cart and `localStorage` logic is re-implemented in **14** LWCs, each declaring `CART_STORAGE_KEY = "breg_shopping_cart"`: `breg_AgentSearch`, `breg_EntityListBuilder`, `breg_PaymentRedirection`, `breg_ReviewNotifications`, `breg_Shopping_Cart`, `breg_SearchAndBuy`, `breg_Manage`, `breg_MyDashboardPage`, `breg_SearchAndBuy_BuyAvailableDocs`, `breg_DeliveryMethod`, `breg_FormsAndFees`, `breg_AnnualsSubmissionChoice`, `breg_CheckoutPage` and `breg_MyFilings`. `breg_Header` and `breg_Home` hardcode the literal. A copy-pasted bug appears in several: `JSON.parse(storedCart) !== "[]"` compares an array to a string, so it is always true.
- Competing utilities:
  - **Lookups (11):** `xLookup` + `lookupSearchResult`, `sc_x_lookup`, `catv_custom_lookup`, `customSelectInput`, and in Aura `Lookup`, `sc_Lookup`, `InputLookup`, `InputLookup2`, `CashierCodeLookup`, `ComboBoxSearchable`, `TypeSearchBox`.
  - **Modals/popups (10):** `breg_ModalPopup`, `breg_Popup`, `breg_RegistrationDynamicFormModal`, `catv_modal`, `pvl_popup`, and in Aura `Popup`, `PVLPopup`, `multiComp_popup`, `sc_popup`, `WizardModal`.
  - **Toasts (3):** `breg_Toast`, `catv_custom_toast`, `pptToastListener`, plus 18 local `showToast()` helpers.
  - **Data tables (5):** `breg_CustomDataTable`, `extendedDataTable`, `breg_DatatableWithPagination`, `jVTable`, `tDRTable`.
  - **File upload (10):** `breg_FileUpload`, `springFiles`, `springFileFix`, `clmFiles`, and in Aura `CustomUploadButton`, `FileDetailUploader`, `CustomFileDetailUploader`, `sc_FileUpload`, `files`, `fileList`.
  - **Search inputs (2):** `breg_SearchInput`, `searchInput`.
  - **URL-parameter parsing:** `c/utils.getPageParamsFromUrl` exists, yet 9 components call `new URLSearchParams(window.location.search)` directly.

**Impact**: Security fixes (F-01, F-04, F-06) have to be applied in many places, and some copies will be missed. Two versions of every form path (CATV provider and requestor, internal and BREG transactions) drift apart.

**Recommendation**:
- Create `c/bregCart` (a single cart service module with server-side pricing, see F-01).
- Merge `catv_provider_tabs` and `catv_requestor_tabs` into one component with a `role` property.
- Standardise on one LWC lookup (`lightning-record-picker`), `LightningModal`, `lightning/toast` or `ShowToastEvent`, and `lightning-file-upload` or one custom uploader.
- Merge `CreateTransaction` and `breg_CreateTransaction` as part of the migration.

A realistic estimate is that 3,000–4,000 LOC can be removed.

**Effort**: L

---

### [MEDIUM] ID F-16: Accessibility gaps on the public government portal (keyboard, labels, alt text)
**Confidence**: Confirmed (single-line grep; multi-line tags were not counted, so figures are a lower bound)

**Evidence**
- `lwc/breg_Header/breg_Header.html:30,37,38,86,93,94`: `<div class="avatar" onclick={toggleDropdown}>`, `<p class="dropdown-item" onclick={handleEditAccount}>Account Settings</p>`, `<p class="dropdown-item" onclick={handleLogout}>Logout</p>`. These have no `role`, no `tabindex` and no key handlers; the file contains 0 `tabindex`/`onkey*`. **Keyboard users cannot reach Account Settings or Logout.**
- `lwc/breg_Expedited/breg_Expedited.html:19`: `<div class={opt.class} data-value={opt.value} onclick={handleOptionClick}>`. The processing-speed choice in the payment flow is mouse-only.
- `lwc/breg_MyDashboardPage/breg_MyDashboardPage.html:25`: clickable dashboard cards are `div`s.
- In total, 14 LWC and 7 Aura clickable non-interactive elements have no `role`.
- `<img src={content.url} />` with no `alt` in `lwc/cmsIconWithBgImg/cmsIconWithBgImg.html:4`, `lwc/cmsIconLink/cmsIconLink.html:4` and `lwc/cmsIconWithCard/cmsIconWithCard.html:4` (public CMS tiles); 2 more in Aura.
- 46 raw `<input>` elements have no `aria-label`/`id` association. `lwc/jVTable/jVTable.html` accounts for 30 of them.

**Impact**: State portals must meet WCAG 2.1 AA under the DOJ ADA Title II rule (2024). The compliance date for large public entities was April 2026. Logout and payment choices that do not work by keyboard block users and create legal exposure.

**Recommendation**:
- Use `<button>` or `lightning-button-menu` for the avatar menu, and `lightning-radio-group` or visual-picker with `role="radio"` and arrow-key support for Expedited.
- Add `alt` (empty `alt=""` for decorative images).
- Run axe or `@sa11y/jest` in the Jest suite (F-12).

**Effort**: M

---

### [MEDIUM] ID F-17: `aura:unescapedHtml` renders field values and labels in community record-creation and payment components
**Confidence**: Likely (field values are normally admin- or system-set; the platform may sanitise, which has not been verified in the org)

**Evidence**
- `aura/CustomRecordCreateField/CustomRecordCreateField.cmp:72-75`: `<aura:if isTrue="{!v.fieldType == 'TEXTAREA'}"><aura:unescapedHtml value="{!v.value}"/>`. This is shown when the field is not creatable (`CustomRecordCreateFieldController.js:36-60` defaults `cType = "READONLY"`).
- The parent `CustomRecordCreate` is community-exposed.
- Label-only uses (lower risk; labels are admin-controlled): `GenericCreatePayment.cmp:73,135,714,787`, `GenericCommunityPayment.cmp:57,59` and `HPEAPRequestCreate.cmp:54,57`.
- `lwc/lookupSearchResult`: see F-06.
- `aura/svg/svgRenderer.js:12` and `aura/sc_svg/sc_svgRenderer.js:12` build `svg.innerHTML = '<use xlink:href="' + xlinkhref + '"></use>'` from a markup attribute (low risk, but the pattern is unsafe if the attribute is ever data-bound).

**Impact**: If any read-only textarea (formula, workflow-populated, or integration-set) can hold user-supplied text, the result is stored XSS for community and internal viewers.

**Recommendation**: Use `lightning:formattedRichText` (which sanitises) or `ui:outputTextArea`. Replace the custom `svg` renderers with `lightning:icon` or `lightning-primitive-icon`.

**Effort**: S

---

### [MEDIUM] ID F-18: Chatty and serial Apex patterns (Apex in loops, per-document callouts, no debounce on public lookups)
**Confidence**: Confirmed

**Evidence**
- `lwc/generatePicklistOptions/generatePicklistOptions.js:17-20`: `rtTypes.forEach(recordTypeName => { this.getPicklistVal(recordTypeName); })` makes one Apex call per record type, un-awaited, and then calls `createInstructions` before those calls finish (a race).
- `lwc/sc_appBackup/sc_appBackup.js:7-8`: `recordIds.map(this.backupAppRecord)` makes one Apex call per record, un-awaited. `this` is unbound when `backupAppRecord` runs.
- `lwc/breg_MyDashboardPage/breg_MyDashboardPage.js:180` and `lwc/breg_PaymentConfirmation/breg_PaymentConfirmation.js:243`: `Promise.all(documents.map(doc => downloadDocument(...)))` makes one DocuSign callout per document, in parallel, with base64 payloads.
- `lwc/tktCreateTicket/tktCreateTicket.js:339-349`: serial `attachFile` per screenshot. This is acceptable for heap reasons but would be better as one ContentVersion upload.
- `lwc/catv_custom_lookup/catv_custom_lookup.html:18`, `lwc/searchInput/searchInput.html:11` and `lwc/breg_AgentSearch`: no debounce before the Apex search (only `xLookup` and `sc_x_lookup` debounce).
- `lwc/breg_Manage/breg_Manage.js`, `breg_AnnualReports`, `breg_CheckoutPage` and similar each call `BREGPortalUtils.getUserInfo` separately (the method is imported in 8 components) and it is not shared through LMS.

**Impact**: Extra Apex requests and callout load (concurrent long-running request limits on DocuSign callouts), slower pages, and a race condition in `generatePicklistOptions`.

**Recommendation**: Bulkify the Apex methods (accept lists) and add a 300 ms debounce in the shared lookup. Fetch user info once in the header and publish it through `breg_MessageChannel__c`. Zip multiple documents on the server, or download them one after another only on demand.

**Effort**: S–M

---

### [MEDIUM] ID F-19: CATV uploads allow 25 MB files, but the files travel as a base64 Apex parameter, far above platform limits; the type check is client-only
**Confidence**: Likely

**Evidence**
- `lwc/catv_provider_tabs/catv_provider_tabs.js:330-386` (and the same logic in `catv_requestor_tabs.js:664+`): `const MAX_FILE_SIZE_MB = 25; ... if (file.type !== 'application/pdf' || file.size > MAX_FILE_SIZE_BYTES)`, then `FileReader` base64, then `await uploadFile({recordId, fileName, fileContent, recObjectName})`.
- `classes/CATV_DashboardController.cls:95-106`: `EncodingUtil.base64Decode(fileContent)` followed by `SpringCMConnector.createFile(...)`.

**Impact**: The Aura/LWC action payload limit is about 4 MB, and the Apex heap limit is 6 MB synchronous. Base64 adds about 33%, so any PDF over about 3 MB fails with a generic error even though the UI says 25 MB is allowed. The MIME type check can be bypassed by renaming the file.

**Recommendation**: Use `lightning-file-upload` (ContentVersion, 2 GB), then push to SpringCM asynchronously from Apex. Or cap the UI at 3 MB. Validate the type on the server by checking the `%PDF` magic bytes.

**Effort**: S

---

### [MEDIUM] ID F-20: Community LWCs depend on 22 `without sharing` Apex controllers that take record Ids from the URL
**Confidence**: Confirmed (class sharing keywords grepped for every Apex class imported by an LWC)

**Evidence**
- Of the 55 Apex classes imported by LWCs:
  - **22 are `without sharing`**: `BREGAccountAffiliationController`, `BREGAccountInfoController`, `BREGAgentSearchController`, `BREGAnnualsController`, `BREGBusinessDetailsController`, `BREGCaseControllerWithoutSharing`, `BREGContactControllerWithoutSharing`, `BREGEntityListBuilderController`, `BREGHelpCenterController`, `BREGMyDashboardController`, `BREGNotificationsHandler`, `BREGPaymentController`, `BREGPortalUtils`, `BREGRegistrationFormController`, `BREGSearchAndBuyController`, `CATV_SelfRegistrationController`, `CATV_WithoutSharingUtility`, `DraftApplicationService`, `FieldUtils`, `PaymentDisplayController`, `SEBSearchController` and `SpringCMConnector`.
  - 11 declare no sharing keyword.
- Most `breg_` pages read record Ids from URL parameters (`c/utils.getPageParamsFromUrl`, for example `account-id`, `caseId`, `entityId`, `pid`).
- Counter-example that is done correctly: `BREGAccountInfoController.getInfo/saveInfo` resolve the contact from `UserInfo.getUserId()` (`classes/BREGAccountInfoController.cls:8-19`).
- No `cacheable=true` method imported by an LWC performs DML directly (checked by parsing method bodies with brace matching). 59 cacheable methods were reviewed.

**Impact**: F-03 shows the concrete exploits already found. Every other `without sharing` method that takes an Id from the URL needs the same review. The front end cannot enforce access, so each server method must.

**Recommendation**: Inventory each `@AuraEnabled` method used by community LWCs (see Appendix A) and label it "self-scoped", "public-by-design" or "needs ownership check". Default new controllers to `with sharing` and `WITH USER_MODE`. Coordinate with 05 P-04.

**Effort**: M

---

### [LOW] ID F-21: `localStorage` cart is not scoped to a user and persists on shared devices
**Confidence**: Confirmed

**Evidence**
- The cart key `"breg_shopping_cart"` is global per browser origin. It holds `caseId`, `companyName`, `companyUrl` and fees (`breg_Shopping_Cart.js:114-141`).
- It is cleared only on header logout (`breg_Header.js:50`) and after payment (`breg_PaymentRedirection.js:29`, `breg_CheckoutPage.js:172`). A guest cart survives into a later user's session on library or kiosk PCs.

**Impact**: Minor privacy leak between users, and a chance of paying for someone else's filings.

**Recommendation**: Keep the cart on the server (see F-01), or key the storage by user Id and expire it.

**Effort**: S (after F-01)

---

### [LOW] ID F-22: Old API versions across LWC and Aura
**Confidence**: Confirmed

**Evidence**
- `sfdx-project.json` `sourceApiVersion` is 67.0.
- **23 LWCs are below v58** (lowest 48.0: `xLookup`, `lookupSearchResult`, `createAppClassification`, `tDRForm`), listed in Appendix E.
- **91 of 147 Aura bundles are at v46 or lower**; 15 are at v38–41 (`CustomRecordCreateField` v38, `CustomPaymentButton` v39, `GenericCreatePayment` v41, and others).
- The Lightning Out VF pages are at v43–45 (`pages/BatchTransaction.page-meta.xml` v45 and so on).

**Impact**: These components miss framework fixes and behaviour versioning (for example LWS, `lwc:if`, and the stricter `@api` mutation rules), so upgrade testing piles up.

**Recommendation**: Bump versions as each component is touched, with regression testing. Target at least 62.

**Effort**: M

---

### [LOW] ID F-23: Legacy LWC idioms: `@track` on primitives, `if:true` directives
**Confidence**: Confirmed

**Evidence**
- 300 uses of `@track`. At least 124 decorate primitive literals (`@track isLoading = false;`, see `lwc/breg_Shopping_Cart/breg_Shopping_Cart.js:13,19`, `breg_Payment.js:8`), and 70 more are bare declarations.
- 425 `if:true`/`if:false` directives against 552 `lwc:if`.
- `catv_requestor_tabs.html:155,200` put `if:true` and `for:each` on the same `<template>`.

**Impact**: Noise and inconsistency. `if:true` is deprecated.

**Recommendation**: Clean these up with codemods (`@lwc/eslint-plugin-lwc` rules `no-deprecated`, `valid-track`).

**Effort**: S

---

### [LOW] ID F-24: User-facing strings hardcoded instead of Custom Labels
**Confidence**: Confirmed

**Evidence**
- Only about 60 of 232 LWCs use labels: 42 have a `labels.js` module and 18 import `@salesforce/label` directly. The org has 775 labels.
- Hardcoded examples:
  - `breg_PaymentConfirmation.js:57` `"Error retrieving payment: "`;
  - `catv_header.js:109` `'Something went wrong!!'`;
  - `makePaymenttoMultipleFilings.js:244,268`;
  - `lwc/breg_Home/breg_Home.js:22` (TODO about a hardcoded date in a label template);
  - all Aura toasts.

**Impact**: Translation (Hawaiian, Ilocano, and so on under state language-access rules) and wording changes need code deploys.

**Recommendation**: Extend the `labels.js` pattern that already exists in the `breg_` components.

**Effort**: M

---

### [LOW] ID F-25: Dead and test artifacts deployed as production front-end metadata
**Confidence**: Confirmed

**Evidence**
- `aura/DocusignLightningTest` (12 LOC, quick action).
- `staticresources/CustomTemplate` (WordPress page dump, see F-05), `staticresources/Lgt_InputLookup/__MACOSX/`, `staticresources/sc_testCardCaches.txt` and `sc_testData.txt` (Public).
- `lwc/springFileFix` (a one-off fix tool).
- `lwc/breg_NavigateEverywhere/breg_NavigateEverywhere.js:25-32` and `lwc/breg_BaseFormComponent.js:201-202,386`: commented-out code blocks.
- `aura/AGRCustomTheme` has hardcoded links to a retired sandbox (F-10).

**Impact**: Larger attack and maintenance surface, and confusion during migration.

**Recommendation**: Delete these after confirming they are not referenced in Experience Builder or flexipages.

**Effort**: S

---

### [LOW] ID F-26: Global `document` access and style injection into base components (fragile under LWS)
**Confidence**: Confirmed

**Evidence**
- `lwc/breg_SearchAndBuy/breg_SearchAndBuy.js:375` and `breg_SearchAndBuy_BusinessDetails.js:180`: `document.createElement('style')` is appended into `lightning-tabset` to restyle `.slds-tabs_default__link` inside another component's shadow tree.
- `lwc/makePaymenttoMultipleFilings/makePaymenttoMultipleFilings.js:125`: `document.getElementsByClassName(...)`.
- `document.body.appendChild(link)` download helpers in `lwc/utils/utils.js:283-288` and `breg_SearchAndBuy_CompanyInformation.js:252-259` (acceptable, but they should be centralised).
- There are no `eval`, `new Function`, string `setTimeout`, `postMessage` or `message` listeners in LWC or Aura. Only 14 `eslint-disable` comments in LWC (7 `no-async-operation`, 2 `no-inner-html`).

**Impact**: These are cosmetic hacks that break when base-component internals change. They are not a Locker bypass.

**Recommendation**: Use SLDS styling hooks (`--slds-c-tabs-*`) or `loadStyle` with a static stylesheet.

**Effort**: S

## Aura Migration Assessment

Classification rules (generated by script from each bundle's markup and JS, then adjusted by hand):
- **(a) Easy**: 60 LOC or less, or a thin wrapper around an LWC child (100 LOC or less), with no Aura-only APIs.
- **(b) Moderate**: 60–450 LOC of standard CRUD, lookups or payment UI without Aura-only APIs.
- **(c) Complex**: uses `lightning:overlayLibrary`, `force:recordData`, `$A.createComponent(s)`, application events, a `forceCommunity:themeLayout`, heavy `aura:method` APIs, or more than 450 LOC.

| Category | Count | Notes |
|---|---|---|
| Events (`.evt`) | 12 | 8 APPLICATION events (`APP_MESSAGE`, `BatchTransactionRedirect`, `ChangeScreen`, `NewTransactionRedirect`, `ValueChangedEvent`, `sc_ApplicationDependFieldEvent`, `setExpId`, `setStartUrl`) become Lightning Message Service channels. They are removed along with their consumers. |
| Lightning Out apps (`.app`) | 4 | `BatchJobsExecuteApp`, `BatchTransactionPage`, `GroupTransactions2Page` and `NewTransactionNoAccountPage` host components in VF list buttons (`pages/BatchTransaction.page`, `GroupTransactions2.page`, `InvoiceBatchTransaction.page`, `NewTransactionNoAccount.page`). They can be replaced with LWC list-view actions or screen flows. |
| (a) Easy / thin wrappers | 54 | 11 are quick-action or override wrappers around LWCs. **About 20 `sc_*` leaf fields are "easy" on their own but must move together with the `sc_` form builder.** |
| (b) Moderate | 40 | Includes the community payment components (`GenericCommunityPayment`, `HPEAPRequestCreate`, `CustomPaymentButton`, `paymentTerminal`) and the jQuery lookups. |
| (c) Complex | 37 | 3 are **theme layouts** (`AGRCustomTheme`, `ComplaintsThemeLayout`, `HiTheme`). These stay Aura unless the sites move to LWR. The `sc_` builder core (`sc_ApplicationForm` 1,714 LOC, `sc_Card`, `sc_FormField`, `sc_FormMultiLineInput`, `sc_MiniCard`, `sc_FieldInput`, `sc_FormSelectField`) uses dynamic `$A.createComponents` from metadata. The finance consoles are `GenericCreatePayment` (1,963), `BatchTransaction` (822), `RelatedListTreeViewer` (821), `GroupTransactions2` (769), `CreateTransaction` and `breg_CreateTransaction` (648/645, duplicates), `NewTransactionNoAccount`, `PaymentRecwkst` and `LicenseMassScanner`. |
| **Total** | **147** | |

Some bundles must stay Aura: `breg_NewAccountOverride` and `breg_NewCaseOverride` (standard-action overrides still need an Aura wrapper around an LWC), and the 3 theme layouts (Aura-template sites).

Aura-only features counted:
- `lightning:overlayLibrary`: 5 bundles (`BatchJobsExecute`, `RelatedListTreeViewer`, `RelatedListTreeViewerCell`, `flow`, `licenseLicenseeNameActions`) → `LightningModal`.
- `force:recordData`: 2 (`TransactionCashCheckPayment`, `TransactionCreditCardPayment`) → `getRecord`.
- `aura:method`: 26 bundles → `@api` methods.
- `$A.createComponent(s)`: 8 bundles → `lwc:component` dynamic import (requires LWS and the `lightning__dynamicComponent` capability).
- `force:*` events (`e.force:navigateToSObject`, `showToast`, `refreshView`, `closeQuickAction`): about 40 bundles → `NavigationMixin`, `ShowToastEvent`, `RefreshEvent`, `CloseActionScreenEvent`.
- `ui:*` (deprecated) components: 30 bundles.

### Top 15 migration candidates (value ÷ effort; security-driven first)

| # | Aura bundle(s) | Cat. | LOC | Why first | Target |
|---|---|---|---|---|---|
| 1 | `InputLookup`, `InputLookup2` | b | 233 / 273 | Removes jQuery 2.2.4, Bootstrap 3.3.6 and typeahead from community pages (F-05); 74 duplicated windows | One LWC lookup / `lightning-record-picker` |
| 2 | `Lookup`, `sc_Lookup` | b | 211 / 198 | Community-exposed dynamic-SOQL lookups (F-04); 100 duplicated windows | Same shared LWC lookup |
| 3 | `CustomRecordCreateField` (+ `2`, `3`) | c | 478 / 539 / 275 | `aura:unescapedHtml` (F-17); three near-copies | `lightning-record-edit-form` + `lightning-input-field` |
| 4 | `CustomPaymentButton` | b | 120 | Sandbox URL default (F-10); community payment entry | LWC with server-derived URL |
| 5 | `GenericCommunityPayment`, `HPEAPRequestCreate` | b | 286 / 233 | Community payment flows, 84 shared windows, weak error handling | One parameterised LWC |
| 6 | `TransactionCashCheckPayment`, `TransactionCreditCardPayment` | c* | 50 / 45 | "Complex" only because of `force:recordData`; small in practice | LWC quick actions with `getRecord` |
| 7 | `tktCreateTicketAction`, `tktMyTicketsAction`, `callQuickEntryAction`, `NewAppClassification` | a | 9–22 | Wrappers around existing LWCs | Expose the LWCs directly as `lightning__RecordAction`/`GlobalAction` |
| 8 | `D1D2DependencyRefund`, `LicenseTypeBatchJobs`, `DocusignLightningTest` | a | 12–36 | Headless quick actions (delete `DocusignLightningTest`) | LWC headless actions (`@api invoke`) |
| 9 | `MultiPicklist`, `sc_MultiPicklist`, `CustomMultiselect` | b/c | 171 / 176 / 271 | Three multiselects, 150 duplicated windows | `lightning-dual-listbox` / `pvlMultiSelectPicklist` |
| 10 | `files`, `fileList`, `FileDetailUploader`, `CustomFileDetailUploader`, `sc_Files`, `sc_FileUpload`, `CustomUploadButton` | a/b | 41–166 | Seven uploaders; tied to the SpringCM token fix (F-02) | One LWC uploader (ContentVersion, then async to CLM) |
| 11 | `loginForm` (+ `setStartUrl`, `setExpId` events) | b | 215 | Public login, `ui:` components, app events | Standard LWR/Aura login or an LWC login form |
| 12 | `CreateTransaction` + `breg_CreateTransaction` | c | 648 / 645 | 256 + 228 duplicated windows; one merged LWC halves the work | Single LWC with a division property |
| 13 | `GroupTransactions2` + `NewTransactionNoAccount` + `BatchTransaction` (+ 4 Lightning Out apps and VF pages) | c | 769 / 576 / 822 | Hardcoded RecordType Ids (F-10); Lightning Out and app events | LWC list-view actions and LMS |
| 14 | `Popup`, `PVLPopup`, `multiComp_popup`, `sc_popup`, `WizardModal`, `Popover`, `sc_Popover`, `LicensePopover` | a | 13–42 | Trivial; consolidates modal sprawl | `LightningModal`, `lightning-helptext` |
| 15 | `ListView`, `ListViewItem`, `ListViewHeader`, `RelatedList` | b/c | 335 / 179 / 69 / 135 | Community-exposed dynamic `ORDER BY` concatenation (`ListViewController.cls:12-13`) | `lightning-datatable` + wire `getListUi`/`getRelatedListRecords` |

Defer these until the above are done:
- the `sc_` form builder (it moves as a unit and is a large L/XL effort);
- `RelatedListTreeViewer*` (tree-grid with overlays and flows);
- `LicenseMassScanner` and `PaymentRecwkst` (internal back office).

## Appendix

### A. Community / Experience Builder–exposed components (public attack surface)

**LWC: 50 with `lightningCommunity__Page`/`__Default` and `isExposed=true`** (API version in brackets):
- breg_AccountInfo (64), breg_AgentSearch (65), breg_AnnualReports (63), breg_AuthenticateCertificate (64, guest), breg_CheckoutPage (64), breg_ELB_AdditionalServices (63), breg_EntityListBuilder (63), breg_FAQs (63), breg_Footer (63), breg_Header (63), breg_Home (63), breg_LoginRedirectionPage (65), breg_Manage (63), breg_MyBusinesses (64), breg_MyDashboardPage (64), breg_NameClearenceSearchComponent (58), breg_Payment (64), breg_PaymentAuthorizationNotice (65), breg_PaymentConfirmation (64), breg_PaymentRedirection (64), breg_Popup (63), breg_RegistrationChecker (65), breg_RegistrationDynamicFormModal (63), breg_SearchAndBuy (63), breg_SearchInput (63), breg_Shopping_Cart (63), breg_StartNewBusinessWizard (63), breg_Toast (63), breg_VerifyCompanyInfo (63)
- caseBREGComplaintEnglish (58), caseCATVComplaintEnglish (59), caseCaseEnglish (58), caseDCAComplaintEnglish (60), caseDFIComplaintEnglish (60), caseGeneralComplaintEnglish (59)
- catv_dashboard (63), catv_error_handling_cmp (62), catv_header (63), catv_provider_tabs (63), catv_registration_page (62, guest), catv_requestor_tabs (63)
- cmsIconLink (58), cmsIconWithBgImg (58), cmsIconWithCard (58), cmsNews (58), cmsNewsList (58)
- makePaymenttoMultipleFilings (56)
- sebCaseDocuments (65), sebSearch (65), sebSearchResult (65)

Also: `breg_MainMenu` declares community targets but `isExposed=false`. 90 LWCs are exposed in total (including record, app, flow and tab targets).

**Aura: 41 with `forceCommunity:*`**:
- Theme layouts: AGRCustomTheme, ComplaintsThemeLayout, HiTheme
- Record creation: AccountRecordSearchCreate, AccountRecordUpsert, ApplicationRecordsCreation, ApplicationRecordsWizard, CustomRecordCreate
- Registration and login: CustomCommunityRegistration, loginForm
- Payments: CustomPaymentButton, GenericCommunityPayment, GenericCreatePayment, HPEAPRequestCreate, paymentTerminal
- Files: CustomUploadButton, FileDetailCreator
- Lists and lookups: ListView, ListViewItem, Lookup, actionsOverriden
- Popups: PVLPopup, multiComp_popup, sc_popup
- Fiscal (TDR/JV): createApplication, generateTDR, generateTDRFile, jvFilters, newFiscalForms, tdrFilters
- `sc_` form builder: sc_ApplicationCreation, sc_ApplicationDetail, sc_ApplicationForm, sc_Card, sc_FormField, sc_FormMultiLineInput, sc_FormSelectField, sc_FormTableInput, sc_FormTextAreaField, sc_Lookup, sc_SummaryReview

**Guest-profile class grants relevant to these components** (from `profiles/` and `permissionsets/`):
- `CATV Portal Profile` (Guest): CATV_CustomLookUpController, CATV_SelfRegistrationController.
- `Digital Form Profile` (Guest): DraftApplicationDetailCont, **SpringCMConnector**, sc_LookupController.
- `BREG_Site_Guest_User` permission set: BREGCaseControllerWithoutSharing, BREGPaymentController, BREGPortalUtils (plus 19 more per 05 P-04).
- `DCCA BREG - CustomerCommunityLogin`: BREGPortalUtils, LookUpController, SecurityPortalTransactionsHelper, SpringCMConnector.

### B. Components without Jest tests

**All 232 LWC bundles** (0 have `__tests__`). Aura has no unit-test harness in the repo. Recommended first wave (highest risk × logic density):
- `utils`, `breg_BaseFormComponent`, `breg_Shopping_Cart`, `breg_CheckoutPage`, `breg_PaymentConfirmation`, `breg_FormsAndFees`, `breg_StartNewBusinessWizard`, `breg_RegistrationDynamicForm`;
- `breg_Member` and `breg_MembersChange` (about 1,160 and 1,380 LOC);
- `catv_custom_lookup`, `catv_provider_tabs`, `catv_requestor_tabs`, `makePaymenttoMultipleFilings`, `xLookup`, `lookupSearchResult`, `paymentDisplay`, `tDRForm`, `jVForm`.

### C. Third-party JavaScript library versions in `staticresources/`

| Resource / file | Library & version (from header) | Loaded by | Known issues |
|---|---|---|---|
| `Lgt_InputLookup/js/jquery-2.2.4.min.js` | jQuery 2.2.4 | `aura/InputLookup`, `aura/InputLookup2` | CVE-2015-9251, CVE-2019-11358, CVE-2020-11022, CVE-2020-11023 |
| `Lgt_InputLookup/js/bootstrap.min.js` | Bootstrap 3.3.6 | same | CVE-2018-14040, -14041, -14042, CVE-2019-8331 |
| `Lgt_InputLookup/js/typeahead.js`, `typeahead.js` (Private) | typeahead.js 0.10.5 (2014, unmaintained) | same | Renders HTML in templates; no fixes |
| `CustomTemplate/jquery.js` | jQuery 1.12.4 | not loaded (CSS only via `AGRCustomTheme`); **Public** cache | same jQuery CVEs |
| `CustomTemplate/jquery-migrate.js` | jQuery Migrate 1.4.1 | not loaded | re-enables unsafe legacy behaviours |
| `CustomTemplate/thickbox.js` | Thickbox 3.1 (2007) | not loaded | unmaintained |
| `CustomTemplate/jquery_002.js` | jQuery Cookie 1.3 | not loaded | unmaintained |
| `CustomTemplate/jquery_003.js` | Nivo Slider 3.2 | not loaded | unmaintained |
| `CustomTemplate/ga.js`, `analytics.js`, `tracker.js` (v6.3.1829), `embed_data/*.js` | Legacy Google Analytics, YouTube embed | not loaded | third-party tracking code in the org |
| `leaflet_1_0_2` | Leaflet 1.0.2 (referenced) | `aura/CustomRecordCreateMap` | **resource missing from repo** (F-11) |
| `SNA_*_sf_default_cdn_*` (6) | Experience Cloud LWR CDN bundles (SLDS/DXP CSS, images) | LWR sites | platform-generated; not audited |
| `mdslds212` | MDS/SLDS 2.1.2 SCSS | CSS only | n/a |

No PDF, moment, or chart libraries were found in static resources. PDF generation is done server-side (VF `renderAs=pdf`) and viewed with `c/utils.openPdfInNewTab`.

### D. Apex error-handling triage (LWC files importing Apex where `.then` > `.catch` or `await` > `try`)

- More `await` than `try`: `breg_Changes` (5/0), `breg_Expedited` (1/0), `breg_StocksAnnuals` (1/0), `breg_LoginRedirectionPage` (1/0), `cmsNews` (3/0), `cmsNewsList` (1/0), `customSelectInput` (1/0), `generatePicklistOptions` (2/0), `springFiles` (3/0), `sc_appBackup` (1/0), `breg_CheckoutPage` (createPayment outside `try`), `breg_FormFilingInternal`, `breg_VerifyCompanyInfo` (11/2), `breg_StartNewBusinessWizard` (12/5), `catv_provider_tabs` (14/0; relies on `.then/.catch`), `catv_requestor_tabs` (25/6), `tktMyTickets` (6/4).
- More `.then` than `.catch`: `jVForm` (3/0), `tDRForm` (3/0), `paymentDisplay` (3/0), `syncApp` (1/0), `springFileFix` (2/0), `catv_header` (3/1), `catv_registration_page` (3/2), `sebSearch` (3/1), `travelApprovalValidator` (2/1), `breg_bigObjectRelatedList` (1/0).
- Aura: `GenericCreatePayment` (11 callbacks / 0 error branches), `CustomPaymentButton` (1/0), `CustomRecordCreate` (3/0), `paymentTerminal` (3/1).

### E. LWCs below API v58 (23)

attestToMailingNotices 52, createAppClassification 48, customSelectInput 50, generatePicklistOptions 56, jVForm 49, jVTable 49, licenseTaxClearancer 52, lookupSearchResult 48, makePaymenttoMultipleFilings 56, paymentDisplay 56, pptToastListener 55, pvl_popup 56, sc_appBackup 56, sc_appRecover 56, sc_nav_cards 55, sc_pagination 55, sc_vnav_cards 55, sc_x_lookup 55, springFileFix 56, tDRAmountInput 50, tDRForm 48, tDRTable 49, xLookup 48.

Aura bundles at v38–41 (15): AGRCustomTheme, ComplaintsThemeLayout, CreateTransaction, CustomMultiselect, CustomPaymentButton, CustomRecordCreate, CustomRecordCreateField, CustomRecordCreateField3, CustomRecordCreateMap, CustomUploadButton, GenericCreatePayment, InputLookup, InputLookup2, MapIterationChildComponent, breg_CreateTransaction.
