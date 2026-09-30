import { wire, track } from "lwc";
import BaseFormComponent from 'c/breg_BaseFormComponent';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import TNTMSM_CLASSIFICATION_FIELD from "@salesforce/schema/Case.breg_TNTMSM_Classification__c";

export default class Breg_TNTMSMAssignment extends BaseFormComponent {
    defaultTitle = 'TN/TM/SM Assignment';
    TNTMSMAssignmentTypeValue;
    TNTMSMNameValue;
    certificateNumberValue;
    classificationTypeValue;
    @track classificationTypeOptionsAll = [];
    @track classificationTypeOptions = [];

    get showClassificationType() {
        return this.TNTMSMAssignmentTypeValue === 'Trademark' || this.TNTMSMAssignmentTypeValue === 'Service Mark';
    }

    get TNTMSMAssignmentTypeOptions() {
        return [
            { label: 'Trade Name', value: 'Trade Name' },
            { label: 'Trademark', value: 'Trademark' },
            { label: 'Service Mark', value: 'Service Mark' },
            { label: 'Publicity Rights Name', value: 'Publicity Rights Name' }
        ];
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    results({ data }) {
        if (data) {
            this.caseRecTypeId = data.defaultRecordTypeId;
        } 
    }

    @wire(getPicklistValues, { recordTypeId: "$caseRecTypeId", fieldApiName: TNTMSM_CLASSIFICATION_FIELD })
    async classificationTypeOptionsWired({ data }) {
        this.classificationTypeOptionsAll = this.setCBOptionsFromPicklistValues(data);
        this.setClassificationTypeOptions();
    }

    setClassificationTypeOptions() {
        if (this.classificationTypeOptionsAll.length === 0) return;

        if (this.TNTMSMAssignmentTypeValue === 'Trademark') {
            this.classificationTypeOptions = this.classificationTypeOptionsAll.slice(0, 34); // all value in the picklist before '34 - Smokers Articles' value
        } else if (this.TNTMSMAssignmentTypeValue === 'Service Mark') {
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