import { LightningElement, api, track } from "lwc";
import { Labels } from "./labels";

export default class Breg_MySubscriptions extends LightningElement {
    labels = Labels;
    showSubscriptionCard = false;
    @track chosenSubscription;
    get isSubscriptionsExists() {
        return this.data.length > 0;
    }
    localData;
    @api get data() {
        return this.localData;
    }
    set data(value) {
        this.setAttribute("data", value);
        this.localData = value;
        this.handleValueChange(value);
    }

    handleValueChange(value) {
        if (this.chosenSubscription) {
            let updated = value.find((item) => item.recordId === this.chosenSubscription.recordId);

            if (updated) {
                this.chosenSubscription = { ...updated };
            }
        }
    }

    get columns() {
        if (this.isSubscriptionsExists) {
            return [
                { label: this.labels.BREG_Subscription_Name, fieldName: "subscriptionName" },
                { label: this.labels.BREG_Delivery_Method, fieldName: "deliveryMethod" },
                { label: this.labels.BREG_Associated_Entity, fieldName: "associatedEntity" },
                { label: this.labels.BREG_Column_ExpirationDate, fieldName: "expirationDate", type: "date", typeAttributes: {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    timeZone: 'UTC'
                } },
                { label: this.labels.BREG_Recipient, fieldName: "recipient" },
                { label: this.labels.BREG_Status, fieldName: "status" },
                {
                    type: "action",
                    typeAttributes: {
                        rowActions: [{ label: this.labels.BREG_View, name: "view" }]
                    }
                }
            ];
        }
    }

    handleAction(event) {
        const { action, row } = event.detail;
        if (action.name === "view") {
            this.chosenSubscription = row;
            this.showSubscriptionCard = true;
        }
    }

    handleCardClose() {
        this.showSubscriptionCard = false;
    }

    handleUpdate(event) {
        this.dispatchEvent(new CustomEvent("updatenotification"));
    }
}