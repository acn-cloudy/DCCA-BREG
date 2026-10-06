# Application Process — Object and Field Inventory

**Scope.** This inventory reverse-engineers the Professional & Vocational Licensing (PVL) application process centred on `Application__c`. It is a source-code inventory, not a substitute for live-org configuration or a business-owner validation.

## Deliverable

The detailed, machine-readable inventory is in [`08-application-process-data-inventory.csv`](08-application-process-data-inventory.csv).

- **204** `Application__c` custom fields are included because they are directly referenced in application-oriented Apex, application triggers, or application-named Flows.
- **17** lookup/master-detail relationships point to `Application__c`, including the self-reference for dependent applications.
- Standard Salesforce fields used by the process (`Id`, `Name`, `RecordTypeId`, `RecordType.DeveloperName`, audit fields, and owner fields) are not enumerated in the CSV.

## Core objects

| Object | Role in the application process | Link to application |
|---|---|---|
| `Application__c` | Application record, lifecycle, applicant, licence, phase, status, fees, renewal and document-generation controls. | Primary record |
| `Application_Cache__c` | Portal/draft application cache; an application can reference it through `DraftApplication__c`. | Lookup from Application; reassessment lookup back to Application |
| `ApplicationRequirement__c` | Application requirements/checklist. | Master-detail |
| `ApplicationClassifications__c` | Requested application classifications. | Master-detail |
| `Education__c`, `Partner_Officer__c`, `ExamsRequired__c` | Applicant qualifications, officers/partners, and examination requirements. | Master-detail |
| `Transaction__c` | Payment/financial transaction associated with an application. | Lookup |
| `License__c` | Licence produced from or associated with the application. | Lookup |
| `InsuranceBond__c`, `OtherStateLicenses__c`, `Earned_Prelicense__c` | Supporting eligibility and compliance records. | Lookup |
| `Notification__c`, `IVR_Application_Status_Snapshot__c`, `Work_Item__c` | Applicant communications, status integration snapshot, and work tracking. | Lookup |
| `AdditionalDependentAppsLicenses__c` | Relationships between a dependent application and licences/applications. | Lookup |
| `Application__c` | Parent/dependent application relationship. | Self-lookup: `DependentApplication__c` |

## Important field groups

The CSV is the authoritative exhaustive list. These groups make it easier to orient:

- **Identity and routing:** `Applicant__c`, `PVLPortalUser__c`, `BoardProgramName__c`, `LicenseType__c`, `Type__c`, `TypeofEntity__c`, `MethodofLicensure__c`, `Island__c`.
- **Lifecycle:** `Status__c`, `Phase__c`, `PreviousStatus__c`, `ApplicationReceivedDate__c`, `CompleteApplicationBy__c`, phase start/end timestamps, and `IsApplicationTerminated__c`.
- **Licence and renewal:** `CurrentLicense__c`, `LicensePeriod__c`, `LicensePeriodRNEW__c`, `ActiveInactive__c`, renewal-period flags, permit-to-practice fields, and `ApplicationRenewingInactive__c`.
- **Dependency and compliance:** `DependentApplication__c`, `DependentLicense__c`, `DependencyRequired__c`, `D2CEisRequired__c`, `CEisConfirmed__c`, `BondWaiver__c`, and `OutstandingAmount__c`.
- **Portal and renewal payloads:** `DraftApplication__c`, `OnlineApplicationType__c`, `OnlineSubmitStatus__c`, `OnlineRenewalEmployment__c`, `OnlineRenewalInsurance__c`, and online-renewal address/class fields.
- **Documents and notifications:** `GenerateLicense__c`, `GenerateDeficiencyNotification__c`, approval/rejection/temporary-license flags, `SpringCMTemplateName__c`, notification email, and delivery controls.

## Method and limitations

A field appears in the CSV when its API name exists on `Application__c` and is statically referenced in classes whose names contain “Application,” `Application*` triggers, or `*Application*` Flows. This intentionally prioritizes fields used by application code. It does not prove that every listed field is used in every licence type, record type, or active Flow version, nor does it include fields referenced only through dynamic SOQL, custom metadata, page layouts, or external integrations.

