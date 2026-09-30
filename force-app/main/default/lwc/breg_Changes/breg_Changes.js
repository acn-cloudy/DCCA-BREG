import { LightningElement, api, track } from "lwc";
import StartNewBusinessWizardComponent from "c/breg_StartNewBusinessWizard";
import { getPageParamsFromUrl, setFormData, navigateToPage } from "c/utils";
import getAccountWithRelationshipsById from "@salesforce/apex/BREGAccountAffiliationController.getAccountWithRelationshipsById";
import getTNTMSMWithRelationships from "@salesforce/apex/BREGAccountAffiliationController.getTNTMSMWithRelationships";
import getFormConfiguration from "@salesforce/apex/BREGPortalUtils.getFormConfiguration";

export default class Breg_Changes extends StartNewBusinessWizardComponent {
    businessProcessValue = "Change";
    currentStep = "Search";
    searchValue = "";
    searchType = "";
    accountRecord;
    tntmsmRecord;
    @api isNotGuest;
    @track formData;
    @track formConfiguration;

    steps = ["Search", "Form Filling", "Form Review", "Forms and Fees"];

    get searchStep() {
        return this.currentStep === "Search";
    }

    get dynamicFormsHeaderTitle() {
        return "Business Filing";
    }

    async connectedCallback() {
        this.setVarsFromUrlParams();

        if (this.caseId) {
            this.processFormFromCase();
            this.currentStep = "Form Filling";
            return;
        }

        if (this.formConfigId) {
            await this.loadFormConfiguration();
            this.currentStep = "Form Filling";
        } else if (this.formSuffix) {
            // Used for X-11 form only for now
            await this.loadFormConfiguration();
            this.currentStep = "Form Filling";
            // Remove Search step if formSuffix is provided
            this.steps = this.steps.filter((step) => step !== "Search");
        }

        if (this.tntmsmId) {
            this.tntmsmRecord = await getTNTMSMWithRelationships({ tntmsmId: this.tntmsmId });
            //console.log("*** tntmsmRecord:", JSON.stringify(this.tntmsmRecord));
            this.setFormData();
        } else if (this.accountId) {
            this.accountRecord = await getAccountWithRelationshipsById({ accId: this.accountId });
            //console.log("*** accountRecord:", JSON.stringify(this.accountRecord));
            this.setFormData();
        } else if (this.parentCaseId) {
            const defaultFormData = {};
            this.setDefaultValuesOnFormData(defaultFormData);
            if (this.formConfiguration?.formCode === "WD" && !defaultFormData["Case.breg_Signed_By__c"]) {
                defaultFormData["Case.breg_Signed_By__c"] = "Individual";
            }
            this.formData = defaultFormData;
        } else {
            this.formData = {};
        }
    }

    setFormData() {
        if (this.formData != null && Object.keys(this.formData).length > 0) return;
        const formData =
            setFormData({
                formConfiguration: this.formConfiguration,
                record: this.tntmsmRecord ?? this.accountRecord,
                useSourceFieldsMapping: !this.caseId, // useSourceFieldsMapping only when not loading from Case
                shouldSetRecordId: this.shouldSetRecordId
            }) || {};

        this.setDefaultValuesOnFormData(formData);

        if (this.accountRecord?.Id) {
            formData["Account.breg_Entity_Type__c"] = this.accountRecord.breg_Entity_Type__c;
            formData["Account.breg_Reserved_for_Entity_Type__c"] = this.accountRecord.breg_Reserved_for_Entity_Type__c;
        }

        this.formData = { ...formData };
    }

    async handleConfirm() {
        const nextForm = this.nextFormName;
        if (nextForm && this.accountRecord.ChildAccounts && this.accountRecord.ChildAccounts.length > 0) {
            const nextFormConfig = await getFormConfiguration({ formSuffix: nextForm, businessProcess: this.businessProcessValue });
            if (nextFormConfig) {
                let params = {
                    caseId: this.caseId,
                    parentCaseId: this.caseId,
                    accountId: this.accountRecord.ChildAccounts[0].Id,
                    formConfigId: nextFormConfig?.id,
                    section: "change",
                    isRenewal: false
                };
                navigateToPage("/manage", params);
                return;
            }
        }

        this.setStep(1);
    }

    // Open details
    handleOpenDetails(event) {
        let recordId = event.detail.recordId;
        window.location.href = `/search-and-buy?entityId=${recordId}&activeTab=forms`;
    }

    getQualifiedFormData(formConfiguration) {
        return formConfiguration?.elements?.find((element) => element.name === "Qualification Amendment");
    }

    handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
    }

    get nextFormName() {
        const qualifiedFormConfig = this.getQualifiedFormData(this.formConfiguration);
        let nextForm;
        if (qualifiedFormConfig) {
            const componentSettings = qualifiedFormConfig?.componentSettings ? JSON.parse(qualifiedFormConfig.componentSettings) : {};
            let targetFieldsMapping = qualifiedFormConfig?.targetFieldsMapping ? JSON.parse(qualifiedFormConfig.targetFieldsMapping) : {};

            if (this.formData[targetFieldsMapping.qualificationAmendment] === "Name Change") {
                nextForm = componentSettings.nameChangeForm;
            } else if (this.formData[targetFieldsMapping.qualificationAmendment] === "Voluntary Cancel") {
                nextForm = componentSettings.voluntaryCancelForm;
            } else if (this.formData[targetFieldsMapping.qualificationAmendment] === "Other") {
                nextForm = componentSettings.otherChangeForm;
            }
        }
        return nextForm;
    }

    get confirmLabel() {
        const nextForm = this.nextFormName;
        if (nextForm) {
            return `Continue to ${nextForm} Form`;
        }
        return "Confirm";
    }
}