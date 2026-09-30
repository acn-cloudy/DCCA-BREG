import { wire, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import TNTMSM_CLASSIFICATION_FIELD from "@salesforce/schema/Case.breg_TNTMSM_Classification__c";

export default class Breg_TNTMSMInfo extends BaseFormComponent {
    defaultTitle = "TN/TM/SM/PR Information";
    TNTMSMTypeValue;
    TNTMSMNameValue;
    fileNumberValue;
    certificateNumberValue;
    classificationTypeValue;
    @track classificationTypeOptionsAll = [];
    @track classificationTypeOptions = [];

    get TNTMSMTypeReadOnlyText() {
        let text = "";
        if (this.componentSettings?.TNTMSMTypeReadOnlyText) {
            text = this.componentSettings?.TNTMSMTypeReadOnlyText.replace("{TNTMSMType}", this.TNTMSMTypeValue.toUpperCase());
        } else {
            text = "<b>TN/TM/SM Type:</b> " + this.TNTMSMTypeValue.toUpperCase();
        }
        return text;
    }

    get TNTMSMNameLabel() {
        return this.config?.labelOverride2 || "Name";
    }

    get showTNTMSMType() {
        return this.config.targetFieldsMapping?.includes("TNTMSMType");
    }

    get showTNTMSMName() {
        return this.config.targetFieldsMapping?.includes("TNTMSMName");
    }

    get showFileNumber() {
        return this.config.targetFieldsMapping?.includes("fileNumber");
    }

    get showCertificateNumber() {
        return this.config.targetFieldsMapping?.includes("certificateNumber");
    }

    get showClassificationType() {
        return (
            this.config.targetFieldsMapping?.includes("classificationType") &&
            (this.TNTMSMTypeValue === "Trademark" || this.TNTMSMTypeValue === "Service Mark")
        );
    }

    get TNTMSMTypeOptions() {
        let options = [
            { label: "Trade Name", value: "Trade Name" },
            { label: "Trademark", value: "Trademark" },
            { label: "Service Mark", value: "Service Mark" },
            { label: "Publicity Rights Name", value: "Publicity Rights Name" }
        ];

        if (this.formCode === "T-5" || this.formCode === "TMSM-CANC") {
            options = options.filter((opt) => opt.value === "Trademark" || opt.value === "Service Mark");
        }

        return options;
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    results({ data }) {
        if (data) {
            this.caseRecTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: "$caseRecTypeId",
        fieldApiName: TNTMSM_CLASSIFICATION_FIELD
    })
    async classificationTypeOptionsWired({ data }) {
        this.classificationTypeOptionsAll = this.setCBOptionsFromPicklistValues(data);
        this.setClassificationTypeOptions();
    }

    setClassificationTypeOptions() {
        if (this.classificationTypeOptionsAll.length === 0) return;

        if (this.TNTMSMTypeValue === "Trademark") {
            this.classificationTypeOptions = this.classificationTypeOptionsAll.slice(0, 34); // all value in the picklist before '34 - Smokers Articles' value
        } else if (this.TNTMSMTypeValue === "Service Mark") {
            this.classificationTypeOptions = this.classificationTypeOptionsAll.slice(34);
        } else {
            this.classificationTypeOptions = this.classificationTypeOptionsAll;
        }
    }

    processFormData() {
        super.processFormData();
        this.setClassificationTypeOptions();
    }
}