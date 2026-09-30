import { api, wire } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import BaseFormComponent from "c/breg_BaseFormComponent";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import COUNTRY_FIELD from "@salesforce/schema/Account.BillingCountryCode";
import STATE_FIELD from "@salesforce/schema/Account.BillingStateCode";

const AGENT_ROLE = "Agent";
const NEW_AGENT_ROLE = "New Agent";
const ROLE_FIELD = "breg_Account_Affiliation__c.breg_Role__c";
const ID_FIELD = "breg_Account_Affiliation__c.Id";
const AFFILIATION_FIELD_PREFIX = "breg_Account_Affiliation__c.";
const UNIQUE_TARGET_FIELD_SEPARATOR = " - ";
const HAS_CHANGED_INPUT = "hasChanged";

const NAME_INPUTS = ["memberType", "entityName", "firstName", "lastName"];
const ADDRESS_INPUTS = ["country", "street", "street2", "city", "state", "stateText", "postalCode"];
const FALLBACK_INPUTS = new Set([...NAME_INPUTS, ...ADDRESS_INPUTS]);
const SECTION_INPUTS_BY_MODE = {
    name: NAME_INPUTS,
    address: ADDRESS_INPUTS
};
const CHANGE_FIELD_BY_MODE = {
    name: "Case.breg_Reg_Agent_Has_Changed__c",
    address: "Case.breg_Reg_Agent_Address_Has_Changed__c"
};
const ROLE_COMPARE_INPUTS_BY_MODE = {
    name: ["memberType", "entityName", "firstName", "lastName"],
    address: ["street", "street2", "city", "state", "postalCode", "country"]
};
const VALIDATION_CONFIG_BY_MODE = {
    name: {
        message: "New registrant name must be different from the old name.",
        anchorInputNames: ["entityName", "firstName", "lastName", "memberType"]
    },
    address: {
        message: "New address must be different from the old address.",
        anchorInputNames: ["street", "street2", "city", "state", "stateText", "postalCode", "country"]
    }
};

// Normalizes mapping keys that include an optional uniqueness suffix.
function normalizeMappingInputName(inputName) {
    if (!inputName) {
        return inputName;
    }
    const separatorIndex = inputName.indexOf(UNIQUE_TARGET_FIELD_SEPARATOR);
    return separatorIndex === -1 ? inputName : inputName.substring(0, separatorIndex);
}

// Removes uniqueness suffix from mapped field names.
function cleanMappedFieldName(fieldName) {
    if (!fieldName) {
        return fieldName;
    }
    const separatorIndex = fieldName.indexOf(UNIQUE_TARGET_FIELD_SEPARATOR);
    return separatorIndex === -1 ? fieldName : fieldName.substring(0, separatorIndex);
}

// Parses JSON and returns a fallback value when parsing fails.
function parseJson(jsonValue, fallbackValue) {
    if (!jsonValue) {
        return fallbackValue;
    }
    if (typeof jsonValue === "object") {
        return jsonValue;
    }
    try {
        return JSON.parse(jsonValue);
    } catch (_error) {
        return fallbackValue;
    }
}

export default class Breg_MembersChange extends BaseFormComponent {
    defaultTitle = "Member Change";

    syncingMembers = false;
    prefillingValues = false;
    roleMappingsCache = {};

    accRecTypeId;
    rawCountryPicklist;
    rawStatePicklist;
    countryOptions = [];
    stateOptions = [];

    memberTypeValue;
    entityNameValue;
    firstNameValue;
    lastNameValue;
    countryValue;
    streetValue;
    street2Value;
    cityValue;
    stateValue;
    stateTextValue;
    postalCodeValue;

    dependentFieldsMapping = {
        memberType: ["entityName", "firstName", "lastName"],
        country: ["state", "stateText"]
    };

    // Loads Account metadata used by country/state picklists.
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    objectInfoWired({ data }) {
        if (data) {
            this.accRecTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: COUNTRY_FIELD })
    countryOptionsWired({ data }) {
        this.rawCountryPicklist = data;
        let options = this.setCBOptionsFromPicklistValues(data);

        if (Array.isArray(options)) {
            options.sort((a, b) => a.label.localeCompare(b.label));
            const usIndex = options.findIndex((option) => option.value === "US");
            if (usIndex > 0) {
                const [usOption] = options.splice(usIndex, 1);
                options.unshift(usOption);
            }
        }

        this.countryOptions = options;
        this.updateFilteredStateOptions();
    }

