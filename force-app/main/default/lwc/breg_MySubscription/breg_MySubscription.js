import { LightningElement, api, track } from "lwc";
import { Labels } from "./labels";
import updateMultipleNotifications from "@salesforce/apex/BREGNotificationsHandler.updateMultipleNotifications";

export default class Breg_MySubscription extends LightningElement {
    localChosenSub;
    @api get chosenSubscription() {
        return this.localChosenSub;
    }
    set chosenSubscription(value) {
        this.localChosenSub = value;
        this.setAttribute("localChosenSub", value);
    }

    get isActiveSubscription() {
        return this.chosenSubscription.status === "Active";
    }
    get subscriptionLabel() {
        return this.isActiveSubscription ? this.labels.BREG_Pause : this.labels.BREG_Resume;
    }
    get subscriptionButtonVariant() {
        return this.isActiveSubscription ? "destructive" : "brand";
    }

    get statusBadgeClass() {
        return this.isActiveSubscription ? "slds-badge slds-theme_success" : "slds-badge slds-theme_warning";
    }

    @track isEdit = false;
    @track editedRecipient;
    labels = Labels;
    showModal = false;
    modalType;
    modalLabel;
    modalText;

    get description() {
        if (this.chosenSubscription.subscriptionName.includes("Annual")) {
            return this.labels.BREG_Notif_Annual_Desc;
        } else if (this.chosenSubscription.subscriptionName.includes("Trade")) {
            return this.labels.BREG_Notif_TN_Desc;
        } else if (this.chosenSubscription.subscriptionName.includes("Business")) {
            return this.labels.BREG_Notif_Alerts_Desc;
        } else {
            return "";
        }
    }

    handleSubscriptionChange() {
        this.modalType = "SubscriptionChange";
        this.modalLabel = "Are you sure?";
        this.modalText = this.isActiveSubscription
            ? "Do you want to unsubscribe from these notifications? It will be available to restore untill End Date."
            : "Do you want to restore subscription to notifications?";
        this.showModal = true;
    }

    enableEdit() {
        this.isEdit = true;
        this.editedRecipient = this.chosenSubscription.recipient;
    }

    handleRecipientChange(event) {
        this.editedRecipient = event.target.value;
    }

    handleSaveRecipient() {
        this.modalType = "EmailChange";
        this.modalLabel = "Are you sure?";
        this.modalText = "Do you want to change email who will receive this notification?";
        this.showModal = true;
    }
    handleModalContinue() {
        let updates;
        if (this.modalType === "EmailChange") {
            updates = {
                [this.chosenSubscription.recordId]: {
                    breg_Recipient_Email__c: this.editedRecipient
                }
            };
            this.isEdit = false;
        } else if (this.modalType === "SubscriptionChange") {
            updates = {
                [this.chosenSubscription.recordId]: {
                    breg_Status__c: this.isActiveSubscription ? "Paused" : "Active"
                }
            };
        }

        updateMultipleNotifications({ updatesById: updates })
            .then(() => {
                this.dispatchEvent(new CustomEvent("update"));
            })
            .catch((error) => {
                console.error("Update error:", error);
            });

        this.showModal = false;
    }

    handleModalCancel() {
        this.showModal = false;
    }

    cancelEdit() {
        this.isEdit = false;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent("close"));
    }
}