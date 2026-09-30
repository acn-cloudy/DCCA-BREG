# 05 — Access Control & Security Posture

Scope: `force-app/main/default/` — profiles/ (96), permissionsets/ (140), permissionsetgroups/ (40, 4 custom), customPermissions/ (16), sharingRules/ (435 files, 114 rules), objects/ (233), cspTrustedSites/ (22), remoteSiteSettings/ (31), applications/ (48), tabs/ (121). There are **no** `sites/`, `networks/`, `experiences/`, `namedCredentials/`, `connectedApps/` or `settings/` folders in source, so site activation, guest-user permission-set assignments, named credential definitions, connected-app OAuth policies and session/password policies are **not verifiable** from this repo.

Method: every profile and permission set was parsed with a Python XML parser into a JSON model (user permissions, object permissions, FLS, class/page access, custom permissions, tabs, login IP ranges/hours). The model was cross-referenced against Apex classes classified by sharing keyword (`without sharing`: 135 classes, `with sharing`: 362, `inherited sharing`: 46, of 1,288 classes), `@RestResource` classes (14), sharing rules and object OWDs. The riskiest items were then confirmed by reading the XML.

Source-format caveats (these apply throughout):
- Profiles in this repo carry object permissions only for **custom** objects (about 173). Standard objects (Account, Contact, Case) and managed-package objects (`pymt__*`, `dsfs__*`) are **not** in the profile files. If a standard-object permission is missing, that proves nothing about the org.
- Source profiles list only enabled `userPermissions`. When a permission is absent it is *probably* disabled, but only a retrieve from the live org proves it.
- User → profile / permission-set assignments are not in metadata. Blast radius depends on how many users hold each grant. Pull that from the org with SOQL on `PermissionSetAssignment` and `User.ProfileId`.

## Summary

- **Unauthenticated users can probably read every payment transaction.** The `PaymentConnect` guest sharing rule shares every `Transaction__c` record that has a Status. The PaymentConnect guest profile has Read on the object plus FLS on 48 fields, including billing name, street, city and postal code, amounts and license numbers. Confirmed in metadata.
- **Unauthenticated Apex REST endpoints can forge financial records.** `PaymentREST` (`/CreatePayment`) and `TransactionREST` (`/CreateTransaction`) are `global without sharing` and have no caller check. They are granted to three guest profiles (`pre-payment`, `securities`, `transcripts`). Anyone who reaches those sites could insert `pymt__PaymentX__c`, `Transaction__c` and `Account` records with any amount and status.
- **External community users hold Modify All / View All on `Transaction__c`.** This applies to all three BREG community profiles, so any BREG portal user can read, edit and delete every transaction in the org.
- **Guest-reachable `without sharing` Aura controllers change records by caller-supplied Id with no ownership check.** Example: `BREGCaseControllerWithoutSharing` can set any Case to "Expedited" or re-point its Contact. Separately, 20 guest sharing rules share *all* complaint Cases, complainant Accounts, BREG entity records, draft license applications and OmniStudio definitions to public sites.
- **Nine profiles are System Administrator equivalents.** Four of them (`Integration`, `Wordpress Administrator`, `DCCA SEC/SEB System Administrator`, `DCCA System Administrator`) are **not** API-only and have **PasswordNeverExpires**. None of the 96 profiles has a login IP range or login hours. Three vendor or integration profiles (Accenture, Pacxa, Google) have org-wide read or user-management rights.
- **Internal sharing is effectively open.** 90 of 166 custom objects with an OWD are Public Read/Write, including `License__c`, `Application__c`, `SEBCase__c`, `HPEAPRequest__c` (holds last-4 SSN), `Deposits__c`, `FeeSchedule__c`, `BREG_ADDRESS_PROTECTION__c` and `Voice_Call_Session_Recording__c`. Also:
  - Three "Read-Only" permission sets grant View All on 264–323 objects.
  - One of them, `Read_Only_DCCA_Payments`, also grants **Modify All on `pymt__PaymentX__c`**.
- **The org is not following "minimum profile + permission sets".** It has 78 custom profiles, including clones (`DCCA PVL Limited Admin` is identical to `DCCA PVL Admin`), only 4 custom permission set groups and no muting permission sets. Access is carried mainly by profiles.
- **The network perimeter needs cleanup.** An active Remote Site points at a **pipedream.net request bin**. Others point at a raw-IP HTTP host (`http://44.232.202.215`), `http://icanhazip.com` and a staging tax endpoint. One CSP entry is a scheme-less wildcard (`*.qualtrics.com`), and third-party trackers are allowed every CSP directive. Secrets (passwords, a client secret, a DocuSign private key, an API token) are modelled as fields on **Public** custom metadata types and custom settings.

| Severity | Count |
|---|---|
| Critical | 6 |
| High | 11 |
| Medium | 11 |
| Low | 3 |
| **Total** | **31** |

## Dangerous Permissions Matrix

Rows are every profile or permission set that grants at least one of the key permissions (MAD, VAD, MU, Apex, Cust, MMeta, MPP, APS, MShr, RstPw, VAU, WklyExp, QAF). External profiles are also included if they grant `RunFlow` or `ApiEnabled`. "X" means the permission is enabled in the file.

Column key: MAD=ModifyAllData, VAD=ViewAllData, MU=ManageUsers, Apex=AuthorApex, Cust=CustomizeApplication, MMeta=ModifyMetadata, MPP=ManageProfilesPermissionsets, APS=AssignPermissionSets, MShr=ManageSharing, RstPw=ResetPasswords, VAU=ViewAllUsers, VSet=ViewSetup, ExpRpt=ExportReport, WklyExp=DataExport, API=ApiEnabled, APIonly=ApiUserOnly, PwNvr=PasswordNeverExpires, Flow=RunFlow, QAF=QueryAllFiles, MIP=ManageIpAddresses, ConnApp=ManageRemoteAccess, AuthProv=ManageAuthProviders.

| Type | Name | License | MAD | VAD | MU | Apex | Cust | MMeta | MPP | APS | MShr | RstPw | VAU | VSet | ExpRpt | WklyExp | API | APIonly | PwNvr | Flow | QAF | MIP | ConnApp | AuthProv |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Profile | Accenture User | Salesforce |  | X |  | X | X | X |  |  |  |  | X | X | X | X | X |  |  |  |  |  | X |  |
| Profile | Admin | Salesforce | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  |  |  |  | X | X | X |
| Profile | Analytics Cloud Integration User | Analytics Cloud Integration User |  | X |  |  |  |  |  |  |  |  | X | X |  |  | X | X | X |  | X |  |  |  |
| Profile | Analytics Cloud Security User | Analytics Cloud Integration User |  |  |  |  |  |  |  |  |  |  | X | X |  |  | X | X | X |  |  |  |  |  |
| Profile | Customer Community Login User | Customer Community Login |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | X |  |  |  |  |
| Profile | DCCA BREG - CustomerCommunityLogin | Customer Community Login |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | X |  |  |  |  |
| Profile | DCCA BREG - CustomerCommunityUser | Customer Community Login |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | X |  |  |  |  |
| Profile | DCCA BREG - Subscriber Login | Customer Community Login |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | X |  |  |  |  |
| Profile | DCCA ISCO Data Export | Salesforce |  |  |  |  |  | X |  |  |  |  |  | X |  | X | X |  |  |  |  |  |  |  |
| Profile | DCCA Integration1 | Salesforce | X | X |  | X | X | X | X | X | X |  | X | X | X | X | X | X |  |  |  | X | X |  |
| Profile | DCCA PVL Admin | Salesforce |  |  |  |  | X |  |  |  |  |  |  | X | X |  | X |  |  | X |  |  |  |  |
| Profile | DCCA SEB/SEC Administrator | Salesforce |  | X |  |  |  | X | X | X | X |  | X | X | X | X | X |  |  |  |  | X |  |  |
| Profile | DCCA SEC/SEB System Administrator | Salesforce | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  | X |  |  | X | X | X |
| Profile | DCCA System Administrator | Salesforce |  | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  | X |  |  | X | X | X |
| Profile | DocuSign Integration | Salesforce | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  |  |  | X | X | X |
| Profile | Google Integration User | Salesforce |  |  | X |  |  | X | X | X | X | X | X | X | X | X | X | X |  |  |  | X | X |  |
| Profile | Integration | Salesforce | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  | X |  |  | X | X | X |
| Profile | Pacxa User | Salesforce |  | X |  |  |  |  |  |  |  |  | X | X |  |  | X |  |  | X |  |  |  |  |
| Profile | Sales Insights Integration User | Sales Insights Integration User |  | X |  |  |  |  |  |  |  |  | X | X |  |  | X | X | X |  |  |  |  |  |
| Profile | Wordpress Administrator | Salesforce | X | X | X | X | X | X | X | X | X | X | X | X | X | X | X |  | X |  |  | X | X | X |
| PermSet | BREG_Integration_User_Permissions | - |  |  |  | X |  | X |  |  |  |  |  | X |  |  | X |  |  |  |  |  |  |  |
| PermSet | DCCA_ISCO | - |  |  |  |  |  |  |  |  |  |  |  |  |  | X |  |  |  |  |  |  |  |  |
| PermSet | JKEC_Manage_MFA_in_API | - |  |  | X |  |  |  | X | X | X | X | X | X |  |  |  |  |  |  |  | X |  |  |
| PermSet | Multi_Factor_Authentication_in_API | - |  |  | X |  |  |  | X | X | X | X | X | X |  |  |  |  |  |  |  | X |  |  |
| PermSet | QueryAllFiles | - |  | X |  |  |  |  |  |  |  |  |  | X |  |  |  |  |  |  | X |  |  |  |
| PermSet | SEBSECAdministrator | - |  |  | X |  |  |  | X | X | X | X | X | X | X |  |  |  |  |  |  | X |  |  |

How widely other permissions are granted (profiles + permission sets):

| Permission | Grants | Notes |
|---|---|---|
| ApiEnabled | 87 | Almost every internal profile; API access is not restricted to integration users |
| ExportReport | 73 | Includes PVL/SEC staff and `License API Only` profiles |
| ViewSetup | 53 | |
| RunFlow | 51 | All BREG community profiles and `Customer Community Login User`; **no guest profile in source has RunFlow** |
| TransferAnyEntity | 19 | Includes PVL Applications/Records/Supervisor and SEC Clerical/Exam Supervisor/Reviewer staff profiles, plus `Call_Center_Case_Access` and `UJET_Agent` permission sets |
| EditReadonlyFields | 12 | Includes `DCCA PVL Admin`, `DCCA PVL Limited Admin`, `DCCA PVL Limited Admin2`, `Pacxa User` |
| ManageLoginAccessPolicies / ManagePasswordPolicies | 12 / 12 | Includes the three MFA / SEB-SEC permission sets |
| ManageCustomPermissions | 11 | Includes `DCCA PVL Admin`, `DCCA PVL Limited Admin` |
| PrivacyDataAccess / ManageDataIntegrations | 10 / 10 | Includes vendor profiles `Accenture User`, `Pacxa User` |
| InstallPackaging | 3 | `Admin`, `DocuSign Integration`, `Wordpress Administrator` |
| BypassMFAForUiLogins, ViewEncryptedData, ManageEncryptionKeys, BulkApiHardDelete | 0 | Not granted anywhere in source |

## Findings

### [CRITICAL] ID P-01: Guest users of the PaymentConnect site can read all Transaction records, including payer billing identity

**Confidence**: Confirmed (metadata). Likely (live exposure — depends on the PaymentConnect site being active; the Remote Site `PaymentConnectSiteURL` → `https://hawaiidcca.secure.force.com` suggests it is).

**Evidence**:
- `force-app/main/default/sharingRules/Transaction__c.sharingRules-meta.xml` L349–363: `<sharingGuestRules><fullName>Site_Guest_User</fullName><accessLevel>Read</accessLevel><sharedTo><guestUser>PaymentConnect</guestUser>` with criteria `Status__c notEqual ''`. This matches every transaction that has a status.
- `force-app/main/default/sharingRules/Filing__c.sharingRules-meta.xml` L33: `SiteGuestUser` Read to `guestUser PaymentConnect` with criteria `Status__c notEqual ''`.
- `force-app/main/default/profiles/PaymentConnect Profile.profile-meta.xml` (`<userLicense>Guest User License</userLicense>` L37000):
  - L34327–34336: `Transaction__c` `allowCreate=true`, `allowRead=true`.
  - FLS readable on 48 `Transaction__c` fields, including `BillingFirstName__c`, `BillingLastName__c`, `BillingStreet__c`, `BillingCity__c`, `BillingPostalCode__c`, `AccountAddress__c`, `PersonAccountContact__c`, `PaymentAmount__c`, `TotalAmount__c`, `LicenseNumbers__c` (editable) and `SEB_Case__c`.
  - `Filing__c` CR.
- `Transaction__c` OWD is Private/Private (`objects/Transaction__c/Transaction__c.object-meta.xml`), so the guest rule is the only thing opening it up.

**Impact**: An anonymous user can enumerate every DCCA payment transaction org-wide through standard Aura/UI API calls on the site (for example `getRecord`, list views or `/services/data` via the guest session). That exposes payer names, addresses, amounts, license numbers and related SEB case Ids. For a government regulator this is a reportable PII disclosure.