    @wire(getPicklistValues, { recordTypeId: "$accRecTypeId", fieldApiName: STATE_FIELD })
    stateOptionsWired({ data }) {
        this.rawStatePicklist = data;
        this.updateFilteredStateOptions();
    }

    get role() {
        return this.componentSettings?.memberRole || this.defaultValuesMapping?.[ROLE_FIELD] || AGENT_ROLE;
    }

    // Returns whether this component operates in name or address mode.
    get membersChangeType() {
        if (this.componentSettings?.membersChangeType) {
            return this.componentSettings.membersChangeType;
        }
        return this.detectMembersChangeType();
    }

    get isNameMode() {
        return this.membersChangeType === "name";
    }

    get isAddressMode() {
        return this.membersChangeType === "address";
    }

    get isAgentRole() {
        return this.role === AGENT_ROLE || this.role === NEW_AGENT_ROLE;
    }

    get showMemberTypeSelector() {
        return this.hasInputMapping("memberType") && !this.componentSettings?.hideMemberType;
    }

    get showDescriptionBeforeCheckbox() {
        return this.showDescription && !(this.editMode && this.showHasChangedCheckbox && this.componentSettings?.showDescriptionAfterCheckbox);
    }

    get showDescriptionAfterCheckbox() {
        return this.showDescription && this.editMode && this.showHasChangedCheckbox && this.componentSettings?.showDescriptionAfterCheckbox;
    }

    get showCompactReadOnlyName() {
        return this.isNameMode && this.readOnly;
    }

    get showCompactReadOnlyMemberType() {
        return this.showCompactReadOnlyName && this.showMemberType && this.hasValue(this.memberTypeValue);
    }

    get compactReadOnlyNameValue() {
        return this.normalizeDisplayText(this.buildMemberName(this.memberTypeValue, this.entityNameValue, this.firstNameValue, this.lastNameValue));
    }

    get compactReadOnlyMemberTypeValue() {
        return this.normalizeDisplayText(this.memberTypeValue);
    }

    get isEntity() {
        return this.hasInputMapping("entityName") && (this.memberTypeValue === "Entity" || (!this.showMemberTypeSelector && !this.memberTypeValue));
    }

    get isIndividual() {
        return this.hasInputMapping("firstName") && (this.memberTypeValue === "Individual" || (!this.showMemberTypeSelector && !this.memberTypeValue));
    }

    get showEntityNameField() {
        return this.hasInputMapping("entityName") && this.isEntity;
    }

    get showFirstNameField() {
        return this.hasInputMapping("firstName") && this.isIndividual;
    }

    get showLastNameField() {
        return this.hasInputMapping("lastName") && this.isIndividual;
    }

    get showMemberType() {
        return this.hasInputMapping("memberType") && !this.componentSettings?.hideMemberType;
    }

    get showMemberTypeDescription() {
        return this.showMemberType && this.componentSettings?.memberTypeDescription;
    }

    get showCountryField() {
        return this.hasInputMapping("country");
    }

    get showStreetField() {
        return this.hasInputMapping("street");
    }

    get showStreet2Field() {
        return this.hasInputMapping("street2");
    }

    get showCityField() {
        return this.hasInputMapping("city");
    }

    get showPostalCodeField() {
        return this.hasInputMapping("postalCode");
    }

    get showStateField() {
        return this.hasInputMapping("state") || this.hasInputMapping("stateText");
    }

    get showStreetAbbreviationHelp() {
        return this.isAddressMode && this.editMode && this.showStreetField && this.componentSettings?.hideStreetAbbreviationHelp !== true;
    }

    get showReadOnlyStreetLine() {
        return this.showStreetField && this.hasValue(this.streetValue);
    }

    get showReadOnlyStreet2Line() {
        return this.showStreet2Field && this.hasValue(this.street2Value);
    }

    get showReadOnlyCityStatePostalLine() {
        return this.hasValue(this.readOnlyCityStatePostalLine);
    }

    get showReadOnlyCountryLine() {
        return this.showCountryField && this.hasValue(this.readOnlyCountryLabel);
    }

