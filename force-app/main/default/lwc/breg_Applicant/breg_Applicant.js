import { wire } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import {capitalizeFirstLetter} from "c/utils";
import CASE_OBJECT from "@salesforce/schema/Case";
import APPLICANT_ENTITY_TYPE_FIELD from "@salesforce/schema/Case.breg_Applicant_Entity_Type__c";

export default class Breg_Applicant extends BaseFormComponent {
    defaultTitle = "Applicant";
    applicantTypeValue;
    applicantLocationTypeValue;
    applicantEntityNameValue;
    applicantEntityLocationValue;
    applicantEntityFileValue;
    applicantEntityTypeValue;
    applicantEntityTypeDescriptionValue;
    applicantFirstNameValue;
    applicantLastNameValue;
    applicantFullName;
    applicantEntityTypeOptions = [];
    fileNumberRequired = false;

    get applicantTypeLabel() {
        return `${capitalizeFirstLetter(this.config.labelOverride2 || this.defaultTitle)} is:`;
    }

    get applicantLocationTypeLabel() {
        return `${capitalizeFirstLetter(this.config.labelOverride2 || this.defaultTitle)} Location Type`;
    }

    get applicantEntityTypeLabel() {
        return `${capitalizeFirstLetter(this.config.labelOverride2 || this.defaultTitle)} Entity Type`;
    }

    applicantTypeOptions = [
        { label: "Entity", value: "Entity" },
        { label: "Individual", value: "Individual" },
    ];

    applicantLocationTypeOptions = [
        { label: "Person intending to organize or change name of a Domestic business entity", value: "Domestic" },
        { label: "Person intending to organize or change name of a Foreign business entity", value: "Foreign" }
    ];

    get showApplicantType() {
        return this.config.targetFieldsMapping?.includes("applicantType");
    }

    get showApplicantLocationType() {
        return this.config.targetFieldsMapping?.includes("applicantLocationType");
    }
    
    get showApplicantEntityLocationField() {
        return this.config.targetFieldsMapping?.includes("applicantEntityLocation");
    }
    
    get showApplicantEntityFileField() {
        return this.config.targetFieldsMapping?.includes("applicantEntityFile");
    }
    
    get showApplicantEntityTypeField() {
        return this.config.targetFieldsMapping?.includes("applicantEntityType");
    }

    get showApplicantEntityFields() {
        return this.applicantTypeValue === 'Entity';
    }

    get showApplicantIndividualFields() {
        return this.applicantTypeValue === 'Individual';
    }

    get showApplicantEntityTypeDescription() {
        return this.applicantEntityTypeValue === 'Other' && this.showApplicantEntityFields;
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    results({ data }) {
        if (data) {
            this.caseRecTypeId = data.defaultRecordTypeId;
        } 
    }

    @wire(getPicklistValues, { recordTypeId: "$caseRecTypeId", fieldApiName: APPLICANT_ENTITY_TYPE_FIELD })
    async applicantEntityTypeOptionsWired({ data }) {
        this.applicantEntityTypeOptions = this.setCBOptionsFromPicklistValues(data);
        // If this is not a T-1 form, remove the Sole Proprietor option
        if (this.formCode !== 'T-1') {
            this.applicantEntityTypeOptions = this.applicantEntityTypeOptions.filter(
                option => option.value !== 'Sole Proprietor'
            );
        }
    }

    handleInputChange(event) {
        super.handleInputChange(event);
        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag === "lightning-input" || inputTag === 'lightning-textarea') return;
        const field = event.target.name;
        const value = event.target.value;
        if (field === "applicantType") {
            this.dispatchCustomEvent("change", this.getValueChangeData(field, value === "Entity"));
        }
    }

    handleInputBlur(event) {
        if (this.readOnly) return;
        event.preventDefault();
        event.stopPropagation();
        super.handleInputBlur(event);
        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag !== "lightning-input" && inputTag !== 'lightning-textarea') return;
        const inputName = event?.target?.name;
        const value = this.getValueFromEvent(event);
        if (inputName === "applicantFirstName" || inputName === "applicantLastName") {
            this.applicantFullName = `${this.applicantFirstNameValue || ''} ${this.applicantLastNameValue || ''}`;
            this.dispatchCustomEvent("change", { field: "applicantName", value: this.applicantFullName });
        } else if (inputName === "applicantEntityName") {
            this.dispatchCustomEvent("change", { field: "applicantName", value });
        }
    }

    processFormData() {
        super.processFormData();
        const applicantTypeField = this.targetFieldsMapping?.applicantType;
        if (applicantTypeField) {
            const applicantTypeValue = this.formData[applicantTypeField];
            if (applicantTypeValue === true) {
                this.applicantTypeValue = "Entity";
            } else if (applicantTypeValue === false) {
                this.applicantTypeValue = "Individual";
            }
        }
    }
}