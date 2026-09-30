import { LightningElement, api, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import ENTITY_TYPE_FIELD from "@salesforce/schema/Account.breg_Entity_Type__c";
export default class Breg_ELB_SelectRecordTypes extends LightningElement {
    @api searchInput; //
    recordTypes1 = [];
    recordTypes2 = [];
    //allRecordTypes = [];
    selectedTypes = [];
    showValidationError = false;
    error;

    accountRecordTypeId;
    entityTypes;

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    results({ error, data }) {
        if (data) {
            this.accountRecordTypeId = data.defaultRecordTypeId;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error("Error:", JSON.stringify(error));
            this.accountRecordTypeId = undefined;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accountRecordTypeId", fieldApiName: ENTITY_TYPE_FIELD })
    picklistResults({ error, data }) {
        if (data) {
            // Filter out 'CA' and 'R7' entity type values
            this.entityTypes = data.values.filter(entityType => entityType.value !== 'CA' && entityType.value !== 'R7');
            if (this.entityTypes) {
                const half = Math.ceil(this.entityTypes.length / 2);
                this.recordTypes1 = this.entityTypes.slice(0, half);
                this.recordTypes2 = this.entityTypes.slice(half);
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
            console.error("Error:", JSON.stringify(error));
            this.entityTypes = undefined;
        }
    }

    connectedCallback() {
        if (this.searchInput.recordTypes != null) {
            this.selectedTypes = this.searchInput.recordTypes;
        }
    }

    @api
    validate() {
        let isValid = true;
        if (this.selectedTypes.length === 0) {
            isValid = false;
            this.showValidationError = true;
        } else {
            this.showValidationError = false;
        }
        return isValid;
    }
    get checkboxItems1() {
        return this.getColumn(true);
    }

    get checkboxItems2() {
        return this.getColumn(false);
    }

    getColumn(firstColumn) {
        let columns;
        if (firstColumn) {
            columns = this.recordTypes1;
        }
        else {
            columns = this.recordTypes2;
        }
        return columns.map((recordType) => ({
            label: recordType.label,
            value: recordType.value,
            checked: this.selectedTypes.includes(recordType.value)
        }));
    }

    handleCheckboxChange(event) {
        var fieldValue = event.target.name;
        if (event.target.checked) {
            if (!this.selectedTypes.includes(fieldValue)) {
                this.selectedTypes = [...this.selectedTypes, fieldValue];
            }
        } else {
            // Remove the unchecked type from the selectedTypes array
            this.selectedTypes = this.selectedTypes.filter((type) => type !== fieldValue);
        }
        this.sendEvent();
    }

    handleSelectAllClick() {
        this.selectedTypes = [...this.recordTypes1.map(rt => rt.value), ...this.recordTypes2.map(rt => rt.value)];
        this.sendEvent();
    }
    handleDeselectAllClick() {
        this.selectedTypes = [];
        this.sendEvent();
    }

    sendEvent() {
        this.dispatchEvent(
            new CustomEvent("stepdata", {
                detail: {
                    recordTypes: this.selectedTypes
                }
            })
        );
    }
}