    get readOnlyStreetLine() {
        return this.normalizeDisplayText(this.streetValue);
    }

    get readOnlyStreet2Line() {
        return this.normalizeDisplayText(this.street2Value);
    }

    get readOnlyCountryLabel() {
        const countryLabel = this.getLabelFromOptions(this.countryOptions, this.countryValue) || this.countryValue;
        return this.normalizeDisplayText(countryLabel);
    }

    get readOnlyStateLabel() {
        const stateLabel = this.hasValue(this.stateTextValue)
            ? this.stateTextValue
            : this.getLabelFromOptions(this.stateOptions, this.stateValue) || this.stateValue;

        return this.normalizeDisplayText(stateLabel);
    }

    get readOnlyCityStatePostalLine() {
        const cityLabel = this.normalizeDisplayText(this.cityValue);
        const stateLabel = this.readOnlyStateLabel;
        const postalCodeLabel = this.normalizeDisplayText(this.postalCodeValue);

        const statePostalLabel = [stateLabel, postalCodeLabel].filter((value) => this.hasValue(value)).join(" ");

        if (this.hasValue(cityLabel) && this.hasValue(statePostalLabel)) {
            return `${cityLabel}, ${statePostalLabel}`;
        }

        return cityLabel || statePostalLabel;
    }

    get showStatesPicklist() {
        return Array.isArray(this.stateOptions) && this.stateOptions.length > 0;
    }

    get countryDisabled() {
        return this.readOnly || this.isAgentRole;
    }

    get stateDisabled() {
        return this.readOnly || this.isAgentRole;
    }

    get memberTypeDescription() {
        return this.componentSettings?.memberTypeDescription || "Agent Type";
    }

    get memberTypeOptions() {
        return [
            { label: "Individual", value: "Individual" },
            { label: "Entity", value: "Entity" }
        ];
    }

    get memberTypeSelectorLabel() {
        return `Is the ${this.config?.labelOverride2?.toLowerCase() || "registered agent"} an individual or an entity?`;
    }

    getCurrentSectionInputNames() {
        return SECTION_INPUTS_BY_MODE[this.membersChangeType] || NAME_INPUTS;
    }

    getValidationConfig() {
        return VALIDATION_CONFIG_BY_MODE[this.membersChangeType] || null;
    }

    @api
    async reportValidity() {
        const baseValid = await super.reportValidity();
        const membersChangeValid = this.validateAgainstCurrentAgent(true);
        const atLeastOneChangeValid = this.validateAtLeastOneChangeSelected(true);
        return baseValid && membersChangeValid && atLeastOneChangeValid;
    }

    @api
    checkValidity() {
        const membersChangeValid = this.validateAgainstCurrentAgent(false);
        const atLeastOneChangeValid = this.validateAtLeastOneChangeSelected(false);
        const baseValid = super.checkValidity();
        return baseValid && membersChangeValid && atLeastOneChangeValid;
    }

    validateAtLeastOneChangeSelected(shouldReport) {
        const hasChangedInput = this.template.querySelector('lightning-input[name="hasChanged"]');
        if (!this.shouldRequireAtLeastOneChangeSelection()) {
            return true;
        }

        if (hasChangedInput) {
            hasChangedInput.setCustomValidity("");
        }

        if (this.isAnyChangeSelectedInFormData()) {
            if (shouldReport && hasChangedInput) {
                hasChangedInput.reportValidity();
            }
            return true;
        }

        if (hasChangedInput) {
            hasChangedInput.setCustomValidity("Select at least one change: Name Change or Address Change.");
        }
        if (shouldReport && hasChangedInput) {
            hasChangedInput.reportValidity();
        }
        return false;
    }

    shouldRequireAtLeastOneChangeSelection() {
        return this.formCode === "X-8" && this.editMode && this.role === NEW_AGENT_ROLE;
    }

    // Save-time checkbox validation should use shared formData only; undefined is treated as false.
    isAnyChangeSelectedInFormData() {
        return Object.keys(CHANGE_FIELD_BY_MODE).some((mode) => this.toBoolean(this.formData?.[CHANGE_FIELD_BY_MODE[mode]]));
    }

    // Checks whether at least one change checkbox is selected, using the next value for the current change if provided (used when toggling "has changed" on/off).
    isAnyChangeSelected(nextHasChangedValue) {
        return Object.keys(CHANGE_FIELD_BY_MODE).some((mode) => this.isChangeSelected(mode, nextHasChangedValue));
    }

