import { LightningElement, api, wire, track } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import createAppClass from "@salesforce/apex/ApplicationClassificationsService.createRecord";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const FIELDS = [
  "Application__c.LicenseType__c",
  "Application__c.Id",
  "Application__c.Name"
];
export default class CreateAppClassification extends LightningElement {
  @api recordId;
  @track isLoading;
  @track header = "Add Classification";
  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  application;

  get licenseTypeId() {
    if (this.application && this.application.data)
      return (
        " where LicenseType__c = '" +
        this.application.data.fields.LicenseType__c.value +
        "'"
      );
    else return "";
  }
  submit() {
    this.isLoading = true;
    const lookup = this.template.querySelector('[data-id="lookup"]');

    const fields = this.template.querySelectorAll('[data-id="field"]');
    let isValid = true;
    fields.forEach((item) => {
      isValid = isValid && item.reportValidity();
    });

    if (isValid) {
      let record = {};
      fields.forEach((item) => {
        record[item.fieldName] = item.value;
      });

      record.Classification__c = lookup.selectedRecord.Id;
      const str = JSON.stringify(record);
      createAppClass({ str })
        .then(() => {
          const event = new ShowToastEvent({
            title: "Success",
            variant: "success",
            message: "Application classification has been created successfully"
          });
          this.isLoading = false;
          this.dispatchEvent(event);
          this.dispatchEvent(new CustomEvent("close"));
        })
        .catch((error) => {
          const event = new ShowToastEvent({
            title: "Error",
            variant: "error",
            message: error
          });
          this.dispatchEvent(event);
          this.isLoading = false;
        });
    } else {
      this.isLoading = false;
    }
  }
  cancel() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}