**Recommendation**:
1. Delete or narrow `Site_Guest_User` (Transaction__c) and `SiteGuestUser` (Filing__c).
2. Guest flows should look up a single transaction through a `with sharing` or user-mode Apex method, keyed by an unguessable token (for example a hashed reference plus amount). Do not use a sharing rule.
3. Remove Read FLS on billing and address fields from the guest profile.
4. Review Setup → Guest User Sharing Rule audit and run the Salesforce "Guest User Access Report".

**Effort**: M

### [CRITICAL] ID P-02: Unauthenticated Apex REST endpoints (`/CreatePayment`, `/CreateTransaction`) granted to guest profiles

**Confidence**: Confirmed (class access grant). Likely (exploitability — Apex REST on a site is reachable at `https://<site>/services/apexrest/...` for the guest user when class access is granted).

**Evidence**:
- `force-app/main/default/classes/PaymentREST.cls` L5–8: `@RestResource(urlMapping='/CreatePayment') global without sharing class PaymentREST { @HttpPost ...`. It inserts `pymt__PaymentX__c` with caller-supplied `PaymentAmount`, `Status`, `pymt__Transaction_Id__c`, `Card_Type`, `Last_4_Digits`. There is no authentication or signature check. Exception messages are echoed back to the caller (L59).
- `force-app/main/default/classes/TransactionREST.cls` L5–8: `global without sharing` `@HttpPost`. It creates `Transaction__c` and new Person or Business `Account` records from the JSON body.
- Class access `<apexClass>PaymentREST</apexClass>` / `<apexClass>TransactionREST</apexClass>` `<enabled>true</enabled>` in:
  - `profiles/pre-payment Profile.profile-meta.xml` L3844 / L4624
  - `profiles/securities Profile.profile-meta.xml` L3844 / L4624
  - `profiles/transcripts Profile.profile-meta.xml` L3844 / L4624
  - also `profiles/DCCA BREG - CustomerCommunityLogin.profile-meta.xml` (external authenticated users)

**Impact**: Anyone on the internet could:
- Create payment records marked with any status (for example "Completed") against any transaction whose external Id they know or guess. That could satisfy fees or licensing prerequisites without paying.
- Create arbitrary Accounts and Transactions, polluting financial and reconciliation data. The guest profiles also have access to `ReconciliationBatchJob` and `PaymentXBatch` classes.

**Recommendation**:
1. Remove these two classes from every guest and community profile right away.
2. Expose them only to a dedicated integration user (API-only, `Salesforce Integration` license) over OAuth via a connected app.
3. Convert them to `with sharing` or user mode, and validate the caller (for example a named-credential-backed HMAC).
4. Stop echoing `ex.getMessage()` to the caller.

**Effort**: S (remove grants) / M (re-platform the integration)

### [CRITICAL] ID P-03: External community users hold Modify All / View All on `Transaction__c`

**Confidence**: Confirmed.

**Evidence**:
- `profiles/DCCA BREG - CustomerCommunityLogin.profile-meta.xml` L33895–33903: `<allowCreate>true</allowCreate><allowDelete>true</allowDelete><allowEdit>true</allowEdit><allowRead>true</allowRead><modifyAllRecords>true</modifyAllRecords><object>Transaction__c</object>…<viewAllRecords>true</viewAllRecords>`.
- `profiles/DCCA BREG - CustomerCommunityUser.profile-meta.xml` L33835–33843: same block.
- `profiles/DCCA BREG - Subscriber Login.profile-meta.xml` L33835–33843: same block.
- All three are `<userLicense>Customer Community Login</userLicense>`.

**Impact**: View All / Modify All ignores OWD, sharing and external sharing. Every BREG portal user (a member of the public who self-registered) can read, edit and delete every transaction for every division (PVL, INS, RICO, BREG and others). That includes other people's billing identities and payment amounts. It also allows tampering with outstanding balances.

**Recommendation**:
1. Set `modifyAllRecords`, `viewAllRecords` and `allowDelete` to false on these three profiles.
2. Give community users access to their own transactions through sharing sets or Account-based sharing (the external OWD is already Private).
3. Check the org for any other external profile with View All / Modify All. None was found in source apart from these three.

**Effort**: S

### [CRITICAL] ID P-04: Guest-reachable `without sharing` Aura controllers perform DML on caller-supplied record Ids

**Confidence**: Likely. The class grants are confirmed. Assignment of `BREG_Site_Guest_User` to the BREG guest user is inferred from its name and from the matching guest sharing rules, because assignments are not in source.

**Evidence**:
- `permissionsets/BREG_Site_Guest_User.permissionset-meta.xml` L24, L40: grants `BREGCaseControllerWithoutSharing` and `BREGContactControllerWithoutSharing`. In total it grants 22 classes, 15 of them `without sharing`, including `BREGPaymentController`, `BREGPortalUtils` and `DocuSignJWT`. Object perms: Case CR, Account CR (L1771–1781).
- `classes/BREGCaseControllerWithoutSharing.cls` L1–40, `public without sharing`:
  - `updateCasesProcessingSpeed(List<Id>)` sets `breg_Processing_Speed__c='Expedited'` on any Case Ids passed in.
  - `updateCaseContact(caseId, contactId)` re-points any Case's Contact.
  - `updateCaseSubscriptionCheckbox` flips alert subscriptions.
  - None of the three checks that the caller owns the record.
- `classes/BREGContactControllerWithoutSharing.cls` L1–60: `createNewContact`, plus `findExistingContact`, which returns a Contact Id when the full name, email, phone and address match. That is a PII existence oracle.
- `profiles/pre-payment Profile.profile-meta.xml` L2252 (also `securities` and `transcripts`): `CustomRecordCreate` (`public without sharing`, 692 lines, many `@AuraEnabled` methods) plus 17 other `without sharing` classes (`CreateTransaction`, `GenericCommunityPaymentController`, `InvestigationAllHandler`, `TransactionHandler` and others).
- `profiles/Digital Form Profile.profile-meta.xml`: 10 of 15 granted classes are `without sharing`, including `sc_ApplicationController`, `DraftApplicationService` and `sc_UserSelector`. `sc_ApplicationController.loadPreValues(appCacheName)` and similar methods read draft applications (`Application_Cache__c`, Text Name field) by caller-supplied name.
- `permissionsets/External_CATV_Provider` and `External_CATV_Requestor`: `CATV_WithoutSharingUtility`, which provides generic `doInsert`/`doUpdate`/`doDelete` and `queryRecords(String query, …, AccessLevel.SYSTEM_MODE)`. Those are public (non-Aura) helpers, so exposure depends on the calling controllers.

**Impact**: Guest users effectively have **edit** rights (through system-mode Apex) on Cases and other objects they do not own. Examples: an anonymous caller can escalate any BREG filing to Expedited processing without paying the expedite fee, or re-assign a case's contact to themselves. The task rules classify guest edit/delete as Critical.

**Recommendation**:
1. For every class granted to a guest profile or guest permission set, switch to `with sharing` or `WITH USER_MODE`.
2. Add ownership checks (for example a session token tied to the Case or transaction).
3. Move the few operations that genuinely need system mode into narrowly scoped inner methods.
4. Coordinate with the Apex review (report 0x) for per-method fixes.

**Effort**: L

### [CRITICAL] ID P-05: Guest sharing rules share entire record populations (complaints, complainant accounts, BREG entities, draft applications, OmniStudio definitions) to public sites

**Confidence**: Confirmed for the rules themselves. Likely for effective exposure. Guest Read on the standard objects Case and Account for the `dcca` site cannot be verified because standard-object permissions are not in source. `Digital Form Profile` has no Read on `Application_Cache__c` in source, so that path is exposed through the `without sharing` Apex in P-04.

**Evidence** (all `sharingGuestRules`, `accessLevel` Read, criteria effectively "all records"):

| File (sharingRules/) | Rule | Guest site | Criteria |
|---|---|---|---|
| Case.sharingRules-meta.xml L429/443/457/471 | GuestUserCaseAccessCableComplaint / DCAComplaint / DFIComplaint / GeneralComplaint | dcca | RecordType = CATV / DCA / DFI / General Complaint |
| Account.sharingRules-meta.xml L23 | ShareComplainantAccounts | dcca | RecordType = Complainant |
| Account.sharingRules-meta.xml L37 | BREG_Site_Guest_User_Sharing | BREG | RecordType = BREG Account |
| breg_Account_Affiliation__c, breg_Annual__c, breg_Document__c, breg_Fee__c, breg_Transaction__c | BREG_Site_Guest_User_Sharing | BREG | Name != '' |
| breg_Form_Configuration__c | BREG_Guest_User | BREG | Name != '' |
| Knowledge__kav | breg_Knowledge_sharing | BREG | breg_Topic__c != '' |
| Application_Cache__c.sharingRules-meta.xml L4 | Enable_Guest_User | Digital_Form | Name != '1' |
| OmniProcess / OmniDataTransform / OmniUiCard / OmniESignatureTemplate | Omni_*_Guest_User | dcca | Name != '' / CreatedById startsWith '005' |

- `Application_Cache__c` is labelled "Draft Application". Its `FormData__c`, `AppDataBeforeSubmit__c` and `AppFileData__c` (long text, 32–131 KB) hold in-progress license application data.

**Impact**:
- Complaint Cases and "Complainant" person accounts identify members of the public who filed complaints against licensees. Making them readable by anonymous users is a serious privacy breach and could enable retaliation.
- `breg_Account_Affiliation__c` (officers and agents of a business) may be intentionally public for business search. However, the "all records" criteria also cover inactive or pending rows.
- Sharing every OmniStudio DataRaptor or Integration Procedure definition exposes internal object and field mappings and makes guest-invocable data extraction easier.

**Recommendation**:
1. Remove the four Case rules and `ShareComplainantAccounts`. Complaint intake does not require guest Read after insert.
2. For the BREG business search, restrict criteria to publicly filed statuses and expose only the needed fields through a `with sharing` selector.
3. Remove `Enable_Guest_User` on `Application_Cache__c`.
4. Limit the Omni guest rules to the specific processes used by the site (for example with a `Guest_Enabled__c` flag).

**Effort**: M

### [CRITICAL] ID P-06: Interactive-login admin-equivalent profiles with ModifyAllData and PasswordNeverExpires; nine admin-equivalent profiles overall

**Confidence**: Confirmed (metadata). User counts per profile are not verifiable from source.

**Evidence**:
- `profiles/Integration.profile-meta.xml`: `ModifyAllData` L38525 true, `PasswordNeverExpires` L38557 true. No `ApiUserOnly`, so it can log in to the UI.
- `profiles/Wordpress Administrator.profile-meta.xml`: `ModifyAllData` L38598 true, `PasswordNeverExpires` L38634 true, no `ApiUserOnly`. It also grants `InstallPackaging`, `ManageAuthProviders` and `ManageRemoteAccess`.
- `profiles/DCCA SEC%2FSEB System Administrator.profile-meta.xml`: `ModifyAllData` L38532 true, `PasswordNeverExpires` L38564 true.
- `profiles/DCCA System Administrator.profile-meta.xml`: `ViewAllData` L38832, `PasswordNeverExpires` L38724, plus ManageUsers, AuthorApex, ModifyMetadata, ManageProfilesPermissionsets and AssignPermissionSets. ModifyAllData is absent but Modify All Records is set on 91 objects.
- Admin-permission overlap against the standard `Admin` profile (235 enabled permissions): Google Integration User 90%, Accenture User 88%, DocuSign Integration 81%, Wordpress Administrator 80%, DCCA SEC/SEB System Administrator 75%, Integration 72%, DCCA Integration1 71%, DCCA System Administrator 71%.
- No `<loginIpRanges>` or `<loginHours>` element exists in any of the 96 profiles.

**Impact**:
- A long-lived, never-rotated password on a UI-capable Modify All Data account is the single highest-value credential in the org. Phishing it or reusing it gives full data and metadata control.
- There are no IP or hours restrictions to limit that damage.
- "Wordpress Administrator" suggests a website integration account holding full System Administrator rights.

**Recommendation**:
1. Consolidate to one or two administrator profiles.
2. Remove `PasswordNeverExpires` from every non-integration profile.
3. Convert integration accounts to the `Salesforce Integration` license with the existing `Minimum Access - API Only Integrations` or `Salesforce API Only System Integrations` profiles plus scoped permission sets.
4. Add login IP ranges for administrator and integration profiles, and enforce MFA (verify in org).
5. Run the Health Check.

**Effort**: M

### [HIGH] ID P-07: PaymentConnect guest profile can create records on 33 back-office objects and read License data including FEIN

**Confidence**: Confirmed.

**Evidence**:
- `profiles/PaymentConnect Profile.profile-meta.xml` grants `allowCreate=true` on `Investigation__c` (L34087–34095), `Sanction__c`, `LegalAction__c`, `Allegation__c`, `AllegationViolation__c`, `Violation__c`, `SEBCase__c`, `SEBCaseTeam__c`, `SEBCaseContact__c`, `FeeSchedule__c` (L34007–34015), `CashierCode__c`, `Deposits__c`, `CollectionsAllocation__c`, `DocGeneratorSettings__c`, `DocGeneratorDataSource__c`, `TimeandExpenseHeader__c`/`Details__c`, `Exam__c`, `Filing__c`, `Application__c`, `Transaction__c`, `TransactionLine__c` and others (33 objects with Create).
- It also grants Read on `License__c` (L34177–34186) with FLS on 471 License fields, including `License__c.FEIN__c` (L16648), `AccountFEIN__c` and `AccountStateExciseTaxNumber__c`.
- Readable FLS in total: 1,063 fields. Editable: 123.
- `EmailSingle` and `EditTask` are enabled on this guest profile.