    isChangeSelected(mode, nextHasChangedValue) {
        const fieldName = CHANGE_FIELD_BY_MODE[mode];
        if (!fieldName) {
            return false;
        }

        let value = this.formData?.[fieldName];

        if (mode === this.membersChangeType) {
            value = nextHasChangedValue !== undefined ? nextHasChangedValue : this.hasChangedValue;
        }

        return this.toBoolean(value);
    }

    toBoolean(value) {
        return value === true || value === "true" || value === 1 || value === "1";
    }

    // Validates that New Agent values are not identical to current Agent values.
    validateAgainstCurrentAgent(shouldReport) {
        this.clearMembersChangeValidationErrors();

        if (!this.shouldValidateAgainstCurrentAgent()) {
            return true;
        }

        const validationConfig = this.getValidationConfig();
        if (!validationConfig || !this.areRoleSectionsEqual(AGENT_ROLE, NEW_AGENT_ROLE)) {
            return true;
        }

        const inputCmp = this.getFirstInputByNames(validationConfig.anchorInputNames);
        if (inputCmp) {
            inputCmp.setCustomValidity(validationConfig.message);
            if (shouldReport) {
                inputCmp.reportValidity();
            }
        }

        return false;
    }

    shouldValidateAgainstCurrentAgent() {
        if (this.formCode !== "X-8") {
            return false;
        }

        if (this.readOnly || this.role !== NEW_AGENT_ROLE) {
            return false;
        }

        if (this.showHasChangedCheckbox && this.hasChangedValue !== true) {
            return false;
        }

        return this.showFields;
    }

    clearMembersChangeValidationErrors() {
        const validationInputNames = [...NAME_INPUTS, ...ADDRESS_INPUTS];
        validationInputNames.forEach((inputName) => {
            this.template.querySelectorAll(`[data-name="${inputName}"]`).forEach((inputCmp) => {
                inputCmp.setCustomValidity("");
            });
        });
    }

    getFirstInputByNames(inputNames = []) {
        for (const inputName of inputNames) {
            const inputCmp = this.template.querySelector(`[data-name="${inputName}"]`);
            if (inputCmp) {
                return inputCmp;
            }
        }
        return null;
    }

    normalizeCompareValue(value) {
        if (!this.hasValue(value)) {
            return "";
        }
        return `${value}`.trim().toUpperCase();
    }

    getRoleCompareValue(role, inputName) {
        return this.normalizeCompareValue(this.getRoleInputValue(role, inputName));
    }

    getRoleCompareState(role) {
        const stateValue = this.getRoleCompareValue(role, "state");
        if (this.hasValue(stateValue)) {
            return stateValue;
        }
        return this.getRoleCompareValue(role, "stateText");
    }

    // Compares whether two roles have identical values for the relevant inputs.
    areRoleSectionsEqual(sourceRole, targetRole, mode = this.membersChangeType) {
        const inputNames = ROLE_COMPARE_INPUTS_BY_MODE[mode] || [];
        const sourceSignature = this.buildRoleCompareSignature(sourceRole, inputNames);
        const targetSignature = this.buildRoleCompareSignature(targetRole, inputNames);
        return this.hasValue(targetSignature) && sourceSignature === targetSignature;
    }

    // Builds a signature string for a role by concatenating normalized compare values for all inputs, used to compare whether two roles have identical values for the relevant inputs.
    buildRoleCompareSignature(role, inputNames = []) {
        const compareValues = inputNames.map((inputName) => {
            if (inputName === "state") {
                return this.getRoleCompareState(role);
            }
            return this.getRoleCompareValue(role, inputName);
        });

        return compareValues.some((value) => this.hasValue(value)) ? compareValues.join("|") : "";
    }

    normalizeDisplayText(value) {
        if (!this.hasValue(value)) {
            return "";
        }
        return `${value}`.toUpperCase();
    }

    detectMembersChangeType() {
        if (this.hasInputMapping("country") || this.hasInputMapping("street") || this.hasInputMapping("city") || this.hasInputMapping("postalCode")) {
            return "address";
        }
        return "name";
    }

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();

