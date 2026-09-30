import { track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import StartNewBusinessWizardComponent from "c/breg_StartNewBusinessWizard";
import { loadStyle } from "lightning/platformResourceLoader";
import BREG_PORTAL_RESOURCES from "@salesforce/resourceUrl/BREG_portalResources";
import { setFormData, getStateParamsFromUrl } from "c/utils";
import getAccountWithRelationshipsById from "@salesforce/apex/BREGAccountAffiliationController.getAccountWithRelationshipsById";
import getTNTMSMWithRelationships from "@salesforce/apex/BREGAccountAffiliationController.getTNTMSMWithRelationships";


export default class Breg_FormFilingInternal extends StartNewBusinessWizardComponent {
    pageReference;
    accountId;
    accountRecord;    
    @track formData;
    @track formConfiguration;
    currentStep = "Form Filling";
    annualId;
    annualReportFilingYear;
    isAmendedAnnualReport;

    /**
     * Override steps to exclude Forms and Fees (purchase step)
     * Internal users don't need to see the payment/purchase step
     */
    steps = ["Form Filling", "Form Review"];

    get dynamicFormsHeaderTitle() {
        return "Business Filing";
    }

    /**
     * Wire adapter to get current page reference and read state parameters
     */
    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
            this.pageReference = pageRef;
        }
    }

    loadInternalStyles() {
        loadStyle(this, BREG_PORTAL_RESOURCES + '/css/BREG_internalStyles.css')
        .then(() => {
            this.internalStylesLoaded = true;
            console.log('** BREG internal styles loaded successfully');
        })
        .catch(error => {
            console.error('** Error loading BREG internal styles:', error);
        });
    }

    async connectedCallback() {
        this.loadInternalStyles();

        const { formConfigId, accountId, caseId, tntmsmId, readOnly, annualId, filingYear, isAmendedAnnualReport} = getStateParamsFromUrl(this.pageReference);
        this.annualId = annualId;
        this.annualReportFilingYear = filingYear;
        this.isAmendedAnnualReport = isAmendedAnnualReport;
        this.readOnly = readOnly === 'true' || readOnly === true;
        console.log('isAmendedAnnualReport', this.isAmendedAnnualReport);

        // Handle navigation from "Continue Form Filing" button on Case record
        if (caseId) {
            this.caseId = caseId;
            await this.processFormFromCase();
        } 
        
        // Handle navigation from Account record with form configuration        
        if (formConfigId) {
            this.formConfigId = formConfigId;
            await this.loadFormConfiguration();

            if (tntmsmId) {
                this.tntmsmId = tntmsmId;
                this.tntmsmRecord = await getTNTMSMWithRelationships({ tntmsmId: this.tntmsmId });
                console.log("*** tntmsmRecord:", JSON.stringify(this.tntmsmRecord));
                this.setFormData();
            } else if (accountId) {
                this.accountId = accountId;
                this.accountRecord = await getAccountWithRelationshipsById({ accId: this.accountId });
                console.log('*** accountRecord:', JSON.stringify(this.accountRecord));
                this.setFormData();
            } else {
                this.formData = {};
            }
        }

        if (this.readOnly) {
            this.currentStep = "Form Review";
        }

        this.componentProperties = {
            readOnly: this.readOnly,
            isInternal: true,
            isAmendedAnnualReport: this.isAmendedAnnualReport
        };
    }

    setFormData() {
        if (this.formData != null && Object.keys(this.formData).length > 0) return;
        const formData = setFormData({
            formConfiguration: this.formConfiguration,
            record: this.tntmsmRecord ?? this.accountRecord,
            useSourceFieldsMapping: true,
            shouldSetRecordId: false
        });
        this.setDefaultValuesOnFormData(formData);
        this.formData = { ...formData };
    }

    setDefaultValuesOnFormData(formData) {
        super.setDefaultValuesOnFormData(formData);
        if (this.annualReportFilingYear) {
            formData['Case.breg_Annual_Report_Filing_Year__c'] = this.annualReportFilingYear;
        }
        if (this.annualId) {
            formData['Case.breg_Annual__c'] = this.annualId;
        }
    }

    /**
     * Override handleConfirm to navigate to the created case record
     * instead of proceeding to Forms and Fees step
     */
    handleConfirm() {
        this.navigateToRecord();
        // const contactInfoCmp = this.template.querySelector("c-breg_-account-info");
        // const contactInfoValid = contactInfoCmp.checkValidity();
        // contactInfoCmp.reportValidity();
        // if (contactInfoValid) {
        //     // Navigate to the case record instead of going to Forms and Fees
        //     this.navigateToRecord();
        // }
    }
}