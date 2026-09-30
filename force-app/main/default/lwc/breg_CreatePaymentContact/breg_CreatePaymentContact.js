import { LightningElement, api, wire } from "lwc";
import { setPageUrlParams } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import { Labels } from "./labels";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import createNotifications from "@salesforce/apex/BREGNotificationsHandler.createNotifications";
import getAccountData from "@salesforce/apex/BREGAnnualsController.getAccountData";

export default class Breg_AnnualsPaymentContact extends NavigationMixin(LightningElement) {
    @api accountNumber;
    @api entityId;
    labels = Labels;
    sendAlert = true;
    personAccountRecordTypeId;
    isLoading = true;
    _renderedOnce = false;

    renderedCallback() {
        if (!this._renderedOnce) {
            this._renderedOnce = true;

            setTimeout(() => {
                this.isLoading = false;
            }, 3000);
        }
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    objectInfo({ data, error }) {
        if (data) {
            const rtMap = data.recordTypeInfos;
            const entry = Object.values(rtMap).find((rt) => rt.name === "Person Account");
            this.personAccountRecordTypeId = entry?.recordTypeId || null;
        } else if (error) {
            console.error("Error receiving RecordTypeId:", error);
        }
    }

    handleChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.target.type === "checkbox" ? event.target.checked : event.target.value;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    handlePrev() {
        setPageUrlParams({
            page: "login",
            fileNumber: this.accountNumber,
            accountId: this.accountId,
            year: null
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    handleSubmit(event) {
        this.isLoading = true;
        event.preventDefault();
        const fields = event.detail.fields;
        this.template.querySelector("lightning-record-edit-form").submit(fields);
    }

    handleSuccess(event) {
        const newContactId = event.detail.id;

        this.contactId = newContactId;
        if (this.accountNumber && this.sendAlert) {
            let notificationData = {
                recordId: this.entityId,
                sourceObject: "Account",
                notifications: [
                    {
                        id: "Annual Report Reminder"
                    }
                ]
            };
            const jsonString = JSON.stringify(notificationData);
            createNotifications({ jsonInput: jsonString, contactToUse: this.contactId, isFree: true })
                .then(() => {
                    console.log("Notifications created");
                })
                .catch((error) => {
                    console.error("Error:", error);
                });
        }

        this.isLoading = false;
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }
}