        const inputTag = event?.target?.tagName?.toLowerCase();
        const inputType = event?.target?.type;
        if ((inputTag === "lightning-input" && inputType !== "checkbox") || inputTag === "lightning-textarea") {
            return;
        }

        const inputName = event.target.dataset.name || event.target.name;
        const value = this.getValueFromEvent(event);
        this.applyInputValue(inputName, value);
    }

    handleInputBlur(event) {
        if (this.readOnly) {
            return;
        }

        event.preventDefault();
        event.stopPropagation();

        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag !== "lightning-input" && inputTag !== "lightning-textarea") {
            return;
        }

        const inputName = event?.target?.name;
        const inputType = event?.target?.type;
        let value = this.getValueFromEvent(event);

        if (value && typeof value === "string") {
            value = value.toUpperCase();
        }
        if (inputType === "number") {
            value = parseFloat(value);
        }

        this.applyInputValue(inputName, value);
    }

    applyInputValue(inputName, value) {
        if (!inputName) {
            return;
        }

        if (inputName === HAS_CHANGED_INPUT) {
            const hasChangedInput = this.template.querySelector('lightning-input[name="hasChanged"]');
            if (hasChangedInput) {
                hasChangedInput.setCustomValidity("");
            }
        }

        this[`${inputName}Value`] = value;

        const formDataPatch = this.getFormDataPatchForInput(inputName, value);
        this.resetDependentInputValues(inputName, formDataPatch);

        if (inputName === "country") {
            this.updateFilteredStateOptions();
            if (this.stateValue && this.showStatesPicklist && !this.stateOptions.some((option) => option.value === this.stateValue)) {
                this.stateValue = null;
                this.stateTextValue = null;
                this.getMappedFieldsForInput("state").forEach((field) => {
                    formDataPatch[field] = null;
                });
                this.getMappedFieldsForInput("stateText").forEach((field) => {
                    formDataPatch[field] = null;
                });
            }
        }

        const isAffiliationInput = inputName !== HAS_CHANGED_INPUT;
        if (!isAffiliationInput && Object.keys(formDataPatch).length > 0) {
            this.dispatchCustomEvent("formupdate", { formData: formDataPatch });

            // Unchecking "has changed" must reset optional role data back to default state.
            if (value !== true) {
                this.resetCurrentSectionInputsToDefault();
                this.clearMembersChangeValidationErrors();

                if (this.formCode === "X-8" && this.role === NEW_AGENT_ROLE && this.isAnyChangeSelected(value)) {
                    this.syncMembersByRole();
                } else {
                    this.dispatchCustomEvent("change", {
                        field: "members",
                        value: [],
                        role: this.role
                    });
                }
            }
        }

        if (isAffiliationInput) {
            this.syncMembersByRole();
        }
    }

    // Restores only this section's local inputs to defaults; sibling section values remain on the shared role member.
    resetCurrentSectionInputsToDefault() {
        const sourceRole = this.componentSettings?.prefillFromRole;
        const targetInputs = this.getCurrentSectionInputNames();

        targetInputs.forEach((inputName) => {
            if (!this.hasInputMapping(inputName)) {
                return;
            }

            let nextValue = null;
            if (sourceRole) {
                nextValue = this.getRoleInputValue(sourceRole, inputName);
            }

            this[`${inputName}Value`] = this.normalize(nextValue);
        });
    }

    // Builds a field-value patch for all fields mapped from one logical input.
    getFormDataPatchForInput(inputName, value) {
        const patch = {};
        this.getMappedFieldsForInput(inputName).forEach((fieldName) => {
            patch[fieldName] = value;
        });
        return patch;
    }

    // Clears dependent inputs when a controlling input value changes.
    resetDependentInputValues(inputName, formDataPatch) {
        const dependentInputs = this.dependentFieldsMapping[inputName];
        if (!dependentInputs || dependentInputs.length === 0) {
            return;
        }

        dependentInputs.forEach((dependentInputName) => {
            this[`${dependentInputName}Value`] = null;
            this.getMappedFieldsForInput(dependentInputName).forEach((fieldName) => {
                formDataPatch[fieldName] = null;
            });
        });
    }

    // Checks whether a logical input has at least one target field mapping.
    hasInputMapping(inputName) {
        return this.getMappedFieldsForInput(inputName).length > 0;
    }

    // Returns mapped field API names for a logical input key.
    getMappedFieldsForInput(inputName, mapping = this.targetFieldsMapping) {
        if (!mapping || typeof mapping !== "object") {
            return [];
        }

        const mappedFields = [];
        Object.entries(mapping).forEach(([mappingInputName, fieldName]) => {
            if (normalizeMappingInputName(mappingInputName) === inputName && fieldName) {
                mappedFields.push(fieldName);
            }
        });

        return [...new Set(mappedFields)];
    }

    processFormData() {
        this.processMappedValues();
        this.updateFilteredStateOptions();

        if (this.formCode !== "X-8" || !this.formData || this.syncingMembers) {
            return;
        }

        this.setDefaultAddressValues();
        this.prefillMappedValuesFromRole();
        if (this.prefillingValues) {
            return;
        }

        this.syncMembersByRole();
    }

    // Populates component input values from role-specific member/form data.
    processMappedValues() {
        const roleMember = this.getExistingMemberByRole(this.role);
        const inputNames = this.getComponentInputNames();

        inputNames.forEach((inputName) => {
            if (inputName === HAS_CHANGED_INPUT) {
                const fieldName = this.getFieldName(inputName);
                const value = fieldName ? this.normalize(this.formData?.[fieldName]) : null;
                if (this[`${inputName}Value`] !== value) {
                    this[`${inputName}Value`] = value;
                }
                return;
            }

            const value = this.getDisplayValue(roleMember, inputName);
            if (this[`${inputName}Value`] !== value) {
                this[`${inputName}Value`] = value;
            }
        });
    }

    getComponentInputNames() {
        return [...new Set(Object.keys(this.targetFieldsMapping || {}).map((inputName) => normalizeMappingInputName(inputName)).filter(Boolean))];
    }

    // Resolves display value from current role member first, then shared form data.
    getDisplayValue(roleMember, inputName) {
        if (roleMember) {
            const valueFromMember = this.getValueFromMember(roleMember, inputName, this.getRoleMappings(this.role)[inputName] || []);
            if (valueFromMember !== undefined) {
                return valueFromMember;
            }
        }

        for (const fieldName of this.getMappedFieldsForInput(inputName)) {
            if (this.hasValue(this.formData?.[fieldName])) {
                return this.normalize(this.formData[fieldName]);
            }
        }

        return null;
    }

    // Reads one logical input value from a member record and mapped fields.
    getValueFromMember(member, inputName, fields = []) {
        for (const fieldName of fields) {
            if (this.hasValue(member[fieldName])) {
                return this.normalize(member[fieldName]);
            }

            const cleanedFieldName = cleanMappedFieldName(fieldName);
            if (cleanedFieldName !== fieldName && this.hasValue(member[cleanedFieldName])) {
                return this.normalize(member[cleanedFieldName]);
            }
        }

        if (this.hasValue(member[inputName])) {
            return this.normalize(member[inputName]);
        }

        return undefined;
    }

    // Applies default US/HI values for role-based agent address flows.
    setDefaultAddressValues() {
        if (!this.isAddressMode || !this.isAgentRole) {
            return;
        }

        const patch = {};

        if (this.showCountryField && !this.hasValue(this.countryValue)) {
            this.countryValue = "US";
            this.getMappedFieldsForInput("country").forEach((fieldName) => {
                patch[fieldName] = "US";
            });
        }

        if (this.showStateField && !this.hasValue(this.stateValue)) {
            this.stateValue = "HI";
            this.getMappedFieldsForInput("state").forEach((fieldName) => {
                patch[fieldName] = "HI";
            });
        }

        if (Object.keys(patch).length > 0) {
            this.syncMembersByRole();
        }
    }

    // Prefills empty values from another role when configured (for New Agent copy behavior).
    prefillMappedValuesFromRole() {
        const sourceRole = this.componentSettings?.prefillFromRole;
        if (!sourceRole || this.prefillingValues) {
            return;
        }

        if (this.showHasChangedCheckbox && this.hasChangedValue !== true) {
            return;
        }

        const targetInputs = this.getCurrentSectionInputNames();
        const roleMappings = this.getRoleMappings(this.role);
        const existingRoleMember = this.getExistingMemberByRole(this.role);
        let hasPrefillValues = false;

        targetInputs.forEach((inputName) => {
            if (!this.hasInputMapping(inputName)) {
                return;
            }

            const currentLocalValue = this.normalize(this[`${inputName}Value`]);
            const currentMemberValue = existingRoleMember
                ? this.getValueFromMember(existingRoleMember, inputName, roleMappings[inputName] || [])
                : undefined;

            if (this.hasValue(currentLocalValue) || this.hasValue(currentMemberValue)) {
                return;
            }

            const sourceValue = this.getRoleInputValue(sourceRole, inputName);
            if (!this.hasValue(sourceValue)) {
                return;
            }

            this[`${inputName}Value`] = sourceValue;
            hasPrefillValues = true;
        });

        if (!hasPrefillValues) {
            return;
        }

        this.prefillingValues = true;
        try {
            this.syncMembersByRole();
        } finally {
            this.prefillingValues = false;
        }
    }

    // Dispatches member updates for the current role only when data actually changed.
    syncMembersByRole() {
        if (this.role === NEW_AGENT_ROLE && this.showHasChangedCheckbox && this.hasChangedValue !== true && !this.getExistingMemberByRole(this.role)) {
            return;
        }

        const desiredMember = this.buildDesiredMember(this.role);
        if (!desiredMember) {
            return;
        }

        const existingMember = this.getExistingMemberByRole(this.role);
        if (this.areMembersEqual(existingMember, desiredMember)) {
            return;
        }

        this.syncingMembers = true;
        try {
            this.dispatchCustomEvent("change", {
                field: "members",
                value: [desiredMember],
                role: this.role
            });
        } finally {
            this.syncingMembers = false;
        }
    }

    // Builds the role-scoped member payload used for persistence.
    buildDesiredMember(role) {
        const roleMappings = this.getRoleMappings(role);
        const inputNames = Object.keys(roleMappings).filter((inputName) => inputName !== HAS_CHANGED_INPUT);
        if (inputNames.length === 0) {
            return null;
        }

        const existingMember = this.getExistingMemberByRole(role);
        const fallbackRole = this.componentSettings?.prefillFromRole;
        const roleKey = role.toLowerCase().replace(/[^a-z0-9]+/g, "-");
        const componentInputNames = new Set(this.getComponentInputNames().filter((inputName) => inputName !== HAS_CHANGED_INPUT));

        const desiredMember = {
            ...(existingMember || {}),
            uniqueKey: existingMember?.uniqueKey || `x8-${roleKey}`,
            [ROLE_FIELD]: role
        };

        inputNames.forEach((inputName) => {
            let value;

            if (componentInputNames.has(inputName)) {
                value = this.normalize(this[`${inputName}Value`]);
            } else {
                value = this.getRoleInputValue(role, inputName);
            }

            if (!this.hasValue(value) && fallbackRole && FALLBACK_INPUTS.has(inputName)) {
                value = this.getRoleInputValue(fallbackRole, inputName);
            }

            if (value === null && existingMember?.[inputName] !== undefined && !componentInputNames.has(inputName)) {
                value = existingMember[inputName];
            }

            const normalizedValue = this.normalize(value);
            desiredMember[inputName] = normalizedValue;

            roleMappings[inputName].forEach((fieldName) => {
                const cleanedFieldName = cleanMappedFieldName(fieldName);
                if (!cleanedFieldName.startsWith(AFFILIATION_FIELD_PREFIX)) {
                    return;
                }
                desiredMember[cleanedFieldName] = normalizedValue;
            });
        });

        desiredMember.memberName = this.buildMemberName(desiredMember.memberType, desiredMember.entityName, desiredMember.firstName, desiredMember.lastName);

        return this.hasMeaningfulAffiliationValues(desiredMember) ? desiredMember : null;
    }

    // Collects and caches merged input mappings for a given role.
    getRoleMappings(role) {
        if (this.roleMappingsCache[role]) {
            return this.roleMappingsCache[role];
        }

        const mergedMappings = {};
        const formElements = this.formConfig?.elements || [];

        formElements.forEach((element) => {
            if (element?.name !== "Members Change") {
                return;
            }

            const settings = parseJson(element.componentSettings, {});
            const elementRole = settings?.memberRole || AGENT_ROLE;
            if (elementRole !== role) {
                return;
            }

            const targetMapping = parseJson(element.targetFieldsMapping, {});
            Object.entries(targetMapping).forEach(([mappingInputName, fieldName]) => {
                const inputName = normalizeMappingInputName(mappingInputName);
                if (!inputName || !fieldName) {
                    return;
                }

                if (!mergedMappings[inputName]) {
                    mergedMappings[inputName] = [];
                }

                if (!mergedMappings[inputName].includes(fieldName)) {
                    mergedMappings[inputName].push(fieldName);
                }
            });
        });

        if (Object.keys(mergedMappings).length === 0) {
            Object.entries(this.targetFieldsMapping || {}).forEach(([mappingInputName, fieldName]) => {
                const inputName = normalizeMappingInputName(mappingInputName);
                if (!inputName || !fieldName) {
                    return;
                }
                if (!mergedMappings[inputName]) {
                    mergedMappings[inputName] = [];
                }
                if (!mergedMappings[inputName].includes(fieldName)) {
                    mergedMappings[inputName].push(fieldName);
                }
            });
        }

        this.roleMappingsCache[role] = mergedMappings;
        return mergedMappings;
    }

    // Resolves one logical input value from role member/form mapping sources.
    getRoleInputValue(role, inputName) {
        const roleMappings = this.getRoleMappings(role);
        const fields = roleMappings[inputName] || [];
        const existingMember = this.getExistingMemberByRole(role);

        // Affiliation Id must remain role-specific. Never read it from shared top-level formData.
        if (inputName === "affiliationId" || fields.includes(ID_FIELD)) {
            const existingId = existingMember?.[ID_FIELD] ?? existingMember?.[inputName];
            if (this.hasValue(existingId)) {
                return this.normalize(existingId);
            }
            return null;
        }

        if (existingMember) {
            const memberValue = this.getValueFromMember(existingMember, inputName, fields);
            if (memberValue !== undefined) {
                return memberValue;
            }
        }

        for (const fieldName of fields) {
            const value = this.formData[fieldName];
            if (this.hasValue(value)) {
                return this.normalize(value);
            }
        }

        return null;
    }

    // Finds the current member entry for a specific role.
    getExistingMemberByRole(role) {
        return (this.formData?.members || []).find((member) => member?.[ROLE_FIELD] === role) || null;
    }

    // Indicates whether a member contains any save-worthy affiliation fields.
    hasMeaningfulAffiliationValues(member) {
        return Object.keys(member).some(
            (key) => key.startsWith(AFFILIATION_FIELD_PREFIX) && key !== ROLE_FIELD && key !== ID_FIELD && this.hasValue(member[key])
        );
    }

    // Builds a display name from entity/individual name fields.
    buildMemberName(memberType, entityName, firstName, lastName) {
        if (memberType === "Entity") {
            return entityName || "";
        }
        return `${firstName || ""} ${lastName || ""}`.trim();
    }

    // Updates state options based on selected country (dependent picklist behavior).
    updateFilteredStateOptions() {
        if (!this.rawStatePicklist) {
            this.stateOptions = [];
            return;
        }

        if (!this.rawCountryPicklist || !this.countryValue) {
            this.stateOptions = [];
            return;
        }

        const countryIndex = this.rawCountryPicklist.values.findIndex((countryValue) => countryValue.value === this.countryValue);
        if (countryIndex === -1) {
            this.stateOptions = this.setCBOptionsFromPicklistValues(this.rawStatePicklist);
            return;
        }

        this.stateOptions = this.rawStatePicklist.values
            .filter((stateValue) => this.validForIncludes(stateValue.validFor, countryIndex))
            .map((stateValue) => ({ label: stateValue.label.toUpperCase(), value: stateValue.value }));
    }

    // Checks whether a dependent picklist option is valid for a controlling value index.
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

    hasValue(value) {
        return value !== undefined && value !== null && value !== "";
    }

    normalize(value) {
        return this.hasValue(value) ? value : null;
    }

    areMembersEqual(existingMember, desiredMember) {
        if (!existingMember || !desiredMember) {
            return false;
        }

        const keys = new Set([...Object.keys(existingMember), ...Object.keys(desiredMember)]);
        keys.delete("label");

        for (const key of keys) {
            if (this.normalize(existingMember[key]) !== this.normalize(desiredMember[key])) {
                return false;
            }
        }

        return true;
    }
}