**Impact**: Anonymous users can inject records into enforcement case files (investigations, sanctions, legal actions), fee configuration (`FeeSchedule__c`, `CashierCode__c`) and cash-handling objects (`Deposits__c`). License FEINs are exposed wherever records are shared or returned by system-mode Apex; the guest-accessible renewal classes are `without sharing`.

**Recommendation**:
1. Rebuild the PaymentConnect guest profile from scratch with only the objects the payment page actually inserts (probably `Transaction__c`/`TransactionLine__c` through Apex).
2. Remove Create on enforcement, configuration and cash objects.
3. Remove FEIN and tax FLS.
4. Remove `EmailSingle` and `EditTask`.

**Effort**: M

### [HIGH] ID P-08: Guest profiles are granted back-office Visualforce pages, batch-launching controllers and test classes

**Confidence**: Likely. Page access is confirmed. Whether the batch actually runs also depends on guest Read on the standard-controller object.

**Evidence**:
- `profiles/pre-payment Profile.profile-meta.xml` L33974–34374 (identical in `securities Profile` and `transcripts Profile`) grants `CompletePaymentsDeposit`, `DepositRollupsButton`, `RunReconciliationBatch`, `PaymentCutOffBatch`, `SendTo4Gov`, `PaymentAutoCloserMonitor`, `BatchTransaction`, `InvoiceBatchTransaction`, `PaymentXBatchProgress`, `TransactionRefundAuthFormPdf` and others (39 pages).
- `pages/CompletePaymentsDeposit.page`: `<apex:page standardController="Deposits__c" extensions="CompletePaymentsDeposit" action="{!AddCompletePayments}">`. `classes/CompletePaymentsDeposit.cls` L15, L24 (no sharing keyword): `Database.executeBatch(new AsyncCompletePaymentsDeposit(this.depositId), 20)`. The batch runs **on page load**.
- `pages/DepositRollupsButton.page`: `action="{!StartRollupBatch}"`, also on page load.
- The same three profiles grant 125 Apex classes, 62 of them `@isTest` classes (for example `PaymentRESTTest`, `TransactionRESTTest`, `SEBCaseAllTest`).

**Impact**: Cashier and finance operations (deposit completion, roll-ups, reconciliation re-runs, 4Gov exports, payment cut-off) are reachable from the public URL. At minimum this is a denial-of-service and data-integrity vector. It also signals that these guest profiles were cloned from an internal cashier profile.

**Recommendation**:
1. Remove all non-portal pages and all test classes from guest profiles.
2. Keep only the landing, login, self-registration, error and payment pages the site needs.
3. Add explicit `Site.getSiteId()` / user-type guards in back-office controllers as defence in depth.

**Effort**: S

### [HIGH] ID P-09: `SEBSearchController` (`without sharing`) exposed to the `dcca` guest profile returns Pending enforcement subjects

**Confidence**: Likely.

**Evidence**:
- `profiles/dcca Profile.profile-meta.xml` L4248: `<apexClass>SEBSearchController</apexClass>` enabled. The profile also has `UploadCaseFileToDocSignQueueable` (`without sharing`).
- `classes/SEBSearchController.cls` L9: `public without sharing class`.
  - `searchSEBCaseContacts` returns Contacts linked to SEB cases with `CaseResult__c IN ('Closed','Pending','Legal Action Taken','Warning Letter Issued')`. It does **not** filter on `Public__c`.
  - `getContactSEBCases(contactId)` also omits `Public__c`, so it returns case numbers and results for any contact Id.
  - Only `getCaseContactDocuments` enforces `SEBCaseContact__r.Public__c = true`.

**Impact**: The names of people under *pending* securities enforcement can be enumerated by the public before any action is taken. That creates reputational and legal risk for the agency.

**Recommendation**: Add `Public__c = true` to all three queries, drop 'Pending', switch to `with sharing` plus a guest sharing rule scoped to public records, and add a rate limit or CAPTCHA.

**Effort**: S

### [HIGH] ID P-10: Vendor/contractor profiles hold org-wide read and metadata-authoring rights with no IP restriction

**Confidence**: Confirmed.

**Evidence**:
- `profiles/Accenture User.profile-meta.xml`: `ViewAllData` L38542, `AuthorApex` L37898, `CustomizeApplication` L38018 and `ModifyMetadata` L38390, all true. It also grants `ManageRemoteAccess` (connected apps), `ManageCertificates`, `ManageCustomDomains`, `DataExport`, `PrivacyDataAccess` and `ViewEventLogFiles`. View All Records is set on 166 objects. The profile has 88% overlap with `Admin`.
- `profiles/Pacxa User.profile-meta.xml`: `ViewAllData` L38428 and `ApiEnabled` L38232, plus `ViewAllUsers`, `ManageDataIntegrations`, `EditReadonlyFields`, `PrivacyDataAccess` and View All Records on 166 objects. `Pacxa User` is 92.8% similar to `Sales Insights Integration User`.
- Neither profile has `<loginIpRanges>`.

**Impact**: Named third-party firms can read all regulated data (SSN fragments, FEINs, complaint and enforcement records, payment data) and, for Accenture, deploy code and change metadata in production. This breaks least privilege and complicates any data-breach attribution.

**Recommendation**:
1. Retire vendor-named profiles.
2. Grant vendors time-boxed permission sets (use permission set assignment expiration) on a minimum profile. Keep them sandbox-only where possible.
3. Require IP ranges for any vendor production access.

**Effort**: S

### [HIGH] ID P-11: Integration profiles hold full System Administrator rights

**Confidence**: Confirmed.

**Evidence**:
- `profiles/DocuSign Integration.profile-meta.xml`: `ApiUserOnly` L38076 true, `ModifyAllData` L38576 true, plus ManageUsers, AuthorApex, ModifyMetadata, InstallPackaging and ManageAuthProviders. The description reads "Created for PaymentSupport case18871. API Only Profile".
- `profiles/DCCA Integration1.profile-meta.xml`: `ApiUserOnly` L38074, `ModifyAllData` L38506.
- `profiles/Google Integration User.profile-meta.xml`: `ApiUserOnly` L38250, `AssignPermissionSets` L38278, `ManageUsers` L38770, plus ManageProfilesPermissionsets, ModifyMetadata, ResetPasswords and Modify All Records on 165 objects. It also holds UI custom permissions `BCFandDisputedChargeButtonsCustomPermission` and `Single_Receipt`, a sign that it was cloned from Admin.
- `permissionsets/BREG_Integration_User_Permissions.permissionset-meta.xml`: `AuthorApex` L65, `ModifyMetadata` L73.
- Minimum-access integration profiles already exist but are nearly empty: `Minimum Access - API Only Integrations` has 3 user permissions and `Salesforce API Only System Integrations` has 3.

**Impact**: A leaked OAuth token or JWT key for DocuSign, Google Voice/CCAI or BREG middleware gives full control of the org, including creating admin users (ManageUsers + AssignPermissionSets).

**Recommendation**: Move each integration to the `Salesforce Integration` license with a minimum API-only profile and a purpose-built permission set: object CRUD only on what it touches, no ModifyAllData, no ManageUsers. Rotate the credentials afterwards.

**Effort**: M

### [HIGH] ID P-12: Delegated user/permission administration permission sets create a privilege-escalation path

**Confidence**: Confirmed.

**Evidence**:
- `permissionsets/SEBSECAdministrator.permissionset-meta.xml`: `AssignPermissionSets` L96, `ManageProfilesPermissionsets` L144 and `ManageUsers` L156, plus ResetPasswords, ManageLoginAccessPolicies, ManagePasswordPolicies, ManageIpAddresses, ManageSharing and Modify All Records on 6 SEB objects.
- `permissionsets/Multi_Factor_Authentication_in_API.permissionset-meta.xml`: `AssignPermissionSets` L8, `ManageUsers` L52, plus ManageTwoFactor and ManageProfilesPermissionsets. Its description says "Do not assign to standard users."
- `permissionsets/JKEC_Manage_MFA_in_API.permissionset-meta.xml`: identical (Jaccard 1.0).
- `profiles/DCCA SEB%2FSEC Administrator.profile-meta.xml`: `ViewAllData` L38512, `AssignPermissionSets` L38232, `ManageInternalUsers` L38376, `ManageProfilesPermissionsets` L38396, plus Modify All Records on 91 objects.

**Impact**: Any holder of ManageProfilesPermissionsets + AssignPermissionSets can grant themselves `ModifyAllData` by editing or assigning a permission set. These sets are effectively System Administrator. An "MFA in API" set carrying full user management is especially surprising.

**Recommendation**:
1. Replace these with Delegated Administration (Setup → Delegated Groups) scoped to SEB/SEC roles.
2. Delete `JKEC_Manage_MFA_in_API`, which is a duplicate.
3. Strip `Multi_Factor_Authentication_in_API` down to `ManageTwoFactor` only, if it is needed at all.

**Effort**: S

### [HIGH] ID P-13: "Read-Only" permission sets grant View All on hundreds of objects, and one grants Modify All on payments

**Confidence**: Confirmed.

**Evidence**:
- `permissionsets/Read_Only_DCCA_Payments.permissionset-meta.xml` (label "Read-Only DCCA Payments"): View All Records on 264 objects. L19158–19167: `<allowDelete>true</allowDelete><allowEdit>true</allowEdit>…<modifyAllRecords>true</modifyAllRecords><object>pymt__PaymentX__c</object>`.
- `permissionsets/Read_Only_BREG.permissionset-meta.xml`: View All on 323 objects, including `HPEAPRequest__c` (last-4 SSN), `SEBCase__c`, `Investigation__c`, Case, Contact and `Application_Cache__c`. It also grants 720 classes and 266 pages.
- `permissionsets/Read_Only_eTravel.permissionset-meta.xml`: View All on 268 objects.
- `permissionsets/QueryAllFiles.permissionset-meta.xml`: `ViewAllData` L5836 and `QueryAllFiles` L5832, plus View All on 567 objects. The description says only "Grants the 'Query All Files' permission".
- `permissionsets/Hoala_Access`, `DCCA_Ho_ala_Objects_Read_Only` and `RICO_Transactions`: View All on 47–49 objects each, including License, Application and PrelicenseCEEnrollment (`Last4ofSSN__c`).

**Impact**: The labels ("Read-Only", "QueryAllFiles") hide org-wide data visibility and, for payments, delete rights. Administrators assigning a "read-only BREG" set to a BREG clerk actually grant them every complaint, enforcement case and SSN fragment in the org.

**Recommendation**:
1. Rebuild each read-only set with Read (not View All) scoped to its business area, and rely on sharing.
2. Remove Modify All and Delete on `pymt__PaymentX__c` from `Read_Only_DCCA_Payments`.
3. Split `QueryAllFiles` so that it grants only `QueryAllFiles` (which does not require ViewAllData).

**Effort**: M

### [HIGH] ID P-14: `DCCA ISCO Data Export` profile combines ModifyMetadata, weekly Data Export and Modify All on enforcement and payment objects

**Confidence**: Confirmed.

**Evidence**: `profiles/DCCA ISCO Data Export.profile-meta.xml`:
- `DataExport` L36832 and `ModifyMetadata` L36920, plus ViewSetup, TransferAnyEntity, ViewEventLogFiles and ManageNetworks.
- Modify All Records on 27 objects: `SEBCase__c`, `Investigation__c`, `Sanction__c`, `LegalAction__c`, `Allegation__c`, `Transaction__c`, `TransactionLine__c`, `Deposits__c`, `FeeSchedule__c`, `Filing__c`, `Exam__c` and others. View All on `CashierCode__c`.
- Related permission set `DCCA_ISCO` grants only `DataExport`.

**Impact**: A data-export role should be read-only. This profile can alter enforcement and financial records and change metadata, and it holds the bulk-export capability, which makes it an ideal exfiltration account.

**Recommendation**: Replace the profile with the `DCCA_ISCO` permission set on a minimum profile. Remove ModifyMetadata and all Modify All grants.

**Effort**: S

### [HIGH] ID P-15: Non-admin staff profiles and permission sets hold Modify All on licensing, payment, enforcement and recording objects

**Confidence**: Confirmed.

**Evidence**: grouped instances (object-level `modifyAllRecords=true`):

| Grant | Type | License | Modify All on (examples) |
|---|---|---|---|
| DCCA PVL Admin / DCCA PVL Limited Admin | Profile | Salesforce | 48 objects incl. `License__c`, `Application__c`, `LicenseHistory__c`, `Transaction__c`, `TransactionLine__c`, `RICOReferral__c` |
| DCCA PVL Supervisor | Profile | Platform | 41 objects incl. `License__c`, `Application__c`, `RICOViolation__c` |
| DCCA Admin | Profile | Platform | 38 objects incl. `License__c`, `Transaction__c`, `TransactionLine__c` |
| DCCA Integration | Profile | Platform | 43 objects incl. `License__c`, `Transaction__c`, `TravelApproval__c`, `CashierCode__c` |
| DCCA Cashier / DCCA Maui BAC - New / Payment API Only | Profile | Platform | `Transaction__c`, `TransactionLine__c` |
| DCCA SEB Intake / Supervisor / Attorney | Profile | Platform | `SEBCase__c`, `Investigation__c` |
| DCCA SEC Exam Supervisor | Profile | Platform | `Exam__c` |
| Payment_Delete_Permission | PermSet | – | `Transaction__c`, `TransactionLine__c`, `pymt__PaymentX__c` |
| Google_Integration_Object_Access | PermSet | – | 14 incl. Account, Case, `Voice_Call_Session_Recording__c`, `UJET__UJET_Session__c` |
| BREG_Admin_User | PermSet | – | 11 incl. `BREG_ADDRESS_PROTECTION__c` (address-confidentiality program) |
| DCCA_HPEAP_Transcript_Requests | PermSet | Platform | `HPEAPRequest__c` (holds `LAST4OfSSN__c`) |
| Continuing_Education_Administrator | PermSet | Platform | 8 incl. `PrelicenseCEEnrollment__c` |
| SEBSECAdministrator | PermSet | – | `Allegation__c`, `LegalAction__c`, `Sanction__c`, `Violation__c`, `FileDetails__c`, `Deficiency__c` |

