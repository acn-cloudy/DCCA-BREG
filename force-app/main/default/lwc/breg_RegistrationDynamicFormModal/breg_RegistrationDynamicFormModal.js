import { LightningElement, api, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";

export default class Breg_RegistrationDynamicFormModal extends LightningElement {
    @api title;
    @api formConfiguration;
    @api formData;
    @api cmpProperties;
    @api fullFormConfig;
    isLoading = false;

    @wire(MessageContext)
    messageContext;

    handleFormDataChange() {}

    connectedCallback() {
        // console.log("--- Connected callback in Modal, formData:", JSON.stringify(this.formData));
        // console.log('--- Member 0', JSON.stringify(this.formData?.members[0]));
        // console.log('--- Member 0 unique key', JSON.stringify(this.formData?.members[0]?.uniqueKey));
    }

    async handleSave() {
        this.isLoading = true;
        this.findDynamicFormsComponent();
        const formValid = await this.dynamicFormsComponent.validateForm();
        if (formValid) {
            const savedSuccessfully = await this.dynamicFormsComponent.saveForm(true);
            if (savedSuccessfully) {
                // this.showToast("Success", "Form saved successfully", "success");
            }
        }
        this.isLoading = false;
    }

    handleSaveFormEvent(event) {
        // const formData = event?.detail?.value?.formData;
        // console.log('handleSaveFormEvent received:', JSON.stringify(event?.detail));
        this.showToast("Success", "Form saved successfully", "success");

        this.dispatchEvent(
            new CustomEvent("saveform", {
                bubbles: true,
                detail: event.detail
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent("cancel"));
    }

    findDynamicFormsComponent() {
        this.dynamicFormsComponent = this.template.querySelector("c-breg_-registration-dynamic-form");
    }

    showToast(title, message, variant) {
        publish(this.messageContext, MESSAGE_CHANNEL, {
            type: MESSAGE_TYPE_TOAST,
            title: title,
            message: message,
            variant: variant
        });
    }
}