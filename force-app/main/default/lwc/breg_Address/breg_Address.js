import { api, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import BaseFormComponent from "c/breg_BaseFormComponent";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import COUNTRY_FIELD from "@salesforce/schema/Account.BillingCountryCode";
import STATE_FIELD from "@salesforce/schema/Account.BillingStateCode";
import validateStreet from "@salesforce/apex/BREGStartNewBusinessUtils.validateStreet";
import validatePostalCode from "@salesforce/apex/BREGStartNewBusinessUtils.validatePostalCode";

export default class Breg_Address extends BaseFormComponent {
    defaultTitle = "Address";
    @api isCra = false;
    @api isAgent = false;
    @api hideHeader = false;
    _predefinedValues = {};

    accRecTypeId;
    countryOptions;
    stateOptions;
    countryValue;
    streetValue;
    street2Value;
    stateValue;
    stateTextValue;
    cityValue;
    postalCodeValue;

    // LLC-1 specific checkbox state
    isAddressSameAsMailing = true;
    _addressSameAsMailingInitialized = false;
    _lastMailingAddressSnapshot = null;

    dependentFieldsMapping = {
        country: ["state", "stateText"]
    };

    @api
    get predefinedValues() {
        return this._predefinedValues;
    }
    set predefinedValues(newvalues) {
        this._predefinedValues = newvalues;
        if (newvalues) {
            Object.keys(newvalues).forEach((key) => {
                this[`${key}Value`] = newvalues[key];
            });
        }
    }

    get onlyDomesticAddress() {
        return this.isAgent || this.componentSettings?.onlyDomestic;
    }

    get addressReadOnly() {
        return (!this.onlyAddressEditable && this.readOnly) || this._readOnly;
    }

    get countryAndStateReadOnly(){
        return (!this.onlyAddressEditable && (this.readOnly || this.onlyDomesticAddress || this.isCra)) || this._readOnly;
    }

    get addressReadOnly2() {
        return (!this.onlyAddressEditable && (this.readOnly || this.isCra)) || this._readOnly;
    }

    get addSectionMargin() {
        return this.componentSettings?.addressTitle;
    }

    get displayTitle() {
        return this.title && (!this.hideHeader || this.componentSettings?.addressTitle);
    }

    get showEditSectionButton() {
        return this.readOnly && !this.alwaysReadOnly && this.isAnnualForm && this.displayTitle;
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    results({ data }) {
        if (data) {
            this.accRecTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: COUNTRY_FIELD })
    async countryOptionsWired({ data }) {
        // Store raw country picklist payload for dependent filtering
        this.rawCountryPicklist = data;

        // Build options from picklist values
        let options = this.setCBOptionsFromPicklistValues(data);

        // Sort options by label for display
        if (options && Array.isArray(options)) {
            options.sort((a, b) => {
                if (a.label < b.label) return -1;
                if (a.label > b.label) return 1;
                return 0;
            });

            // Move the option with value === 'US' to the front if it exists
            const usIndex = options.findIndex((opt) => opt.value === "US");
            if (usIndex > 0) {
                const [usOpt] = options.splice(usIndex, 1);
                options.unshift(usOpt);
            }
        }

        this.countryOptions = options;

        // Update dependent state options when country list changes
        this.updateFilteredStateOptions();
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: STATE_FIELD })
    async stateOptionsWired({ data }) {
        // Store raw state picklist payload and update filtered states
        this.rawStatePicklist = data;
        this.updateFilteredStateOptions();
    }

    updateFilteredStateOptions() {
        // if we don't have the state picklist payload yet, clear options
        if (!this.rawStatePicklist) {
            this.stateOptions = [];
            return;
        }

        // If no country picklist loaded or nothing selected, show no states (we only show states related to chosen country)
        if (!this.rawCountryPicklist || !this.countryValue) {
            this.stateOptions = [];
            return;
        }

        // Find index of selected country in the country picklist values
        const countryIndex = this.rawCountryPicklist.values.findIndex((cv) => cv.value === this.countryValue);
        if (countryIndex === -1) {
            // fallback to showing all states
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

    get showStatesPicklist() {
        return this.stateOptions && this.stateOptions.length > 0;
    }

    get showStreetCopyButtons() {
        return !this.componentSettings?.isBusinessAddress;
    }

    get showStreetCopyCheckbox() {
        return !this.componentSettings?.isMailingAddress && this.isAnnualForm && !this.isNested && this.readOnly;
    }

    get isStreetSameAsMailing() {
        const mailingAddressConfig = this.formConfig.elements.find((el) => {
            if (!el.componentSettings) {
                return false;
            }
            let componentSettings = JSON.parse(el.componentSettings);
            return el.name === "Address" && componentSettings.isMailingAddress;
        });
        let isSame = true;
        if (mailingAddressConfig) {
            isSame = this.isSameAddress(mailingAddressConfig);
        } else {
            isSame = false;
        }
        return isSame;
    }

    get showSameAsMailingCheckbox() {
        return this.componentSettings?.showSameAsMailingCheckbox;
    }

    get showSameAsMailingButton() {
        return this.componentSettings?.showSameAsMailingButton;
    }

    get showSameAsBusinessButton() {
        return this.componentSettings?.showSameAsBusinessButton;
    }

    get showSameAsStreetButton() {
        return this.componentSettings?.showSameAsStreetButton;
    }

    get showCopyButtons() {
        return this.showSameAsMailingButton || this.showSameAsBusinessButton || this.showSameAsStreetButton;
    }

    // Show address fields: hide when "Same as the mailing address" checkbox is checked
    get showAddressFieldsAndButtons() {
        return !(this.showSameAsMailingCheckbox && this.isAddressSameAsMailing);
    }

    get showFields() {
        if (this.showHasChangedCheckbox) {
            return this.hasChangedValue;
        }
        if (this.showSameAsMailingCheckbox) {
            return !this.isAddressSameAsMailing;
        }
        return true;
    }

    get readOnlyAddressString() {
        const city = this.cityValue ? `${this.cityValue}, ` : "";
        const postal = this.postalCodeValue ?? "";
        const stateLabel = this.getLabelFromOptions(this.stateOptions, this.stateValue);
        let stateFull = stateLabel ? `${stateLabel} ` : "";

        return `${city}${stateFull}${postal}`.trim();
    }

    get countryFull() {
        return this.getLabelFromOptions(this.countryOptions, this.countryValue);
    }

    get stateFull() {
        const stateLabel = this.getLabelFromOptions(this.stateOptions, this.stateValue);
        return stateLabel || this.stateTextValue;
    }

    get countryReadOnlyText() {
        return `${this.countryFull || ""}`.trim();
    }

    get stateReadOnlyText() {
        return `${this.stateFull || ""}`.trim();
    }

    get hasChangedCheckboxLabel() {
        return this.componentSettings?.hasChangedCheckboxLabel || `The above named entity has changed its ${this.config?.labelOverride2?.toLowerCase()}.`;
    }

    get description() {
        let defaultDescription = !this.isNested ? this.config?.labelOverrideLong : this.componentSettings?.addressDescription;
        if (this.readOnly) {
            return this.componentSettings?.descriptionReadOnly ?? defaultDescription;
        }
        return defaultDescription;
    }

    connectedCallback() {
        super.connectedCallback();
        this.setDefaultValues();

        // Override title if specified in component settings
        // Used to set a title when the Address component is nested within the Member component.
        if (this.componentSettings?.addressTitle) {
            this.title = this.componentSettings.addressTitle;
        }
    }

    handleInputChange(event) {
        super.handleInputChange(event);

        // Validate street on blur for Hawaii addresses
        const inputName = event?.target?.name;

        // When country changes, update available states and clear state if no longer valid
        if (inputName === "country") {
            this.updateFilteredStateOptions();

            // clear state selection if it's no longer available
            if (this.stateValue && (!this.stateOptions || !this.stateOptions.some((o) => o.value === this.stateValue))) {
                const formData = { ...this.formData };
                const stateFieldName = this.getFieldName("state");
                const stateTextFieldName = this.getFieldName("stateText");
                this.stateValue = null;
                this.stateTextValue = null;
                if (stateFieldName) formData[stateFieldName] = null;
                if (stateTextFieldName) formData[stateTextFieldName] = null;
                this.dispatchCustomEvent("formupdate", { formData });
            }
        }

        if (inputName === "state" || inputName === "country") {
            this.validateStreet();
            this.validatePostalCode();
        }
    }

    handleInputBlur(event) {
        super.handleInputBlur(event);

        // Validate street on blur for Hawaii addresses
        const inputName = event?.target?.name;
        if (inputName === "street") {
            this.validateStreet();
        } else if (inputName === "postalCode") {
            this.validateStreet();
            this.validatePostalCode();
        }
    }

    async reportValidity() {
        // Get base validation result first
        const baseValid = await super.reportValidity();

        // Only do custom validation if base validation passed
        if (!baseValid) {
            return false;
        }

        // Custom validations for street and postal code
        const streetValid = await this.validateStreet();
        const postalCodeValid = await this.validatePostalCode();

        return baseValid && streetValid && postalCodeValid;
    }

    async validateStreet() {
        let isValid = true;
        if (!this.isAgent) return isValid; // validate only for agent addresses

        const streetInput = this.template.querySelector('[data-name="street"]');

        if (!streetInput) {
            console.warn("Street input not found");
            return isValid;
        }

        // Clear previous errors
        streetInput.setCustomValidity("");

        try {
            const errorMessage = await validateStreet({
                street: this.streetValue || "",
                postalCode: this.postalCodeValue || "",
                state: this.stateValue || "",
                country: this.countryValue || ""
            });

            if (errorMessage) {
                streetInput.setCustomValidity(errorMessage);
                isValid = false;
            }
        } catch (error) {
            console.error("Street validation error:", error);
            streetInput.setCustomValidity("Validation error occurred. Please try again.");
            isValid = false;
        } finally {
            streetInput.reportValidity();
        }

        return isValid;
    }

    async validatePostalCode() {
        console.log("*** Validating postal code for postalCodeValue:", this.postalCodeValue);
        let isValid = true;
        const postalCodeInput = this.template.querySelector('[data-name="postalCode"]');

        if (!postalCodeInput) {
            console.warn("Postal code input not found");
            return isValid;
        }

        // Clear previous errors
        postalCodeInput.setCustomValidity("");

        try {
            const errorMessage = await validatePostalCode({
                postalCode: this.postalCodeValue || "",
                state: this.stateValue || "",
                country: this.countryValue || ""
            });

            if (errorMessage) {
                postalCodeInput.setCustomValidity(errorMessage);
                isValid = false;
            }
        } catch (error) {
            console.error("Postal code validation error:", error);
            postalCodeInput.setCustomValidity("Validation error occurred. Please try again.");
            isValid = false;
        } finally {
            postalCodeInput.reportValidity();
        }

        return isValid;
    }

    processFormData() {
        super.processFormData();
        this.setDefaultValues();
        this.initializeAddressSameAsMailingCopy();
        this.updateFilteredStateOptions();
    }

    // LLC-1 specific copy logic
    initializeAddressSameAsMailingCopy() {
        // Only for LLC-1 forms with principal address and checkbox checked
        if (!this.showSameAsMailingCheckbox || this.componentSettings?.isMailingAddress || !this.isAddressSameAsMailing) {
            return;
        }

        const mailingAddressConfig = this.getMailingAddressConfig();
        if (!mailingAddressConfig) {
            return;
        }

        const currentMailingSnapshot = this.getMailingAddressSnapshot(mailingAddressConfig);

        // Initial copy or mailing address has changed
        if (!this._addressSameAsMailingInitialized || this.hasMailingAddressChanged(currentMailingSnapshot)) {
            this._addressSameAsMailingInitialized = true;
            this._lastMailingAddressSnapshot = currentMailingSnapshot;
            this.copyAddress(mailingAddressConfig);
        }
    }

    getMailingAddressConfig() {
        if (this.isNested) {
            return null;
        }
        return this.formConfig.elements.find((el) => {
            if (!el.componentSettings) {
                return false;
            }
            let componentSettings = JSON.parse(el.componentSettings);
            return el.name === "Address" && componentSettings.isMailingAddress;
        });
    }

    getMailingAddressSnapshot(mailingAddressConfig) {
        const targetFieldsMapping = JSON.parse(mailingAddressConfig.targetFieldsMapping);
        const snapshot = {};
        for (let field in targetFieldsMapping) {
            const sourceFieldName = targetFieldsMapping[field];
            if (sourceFieldName) {
                snapshot[field] = this.formData[sourceFieldName] || null;
            }
        }
        return snapshot;
    }

    hasMailingAddressChanged(currentSnapshot) {
        if (!this._lastMailingAddressSnapshot) {
            return true;
        }
        for (let field in currentSnapshot) {
            if (currentSnapshot[field] !== this._lastMailingAddressSnapshot[field]) {
                return true;
            }
        }
        return false;
    }

    setDefaultValues() {
        if (this.isAnnualForm && !this.isAgent) return; // do not set defaults for annual report forms

        const countryFieldName = this.getFieldName("country");
        const stateFieldName = this.getFieldName("state");

        if (
            (!this.countryValue && countryFieldName && !this.formData[countryFieldName]) ||
            (!this.stateValue && stateFieldName && !this.formData[stateFieldName] && this.countryValue === "US")
        ) {
            const formData = {};
            if (!this.countryValue && countryFieldName && !this.formData[countryFieldName]) {
                this.countryValue = "US";
                formData[countryFieldName] = this.countryValue;
            }
            if (((!this.stateValue && stateFieldName && !this.formData[stateFieldName]) || this.onlyDomesticAddress) && this.countryValue === "US") {
                this.stateValue = "HI";
                formData[stateFieldName] = this.stateValue;
            }
            this.dispatchCustomEvent("formupdate", { formData });
            // After setting defaults, refresh dependent state options
            this.updateFilteredStateOptions();
        }
    }

    updateAddressValues(formData = this.formData){
        const countryFieldName = this.getFieldName("country");
        const stateFieldName = this.getFieldName("state");
        this.countryValue = formData[countryFieldName] || null;
        this.stateValue = formData[stateFieldName] || null;
         // After updating values, refresh dependent state options
         this.updateFilteredStateOptions();
    }

    handleMailingAddressClick() {
        let copiedFormData;
        if (!this.isNested) {
            let mailingAddressConfig = this.formConfig.elements.find((el) => {
                if (!el.componentSettings) {
                    return false;
                }
                let componentSettings = JSON.parse(el.componentSettings);
                return el.name === "Address" && componentSettings.isMailingAddress;
            });
            if (mailingAddressConfig) {
                copiedFormData = this.copyAddress(mailingAddressConfig);
            }
        } else {
            this.dispatchCustomEvent("copymailingaddress");
            return;
        }
         this.updateAddressValues(copiedFormData || this.formData);
    }

    // LLC-1 specific checkbox handler
    handleAddressSameAsMailingCheckboxChange(event) {
        const isChecked = event?.target?.checked ?? true;
        this.isAddressSameAsMailing = isChecked;

        if (isChecked) {
            this.handleMailingAddressClick();
        } else {
            this.clearAddressFields();
        }
    }

    handleBusinessAddressClick() {
        if (!this.isNested) {
            let businessAddressConfig = this.formConfig.elements.find((el) => {
                if (!el.componentSettings) {
                    return false;
                }
                let componentSettings = JSON.parse(el.componentSettings);
                return el.name === "Address" && componentSettings.isBusinessAddress;
            });
            if (businessAddressConfig) {
                this.copyAddress(businessAddressConfig);
            }
        } else {
            this.dispatchCustomEvent("copybusinessaddress");
        }
    }

    clearAddressFields() {
        const formData = { ...this.formData };
        const fieldsToReset = ["street", "street2", "city", "state", "stateText", "postalCode", "country"];

        fieldsToReset.forEach((field) => {
            const fieldName = this.getFieldName(field);
            if (fieldName) {
                this[`${field}Value`] = null;
                formData[fieldName] = null;
            }
        });

        this.dispatchCustomEvent("formupdate", { formData });
    }
}