- In addition, View All on the licensing object set (about 24–27 objects including `License__c` and `PrelicenseCEEnrollment__c`) is granted to every PVL staff profile, `DCCA RICO Access`, and `License API Only` / `License RICO API Only`.

**Impact**: Modify All bypasses sharing, so the role and territory model the org has built (division-based `Transaction__c` sharing rules, SEB/SEC role rules) is undone for these users. Payment Modify All also allows silent refund or amount edits.

**Recommendation**:
1. Remove Modify All wherever the business need is "edit records in my division". Sharing rules already exist for that.
2. Keep Modify All only in small, audited "Super User" permission sets.
3. Add Field History and Field Audit Trail on payment amount and status fields.

**Effort**: M

### [HIGH] ID P-16: Internal OWD is Public Read/Write on 90 custom objects, including PII, licensing, enforcement and payment objects

**Confidence**: Confirmed.

**Evidence**: `<sharingModel>ReadWrite</sharingModel>` in `objects/<Obj>/<Obj>.object-meta.xml` for 90 objects (full table in Appendix A1). Examples:
- `License__c` (501 fields) and `Application__c` (443 fields)
- `SEBCase__c`, `RICOReferral__c`, `Violation__c`, `Deficiency__c`
- `HPEAPRequest__c` (`LAST4OfSSN__c`), `DFIRegistration__c`
- `Deposits__c`, `CashierCode__c`, `FeeSchedule__c`, `PaymentReconciliation__c`, `Reconciliation_Batch__c`
- `BREG_ADDRESS_PROTECTION__c`, `breg_WEB_WEB_PERSONS__c`
- `Voice_Call_Session_Recording__c`
- `SpringCLM_Session__c` (holds `AccessToken__c` / `RefreshToken__c`)
- `Account_Access_Request__c`, `PVL_Portal_User__c`

By contrast, only 7 objects are Private (`Transaction__c`, `FileDetails__c`, `StatusHistory__c`, `TravelApproval__c`, `Work_Item__c`, `tkt_Ticket__c`, `Application_Log__c`). `Exam__c` and `Filing__c` are Public Read Only.

**Impact**: Every internal user with object Read (for example a RICO clerk) can read, and with Edit can modify, every license, application and SEB case across divisions. `BREG_ADDRESS_PROTECTION__c` is Public R/W even though address protection exists to shield victims' addresses. The many division-scoped sharing rules the org maintains are pointless for these objects.

**Recommendation**:
1. Move sensitive objects to Private (or Public Read Only where cross-division lookup is required).
2. Recreate the needed access with division or record-type criteria sharing rules. The pattern already used for `Transaction__c` can serve as the template.
3. Start with `BREG_ADDRESS_PROTECTION__c`, `HPEAPRequest__c`, `SEBCase__c`, `Voice_Call_Session_Recording__c` and `SpringCLM_Session__c`.

**Effort**: L

### [HIGH] ID P-17: Credentials modelled as fields on Public custom metadata types and custom settings; OAuth tokens stored in a Public R/W object

**Confidence**: Likely. The field definitions are confirmed. The record values are not in source.

**Evidence**:
- `objects/Org_Credential__mdt/fields/Password__c.field-meta.xml` and `Key__c`. The object has `<visibility>Public</visibility>`.
- `objects/SpringCMApiEnvironment__mdt/fields/Client_Secret__c.field-meta.xml` (Public).
- `objects/breg_DocuSign_Auth__mdt/fields/Request_Private_Key__c.field-meta.xml` (Public). It is used by `DocuSignJWT`, which is granted to guest permission set `BREG_Site_Guest_User` (L84).
- `objects/TaxClearanceApi__c/fields/Password__c.field-meta.xml` and `Username__c` (Hierarchy custom setting, Public).
- `objects/qual_Integration_Settings__c/fields/qual_Api_Token__c.field-meta.xml` (Hierarchy custom setting, Public).
- `SpringCLM_Session__c.AccessToken__c` / `RefreshToken__c`: the object OWD is ReadWrite. FLS read/edit on these fields sits on external profiles `CATV Community Profile` (L20898, L20903) and `Customer Community Plus Login User`, and is granted to the 9 admin-equivalent profiles and to `Accenture User` / `Pacxa User` through View All.

**Impact**: Anyone with "View All Custom Settings" or "Customize Application" (11+ grants), or any code path running in system mode for a guest, can read integration passwords, DocuSign's RSA private key (allowing impersonation of the DocuSign API user) and SpringCM tokens. Protected packaging or Named Credentials would prevent this.

**Recommendation**:
1. Move secrets to Named Credentials / External Credentials. The code already uses `callout:DocuSign`, `callout:OracleGL` and others for some integrations.
2. Delete the secret fields.
3. Rotate every credential that has been stored this way.
4. Make `SpringCLM_Session__c` Private and remove token FLS from all external profiles.

**Effort**: M

### [MEDIUM] ID P-18: External sharing model more open than needed on 10 objects

**Confidence**: Confirmed.

**Evidence** (`<externalSharingModel>` in object-meta.xml):
- ReadWrite: `breg_Stock__c`, `breg_TN_TM_SM__c` (trade names/marks, 53 fields), `Field_Filter__c`, `util_closer_Batch_Log__c`
- Read: `Application_Cache__c` (Draft Application form data), `breg_Fee__c`, `breg_Form_Configuration__c`, `Application_Meta_Data__c`, `Card_Meta_Data__c`, `Field_Meta_Data__c`

**Impact**: Any external user with object Read sees all records. External Read/Write on `breg_TN_TM_SM__c` / `breg_Stock__c` lets any portal user who gains Edit alter other entities' trade-name and stock records. External Read on `Application_Cache__c` would expose all draft applications to any community user who is given object Read.

**Recommendation**:
1. Set `externalSharingModel` to Private for `Application_Cache__c`, `breg_Stock__c`, `breg_TN_TM_SM__c` and `util_closer_Batch_Log__c`.
2. Keep Read only for configuration and metadata objects (`breg_Fee__c`, `breg_Form_Configuration__c`, `*_Meta_Data__c`).

**Effort**: S

### [MEDIUM] ID P-19: Remote Site Settings include a request-bin, a raw-IP HTTP host, plaintext HTTP endpoints and staging endpoints in production

**Confidence**: Confirmed (metadata). Usage in code was checked by grep.

**Evidence** (`remoteSiteSettings/*.remoteSite-meta.xml`, all `isActive=true`):
- `test` → `https://eod2cgfefmvt6uf.m.pipedream.net`, a public request-inspection service. It is not referenced in source code.
- `WordpressSiteTestServer` → `http://44.232.202.215` (raw AWS IP, HTTP).
- `icanhazip` → `http://icanhazip.com`.
- `barcode_link` → `http://barcodes4.me`, used over HTTP in `classes/DocGeneratorDataSourceDomain.cls:100`.
- `TaxClearanceApiStagingEndpoint` → `https://hitaxstaging.hawaii.gov`.
- `QRCode` → `https://api.qrserver.com`. A third party receives the QR payload from `pages/PVL_Pocket_ID_PDF.page:184`.
- Duplicates: `Production_API` and `Production_Merge` both → `apina21.springcm.com`; `Google_CCAI_Platform` and `ccai_platform` → the same host.
- Hardcoded UAT SpringCM endpoints appear in non-test code, for example `classes/SpringCMConnector.cls:399` → `https://apiuatna11.springcm.com`.

**Impact**: An active pipedream endpoint is a ready-made exfiltration channel for any Apex or anonymous-Apex user. HTTP endpoints leak data in transit. A staging endpoint in production risks sending real taxpayer data to a lower-trust environment.

**Recommendation**:
1. Deactivate or delete `test`, `WordpressSiteTestServer`, `icanhazip`, `TaxClearanceApiStagingEndpoint` and duplicates.
2. Move `barcodes4.me` to HTTPS, or generate barcodes and QR codes on-platform.
3. Migrate the remaining endpoints to Named Credentials, which removes the need for Remote Site Settings.

**Effort**: S

### [MEDIUM] ID P-20: CSP Trusted Sites use a scheme-less wildcard and allow every directive for third-party trackers

**Confidence**: Confirmed.

**Evidence** (`cspTrustedSites/`):
- `Qualtrics_Wildcard` → `*.qualtrics.com` (no scheme, so HTTP is allowed), all directives, context All. It is redundant with `Qualtrics`, `Qualtrics_Frame` and `Qualtrics_Intercept`.
- `Google_CCAI_Platform` → `https://*.ccaiplatform.com`, all directives. `CCAIP_UW1_Connector` already pins the tenant host.
- `stats_g_doubleclick_net`, `www_google_analytics_com` and `www_googletagmanager_com` (three duplicate entries: `…com`, `…com1`, `…com2`) are all allowed for Connect, Frame, Font, Img, Media and Style on Communities.
- `hbe_dcca_hawaii_gov` duplicates `DCCA_BREG_Portal` (same URL).
- Legacy domains: `dccabreg.force.com`; `CommTrustedSite` → `https://hi-dcca--c.vf.force.com`.

**Impact**: Wildcards and all-directive grants widen the XSS and clickjacking blast radius on public portals. Tag-manager frame/connect permission lets marketing tags load arbitrary third-party scripts and beacon data from authenticated portal pages.

**Recommendation**:
1. Remove `Qualtrics_Wildcard` and the wildcard CCAI entry.
2. Restrict analytics hosts to Img/Connect only.
3. Delete duplicates and legacy `force.com` domains after verifying enhanced-domain redirects.

**Effort**: S

### [MEDIUM] ID P-21: Guest profiles carry unnecessary system permissions; OmniStudio guest permission set grants Designer

**Confidence**: Confirmed.

**Evidence**:
- All 9 guest profiles enable `ChatterEnabledForUser`, `AllowUniversalSearch`, `ContentWorkspaces`, `SelectFilesFromSalesforce` and `AddDirectMessageMembers`.
- `CATV Portal Profile` and `PaymentConnect Profile` also enable `EmailSingle` and `EditTask`.
- `permissionsets/OmniStudio_Guest_User.permissionset-meta.xml` L848: `OmniStudioDesigner` enabled (license `OmniStudioDesigner`) alongside `OmniStudioRuntime`, with Read on `OmniProcess`, `OmniDataTransform`, `OmniScriptSavedSession` and others.
- Nine guest profiles exist for what appear to be about 5 sites: BREG, CATV, Digital_Form, PaymentConnect, dcca. `pre-payment`, `securities` and `transcripts` share an identical 125-class / 39-page footprint. The standard `Guest License User` profile is also present.

**Impact**: `EmailSingle` on a guest lets the site send email as the org, which is a spam and phishing relay risk if any controller exposes it. Designer permission for guests is never required. Every extra guest profile is another public attack surface to maintain.

**Recommendation**:
1. Strip guest profiles to the documented minimum.
2. Remove `OmniStudioDesigner` from the guest permission set.
3. Confirm which sites are live and delete orphaned guest profiles.

**Effort**: S

### [MEDIUM] ID P-22: Sharing rules reference hardcoded user Ids and individual-person groups

**Confidence**: Confirmed.

**Evidence**:
- `sharingRules/FileDetails__c.sharingRules-meta.xml` L28: `Grant_Access_to_Kim_Umetsu_s_Records`, criteria `OwnerId equals 005t00000021c3TAAQ`.
- `sharingRules/Filing__c.sharingRules-meta.xml` L13: `Blake_Edit_Cara_s_Filings`, criteria `Reviewer__c equals 005t0000003TYkxAAG`, shared to group `Blake_Yoshimura`.
- `sharingRules/Transaction__c.sharingRules-meta.xml` L285: `PVL_Sharing_Rule`, criteria `CreatedById equals 005t0000006Z5QTAA0`. L364/L372: `AngelaRodriguezTransactionSharingRule`, which shares from group `AngelaRodriguez`.
- 412 of 435 sharing rule files are empty stubs.

**Impact**: Access tied to named people is not revoked when they change roles or leave, and it breaks in sandboxes (Ids differ). This is a classic source of access drift.

**Recommendation**: Replace these with role, queue or public-group criteria. Remove the empty stub files from source control, or exclude them from the manifest.

**Effort**: S

### [MEDIUM] ID P-23: External profiles hold sensitive FLS (DOB, FEIN, tokens) on objects they should not need, and portal users can edit a validation-bypass field

**Confidence**: Confirmed (FLS). Unverified (whether object access is granted elsewhere).

