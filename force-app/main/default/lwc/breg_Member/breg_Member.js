import { api, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import BaseFormComponent from "c/breg_BaseFormComponent";
import BREG_Not_Own_Agent_Error from "@salesforce/label/c.BREG_Not_Own_Agent_Error";
import { getPageParamsFromUrl } from "c/utils";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import BILLING_COUNTRY_FIELD from "@salesforce/schema/Account.BillingCountryCode";
import BILLING_STATE_FIELD from "@salesforce/schema/Account.BillingStateCode";

export default class Breg_Member extends BaseFormComponent {
    @api member;
    accRecTypeId;
    rawCountryPicklist;
    rawStatePicklist;
    countryOptions = [];
    stateOptions = [];

    memberTypeValue;
    officerDirectorTitlesValue = "";
    officerDirectorOtherTitleValue;
    entityNameValue;
    firstNameValue;
    lastNameValue;
    numberOfSharesValue;
    entityLocationCountryValue;
    entityLocationStateValue;
    entityLocationStateTextValue;
    entityFileNumberValue;
    entityTypeValue;
    TNTMSMEntityTypeValue;
    entityTypeDescriptionValue;
    titlesAreVacantLabel = "Check here if the titles above are VACANT";
    entityLocationRequired = false;
    entityFileNumberRequired = false;
    @api tntmsmEntityTypeOptions = [];
    @api entityTypeOptions = [];
    @api officerDirectorTitlesOptions = [];
    @api memberLabel;
    @api memberRole;
    @api isSingle;
    @api isDeleteMemberDisabled;
    notOwnAgentErrorText = BREG_Not_Own_Agent_Error;

    dependentFieldsMapping = {
        country: ["state", "stateText"],
        memberType: ["entityName", "entityLocationCountry", "entityLocationState", "entityFileNumber", "TNTMSMEntityType", "entityTypeDescription", "firstName", "lastName"],
        TNTMSMEntityType: ["TNTMSMEntityTypeDescription"],
        entityType: ["entityTypeDescription"]
    };

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountInfoWired({ data }) {
        if (data) {
            this.accRecTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: BILLING_COUNTRY_FIELD })
    countryOptionsWired({ data }) {
        if (data) {
            this.rawCountryPicklist = data;
            let options = this.setCBOptionsFromPicklistValues(data);
            options = options.sort((a, b) => {
                if (a.value === "US") return -1;
                if (b.value === "US") return 1;
                return 0;
            });
            this.countryOptions = options;
            this.initializeEntityLocationInputs();
            this.updateFilteredStateOptions();
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: BILLING_STATE_FIELD })
    stateOptionsWired({ data }) {
        if (data) {
            this.rawStatePicklist = data;
            this.initializeEntityLocationInputs();
            this.updateFilteredStateOptions();
        }
    }

    /**
     * Labels and options
     **/

    get memberTypeOptions() {
        let options = [
            { label: "Individual", value: "Individual" },
            { label: "Entity", value: "Entity" }
        ];

        if (this.isAgentRole && this.isAnnualForm) {
            options.push({
                label: "Commercial Registered Agent",
                value: "CRA"
            });
        }
        return options;
    }

    get readOnlyMemberType() {
        return this.memberTypeValue ? ` (${this.memberTypeValue.toUpperCase()})` : "";
    }

    get readOnlyFullName() {
        return `${this.firstNameValue?.toUpperCase() || ""} ${this.lastNameValue?.toUpperCase() || ""}`.trim();
    }

    get readOnlyEntityType() {
        let label = this.getLabelFromOptions(this.entityTypeOptions, this.entityTypeValue);
        if (this.entityTypeDescriptionValue != null) {
            label = this.entityTypeDescriptionValue;
        }
        return this.entityTypeLabel === "Entity Type" ? `${label?.toUpperCase()}` : `<b>${this.entityTypeLabel}</b>: <br> ${label?.toUpperCase()}`;
    }

    get entityTypeLabel() {
        return this.componentSettings?.entityTypeLabel || `${this.memberLabel} Entity Type`;
    }

    get entityNameLabel() {
        return this.componentSettings?.entityNameLabel || `${this.memberLabel} Entity Name`;
    }

    get showEntityNameHelpLink() {
        return !!this.componentSettings?.showHelpLink;
    }

    get memberTypeSelectorLabel() {
        return `Is the ${this.memberLabel?.toLowerCase()} an individual or an entity?`;
    }

    get officerDirectorTitlesLabel() {
        return `${this.memberLabel} Titles`;
    }

    /**
     * Fields visibility
     **/

    get showMemberTypeSelector() {
        return "memberType" in this.targetFieldsMapping;
    }

    get showOfficeHeldField() {
        return "officeHeld" in this.targetFieldsMapping;
    }

    get showOfficeTitleField() {
        return "officeTitle" in this.targetFieldsMapping;
    }

    get showNumberOfSharesField() {
        return "numberOfShares" in this.targetFieldsMapping;
    }

    get showEntityLocationField() {
        return "entityLocationCountry" in this.targetFieldsMapping;
    }

    get showEntityLocationStatesPicklist() {
        return Array.isArray(this.stateOptions) && this.stateOptions.length > 0;
    }

    get showEntityLocationStateInput() {
        return !this.showEntityLocationStatesPicklist;
    }

    get entityLocationCountryReadOnly() {
        const label = this.getEntityLocationCountryLabelByValue(this.entityLocationCountryValue) || this.entityLocationCountryValue;
        return label ? `Country: ${label.toUpperCase()}` : "";
    }

    get entityLocationStateReadOnly() {
        const stateLabel = this.showEntityLocationStatesPicklist
            ? this.getEntityLocationStateLabelByValue(this.entityLocationStateValue) || this.entityLocationStateValue
            : this.entityLocationStateTextValue || this.entityLocationStateValue;

        return stateLabel ? `State/Province: ${stateLabel.toUpperCase()}` : "";
    }

    get showEntityFileNumberField() {
        return "entityFileNumber" in this.targetFieldsMapping;
    }

    get showEntityTypeField() {
        return "entityType" in this.targetFieldsMapping;
    }
    get showEntityTypeDescriptionField() {
        return this.entityTypeValue === "Other";
    }
    get showTNTMSMEntityTypeField() {
        return "TNTMSMEntityType" in this.targetFieldsMapping;
    }
    get showTNTMSMEntityTypeDescriptionField() {
        return this.TNTMSMEntityTypeValue === "Other";
    }

    get showOfficerDirectorTitlesField() {
        return "officerDirectorTitles" in this.targetFieldsMapping;
    }

    get showTitlesAreVacantField() {
        return "titlesAreVacant" in this.targetFieldsMapping;
    }

    get showOfficerDirectorOtherTitleField() {
        return "officerDirectorOtherTitle" in this.targetFieldsMapping && this.officerDirectorTitlesValue?.includes("Other");
    }

    get isEntity() {
        return "entityName" in this.targetFieldsMapping && (this.memberTypeValue === "Entity" || !this.showMemberTypeSelector);
    }

    get showEntityName() {
        return this.isEntity || this.isCRA;
    }

    get isIndividual() {
        return "firstName" in this.targetFieldsMapping && (this.memberTypeValue === "Individual" || !this.showMemberTypeSelector);
    }

    get showAddressFields() {
        return "street" in this.targetFieldsMapping && "city" in this.targetFieldsMapping && (!this.readOnly || this.member["breg_Account_Affiliation__c.breg_Address__CountryCode__s"]);
    }

    get showActions() {
        return !this.isSingle && !this.cmpProperties?.hideMemberActions;
    }

    get showRemoveButton() {
        return !this.isSingle && !this.isDeleteMemberDisabled;
    }

    /**
     * Helper variables and methods
     **/

    get isAgentRole() {
        return this.memberRole === "Agent" || this.memberRole === "New Agent";
    }

    get isCRA() {
        return this.memberTypeValue === "CRA";
    }

    get isNotSingle() {
        return !this.isSingle;
    }

    get officerDirectorTitlesOptionsFiltered() {
         let options = this.officerDirectorTitlesOptions ?? [];

        const invalidValues = ["1V", "9V", "G", "L", "MGR"]; //might need to delete from org if not used anywere else
        options = options.filter((o) => !invalidValues.includes(o.value));

        const removeDirector = this.memberRole === "Officer";
        if (removeDirector) {
            options = options.filter((o) => o.value !== "D");
        }

        return options;
    }

    get officerDirectorTitlesValueArray() {
        if (this.officerDirectorTitlesValue) {
            return this.officerDirectorTitlesValue.split(";");
        }
        return [];
    }

    get officerDirectorTitlesValueText() {
        const offDirTitlesArr = [];
        this.officerDirectorTitlesValueArray.forEach((val) => {
            const label = this.getLabelFromOptions(this.officerDirectorTitlesOptions, val);
            if (label) {
                offDirTitlesArr.push(label);
            }
        });
        return offDirTitlesArr.join(", ");
    }

    get isButtonDisabled() {
        return this.readOnly || this.isDeleteMemberDisabled;
    }

    get showDeleteButton() {
        return !this.isButtonDisabled;
    }

    get localNonAddressReadOnly() {
        return this.readOnly ||
            (
                this.isAnnualForm &&
                this.cmpProperties?.hideMemberActions &&
                this.cmpProperties?.memberInitiated &&
                this.config?.isReadOnly === true
            );
    }

    connectedCallback() {
        super.connectedCallback();
        const { isRenewal } = getPageParamsFromUrl();
        if (isRenewal === "true") {
            this.alwaysReadOnly = true;
        }
    }

    handleDelete(event) {
        this.dispatchEvent(
            new CustomEvent("delete", {
                detail: {
                    memberKey: event.target.dataset.key
                }
            })
        );
    }

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();

        const inputTag = event?.target?.tagName?.toLowerCase();
        const inputType = event?.target?.type;
        if ((inputTag === "lightning-input" && inputType !== "checkbox") || inputTag === "lightning-textarea") return;

        const inputName = event.target.dataset.name || event.target.name;
        let value = this.getValueFromEvent(event);
        const field = this.getFieldName(inputName);

        let member = { ...this.member };
        if (typeof value === "object" && Array.isArray(value)) {
            if (value.includes("Other") && !this[`${inputName}Value`]?.includes("Other")) {
                value = ["Other"];
            } else {
                value = value.filter((val) => val !== "Other");
            }
            member[field] = value.join(";");
            member[inputName] = value.join(";");
            this[`${inputName}Value`] = value.join(";");
        } else {
            member[field] = value;
            member[inputName] = value;
            this[`${inputName}Value`] = value;
        }

        this.resetDependentFieldsValue(inputName, member);
        this.dispatchCustomEvent("change", { member });
    }

    handleChangeNestedComponent(event) {
        const inputName = event.detail.value.inputName;
        const value = event.detail.value.value;
        const field = this.getFieldName(inputName);
        let member = { ...this.member };
        member[field] = value;
        member[inputName] = value;
        this.resetDependentFieldsValue(inputName, member);
        this.dispatchCustomEvent("change", { member });
    }

    handleInputBlur(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this.readOnly) return;
        try {
            const inputTag = event?.target?.tagName?.toLowerCase();
            const inputType = event?.target?.type;
            const inputName = event?.target?.name;
            const field = this.getFieldName(inputName);
            let value = this.getValueFromEvent(event);
            console.log("** handleBlur:", inputTag, inputName, value, typeof value);
            if (value && typeof value === "string" && (inputTag === "lightning-input" || inputTag === "lightning-textarea")) {
                if (inputType === "number") {
                    value = parseFloat(value);
                } else {
                    value = value.toUpperCase();
                }
                let member = { ...this.member };
                member[field] = value;
                member[inputName] = value;
                this[`${inputName}Value`] = value;
                if (inputName === "firstName" || inputName === "lastName") {
                    member.memberName = `${member.firstName || ""} ${member.lastName || ""}`;
                } else if (inputName === "entityName") {
                    member.memberName = member.entityName;
                    this.validateRegAgent();
                }

                this.resetDependentFieldsValue(inputName, member);
                this.dispatchCustomEvent("change", { member });
            }
        } catch (error) {
            console.error("** Member handleInputBlur error:", error);
        }
    }

    async reportValidity() {
        const baseValid = await super.reportValidity();
        const regAgentValid = this.validateRegAgent();
        return baseValid && regAgentValid;
    }

    validateRegAgent() {
        let isValid = true;
        if (!this.isAgentRole) return isValid; // validate only for agent

        const entityNameInput = this.template.querySelector('[data-name="entityName"]');

        if (!entityNameInput) {
            return isValid;
        }

        // Clear previous errors
        entityNameInput.setCustomValidity("");

        try {
            const memberName = (this.entityNameValue ?? "").trim().toUpperCase();
            const companyName = (this.companyName ?? "").trim().toUpperCase();

            if (memberName && companyName && memberName === companyName) {
                entityNameInput?.setCustomValidity(this.notOwnAgentErrorText);
                isValid = false;
            }
        } catch (error) {
            console.error("Entity Name validation error:", error);
            entityNameInput.setCustomValidity("Validation error occurred. Please try again.");
            isValid = false;
        } finally {
            entityNameInput.reportValidity();
        }

        return isValid;
    }

    resetDependentFieldsValue(inputName, member) {
        const mapping = this.dependentFieldsMapping[inputName];
        if (!mapping || mapping.length === 0) return;

        mapping.forEach((inputNameToRest) => {
            this[`${inputNameToRest}Value`] = null;
            member[inputNameToRest] = null;
            const fieldName = this.getFieldName(inputNameToRest);
            if (fieldName) {
                member[fieldName] = null;
            }
        });

        if (inputName === "memberType") {
            this.entityLocationStateTextValue = null;
        }
    }

    handleAddressFormUpdate(event) {
        const member = { ...this.member };
        const countryField = this.getFieldName("country");
        const stateField = this.getFieldName("state");
        member[countryField] = event.detail.value.formData[countryField];
        member[stateField] = event.detail.value.formData[stateField];
        this.member = { ...member };
        // console.log("*** handleAddressFormUpdate member: ", JSON.stringify(member));
        this.dispatchCustomEvent("change", { member });
    }

    populateDefaultValues() {
        const field = this.getFieldName("officerDirectorTitles");
        const value = this.defaultValuesMapping?.[field];

        if (value && !this.member?.[field] && !this.member?.officerDirectorTitles) {
            this.member = {
                ...this.member,
                [field]: value,
                officerDirectorTitles: value
            };
            this.officerDirectorTitlesValue = value;
        }
    }

    processFormData() {
        super.processFormData(this.member);
        this.initializeEntityLocationInputs();
    }

    initializeEntityLocationInputs() {
        if (!Array.isArray(this.countryOptions) || this.countryOptions.length === 0) {
            return;
        }

        const mappedCountryField = this.getFieldName("entityLocationCountry");
        const persistedCountryValue = mappedCountryField ? this.member?.[mappedCountryField] : this.member?.entityLocationCountry;
        if (!this.entityLocationCountryValue && persistedCountryValue) {
            this.entityLocationCountryValue = persistedCountryValue;
        }

        // BREG-5202
        // if (this.entityLocationCountryValue == null || this.entityLocationCountryValue == undefined || this.entityLocationCountryValue === "") {
        //     this.entityLocationCountryValue = "US";
        // }

        this.entityLocationCountryValue = this.normalizeEntityLocationCountryValue(this.entityLocationCountryValue);

        const member = { ...this.member };
        const memberCountryField = mappedCountryField || "entityLocationCountry";
        const memberCountryValue = member?.[memberCountryField] ?? member?.entityLocationCountry;
        if (memberCountryValue !== this.entityLocationCountryValue) {
            member[memberCountryField] = this.entityLocationCountryValue;
            member.entityLocationCountry = this.entityLocationCountryValue;
            this.member = member;
            this.dispatchCustomEvent("change", { member });
        }

        this.updateFilteredStateOptions();

        const rawStateValue = (this.entityLocationStateValue || "").trim();
        if (!rawStateValue) {
            this.entityLocationStateTextValue = null;
            return;
        }

        const upperStateValue = rawStateValue.toUpperCase();
        const stateMatch = this.stateOptions.find((option) => option.value === rawStateValue || option.label === upperStateValue);
        if (stateMatch) {
            this.entityLocationStateValue = stateMatch.value;
            this.entityLocationStateTextValue = null;
            return;
        }

        this.entityLocationStateTextValue = upperStateValue;
    }

    updateFilteredStateOptions() {
        if (!this.rawStatePicklist || !this.rawCountryPicklist || !this.entityLocationCountryValue) {
            this.stateOptions = [];
            return;
        }

        const normalizedCountryValue = this.normalizeEntityLocationCountryValue(this.entityLocationCountryValue);
        if (normalizedCountryValue !== this.entityLocationCountryValue) {
            this.entityLocationCountryValue = normalizedCountryValue;
        }

        const countryIndex = this.rawCountryPicklist.values.findIndex((countryValue) => countryValue.value === normalizedCountryValue);
        if (countryIndex === -1) {
            this.entityLocationCountryValue = normalizedCountryValue;
            console.warn(`Country value "${normalizedCountryValue}" not found in picklist values.`);
            this.stateOptions = this.setCBOptionsFromPicklistValues(this.rawStatePicklist);
            return;
        }

        this.stateOptions = this.rawStatePicklist.values
            .filter((stateValue) => this.validForIncludes(stateValue.validFor, countryIndex))
            .map((stateValue) => ({ label: stateValue.label.toUpperCase(), value: stateValue.value }));
    }

    normalizeEntityLocationCountryValue(value) {
        if (!value || !Array.isArray(this.countryOptions) || this.countryOptions.length === 0) {
            return value;
        }

        const normalizedInput = `${value}`.trim().toUpperCase();
        const exactMatch = this.countryOptions.find((option) => option.value === value);
        if (exactMatch) {
            return exactMatch.value;
        }

        const byLabel = this.countryOptions.find((option) => option.label === normalizedInput);
        if (byLabel) {
            return byLabel.value;
        }

        const byValueCaseInsensitive = this.countryOptions.find((option) => `${option.value}`.trim().toUpperCase() === normalizedInput);
        if (byValueCaseInsensitive) {
            return byValueCaseInsensitive.value;
        }

        return value;
    }

    validForIncludes(validFor, index) {
        if (index < 0 || !validFor) {
            return false;
        }

        if (Array.isArray(validFor)) {
            return validFor.includes(index);
        }

        if (typeof validFor === "string") {
            try {
                const bytes = atob(validFor);
                const byteIndex = Math.floor(index / 8);
                const bitMask = 1 << index % 8;
                if (byteIndex >= bytes.length) {
                    return false;
                }
                return (bytes.charCodeAt(byteIndex) & bitMask) !== 0;
            } catch (_error) {
                return false;
            }
        }

        return false;
    }

    getEntityLocationStateLabelByValue(value) {
        if (!value || !Array.isArray(this.stateOptions)) {
            return null;
        }
        const option = this.stateOptions.find((stateOption) => stateOption.value === value);
        return option ? option.label : null;
    }

    getEntityLocationCountryLabelByValue(value) {
        if (!value || !Array.isArray(this.countryOptions)) {
            return null;
        }
        const option = this.countryOptions.find((countryOption) => countryOption.value === value);
        return option ? option.label : null;
    }

    applyEntityLocationInputValue(inputName, value) {
        const field = this.getFieldName(inputName);
        if (!field) {
            return;
        }

        const member = { ...this.member };
        member[field] = value;
        member[inputName] = value;
        this[`${inputName}Value`] = value;
        this.member = member;
        this.dispatchCustomEvent("change", { member });
    }

    handleEntityLocationCountryChange(event) {
        event.preventDefault();
        event.stopPropagation();

        this.entityLocationCountryValue = this.normalizeEntityLocationCountryValue(this.getValueFromEvent(event));
        this.entityLocationStateValue = null;
        this.entityLocationStateTextValue = null;

        this.applyEntityLocationInputValue("entityLocationCountry", this.entityLocationCountryValue);
        this.updateFilteredStateOptions();
        this.applyEntityLocationInputValue("entityLocationState", null);
    }

    handleEntityLocationStateChange(event) {
        event.preventDefault();
        event.stopPropagation();

        this.entityLocationStateValue = this.getValueFromEvent(event);
        this.entityLocationStateTextValue = null;
        this.applyEntityLocationInputValue("entityLocationState", this.entityLocationStateValue || null);
    }

    handleEntityLocationStateTextChange(event) {
        event.preventDefault();
        event.stopPropagation();

        const value = this.getValueFromEvent(event);
        this.entityLocationStateTextValue = value;
    }

    handleEntityLocationStateTextBlur(event) {
        event.preventDefault();
        event.stopPropagation();

        let value = this.getValueFromEvent(event);
        if (value && typeof value === "string") {
            value = value.toUpperCase();
        }
        this.entityLocationStateTextValue = value;
        this.applyEntityLocationInputValue("entityLocationState", value || null);
    }

    handleCopyMailingAddress() {
        if (!this.isNested) {
            let mailingAddressConfig = this.formConfig.elements.find((el) => {
                if (!el.componentSettings) {
                    return false;
                }
                let componentSettings = JSON.parse(el.componentSettings);
                return el.name === "Address" && componentSettings.isMailingAddress;
            });
            if (mailingAddressConfig) {
                this.member = { ...this.member, ...this.copyAddress(mailingAddressConfig) };
                if (this.isAgentRole) {
                    const countryFieldName = this.getFieldName("country");
                    const stateFieldName = this.getFieldName("state");
                    this.member[countryFieldName] = 'US';
                    this.member[stateFieldName] = 'HI';
                }
                this.dispatchCustomEvent("change", { member: this.member });
            }
        }
    }

    handleCopyBusinessAddress() {
        if (!this.isNested) {
            let businessAddressConfig = this.formConfig.elements.find((el) => {
                if (!el.componentSettings) {
                    return false;
                }
                let componentSettings = JSON.parse(el.componentSettings);
                return el.name === "Address" && componentSettings.isBusinessAddress;
            });
            if (businessAddressConfig) {
                this.member = { ...this.member, ...this.copyAddress(businessAddressConfig) };
                if (this.isAgentRole) {
                    const countryFieldName = this.getFieldName("country");
                    const stateFieldName = this.getFieldName("state");
                    this.member[countryFieldName] = 'US';
                    this.member[stateFieldName] = 'HI';
                }
                this.dispatchCustomEvent("change", { member: this.member });
            }
        }
    }

    handleEditSectionClick() {
        const formConfig = this.prepareFormConfigForEditSectionModal();
        this.dispatchEvent(
            new CustomEvent("editsection", {
                detail: {
                    formConfig,
                    title: this.memberRole,
                    member: this.member
                }
            })
        );
    }
}