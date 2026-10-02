# DCCA Salesforce DX Project

## Project Overview

**DCCA** (Department of Commerce and Consumer Affairs — Hawaii) is a large-scale Salesforce DX project tracking multiple government regulatory and licensing programs across a single shared Salesforce org.

- **Org alias:** `DCCA`
- **Active sandbox:** `hi-dcca--iscodfull.sandbox.my.salesforce.com`
- **Salesforce API version:** 67.0
- **Namespace:** none

## Directory Structure

```
DCCA/
├── force-app/main/default/   # All Salesforce metadata (source of truth)
│   ├── classes/              # 1,288 Apex classes (730 production, 558 test)
│   ├── triggers/             # 61 Apex triggers
│   ├── lwc/                  # 233 Lightning Web Components
│   ├── aura/                 # 147 Aura components
│   ├── flows/                # 266 flows (screen, record-triggered, scheduled)
│   ├── objects/              # 233 custom objects
│   ├── pages/                # 167 Visualforce pages
│   ├── profiles/             # 96 profiles
│   ├── permissionsets/       # 140 permission sets
│   └── ...                   # layouts, staticresources, flexipages, etc.
├── config/
│   └── project-scratch-def.json
├── manifest/
│   └── package.xml           # Full metadata retrieval manifest
├── scripts/
│   ├── apex/hello.apex
│   └── soql/account.soql
├── analysis/                 # Code review reports (generated, not source)
├── sfdx-project.json
├── package.json
├── jest.config.js
└── eslint.config.js
```

## Common Commands

```bash
# Deploy / retrieve
sf project deploy start
sf project retrieve start

# Apex testing
sf apex run test --test-level RunLocalTests

# Open org
sf org open

# Authenticate
sf org login web

# LWC testing
npm test                     # run LWC Jest tests (none exist yet)
npm run test:unit:coverage

# Linting & formatting
npm run lint
npm run prettier
npm run prettier:verify
```

The pre-commit hook (Husky) runs Prettier, ESLint, and LWC Jest automatically on changed files.

## Domain Map

The org hosts 16+ bounded domains sharing one Salesforce org:

| Domain | Prefix | Purpose |
|--------|--------|---------|
| Business Registration | `BREG` / `breg_` | Entity registration, filings, licensing (largest domain) |
| Professional & Vocational Licensing | `PVL` / `pvl` | License applications, renewals, exams, enforcement |
| Payments & Finance | — | `Transaction__c`, `TransactionLine__c`, Chargent/PaymentConnect |
| Documents & Integrations | — | DocuSign CLM (SpringCM), DocuSign eSignature, file management |
| Enforcement | `SEB` / `RICO` / `sc_` | Investigations, sanctions, filings |
| Cable TV | `CATV` / `catv_` | Cable TV provider portal |
| Internal Ticketing | `tkt_` | Internal help-desk tickets |
| Dynamic Form Builder | `sc_` | Runtime form rendering via metadata |
| IMLCC | — | Interstate Medical Licensure Compact integration |
| Qualtrics CX | `qual_` | Customer experience surveys |
| Case Auto-Close | `util_closer_` | Automated case lifecycle management |
| CaseTeam | — | fflib-based case team management |
| Communities / Identity | — | Experience Cloud portals (BREG public, CATV provider) |
| Shared Utilities | — | `TriggerFactory`, `OrgConfiguration__c`, logging |

## Trigger Frameworks (5 coexist — be aware)

1. **`TriggerFactory` + `ITrigger` + `SObjectDomain`** — PVL domain (Domain/Handler/Service/Selector pattern)
2. **`BREGBaseTriggerHandler`** — BREG's own base class with static recursion guard
3. **fflib `SObjectDomain`** — CaseTeam domain only
4. **Inline trigger logic** — enforcement/RICO/SEB triggers
5. **`tkt_Trigger_Control__c` bypass** — tkt_ domain

When adding trigger logic, match the existing framework for that domain — do not mix frameworks.

## Key Integration Points