**Evidence**:
- `profiles/DCCA BREG - CustomerCommunityLogin.profile-meta.xml`: `SEBCase__c.DateofBirth__c` (L20291) and `SEBCase__c.RespondentFEIN__c` (L20436) are readable **and editable**, with `SEBCase__c` CR. It also has View/Edit on `SpringCLM_Session__c.AccessToken__c`/`RefreshToken__c`.
- `profiles/CATV Community Profile.profile-meta.xml` and `Customer Community Plus Login User`: 1,392 and 1,387 readable fields, including `Application__c.FEIN__c` (edit), `Application__c.Birthdate__c`, `Application__c.SocialSecurityTemplate__c`, `License__c.FEIN__c` (edit) and `SpringCLM_Session__c` tokens (edit). No object permissions appear in source, so this is dormant FLS that becomes active the moment any object Read is granted.
- `profiles/transcripts Profile.profile-meta.xml` L12573: guest FLS read/edit on `HPEAPRequest__c.LAST4OfSSN__c`. `pre-payment Profile`: guest Read on `PrelicenseCEEnrollment__c.Last4ofSSN__c`.
- `permissionsets/BREG_Portal_User.permissionset-meta.xml` L2427: `breg_Account_Affiliation__c.breg_Bypass_Validation_Token__c` editable. The validation rules `objects/breg_Account_Affiliation__c/validationRules/BREG_Restrict_Edit_On_Case_Completed` and `BREG_Block_Edit_When_Entity_Populated` are skipped when `ISCHANGED(breg_Bypass_Validation_Token__c)`.

**Impact**: Dormant FLS turns a small object-permission change into a PII leak. A user-editable bypass token defeats server-side integrity rules on business affiliations.

**Recommendation**:
1. Remove sensitive FLS from all external profiles.
2. Make `breg_Bypass_Validation_Token__c` read-only for every non-admin, or replace the pattern with a transient static flag inside Apex.

**Effort**: S

### [MEDIUM] ID P-24: Profile-centric access model — the org is not following "minimum profile + permission sets"

**Confidence**: Confirmed.

**Evidence**:
- 96 profiles, 78 of them custom (Salesforce 32, Platform 39, Guest 9, Community 6, other 10).
- Profiles carry the bulk of access: PVL staff profiles grant 405–539 classes, 124–152 pages and 46–62 objects each.
- Only 4 custom permission set groups: `Call_Center_Case_Access_for_DCCA`, `DCCA_Case_Access`, `Work_Item_Processing_Support`, `Work_Item_Processing_Support_Salesforce_Lic`. The other 36 are `force__` standard groups. `force__Public_Sector_Solutions_Admin` has `<status>Failed</status>`.
- There are **zero** muting permission sets.
- Only a few profiles look like minimum profiles: `Minimum Access - Salesforce`, and `DCCA BREG Standard User`, `DCCA OCP Manager`, `DCCA PVL Limited Admin2` and `CATV Staff`, which are about 96% similar to Minimum Access.
- The newer work (BREG, CATV, tkt, util_closer, Call Center) *does* use permission sets, so the org is part-way through a migration.

**Impact**: Profiles cannot be granted temporarily or audited per capability, and every profile clone copies its dangerous permissions (see P-06, P-08, P-28). Salesforce is retiring permissions-on-profiles over time.

**Recommendation**:
1. Adopt a target model: one minimum profile per license type, plus persona permission set groups built from capability permission sets, with muting sets for exceptions.
2. Migrate one division at a time, starting with PVL, which has the most profiles.

**Effort**: XL

### [MEDIUM] ID P-25: Excessive Apex class grants — managed-package classes, test classes and `without sharing` classes granted en masse

**Confidence**: Confirmed.

**Evidence**:
- `permissionsets/DCCA_Travel_Approval.permissionset-meta.xml` grants 1,564 classes. 1,133 of them are managed-package classes not in the repo: `pymt` 453, `TwilioSF` 219, `dsfs` 212, `dlrs` 107, `SpringCMEos` 93, `cterminal` 49. This is for a travel-approval use case.
- Of 544 `@isTest` classes, 542 are granted to `Admin` and 335 to `Google Integration User`. 212 are granted to `DCCA PVL Admin`, 128–134 to the other PVL profiles, 78 to `DCCA BREG - CustomerCommunityLogin` (external) and 62 to each of 3 guest profiles.
- `without sharing` classes granted: 46 to each PVL staff profile, 49 to `DCCA SEC Exam Supervisor`, 39 to `DCCA BREG - CustomerCommunityLogin`, 81 to `Google Integration User`.

**Impact**: Class access is the gate that stops users calling `@AuraEnabled` / `webservice` methods directly. Blanket grants make every `without sharing` method callable by far more users than intended.

**Recommendation**:
1. Grant class access through feature permission sets that list only the controllers the feature's components call.
2. Never grant test classes.
3. Remove managed-package class grants from `DCCA_Travel_Approval`.

**Effort**: M

### [MEDIUM] ID P-26: No login IP ranges or login hours on any profile; session and password policy not in source

**Confidence**: Likely. IP ranges and hours do round-trip in profile metadata, so their absence is meaningful. Session settings are Unverified.

**Evidence**:
- No `<loginIpRanges>` or `<loginHours>` elements in any of `force-app/main/default/profiles/*.profile-meta.xml` (96 files), including `Admin`, `DCCA System Administrator`, the integration profiles and `Accenture User` / `Pacxa User`.
- No `settings/Security.settings-meta.xml` in source.

**Impact**: Admin and integration credentials can be used from any network. This combines with PasswordNeverExpires (P-06).

**Recommendation**:
1. Add IP ranges to admin, integration and vendor profiles.
2. Retrieve and version `Security.settings` and `Session.settings`, and require MFA and high-assurance sessions for admin profiles.

**Effort**: S

### [MEDIUM] ID P-27: Broad secondary permissions — Export Reports, API Enabled and Transfer Records granted widely

**Confidence**: Confirmed.

**Evidence**:
- `ExportReport` is in 73 profiles and permission sets, including `DCCA PVL Applications Staff`, `DCCA PVL Records Staff`, `DCCA SEC Clerical`, `DCCA SEC Reviewer%2FExaminer`, `License API Only` and `License RICO API Only`.
- `ApiEnabled` is in 87 grants, which is almost every internal profile.
- `TransferAnyEntity` is in 19 grants, including PVL and SEC staff profiles and the `Call_Center_Case_Access` and `UJET_Agent` permission sets.
- `EditReadonlyFields` is on `DCCA PVL Admin`, `DCCA PVL Limited Admin`, `DCCA PVL Limited Admin2` and `Pacxa User`.

**Impact**: Combined with Public R/W OWDs (P-16) and View All grants (P-13, P-15), clerical users can bulk-export org-wide PII through reports or the API.

**Recommendation**:
1. Remove ApiEnabled from human-user profiles that do not use Data Loader or other integrations.
2. Move ExportReport and TransferAnyEntity into a "Power User" permission set with named holders.

**Effort**: S

### [MEDIUM] ID P-28: Clone and duplicate profiles, including a "Limited Admin" identical to the full admin profile

**Confidence**: Confirmed. Jaccard similarity was computed over all enabled grants: user permissions, object CRUD, FLS, classes, pages, tabs and custom permissions.

**Evidence** (profile pairs with Jaccard ≥ 0.99):
- `DCCA PVL Admin` ↔ `DCCA PVL Limited Admin`: **1.000**. The "limited" profile is a strict subset differing by one grant.
- `License API Only` ↔ `License RICO API Only`: 0.998.
- `DCCA Cases and Complaints` ↔ `DCCA Manager`: 0.996.
- `DCCA BREG - CustomerCommunityUser` ↔ `DCCA BREG - Subscriber Login`: 0.996.
- `DCCA Director%27s Office` ↔ `DCCA Travel Approval`: 0.994.
- `DCCA Complaints General` ↔ `DCCA Complaints`: 0.993.
- `CATV Community Profile` ↔ `Customer Community Plus Login User`: 0.993.

Versioned or orphan names: `test` (Platform), `DCCA Integration1`, `DCCA PVL Limited Admin2`, `DCCA Maui BAC_V2`, `DCCA SEB Clerical_v2`, `DCCA Maui BAC - New`. The standard `Standard`, `SolutionManager`, `MarketingProfile`, `ContractManager` and `Read Only` profiles are 0.99 similar to each other. The full list of pairs ≥ 0.9 is in Appendix A3.

**Impact**: Misleading names ("Limited Admin") lead administrators to over-assign. Clone sprawl multiplies the review burden and propagates dangerous permissions.

**Recommendation**:
1. Merge each near-identical pair.
2. Delete `test` and the unused `_v2`/`1`/`2` variants after checking user assignments.
3. Either make "Limited Admin" actually limited or rename it.

**Effort**: M

### [LOW] ID P-29: Duplicate, near-duplicate and empty permission sets

**Confidence**: Confirmed.

**Evidence** (Jaccard over grants; the full list is in Appendix A3):
- `Complaints_BREG`, `Complaints_CATV`, `Complaints_DCA`, `Complaints_DFI`, `Complaints_General`, `Complaints_INS` and `Complaints_RICO` are identical (1.0). So are `Complaints_ALL`, `Complaints_ASO` and `Complaints_OCP`. Ten permission sets reduce to two distinct grant sets. The per-division separation is actually done by sharing rules to the same-named groups.
- Identical pairs: `JKEC_Manage_MFA_in_API` = `Multi_Factor_Authentication_in_API`, and `Deposit_Read_Access` = `SF_Deposit_Read_Only`. `tkt_Ticket_User_Platform` = `tkt_Ticket_User_Standard` and `Voice_Call_Reviewer` = `Voice_Call_Reviewer_Platform` differ only by license, which is legitimate.
- Near-duplicates: `Filing_CRU` / `SEC_Filing_Assign_Reviewer_Permission` / `BREG_Create_Filings_Permission` (0.98–0.996); `Call_Center_Case_Access` / `UJET_Agent` (0.968); `DCCA_Ho_ala_Objects_Read_Only` / `RICO_Transactions` (0.943); `PC_Standard_User_Add_OnCopy` (a "Copy").
- Empty (no grants at all): `BREG_BAC_User_permissions`, `DCCA_Conga_Permission_Set`, `ExcludeFromFiscalTDRForm`, `sfdcInternalInt__sfdc_nc_constraints_engine_deploy`.

**Impact**: Hygiene. The duplication hides which set is authoritative and makes future least-privilege changes error-prone.

**Recommendation**: Collapse `Complaints_*` into one permission set, since sharing is already group-based. Delete the empty sets and the `JKEC_` duplicate.

**Effort**: S

### [LOW] ID P-30: Custom permissions are well scoped but barely used in Apex; the Google integration profile holds UI custom permissions

**Confidence**: Confirmed.

**Evidence**:
- 16 custom permissions exist in `customPermissions/`. Holders (full table in Appendix A5) are mostly single-purpose permission sets.
- Only 2 Apex checks: `classes/tkt_TicketController.cls:8` (`FeatureManagement.checkPermission('tkt_Can_Create_Tickets')`) and `classes/BREGExternalAPIGetUserPermissions.cls:31`.
- Other checks are in validation rules and flexipages (`$Permission.BREG_Supervisor`, `BREG_Edit_Account`, `BREG_Edit_Completed_Affiliation`, `CATV_Provider_Portal_User`, `CATV_Requester_Portal_User`, `Edit_Inactive_Insurance_Bond_Permission`).
- `BCFandDisputedChargeButtonsCustomPermission` and `Single_Receipt` are granted to the `Google Integration User` profile, an API user that has no need for UI buttons (another clone-from-Admin indicator).
- `CATV_*` custom permissions are held only by the matching `External_CATV_*` permission sets. That is appropriate.

**Impact**: Low. Custom permissions are not over-granted. The main gap is that sensitive `without sharing` operations (P-04) do not use custom-permission gates.

**Recommendation**: Use custom permissions plus `FeatureManagement.checkPermission` to gate privileged Apex operations such as payment adjustments, reconciliation re-runs and case expediting. Remove the UI custom permissions from `Google Integration User`.

**Effort**: S

### [LOW] ID P-31: Named Credentials and Connected Apps are not in source; some endpoints hardcoded

**Confidence**: Confirmed (absence in repo).

**Evidence**:
- Apex references `callout:Amazon_SES`, `callout:DocuSign`, `callout:DocuSignSource`, `callout:DocuSignUpload`, `callout:DocuSignSourceUpload`, `callout:IMLCC`, `callout:OracleGL` and `callout:UI_API_Credentials`. There is no `namedCredentials/` or `externalCredentials/` folder, so their auth protocols and principals cannot be reviewed.
- `callout:UI_API_Credentials` is used for Tooling API writes to StaticResource. That is effectively a metadata-write credential and should be reviewed.
- There is no `connectedApps/` folder, so OAuth policies (IP relaxation, refresh-token policy, permitted users) cannot be reviewed.
- Hardcoded endpoints: SpringCM UAT (`apiuatna11.springcm.com`, 134 references mostly in tests, and in `SpringCMConnector.cls:399`) and `https://test.salesfor.com`.

**Impact**: The integration trust boundary is unreviewable from source, and hardcoded UAT hosts may silently fail or leak data in production.

**Recommendation**:
1. Add Named Credentials, External Credentials and Connected Apps to the retrieve manifest, using secret-free metadata.
2. Set Connected App policies to "Admin approved users are pre-authorized" with IP enforcement.
3. Parameterise endpoints through Named Credentials.

**Effort**: S

## Appendix

