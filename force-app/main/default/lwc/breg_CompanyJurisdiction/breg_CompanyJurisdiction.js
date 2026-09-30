import { track, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import BILLING_STATE_FIELD from "@salesforce/schema/Account.BillingStateCode";
import FORMATION_COUNTRY_FIELD from "@salesforce/schema/Account.BillingCountryCode";
import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_CompanyJurisdiction extends BaseFormComponent {
    defaultTitle = "Company Jurisdiction";
    countryValue;
    stateValue;
    stateTextValue;
    @track stateOptions = [];
    @track countryOptions = [];

    dependentFieldsMapping = {
        country: ["state", "stateText"]
    };

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountInfo;

    @wire(getPicklistValues, { recordTypeId: "$accountInfo.data.defaultRecordTypeId", fieldApiName: FORMATION_COUNTRY_FIELD })
    countryOptionsWired({ data, error }) {
        if (data) {
            this.rawCountryPicklist = data;
            let options = this.setCBOptionsFromPicklistValues(data);
            // Sort to put US first
            this.countryOptions = options.sort((a, b) => (a.value === "US" ? -1 : b.value === "US" ? 1 : 0));
            this.updateFilteredStateOptions();
        } else {
            this.rawCountryPicklist = null;
            this.countryOptions = [];
            console.error("countryOptionsWired error:", error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accountInfo.data.defaultRecordTypeId", fieldApiName: BILLING_STATE_FIELD })
    stateOptionsWired({ data, error }) {
        if (data) {
            this.rawStatePicklist = data;
            this.updateFilteredStateOptions();
        } else {
            this.rawStatePicklist = null;
            this.stateOptions = [];
            console.error("stateOptionsWired error:", error);
        }
    }

    updateFilteredStateOptions() {
        // if we don't have the state picklist payload yet, clear options
        if (!this.rawStatePicklist) {
            this.stateOptions = [];
            return;
        }

        // If no country picklist loaded or nothing selected, show all states
        if (!this.rawCountryPicklist || !this.countryValue) {
            this.stateOptions = [];
            return;
        }

        // Find index of selected country in the country picklist values
        const countryIndex = this.rawCountryPicklist.values.findIndex((cv) => cv.value === this.countryValue);
        if (countryIndex === -1) {
            this.stateOptions = this.setCBOptionsFromPicklistValues(this.rawStatePicklist);
            return;
        }

        // Filter state values by their validFor bitmask including the country index

        this.stateOptions = this.rawStatePicklist.values
            .filter((sv) => this.validForIncludes(sv.validFor, countryIndex))
            .map((v) => ({ label: v.label.toUpperCase(), value: v.value }));
    }

    // Check if a picklist value's validFor includes the given controller index.
    // Supports both an array of indices (e.g. [38]) and a base64 bitmask string.
    validForIncludes(validFor, index) {
        if (index < 0) return false;
        if (!validFor) return false;

        // If validFor is already an array of controller indices (newer UI API), use simple membership check
        if (Array.isArray(validFor)) {
            return validFor.includes(index);
        }

        // If validFor is a base64 bitmask string, decode and check the bit
        if (typeof validFor === "string") {
            try {
                const bytes = atob(validFor);
                const byteIndex = Math.floor(index / 8);
                const bitMask = 1 << index % 8;
                if (byteIndex >= bytes.length) return false;
                const charCode = bytes.charCodeAt(byteIndex);
                return (charCode & bitMask) !== 0;
            } catch (e) {
                console.warn("validForIncludes decode error", e);
                return false;
            }
        }

        // Unknown format
        return false;
    }

    // intercept country change to re-filter states, protect country when state changes
    handleInputChange(event) {
        super.handleInputChange(event);
        const inputName = event.target.name || event.target.dataset.name;
        // When country changes, update available states and clear state if no longer valid
        if (inputName === "country") {
            this.updateFilteredStateOptions();
        }
    }

    handleInputBlur(event) {
        super.handleInputBlur(event);
    }

    get stateDisabled() {
        return this.readOnly || !this.countryValue;
    }

    get showStateDropdown() {
        return this.stateOptions && this.stateOptions.length > 0;
    }

    get showStateInput() {
        return !this.showStateDropdown;
    }

    get showStatesReadOnly() {
        return this.stateValue;
    }

    get countryValueReadOnly() {
        const option = this.countryOptions.find((opt) => opt.value === this.countryValue);
        return `Country: ${option ? option.label?.toUpperCase() : "UNITED STATES"}`;
    }

    get stateValueReadOnly() {
        const option = this.stateOptions.find((opt) => opt.value === this.stateValue);
        return `State: ${option ? option.label?.toUpperCase() : ""}`;
    }

    get stateTextValueReadOnly() {
         let stateTextValue = this.stateTextValue?.toUpperCase() || "";
        if (this.countryValueReadOnly == "Country: UNITED STATES" && stateTextValue == "") {
            stateTextValue = "HAWAII";
        }
        return `State: ${stateTextValue}`;
    }
}