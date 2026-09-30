import { api, track, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import BaseFormComponent from "c/breg_BaseFormComponent";
import getInfo from "@salesforce/apex/BREGAccountInfoController.getInfo";
import saveInfo from "@salesforce/apex/BREGAccountInfoController.saveInfo";
import { navigateToPage, getPageParamsFromUrl, validatePhoneNumber } from "c/utils";

import { getPicklistValues } from "lightning/uiObjectInfoApi";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import CONTACT_OBJECT from "@salesforce/schema/Contact";
import SERVICE_PROVIDER_FIELD from "@salesforce/schema/Contact.breg_Mobile_Service_Provider__c";


import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";

//import { Labels } from "./labels";

export default class Breg_AccountInfo extends BaseFormComponent {
    @track contactData = {};
    @api caseId;
    @api parentCaseId;
    @api isDynamicForms = false;

    //labels = Labels;
    @api readOnly = false;

    isLoading = false;

    @wire(MessageContext)
    messageContext;

    contactInfo;
    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    wiredContactInfo({ error, data }) {
        if (data) {
            this.contactInfo = data;
            // console.log('this.contactInfo = ' + JSON.stringify(this.contactInfo));
        } else if (error) {
            this.error = error;
            console.error("Error retrieving object info: ", error);
        }
    }

    get contactName() {
        let contactName = "";
        if (this.contactData) {
            contactName = `${this.contactData.FirstName || ""} ${this.contactData.LastName || ""}`.trim();
        }
        return contactName;
    }

    get contactMailingAddress() {
        let mailingAddress = "";
        if (this.contactData) {
            mailingAddress = `${this.contactData.street || ""} ${this.contactData.city || ""} ${this.contactData.state || ""}, ${this.contactData.postalCode || ""} ${this.contactData.country || ""}`.trim();
        }
        return mailingAddress;
    }

    get contactPhone() {
        let phone = "";
        if (this.contactData) {
            phone = this.contactData.Phone || "";
        }
        return phone;
    }

    get contactEmail() {
        let email = "";
        if (this.contactData) {
            email = this.contactData.Email || "";
        }
        return email;
    }

    handleEdit() {
        window.location.href = `/account-settings?caseId=${this.caseId}` + (this.parentCaseId ? `&parentCaseId=${this.parentCaseId}` : "");
    }

    connectedCallback() {
        const { caseId, parentCaseId } = getPageParamsFromUrl();
        if (caseId) {
            this.caseId = caseId;
        }
        if (parentCaseId) {
            this.parentCaseId = parentCaseId;
        }
        this.loadData();
    }

    async loadData() {
        try {
            const contactData = await getInfo();
            if (contactData) {
                this.contactData = contactData;
            }
        } catch (error) {
            console.error("Error loading account info", JSON.stringify(error));
        }
    }

    @api
    getValues() {
        const contact = {};
        this.template.querySelectorAll("lightning-input").forEach((input) => {
            // for checkbox, use checked instead of value
            if (input.type === "checkbox") {
                contact[input.dataset.name] = input.checked;
            } else {
                contact[input.dataset.name] = input.value;
            }
        });
        contact.Id = this.contactData.Id;
        return contact;
    }

    validateForm() {
        let isValid = true;
        const contactInfoCmp = this.template.querySelector("c-breg_-contact-info");
        const addressCmp = this.template.querySelector("c-breg_-address");
        [contactInfoCmp, addressCmp].forEach((cmp) => {
            if (!cmp.reportValidity()) {
                isValid = false;
            }
        });
        this.template.querySelectorAll("lightning-input").forEach((input) => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        this.template.querySelectorAll("input").forEach((input) => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        return isValid;
    }

    checkValidity() {
        let baseValid = super.checkValidity();
        if (!baseValid) {
            return false;
        }

        let requiredContactInfoValid = true;
        if (this.isDynamicForms && this.contactData && Object.keys(this.contactData).length > 0) { // TODO: remove contactData condition (&& this.contactData && Object.keys(this.contactData).length > 0) after testing
            requiredContactInfoValid = this.validateRequiredContactInfo();
        }
        return baseValid && requiredContactInfoValid;
    }

    validateRequiredContactInfo() {
        let requiredContactInfoValid = true;
        let phoneMissing = false;
        let emailMissing = false;
        let errorMessage = "";

        if (!this.contactPhone) {
            phoneMissing = true;
            requiredContactInfoValid = false;
        }
        if (!this.contactEmail) {
            emailMissing = true;
            requiredContactInfoValid = false;
        }

        if (!requiredContactInfoValid) {
            errorMessage = `
                ${phoneMissing ? "Phone Number" : ""}
                ${phoneMissing && emailMissing ? " and " : ""}
                ${emailMissing ? "Email" : ""}
                ${phoneMissing && emailMissing ? " are " : " is "}
                required contact information. Please click the "Edit" button in the "Contact Information for questions, approvals, or returned documents" section to update this information.
            `;

            this.showToast("", errorMessage, "error");
        }

        return requiredContactInfoValid;
    }

    async handleSave() {
        this.isLoading = true;
        try {
            if (this.validateForm()) {
                this.contactData = this.getContactInfo();
                this.contactData = this.getPhones();
                console.debug("Saving contact data: ", JSON.stringify(this.contactData));
                await saveInfo({ infoPayload: JSON.stringify(this.contactData) });
                this.showToast("", "Successfully saved account information", "success");
                if (this.caseId) {
                    this.navigateBackToForm();
                } else {
                    navigateToPage('/');
                }
            }
        }
        catch (error) {
            console.error(JSON.stringify(error));
            this.showToast("", "Error while saving account info: " + error.body.message, "error");
        }
        this.isLoading = false;
    }

    getPhones() {
        const phone = this.template.querySelector('[data-name="Primary Phone"]');
        const secondaryPhone = this.template.querySelector('[data-name="Secondary Phone"]');
        const mobilePhone = this.template.querySelector('[data-name="Mobile Phone"]');
        this.contactData.Phone = phone.value;
        this.contactData.SecondaryPhone = secondaryPhone.value;
        this.contactData.MobilePhone = mobilePhone.value;
        return this.contactData;
    }

    getContactInfo() {
        const contactInfoCmp = this.template.querySelector("c-breg_-contact-info");
        const contactInfo = contactInfoCmp.getValues();
        this.contactData = { ...this.contactData, ...contactInfo };
        return this.contactData;
    }

    handleMobileSameAsPrimary(event) {
        if (event.target.checked) {
            const phone = this.template.querySelector('[data-name="Primary Phone"]');
            const mobilePhone = this.template.querySelector('[data-name="Mobile Phone"]');
            mobilePhone.value = phone.value;
        }
    }

    /**
     * Handles phone input blur event to validate phone number
     * @param {Event} event - The blur event from the input field
     */
    handlePhoneBlur(event) {
        const input = event.target;
        const phoneNumber = input.value;
        const validation = validatePhoneNumber(phoneNumber);

        if (validation.isValid) {
            input.setCustomValidity('');
        } else {
            input.setCustomValidity(validation.errorMessage);
        }
        input.reportValidity();
    }

    navigateBackToForm() {
        const params = {
            caseId: this.caseId,
            readOnly: true
        };
        if (this.parentCaseId) {
            params.parentCaseId = this.parentCaseId;
        }
        navigateToPage('/start', params);
    }

    handleInfoChange(event) {
        const input = event.detail.value;
        this.contactData[`${input.inputName}`] = input.value;
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