### A1. Custom object sharing model (OWD) — all 233 objects under objects/

Legend: Int = `<sharingModel>`, Ext = `<externalSharingModel>`; "Sens" = object name matches PII/payment/licensing/enforcement heuristic. Objects with no sharingModel element (custom settings, CMDT, platform events, big objects) are summarised at the end.

| Object | Int | Ext | Fields | Sens | Flag |
|---|---|---|---|---|---|
| AccountName__c | ReadWrite | Private | 10 |  | Public R/W |
| Account_Access_Request__c | ReadWrite | Private | 7 | Y | Public R/W on sensitive object |
| AdditionalDependentAppsLicenses__c | ReadWrite | Private | 5 | Y | Public R/W on sensitive object |
| AllegationViolation__c | ControlledByParent | ControlledByParent | 5 | Y |  |
| Allegation__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| ApplicationClassifications__c | ControlledByParent | ControlledByParent | 12 | Y |  |
| ApplicationRequirement__c | ControlledByParent | ControlledByParent | 15 | Y |  |
| Application_Cache__c | Read | Read | 26 | Y | External Read; Public Read on sensitive object |
| Application_Log__c | Private | Private | 12 | Y |  |
| Application_Meta_Data__c | Read | Read | 12 | Y | External Read; Public Read on sensitive object |
| Application__c | ReadWrite | Private | 443 | Y | Public R/W on sensitive object |
| AssociatedLicense__c | ControlledByParent | ControlledByParent | 50 | Y |  |
| Associated_Account__c | ReadWrite | Private | 23 |  | Public R/W |
| BREG_ADDRESS_PROTECTION__c | ReadWrite | Private | 6 | Y | Public R/W on sensitive object |
| BoardProgram__c | ReadWrite | Private | 4 |  | Public R/W |
| Card_Cache__c | ControlledByParent | ControlledByParent | 6 |  |  |
| Card_Meta_Data__c | Read | Read | 10 |  | External Read |
| CaseTeamAssignment__c | ControlledByParent | ControlledByParent | 5 |  |  |
| CaseTeamMember__c | ControlledByParent | ControlledByParent | 5 |  |  |
| CaseTeam__c | ReadWrite | Private | 2 |  | Public R/W |
| CashierCode__c | ReadWrite | Private | 14 | Y | Public R/W on sensitive object |
| CertificateRequest__c | ReadWrite | Private | 23 |  | Public R/W |
| Checklist__c | ReadWrite | Private | 20 |  | Public R/W |
| Classification__c | ControlledByParent | ControlledByParent | 8 |  |  |
| CollectionsAllocation__c | ControlledByParent | ControlledByParent | 31 |  |  |
| ContinuingEducation__c | ReadWrite | Private | 4 |  | Public R/W |
| Course__c | ReadWrite | Private | 34 | Y | Public R/W on sensitive object |
| CustomLog__c | ReadWrite | Private | 8 |  | Public R/W |
| DFIRegistration__c | ReadWrite | Private | 14 | Y | Public R/W on sensitive object |
| Deficiency__c | ReadWrite | Private | 4 | Y | Public R/W on sensitive object |
| Deposits__c | ReadWrite | Private | 26 | Y | Public R/W on sensitive object |
| DocGeneratorDataSource__c | ReadWrite | Private | 9 |  | Public R/W |
| DocGeneratorSettings__c | ReadWrite | Private | 6 |  | Public R/W |
| Earned_Continuing_Education__c | ControlledByParent | ControlledByParent | 23 |  |  |
| Earned_Prelicense__c | ControlledByParent | ControlledByParent | 9 | Y |  |
| Education__c | ControlledByParent | ControlledByParent | 7 |  |  |
| EligibleCandidateLoad__c | ReadWrite | Private | 2 |  | Public R/W |
| EmailAlertTrigger__c | ReadWrite | Private | 8 |  | Public R/W |
| EnforcementActionDocument__c | ControlledByParent | ControlledByParent | 4 |  |  |
| ExamDeficiency__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| ExamResultsLoad__c | ReadWrite | Private | 7 | Y | Public R/W on sensitive object |
| ExamResults__c | ControlledByParent | ControlledByParent | 9 | Y |  |
| ExamTypeRequirements__c | ControlledByParent | ControlledByParent | 2 | Y |  |
| ExamTypes__c | ReadWrite | Private | 9 | Y | Public R/W on sensitive object |
| Exam__c | Read | Private | 41 | Y | Public Read on sensitive object |
| ExamsRequired__c | ControlledByParent | ControlledByParent | 21 | Y |  |
| Express_Change_Broker_History__c | ControlledByParent | ControlledByParent | 6 |  |  |
| FeeSchedule__c | ReadWrite | Private | 24 | Y | Public R/W on sensitive object |
| Field_Filter__c | ReadWrite | ReadWrite | 14 |  | Public R/W; External ReadWrite |
| Field_Meta_Data__c | Read | Read | 48 |  | External Read |
| FieldprintResults__c | ReadWrite | Private | 4 |  | Public R/W |
| FileDetails__c | Private | Private | 24 |  |  |
| FilingContact__c | ControlledByParent | ControlledByParent | 3 | Y |  |
| FilingDeficiency__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| Filing__c | Read | Private | 261 | Y | Public Read on sensitive object |
| FiscalForm__c | ReadWrite | Private | 8 |  | Public R/W |
| HPEAPRequest__c | ReadWrite | Private | 30 | Y | Public R/W on sensitive object |
| HardwareFees__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| INET_Request__c | ReadWrite | Private | 44 | Y | Public R/W on sensitive object |
| IVR_Application_Status_Snapshot__c | ReadWrite | Private | 12 | Y | Public R/W on sensitive object |
| Inspections__c | ReadWrite | Private | 5 |  | Public R/W |
| InstructorSubject__c | ControlledByParent | ControlledByParent | 2 | Y |  |
| Instructor__c | ReadWrite | Private | 19 | Y | Public R/W on sensitive object |
| InsuranceBond__c | ControlledByParent | ControlledByParent | 33 | Y |  |
| InsurancePortalSubmission__c | ReadWrite | Private | 36 | Y | Public R/W on sensitive object |
| Insurer__c | ReadWrite | Private | 4 |  | Public R/W |
| Investigation__c | ControlledByParent | ControlledByParent | 40 | Y |  |
| Invoice__c | ControlledByParent | ControlledByParent | 7 | Y |  |
| Knowledge__kav | ReadWrite | Private | 17 |  | Public R/W |
| LegalAction__c | ControlledByParent | ControlledByParent | 8 | Y |  |
| LicenseClassification__c | ControlledByParent | ControlledByParent | 15 | Y |  |
| LicenseConditions__c | ControlledByParent | ControlledByParent | 8 | Y |  |
| LicenseHistory__c | ReadWrite | Private | 65 | Y | Public R/W on sensitive object |
| LicenseName__c | ReadWrite | Private | 9 | Y | Public R/W on sensitive object |
| LicenseNumberAssignments__c | ReadWrite | Private | 4 | Y | Public R/W on sensitive object |
| LicensePeriod__c | ControlledByParent | ControlledByParent | 7 | Y |  |
| LicenseRequirements__c | ReadWrite | Private | 10 | Y | Public R/W on sensitive object |
| LicenseTypeCashierCode__c | ReadWrite | Private | 17 | Y | Public R/W on sensitive object |
| LicenseTypeRequirements__c | ReadWrite | Private | 22 | Y | Public R/W on sensitive object |
| LicenseType_Required_CE__c | ControlledByParent | ControlledByParent | 5 | Y |  |
| LicenseType__c | ReadWrite | Private | 245 | Y | Public R/W on sensitive object |
| License__c | ReadWrite | Private | 501 | Y | Public R/W on sensitive object |
| MakeandSupplier__c | ReadWrite | Private | 6 |  | Public R/W |
| Notification__c | ReadWrite | Private | 33 | Y | Public R/W on sensitive object |
| OtherStateLicenses__c | ReadWrite | Private | 7 | Y | Public R/W on sensitive object |
| PVL_Board_Assignment__c | ReadWrite | Private | 8 |  | Public R/W |
| PVL_Express_Change_Broker_Form__c | ReadWrite | Private | 41 |  | Public R/W |
| PVL_Portal_Persona__c | ReadWrite | Private | 2 |  | Public R/W |
| PVL_Portal_User__c | ReadWrite | Private | 22 | Y | Public R/W on sensitive object |
| PVL_Portal__c | ReadWrite | Private | 0 |  | Public R/W |
| Partner_Officer__c | ControlledByParent | ControlledByParent | 6 |  |  |
| PaymentReconciliation__c | ReadWrite | Private | 21 | Y | Public R/W on sensitive object |
| PrelicenseCEEnrollment__c | ControlledByParent | ControlledByParent | 35 | Y |  |
| ProviderSchoolSubjects__c | ControlledByParent | ControlledByParent | 11 |  |  |
| Purchase_Order__c | ControlledByParent | ControlledByParent | 9 | Y |  |
| Quotes__c | ControlledByParent | ControlledByParent | 10 | Y |  |
| RICOReferral__c | ReadWrite | Private | 28 | Y | Public R/W on sensitive object |
| RICOViolation__c | ControlledByParent | ControlledByParent | 8 | Y |  |
| Reconciliation_Batch__c | ReadWrite | Private | 11 | Y | Public R/W on sensitive object |
| ReferredFromAgencies__c | ControlledByParent | ControlledByParent | 3 |  |  |
| ReferredToAgencies__c | ControlledByParent | ControlledByParent | 3 |  |  |
| RenewalScanningResults__c | ReadWrite | Private | 4 |  | Public R/W |
| Requirements__c | ReadWrite | Private | 8 |  | Public R/W |
| Requisition__c | ReadWrite | Private | 34 | Y | Public R/W on sensitive object |
| SEBCaseContact__c | ControlledByParent | ControlledByParent | 32 | Y |  |
| SEBCaseNumber__c | ReadWrite | Private | 1 | Y | Public R/W on sensitive object |
| SEBCaseTeam__c | ControlledByParent | ControlledByParent | 10 | Y |  |
| SEBCase__c | ReadWrite | Private | 101 | Y | Public R/W on sensitive object |
| Sanction_Payment__c | ControlledByParent | ControlledByParent | 9 | Y |  |
| Sanction__c | ControlledByParent | ControlledByParent | 26 | Y |  |
| ServicesFees__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| SoftwareFees__c | ControlledByParent | ControlledByParent | 4 | Y |  |
| SpringCLM_Session__c | ReadWrite | Private | 2 | Y | Public R/W on sensitive object |
| StatusHistory__c | Private | Private | 23 |  |  |
| Subject__c | ReadWrite | Private | 18 |  | Public R/W |
| Suspense__c | ControlledByParent | ControlledByParent | 13 |  |  |
| TimeandExpenseDetails__c | ControlledByParent | ControlledByParent | 5 |  |  |
| TimeandExpenseHeader__c | ControlledByParent | ControlledByParent | 7 |  |  |
| TransactionLine__c | ControlledByParent | ControlledByParent | 59 | Y |  |
| Transaction__c | Private | Private | 64 | Y |  |
| TravelApproval__c | Private | Private | 361 | Y |  |
| Violation__c | ReadWrite | Private | 4 | Y | Public R/W on sensitive object |
| Voice_Call_Session_Recording__c | ReadWrite | Private | 2 | Y | Public R/W on sensitive object |
| Work_Item__c | Private | Private | 45 | Y |  |
| Worksheet__c | ControlledByParent | ControlledByParent | 381 |  |  |
| breg_Account_Affiliation__c | ReadWrite | Private | 53 |  | Public R/W |
| breg_Acquisition_Transaction__c | ReadWrite | Private | 11 | Y | Public R/W on sensitive object |
| breg_Agent_Search_List__c | ReadWrite | Private | 9 |  | Public R/W |
| breg_Agent_Search_Result__c | ControlledByParent | ControlledByParent | 4 |  |  |
| breg_Annual__c | ReadWrite | Private | 26 |  | Public R/W |
| breg_Batch_Job_Execution__c | ReadWrite | Private | 16 |  | Public R/W |
| breg_Case_Staging__c | ReadWrite | Private | 12 |  | Public R/W |
| breg_Certificate__c | ReadWrite | Private | 17 |  | Public R/W |
| breg_DBEDT_Report__c | ReadWrite | Private | 8 |  | Public R/W |
| breg_Document__c | ReadWrite | Private | 32 |  | Public R/W |
| breg_Email_Log__c | ReadWrite | Private | 3 |  | Public R/W |
| breg_Entity_List_Item__c | ControlledByParent | ControlledByParent | 1 |  |  |
| breg_Entity_List_Result__c | ControlledByParent | ControlledByParent | 8 |  |  |
| breg_Entity_List__c | ReadWrite | Private | 14 |  | Public R/W |
| breg_Fee__c | ReadWrite | Read | 18 | Y | Public R/W on sensitive object; External Read |
| breg_Form_Configuration_Item__c | ControlledByParent | ControlledByParent | 16 |  |  |
| breg_Form_Configuration__c | ReadWrite | Read | 36 |  | Public R/W; External Read |
| breg_Log__c | ReadWrite | Private | 16 |  | Public R/W |
| breg_Notification__c | ReadWrite | Private | 14 | Y | Public R/W on sensitive object |
| breg_RDPMS_Adhoc_Request__c | ReadWrite | Private | 6 |  | Public R/W |
| breg_Rejection_Reason__c | ReadWrite | Private | 4 |  | Public R/W |
| breg_Search_Log__c | ReadWrite | Private | 12 |  | Public R/W |
| breg_Stock__c | ReadWrite | ReadWrite | 21 |  | Public R/W; External ReadWrite |
| breg_TN_TM_SM__c | ReadWrite | ReadWrite | 53 |  | Public R/W; External ReadWrite |
| breg_Test_Annual__c | ReadWrite | Private | 20 |  | Public R/W |
| breg_Transaction_Address__c | ControlledByParent | ControlledByParent | 19 | Y |  |
| breg_Transaction_Business_Info__c | ReadWrite | Private | 49 | Y | Public R/W on sensitive object |
| breg_Transaction__c | ReadWrite | Private | 46 | Y | Public R/W on sensitive object |
| breg_WEB_WEB_ADDRESSES__c | ReadWrite | Private | 23 |  | Public R/W |
| breg_WEB_WEB_BUSINESS_INFO__c | ReadWrite | Private | 45 |  | Public R/W |
| breg_WEB_WEB_FILING_INFO__c | ReadWrite | Private | 37 | Y | Public R/W on sensitive object |
| breg_WEB_WEB_FILING_YEARS__c | ReadWrite | Private | 18 | Y | Public R/W on sensitive object |
| breg_WEB_WEB_PERSONS__c | ReadWrite | Private | 38 | Y | Public R/W on sensitive object |
| breg_WEB_WEB_RESUB__c | ReadWrite | Private | 4 |  | Public R/W |
| breg_WEB_WEB_STOCKS__c | ReadWrite | Private | 19 |  | Public R/W |
| breg_WEB_WEB_TRADE_MARKS__c | ReadWrite | Private | 26 |  | Public R/W |
| qual_Integration_Log__c | ReadWrite | Private | 20 |  | Public R/W |
| tkt_Ticket_Comment__c | ControlledByParent | ControlledByParent | 5 |  |  |
| tkt_Ticket__c | Private | Private | 17 |  |  |
| util_closer_Batch_Log__c | ReadWrite | ReadWrite | 16 |  | Public R/W; External ReadWrite |
| util_closer_Case_Log__c | ControlledByParent | ControlledByParent | 16 |  |  |