| System | Classes | Notes |
|--------|---------|-------|
| DocuSign CLM / SpringCM | `SpringCMConnector`, `SpringCMApiManager`, `SpringCMFileHelper` | 3 separate clients; token in `SpringCLM_Session__c`; config in `SpringCMApiEnvironment__mdt` |
| DocuSign eSignature | `DocuSignAPI`, `DocusignAuthProvider` | Named Credential for auth |
| Oracle GL | `OracleGLBatchloadFlowService` | Batch financial integration |
| Qualtrics | `QualCalloutService` | Config in `qual_Config__mdt` |
| IMLCC | `IMLCCConnector` | Config in `IMLCCSettings__c` |
| Hawaii Tax Clearance | `TaxClearanceApiHelper` | Prod + staging endpoints in Remote Sites |
| Amazon SES | `BREGAmazonSesEmailService` | Direct HTTP callout for bulk email |
| Google CCAI | — | Contact Center AI for voice/chat |
| Chargent / PaymentConnect (Linvio) | `PaymentREST`, `TransactionREST` | In-person and online payments |

## REST API Endpoints

Public/integration-facing REST endpoints:

| Class | Purpose |
|-------|---------|
| `BREGExternalAPISearchBusinesses` | Business registration search |
| `BREGExternalAPIGetDocument` | Document retrieval |
| `BREGExternalAPIGetGoodStandingStatus` | Business standing check |
| `LicenseSearchREST` | License search (PVL) |
| `PVLApplicationStatusCheckResource` | Application status (IVR integration) |
| `PaymentREST` / `TransactionREST` | Payment processing |

## Configuration Pattern

Nearly all runtime behavior is driven by Custom Metadata (`__mdt`), not hardcoded values:

- **BREG:** `BREG_Batch_Job_Configuration__mdt`, `BREG_Form_Setting__mdt`, `BREG_Docusign_Templates_Setting__mdt`
- **PVL:** `PVLSettings__mdt`, `LicenseTypeSetting__mdt`, `LicenseNumberAssignment__mdt`
- **Integrations:** `SpringCMApiEnvironment__mdt`, `qual_Config__mdt`
- **Notifications:** `EmailAlertTypesToTemplate__mdt`, `tkt_Email_Notification_Setting__mdt`
- **Routing:** `tkt_Ticket_Routing_Rule__mdt`, `util_closer_Case_Status_Rule__mdt`

## Testing

### Apex Tests
- 558 test classes (43% of all classes)
- Naming convention: `*Test.cls`
- Run via: `sf apex run test --test-level RunLocalTests`

### LWC Jest
- Jest is configured (`jest.config.js`) but **zero `.test.js` files have been written**
- Pre-commit hook will run Jest on changed LWC files (passes with no tests via `--passWithNoTests`)

## Vendored Libraries

- **fflib (apex-common + apex-mocks):** 41 classes, ~21,000 LOC — used only by CaseTeam domain (~17 consumer classes)
- **dlrs (Declarative Lookup Rollup Summaries):** 3 generated triggers (`dlrs_AllegationTrigger`, `dlrs_LegalActionTrigger`, `dlrs_TransactionTrigger`)

## Key Profiles and Permission Sets

**Integration-only profiles:** `Payment API Only`, `License API Only`, `Salesforce API Only System Integrations`

**Portal profiles:** `DCCA BREG - CustomerCommunityLogin`, `CATV Community Profile`

**Staff profiles:** Domain-scoped (`DCCA PVL Admin`, `DCCA BREG Standard User`, `CATV Staff`, `DCCA SEB Administrator`, etc.)

## Known Architecture Issues (from analysis/)

1. **Three redundant SpringCM clients** — one has a hardcoded UAT endpoint (`SpringCMConnector`)
2. **Five trigger frameworks coexist** — fragmented, no single standard across org
3. **fflib vendored at 21k LOC** for only 17 consumer classes (CaseTeam domain only)
4. **No LWC Jest tests** despite full Jest infrastructure being in place
5. **Token exposure risk** — `SpringCMConnector.getToken()` is `@AuraEnabled`, exposing OAuth tokens to the browser

See `analysis/` directory for full security and architecture review reports.

## MCP Servers (`.mcp.json`)

- **`salesforce-dx`** — Local Salesforce CLI MCP targeting org alias `iscodfull`; toolsets: `metadata, data, code-analysis, lwc-experts, testing, scale-products`
- **`salesforce-hosted`** — Remote Salesforce platform MCP at `https://api.salesforce.com/platform/mcp/v1/sandbox/sobject-all` for the iscodfull sandbox
