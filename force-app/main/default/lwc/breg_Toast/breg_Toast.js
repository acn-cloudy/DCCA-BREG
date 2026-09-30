import { LightningElement, wire } from "lwc";
import { subscribe, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";

const TIMEOUT = 3000;

export default class Breg_Toast extends LightningElement {
    title;
    message;
    variant;
    displayToast = false;

    @wire(MessageContext)
    messageContext;

    subscribeToMessageChannel() {
        this.subscription = subscribe(this.messageContext, MESSAGE_CHANNEL, (message) => this.handleMessage(message));
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    // Handler for message received by component
    handleMessage(message) {
        if (message.type !== MESSAGE_TYPE_TOAST) {
            return;
        }
        this.title = message.title;
        this.message = message.message;
        this.variant = message.variant;
        this.displayToast = true;
        this.closeToast();
    }

    closeToast() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.displayToast = false;
        }, TIMEOUT);
    }

    get iconName() {
        return this.variant === "success" ? "utility:success" : "utility:error";
    }

    get toastClass() {
        return `toast toast-${this.variant}`;
    }
}