Objects with no OWD element (67; settings/CMDT/events/big objects): AccountSettings__c, ApprenticeApplicationCounter__c, BREG_Annuals_Job_Settings__c, BREG_Annuals_Rollover_Job_Settings__mdt, BREG_Batch_Job_Configuration__mdt, BREG_Batch_Setting__mdt, BREG_Case_Owner_Reassignment__mdt, BREG_Docusign_Templates_Setting__mdt, BREG_File_Number_Sequence__c, BREG_Form_Setting__mdt, BREG_Handler_Error__e, BREG_MassEmailSettings__mdt, BREG_Setting__c, BREG_Stamp_Setting__c, BREG_Stamp__mdt, BatchJob_Setting__mdt, BenefitManagementRecertification__c, BusinessAccountCounter__c, Case_Record_Type__mdt, CustomLogEvent__e, CustomLogLevelSettings__c, EmailAlertEvent__e, EmailAlertTypesToTemplate__mdt, FieldsperRecordType__mdt, FlowSettings__c, FlowperRecordType__mdt, IMLCCSettings__c, LicenseNumberAssignment__mdt, LicenseTypeMapping__c, LicenseTypeSetting__mdt, License_REST_API_Setting__mdt, NewBatchTransactionComponentConfig__mdt, ObjectPrefix__mdt, OrgConfiguration__c, Org_Credential__mdt, PVLErrorHandler__e, PVLProcess__e, PVLRenewalSettings__c, PVLScanningComponent__mdt, PVLSettings__mdt, PicklistForRecordType__mdt, ProcessSwitches__c, PublicGroupPermissionMapping__mdt, Send_Letter_to_Printer__mdt, Send_to_4Gov_Email_Setting__mdt, SpringCLMSetting__mdt, SpringCMApiEnvironment__mdt, TaxClearanceApi__c, UploadedFilesperRecordType__mdt, Work_Item_Routing__mdt, breg_BRIM_Transaction_Event__b, breg_Company_Info_Field_Mapping__mdt, breg_DocuSign_Auth__mdt, breg_Docusign_Settings__c, breg_Notification_Category__mdt, fflibe_Domain__mdt, fflibe_Selector__mdt, ppt_Toast__e, qual_Config__mdt, qual_Integration_Settings__c, tkt_Email_Notification_Setting__mdt, tkt_Email_Settings__mdt, tkt_Ticket_Routing_Rule__mdt, tkt_Ticket_Sharing_Group__mdt, tkt_Trigger_Control__c, util_closer_Case_Status_Rule__mdt, util_closer_Settings__c

Standard objects (Account, Contact, Case, etc.) are **not** present under objects/ — their OWDs cannot be assessed from source (Unverified).


### A2. Guest and community profile details

| Profile | License | Object perms (C/R/E/D/VA/MA) | Readable / editable fields | Apex classes (without sharing / @RestResource / test) | VF pages | Notable user perms |
|---|---|---|---|---|---|---|
| BREG Profile | Guest User License | Knowledge__kav:R, breg_Document__c:R | 30 / 5 | 7 (7 / 0 / 0) | 8 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| CATV Portal Profile | Guest User License | (none in source) | 9 / 9 | 2 (1 / 0 / 0) | 4 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces, EditTask, EmailSingle |
| Digital Form Profile | Guest User License | (none in source) | 4 / 4 | 15 (10 / 0 / 0) | 16 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| Guest License User | Guest User License | (none in source) | 5 / 5 | 0 (0 / 0 / 0) | 0 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| PaymentConnect Profile | Guest User License | AllegationViolation__c:CR, Allegation__c:CR, Application__c:CR, AssociatedLicense__c:CR, Associated_Account__c:CR, BoardProgram__c:R, CashierCode__c:CR, Classification__c:R, CollectionsAllocation__c:CR, Course__c:R, Deficiency__c:CR, Deposits__c:CR … (+40) | 1063 / 123 | 19 (10 / 0 / 0) | 88 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces, EditTask, EmailSingle |
| dcca Profile | Guest User License | (none in source) | 5 / 5 | 4 (2 / 0 / 0) | 16 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| pre-payment Profile | Guest User License | DFIRegistration__c:CR, TransactionLine__c:CR, Transaction__c:CR | 141 / 59 | 125 (18 / 2 / 62) | 39 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| securities Profile | Guest User License | SEBCase__c:CR | 58 / 56 | 125 (18 / 2 / 62) | 39 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| transcripts Profile | Guest User License | HPEAPRequest__c:CR | 32 / 31 | 125 (18 / 2 / 62) | 40 | AllowUniversalSearch, ChatterEnabledForUser, ContentWorkspaces |
| CATV Community Profile | Customer Community Plus Login | (none in source) | 1392 / 983 | 0 (0 / 0 / 0) | 0 | ChatterEnabledForUser, EditTask, ShareFilesWithNetworks |
| Customer Community Login User | Customer Community Login | (none in source) | 202 / 136 | 30 (2 / 0 / 4) | 11 | AccessOrchestrationObjects, AllowUniversalSearch, ChatterEnabledForUser, DocGenRuntimeCCUser, RunFlow, ShareFilesWithNetworks |
| Customer Community Plus Login User | Customer Community Plus Login | (none in source) | 1387 / 979 | 0 (0 / 0 / 0) | 0 | AccessOrchestrationObjects, DocGenRuntimeCCUser, ShareFilesWithNetworks |
| DCCA BREG - CustomerCommunityLogin | Customer Community Login | CashierCode__c:R, FileDetails__c:CRE, Filing__c:CRE, SEBCaseNumber__c:CR, SEBCase__c:CR, TransactionLine__c:CRE, Transaction__c:CREDVM, breg_Account_Affiliation__c:CR, breg_Fee__c:R, breg_Form_Configuration_Item__c:CR, breg_Form_Configuration__c:CR | 631 / 481 | 275 (39 / 2 / 78) | 55 | AllowUniversalSearch, ChatterEnabledForUser, RunFlow, ShareFilesWithNetworks |
| DCCA BREG - CustomerCommunityUser | Customer Community Login | Transaction__c:CREDVM, breg_Account_Affiliation__c:CR, breg_Fee__c:R, breg_Form_Configuration_Item__c:CR, breg_Form_Configuration__c:CR | 284 / 165 | 52 (12 / 0 / 4) | 15 | AccessOrchestrationObjects, AllowUniversalSearch, ChatterEnabledForUser, DocGenRuntimeCCUser, RunFlow, ShareFilesWithNetworks |
| DCCA BREG - Subscriber Login | Customer Community Login | Transaction__c:CREDVM, breg_Account_Affiliation__c:CR, breg_Fee__c:R, breg_Form_Configuration_Item__c:CR, breg_Form_Configuration__c:CR | 284 / 165 | 54 (12 / 0 / 4) | 15 | AccessOrchestrationObjects, AllowUniversalSearch, ChatterEnabledForUser, DocGenRuntimeCCUser, RunFlow, ShareFilesWithNetworks |

Guest-facing permission sets (assignment to the site guest user is inferred from the name; assignments are not in source):

| Permission set | Object perms | Apex classes (without sharing) |
|---|---|---|
| BREG_Site_Guest_User | Account:CR, Case:CR, Contact:R, Knowledge__kav:R, TransactionLine__c:CR, Transaction__c:CR, UserExternalCredential:R, breg_Account_Affiliation__c:CR, breg_Annual__c:CR, breg_Document__c:R, breg_Fee__c:R, breg_Form_Configuration_Item__c:R, breg_Form_Configuration__c:R, breg_TN_TM_SM__c:R | 22 (BREGAccountAffiliationController, BREGAgentSearchController, BREGAnnualsController, BREGBusinessDetailsController, BREGCaseControllerWithoutSharing, BREGCaseLifecycleHandler, BREGCaseTriggerHandler, BREGContactControllerWithoutSharing, BREGEntityListBuilderController, BREGHelpCenterController, BREGPaymentController, BREGPortalUtils, BREGRegistrationFormController, BREGSearchAndBuyController, BREGStartNewBusinessUtils) |
| OmniStudio_Guest_User | OmniDataPack:R, OmniDataTransform:R, OmniDataTransformItem:R, OmniESignatureTemplate:R, OmniProcess:R, OmniProcessCompilation:R, OmniProcessElement:R, OmniScriptSavedSession:R, OmniUiCard:R | 0 (-) |
| PC_Community_User_Guest_ADD_ON | Contact:R, pymt__Payment_Method__c:CR, pymt__Payment_Profile__c:CR | 1 (-) |
| BREG_Portal_User | Account:RE, Case:CRE, CashierCode__c:R, Contact:RE, Knowledge__kav:R, TransactionLine__c:CR, Transaction__c:CR, UserExternalCredential:R, breg_Account_Affiliation__c:CR, breg_Annual__c:CRE, breg_Certificate__c:CR, breg_Document__c:CRE, breg_Fee__c:R, breg_Form_Configuration_Item__c:R, breg_Form_Configuration__c:R, breg_Log__c:CRE, breg_Notification__c:CRE, breg_Search_Log__c:CRE, breg_TN_TM_SM__c:R, breg_Transaction__c:CR, pymt__PaymentX__c:R | 29 (BREGAccountAffiliationController, BREGAccountInfoController, BREGAgentSearchController, BREGAnnualsController, BREGBusinessDetailsController, BREGCaseControllerWithoutSharing, BREGCaseLifecycleHandler, BREGCaseTriggerHandler, BREGContactControllerWithoutSharing, BREGCreateTransaction, BREGEntityListBuilderController, BREGHelpCenterController, BREGMyDashboardController, BREGNotificationsHandler, BREGPaymentController, BREGPortalUtils, BREGRegistrationFormController, BREGSearchAndBuyController, BREGStartNewBusinessUtils, BREGUtils) |
| PC_Community_Authenticated_User_ADD_ON | Contact:R, Pricebook2:R, Product2:R, pymt__Payment_Method__c:CRE, pymt__Payment_Profile__c:CRE | 6 (-) |
| External_CATV_Provider | Account:R, Contact:R, INET_Request__c:RE, Invoice__c:CRE, Purchase_Order__c:RE, Quotes__c:CRE | 7 (CATV_WithoutSharingUtility, SpringCMConnector) |
| External_CATV_Requestor | Contact:R, INET_Request__c:CRE, Invoice__c:R, Purchase_Order__c:CRE, Quotes__c:RE | 7 (CATV_WithoutSharingUtility, SpringCMConnector) |

### A3. Duplicate / near-duplicate pairs (Jaccard over all enabled grants)

Permission sets (≥ 0.80, or strict subset with ≥ 5 grants):

