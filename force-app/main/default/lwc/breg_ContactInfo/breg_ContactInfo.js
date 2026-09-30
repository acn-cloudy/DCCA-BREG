import { api, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { Labels } from "./labels";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import BILLING_COUNTRY_FIELD from "@salesforce/schema/Account.BillingCountryCode";
import STATE_FIELD from "@salesforce/schema/Account.BillingStateCode";

export default class Breg_ContactInfo extends BaseFormComponent {
    @api contactData = {};
    @api hideEmail = false;
    @api showPhone = false;
    @api showAddress = false;

    accRecTypeId;
    countryOptions = [];
    stateOptions = [];
    rawCountryPicklist;
    rawStatePicklist;

    countryValue;
    stateValue;
    stateTextValue;

    dependentFieldsMapping = {
        country: ["state", "stateText"]
    };

    noneStateOption = { label: "--None--", value: "__NONE__" };

    connectedCallback() {
        this.countryValue = this.contactData?.MailingCountryCode || "US";
        this.stateValue = this.contactData?.MailingStateCode || "";
        this.stateTextValue = this.contactData?.MailingState || "";
    }

    get showEmail() {
        return !this.hideEmail;
    }

    get showStateDropdown() {
        return this.stateOptions && this.stateOptions.length > 0;
    }

    labels = Labels;

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    handleAccountInfo({ data }) {
        if (data) {
            this.accRecTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: BILLING_COUNTRY_FIELD })
    handleCountryOptions({ data }) {
        if (data?.values) {
            this.rawCountryPicklist = data;
            this.countryOptions = this.setCBOptionsFromPicklistValues(data).sort((a, b) => {
                if (a.value === "US") return -1;
                if (b.value === "US") return 1;
                return 0;
            });
            this.updateFilteredStateOptions();
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: STATE_FIELD })
    handleStateOptions({ data }) {
        if (data?.values) {
            this.rawStatePicklist = data;
            this.updateFilteredStateOptions();
        }
    }

    updateFilteredStateOptions() {
        if (!this.rawStatePicklist) {
            this.stateOptions = [this.noneStateOption];
            this.stateValue = this.noneStateOption.value;
            return;
        }

        if (!this.rawCountryPicklist || !this.countryValue) {
            this.stateOptions = [this.noneStateOption];
            this.stateValue = this.noneStateOption.value;
            return;
        }

        const countryIndex = this.rawCountryPicklist.values.findIndex((cv) => cv.value === this.countryValue);
        if (countryIndex === -1) {
            this.stateOptions = [this.noneStateOption];
            this.stateValue = this.noneStateOption.value;
            return;
        }

        const filteredStates = this.rawStatePicklist.values
            .filter((sv) => this.validForIncludes(sv.validFor, countryIndex))
            .map((item) => ({
                label: item.label,
                value: item.value
            }));

        if (!filteredStates.length) {
            this.stateOptions = [this.noneStateOption];
            this.stateValue = this.noneStateOption.value;
            return;
        }

        this.stateOptions = filteredStates;

        if (!this.stateOptions.some((option) => option.value === this.stateValue)) {
            this.stateValue = "";
        }
    }

    validForIncludes(validFor, index) {
        if (index < 0) return false;
        if (!validFor) return false;

        if (Array.isArray(validFor)) {
            return validFor.includes(index);
        }

        if (typeof validFor === "string") {
            try {
                const bytes = atob(validFor);
                const byteIndex = Math.floor(index / 8);
                const bitMask = 1 << (index % 8);
                if (byteIndex >= bytes.length) return false;
                const charCode = bytes.charCodeAt(byteIndex);
                return (charCode & bitMask) !== 0;
            } catch (error) {
                console.warn("validForIncludes decode error", error);
                return false;
            }
        }

        return false;
    }

    handleInputChange(event) {
        super.handleInputChange(event);
        const inputName = event?.target?.dataset?.name || event?.target?.name;
        if (inputName === "country") {
            this.updateFilteredStateOptions();
        }
    }

    @api
    getValues() {
        const contact = {};
        this.template.querySelectorAll("lightning-input, lightning-combobox").forEach((input) => {
            if (input.dataset.name === "Phone") {
                contact[input.dataset.name] = this.getNormalizedPhoneValue(input.value);
                return;
            }
            if (input.dataset.name === "country") {
                contact.MailingCountryCode = input.value;
                return;
            }
            if (input.dataset.name === "state") {
                if (input.value && input.value !== this.noneStateOption.value) {
                    contact.MailingStateCode = input.value;
                }
                return;
            }
            contact[input.dataset.name] = input.value;
        });
        contact.Id = this.contactData.Id;
        return contact;
    }

    async reportValidity() {
        const phoneValid = this.formatAndValidatePhone();

        const baseValid = super.reportValidity();
        if (!baseValid || !phoneValid) {
            return false;
        }

        const nameValid = await this.validateName();

        return baseValid && nameValid;
    }

    handleInputBlur(event) {
        const input = event?.target;
        const inputName = input?.dataset?.name;
        if (!input || !inputName) {
            return;
        }

        if (inputName === "FirstName" || inputName === "LastName") {
            input.value = this.toTitleCase(input.value);
            this.validateName();
        } else if (inputName === "MailingStreet" || inputName === "MailingCity") {
            input.value = this.toUpperCaseValue(input.value);
        }

        super.handleInputBlur(event);
    }

    toTitleCase(value) {
        return (value || "")
            .trim()
            .toLowerCase()
            .replace(/\b\p{L}/gu, (character) => character.toUpperCase());
    }

    toUpperCaseValue(value) {
        return (value || "").trim().toUpperCase();
    }

    handlePhoneInput(event) {
        const input = event?.target;
        if (!input) {
            return;
        }

        this.validatePhoneCharacters(input);
    }

    handlePhoneBlur() {
        const phoneInput = this.template.querySelector('[data-name="Phone"]');
        if (!phoneInput) {
            return;
        }

        phoneInput.value = this.collapsePhoneWhitespace(phoneInput.value);
        this.formatAndValidatePhone();
    }

    collapsePhoneWhitespace(value) {
        return (value || "").replace(/\s+/g, " ").trim();
    }

    getFormattedPhoneValue(value) {
        const digits = (value || "").replace(/\D/g, "");
        if (digits.length !== 10) {
            return value;
        }

        return `${digits.slice(0, 3)}-${digits.slice(3, 6)}-${digits.slice(6)}`;
    }

    getNormalizedPhoneValue(value) {
        const rawValue = this.collapsePhoneWhitespace(value);

        if (!rawValue) {
            return "";
        }

        if (rawValue.startsWith("+")) {
            const digitsOnly = rawValue.replace(/\D/g, "");
            return `+${digitsOnly}`;
        }

        return this.getFormattedPhoneValue(rawValue);
    }

    formatAndValidatePhone() {
        const phoneInput = this.template.querySelector('[data-name="Phone"]');
        if (!phoneInput) {
            return true;
        }

        const rawValue = this.collapsePhoneWhitespace(phoneInput.value);
        const allowedCharacters = /^[0-9+\- ]*$/;
        if (!allowedCharacters.test(rawValue)) {
            phoneInput.setCustomValidity("Use only numbers, spaces, plus signs, and hyphens");
            phoneInput.reportValidity();
            return false;
        }

        const digits = rawValue.replace(/\D/g, "");

        if (!digits) {
            phoneInput.setCustomValidity("");
            phoneInput.reportValidity();
            return true;
        }

        if (rawValue.startsWith("+")) {
            if (digits.length < 8 || digits.length > 15) {
                phoneInput.setCustomValidity("Enter international number with country code, e.g. +18085551234");
                phoneInput.reportValidity();
                return false;
            }

            phoneInput.value = `+${digits}`;
            phoneInput.setCustomValidity("");
            phoneInput.reportValidity();
            return true;
        }

        if (digits.length !== 10) {
            phoneInput.setCustomValidity("Enter a 10-digit phone number in the format 123-456-7890");
            phoneInput.reportValidity();
            return false;
        }

        phoneInput.value = this.getFormattedPhoneValue(rawValue);
        phoneInput.setCustomValidity("");
        phoneInput.reportValidity();

        return true;
    }

    validatePhoneCharacters(input) {
        const rawValue = (input.value || "").trim();
        const allowedCharacters = /^[0-9+\- ]*$/;
        if (!rawValue) {
            input.setCustomValidity("");
            return true;
        }

        if (!allowedCharacters.test(rawValue)) {
            input.setCustomValidity("Use only numbers, spaces, plus signs, and hyphens");
            return false;
        }

        if ((rawValue.match(/\+/g) || []).length > 1 || (rawValue.includes("+") && !rawValue.startsWith("+"))) {
            input.setCustomValidity("Use plus sign only at the beginning of the phone number");
            return false;
        }

        input.setCustomValidity("");
        return true;
    }

    async validateName() {
        let isValid = true;
        const firstNameInput = this.template.querySelector('[data-name="FirstName"]');
        const lastNameInput = this.template.querySelector('[data-name="LastName"]');

        if (!firstNameInput) {
            console.warn("First name input not found");
            return isValid;
        }

        if (!lastNameInput) {
            console.warn("Last name input not found");
            return isValid;
        }

        firstNameInput.setCustomValidity("");
        lastNameInput.setCustomValidity("");

        const disallowed = ["guest user", "guest"];

        const firstVal = (firstNameInput.value || "").trim().toLowerCase();
        const lastVal = (lastNameInput.value || "").trim().toLowerCase();

        if (disallowed.includes(`${firstVal} ${lastVal}`) || disallowed.includes(firstVal) || disallowed.includes(lastVal)) {
            const message = 'Name cannot be "Guest" or "Guest User".';
            if (disallowed.includes(`${firstVal} ${lastVal}`) || disallowed.includes(firstVal)) {
                firstNameInput.setCustomValidity(message);
                isValid = false;
            }
            if (disallowed.includes(`${firstVal} ${lastVal}`) || disallowed.includes(lastVal)) {
                lastNameInput.setCustomValidity(message);
                isValid = false;
            }
        }

        firstNameInput.reportValidity();
        lastNameInput.reportValidity();

        return isValid;
    }
}