| Jaccard | Perm set A | Perm set B | Grants A / B | Note |
|---|---|---|---|---|
| 1.000 | Complaints_BREG / _CATV / _DCA / _DFI / _General / _INS / _RICO | (all pairs) | 188 each | 7 identical sets |
| 1.000 | Complaints_ALL / _ASO / _OCP | (all pairs) | 173 each | 3 identical sets; 0.92 overlap with the 188-grant group |
| 1.000 | JKEC_Manage_MFA_in_API | Multi_Factor_Authentication_in_API | 17 / 17 | Identical user-management sets |
| 1.000 | Deposit_Read_Access | SF_Deposit_Read_Only | 5 / 5 | Platform vs Salesforce license |
| 1.000 | tkt_Ticket_User_Platform | tkt_Ticket_User_Standard | 39 / 39 | License split (legitimate) |
| 1.000 | Voice_Call_Reviewer | Voice_Call_Reviewer_Platform | 8 / 8 | License split (legitimate) |
| 0.996 | Filing_CRU | SEC_Filing_Assign_Reviewer_Permission | 482 / 484 | |
| 0.983 | BREG_Create_Filings_Permission | Filing_CRU / SEC_Filing_Assign_Reviewer_Permission | 476 / 482–484 | |
| 0.968 | Call_Center_Case_Access | UJET_Agent | 1136 / 1139 | |
| 0.950 | BREG_DOC_I_User_permissions | BREG_DOC_P_User_permissions | 19 / 20 | subset |
| 0.943 | DCCA_Ho_ala_Objects_Read_Only | RICO_Transactions | 2498 / 2586 | |
| 0.905 | BREG_DOC_I_User_permissions | DOC_BAC | 19 / 21 | subset |
| 0.875 | DCCA_Ho_ala_Objects_Read_Only | Read_Only_PVL | 2498 / 2188 | |
| 0.862 | Complaints_DO | Complaints_* (188 group) | 218 / 188 | superset |
| 0.831 | External_CATV_Provider | External_CATV_Requestor | 114 / 102 | Expected (persona pair) |
| 0.615 | PC_Standard_User_Add_On | PC_Standard_User_Add_OnCopy | 13 / 8 | "Copy" is a subset |

Empty permission sets: `BREG_BAC_User_permissions`, `DCCA_Conga_Permission_Set`, `ExcludeFromFiscalTDRForm`, `sfdcInternalInt__sfdc_nc_constraints_engine_deploy`.

Profiles (≥ 0.95, custom profiles only; standard-profile inter-similarity omitted):

| Jaccard | Profile A | Profile B |
|---|---|---|
| 1.000 | DCCA PVL Admin | DCCA PVL Limited Admin |
| 0.998 | License API Only | License RICO API Only |
| 0.996 | DCCA Cases and Complaints | DCCA Manager |
| 0.996 | DCCA BREG - CustomerCommunityUser | DCCA BREG - Subscriber Login |
| 0.996 | DCCA Complaints | StandardAul |
| 0.994 | DCCA Director's Office | DCCA Travel Approval |
| 0.993 | DCCA Complaints General | DCCA Complaints |
| 0.993 | CATV Community Profile | Customer Community Plus Login User |
| 0.985 | DCCA BREG Standard User | DCCA OCP Manager |
| 0.983 | DCCA SEB Intake | DCCA SEB Supervisor |
| 0.982 | DCCA SEB Attorney | DCCA SEB Investigation |
| 0.981 | Call Center Agent | Call Center Supervisor |
| 0.979 | DCCA SEC Exam Supervisor | DCCA SEC Reviewer/Examiner |
| 0.979 | DCCA Cashier | DCCA Manager |
| 0.977 | DCCA PVL Applications Staff | DCCA PVL Records Staff |
| 0.976 | DCCA OCP Manager | DCCA PVL Limited Admin2 |
| 0.976 | DCCA Maui BAC_V2 | DCCA SEB Clerical_v2 |
| 0.962 | DCCA Maui BAC - New | Payment API Only |
| 0.959 | DCCA Maui BAC - New | DCCA Maui BAC |
| 0.955 | TerranoxReadOnly | test |
| 0.954 | DCCA PVL Koan Access | DCCA RICO Access |
| 0.928 | Pacxa User | Sales Insights Integration User |

Admin-clone indicator (share of the 235 `Admin` user permissions present): Google Integration User 90%, Accenture User 88%, DocuSign Integration 81%, Wordpress Administrator 80%, DCCA SEC/SEB System Administrator 75%, Integration 72%, DCCA Integration1 71%, DCCA System Administrator 71%.

### A4. CSP Trusted Sites and Remote Site Settings

CSP Trusted Sites (`cspTrustedSites/`, all `isActive=true`):

| Name | Endpoint | Context | Directives | Issue |
|---|---|---|---|---|
| CCAIP_UW1_Connector | https://dcca-29fs9ik.uw1.ccaiplatform.com | All | Connect, Font, Frame, Img, Media, Style | OK (tenant-pinned) |
| CommTrustedSite | https://hi-dcca--c.vf.force.com | Communities | all 6 | Legacy VF domain |
| DCCA_BREG_Portal | https://hbe.dcca.hawaii.gov | All | Connect, Frame, Img | Duplicate of hbe_dcca_hawaii_gov |
| GoogleApisFonts | https://fonts.googleapis.com | Communities | all 6 | Only Font/Style needed |
| Google_CCAI_Platform | https://*.ccaiplatform.com | All | all 6 | **Wildcard** |
| Org_Site | https://hi-dcca.my.salesforce-sites.com | All | Connect, Font, Frame, Img, Style | |
| Qualtrics | https://zncrtdg1q2tuxpwmy-hibcca.siteintercept.qualtrics.com | All | all 6 | |
| Qualtrics_Frame | https://hibcca.qualtrics.com | All | all 6 | |
| Qualtrics_Intercept | https://siteintercept.qualtrics.com | All | all 6 | |
| Qualtrics_Wildcard | *.qualtrics.com | All | all 6 | **Wildcard, no scheme (allows http)**; redundant |
| apiNA21 / apiNA21download / apiNA21upload | https://api(download/upload)na21.springcm.com | All | all 6 | Frame/Media not needed for API hosts |
| dccabreg | https://dccabreg.force.com | Communities | all 6 | Legacy force.com domain |
| fontsgstaticcom | https://fonts.gstatic.com | All | all 6 | Only Font needed |
| hbe_dcca_hawaii_gov | https://hbe.dcca.hawaii.gov | All | Img | Duplicate |
| hi_dcca_my_site_com | https://hi-dcca.my.site.com | Communities | all 6 | |
| stats_g_doubleclick_net | https://stats.g.doubleclick.net | Communities | all 6 | Tracker with Frame/Connect |
| www_google_analytics_com | https://www.google-analytics.com | Communities | all 6 | Tracker with Frame/Connect |
| www_googletagmanager_com / …com1 / …com2 | https://www.googletagmanager.com | Communities | all 6 | **Three duplicate entries** |

Remote Site Settings (`remoteSiteSettings/`, all `isActive=true`, `disableProtocolSecurity=false`):

| Name | URL | Issue |
|---|---|---|
| test | https://eod2cgfefmvt6uf.m.pipedream.net | **Request-bin / exfil channel; unused in code** |
| WordpressSiteTestServer | http://44.232.202.215 | **Raw IP, HTTP, "Test"** |
| icanhazip | http://icanhazip.com | HTTP; purpose unclear |
| barcode_link | http://barcodes4.me | HTTP; used in DocGeneratorDataSourceDomain.cls:100 |
| TaxClearanceApiStagingEndpoint | https://hitaxstaging.hawaii.gov | Staging in production |
| TaxClearanceApiProdEndpoint | https://hitax.hawaii.gov | Credentials in custom setting (P-17) |
| QRCode | https://api.qrserver.com | Third party receives license data |
| barcodedesign | https://barcode.design | Third party |
| cognex | https://www.cognex.com | Purpose unclear |
| GoogleChartingApi | https://chart.googleapis.com | Deprecated Google API |
| PaymentConnectSiteURL | https://hawaiidcca.secure.force.com | Legacy force.com site domain |
| Chargent_Terminal_API / Chargent_Terminal_oAuth | https://services.poynt.net / https://poynt.net | Payment terminal |
| Chargent_Metadata_OrgAPI / Chargent_Terminal_OrgAPI / production_url / Salesforce / CMS_Content_Type_Manager | own-org domains | Self-callouts; `production_url` duplicates `Chargent_Terminal_OrgAPI` |
| Google_CCAI_Platform / ccai_platform | https://dcca-29fs9ik.uw1.ccaiplatform.com | Duplicate |
| Production_API / Production_Merge | https://apina21.springcm.com | Duplicate |
| Production_Auth, Production_Integration_API, Production_OpenSearch, Production_Web | *.springcm.com | `opensearchqana21` is a QA host |
| Production_Account, Production_Adm_API, Production_Collaboration, Production_Provisioning, Production_eSignature | *.docusign.com/.net | Should be Named Credentials |

### A5. Custom permissions and holders

| Custom permission | Holders | Enforced in |
|---|---|---|
| BCFandDisputedChargeButtonsCustomPermission | P:Admin, P:Google Integration User, PS:BCF_and_Disputed_Charge_Buttons | flexipage |
| BREG_Edit_Account | PS:BREG_Admin_User, BREG_DOC_R_User_permissions, BREG_Standard_User, BREG_Supervisor_User | VR BREG_Block_Edit_When_Entity_Populated |
| BREG_Edit_Completed_Affiliation | PS:BREG_DOC_R_User_permissions | VR BREG_Restrict_Edit_On_Case_Completed |
| BREG_Publish_Documents | PS:BREG_DOC_R_User_permissions | BREGExternalAPIGetUserPermissions.cls:31 |
| BREG_Refund_Request | PS:BREG_Office_Services, DOC_Office_Services | flexipage |
| BREG_Show_Button_for_BREG_users | PS:BREG_Standard_User | flexipage |
| BREG_Show_Custom_New_Case_Button | PS:BREG_Admin_User, BREG_Standard_User, BREG_Supervisor_User | flexipage |
| BREG_Supervisor | PS:BREG_Admin_User, BREG_Supervisor_User | VR BREG_Restrict_Edit_On_Case_Completed |
| CATV_Provider_Portal_User | PS:External_CATV_Provider | VR Quotes__c.Provider_Portal_User_Status_Validation |
| CATV_Requester_Portal_User | PS:External_CATV_Requestor | VR INET_Request__c.Requester_Portal_User_Status_Validation |
| Call_Center_Agent | PS:Call_Center_System_Admin, UJET_Agent | flexipage |
| DCCA_Case_Access | PS:Call_Center_Case_Access, Call_Center_System_Admin | flexipage |
| Edit_Inactive_Insurance_Bond_Permission | PS:Edit_Inactive_Insurance_Bond_Permission | VR InsuranceBond__c.InactiveStatusReadOnly |
| Single_Receipt | P:Admin, P:Google Integration User, PS:Single_Receipt | flexipage |
| Work_Item_Access | PS:Work_Item_Processing | flexipage |
| tkt_Can_Create_Tickets | PS:tkt_Ticket_Admin, tkt_Ticket_System_Access, tkt_Ticket_User_Platform, tkt_Ticket_User_Standard | tkt_TicketController.cls:8 |

### A6. Guest sharing rules (complete list — 20 rules)

| Object | Rule | Guest site | Access | Criteria |
|---|---|---|---|---|
| Account | BREG_Site_Guest_User_Sharing | BREG | Read | RecordTypeId = BREG Account |
| Account | ShareComplainantAccounts | dcca | Read | RecordTypeId = Complainant |
| Application_Cache__c | Enable_Guest_User | Digital_Form | Read | Name != '1' |
| Case | GuestUserCaseAccessCableComplaint | dcca | Read | RecordTypeId = CATV Complaint |
| Case | GuestUserCaseAccessDCAComplaint | dcca | Read | RecordTypeId = DCA Complaint |
| Case | GuestUserCaseAccessDFIComplaint | dcca | Read | RecordTypeId = DFI Complaint |
| Case | GuestUserCaseAccessGeneralComplaint | dcca | Read | RecordTypeId = General Complaint |
| Filing__c | SiteGuestUser | PaymentConnect | Read | Status__c != '' |
| Knowledge__kav | breg_Knowledge_sharing | BREG | Read | breg_Topic__c != '' |
| OmniDataTransform | Omni_Data_Transformation_Guest_User | dcca | Read | CreatedById startsWith '005' |
| OmniESignatureTemplate | Omni_Electronic_Signature_Guest_User | dcca | Read | Name != '' |
| OmniProcess | Omni_Process_Guest_User | dcca | Read | Name != '' |
| OmniUiCard | Omni_UI_Card_Guest_User | dcca | Read | UniqueName != '' |
| Transaction__c | Site_Guest_User | PaymentConnect | Read | Status__c != '' |
| breg_Account_Affiliation__c | BREG_Site_Guest_User_Sharing | BREG | Read | Name != '' |
| breg_Annual__c | BREG_Site_Guest_User_Sharing | BREG | Read | Name != '' |
| breg_Document__c | BREG_Site_Guest_User_Sharing | BREG | Read | Name != '' |
| breg_Fee__c | BREG_Site_Guest_User_Sharing | BREG | Read | Name != '' |
| breg_Form_Configuration__c | BREG_Guest_User | BREG | Read | Name != '' |
| breg_Transaction__c | BREG_Site_Guest_User_Sharing | BREG | Read | Name != '' |

Internal sharing rules: 94 in total (70 criteria, 24 owner), shared to `roleAndSubordinatesInternal` (51), `group` (41) and `role` (2). **No** rule shares to `allInternalUsers`, `allCustomerPortalUsers` or `allPartnerUsers`. External group shares: `Account.CATV_Account_Sharing_With_CATV_Portal`, and User owner rules `CATV_Portal_User_Sharing_With_Portal_Users` / `CATV_Staff_User_Sharing_With_Portal_Users` (Read to group `CATV_Portal_User`).
