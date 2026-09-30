import { api, LightningElement, track } from "lwc";
import constants from "c/breg_constants";
import { Labels } from "./labels";
import { getPageParamsFromUrl } from "c/utils";

export default class Breg_BaseFormComponent extends LightningElement {
    @api config;
    @api formConfig;
    @api isNested = false;
    @api labelHidden = false;
    @api files = [];
    @track _cmpProperties = {};
    labels = Labels;
    _readOnly = false;
    _required = true;
    isInternal = false;
    caseRecTypeId;
    dependentFieldsMapping = {};
    labelHiddenValue = constants.LABEL_HIDDEN;
    emptyInputString = this.labels.BREG_Empty_Input_String;
    natureOfBusinessEmptyString = this.labels.BREG_Nature_of_Business_optional;
    natureOfActivitiesEmptyString = this.labels.BREG_No_Nature_of_Activities_added;
    
    formConfigId;
    prefix;
    whatIsThisForm;
    suffix;
    formName;
    formCode;
    businessProcess;
    businessLocation;
    businessStructure;
    businessProfit;
    registrationType;
    corporationType;
    cooperativeType;
    stockType;
    partnershipType;
    linkedForm;

    title;
    defaultTitle;
    hasChangedValue = false;

    @track _formData = {};
    targetFieldsMapping;
    sourceFieldsMapping;
    defaultValuesMapping;
    componentSettings;
    alwaysEditMode = false;
    alwaysReadOnly = false;
    onlyAddressEditable = false;
    conditionalReadOnly = false;
    optional = false;
    showSection = false;

    @api
    get cmpProperties() {
        return this._cmpProperties;
    }
    set cmpProperties(value) {
        this._cmpProperties = value;
        this.setComponentProperties();
    }

    get companyName() {
        return this.formData["Case.breg_Name_of_the_Entity__c"] ?? this.formData["Case.breg_TNTMSM_Description__c"];
    }
    get readOnly() {
        if (this.alwaysEditMode) return false;
        if (this.alwaysReadOnly) return true;
        if (this.conditionalReadOnly) return true;
        return this._readOnly;
    }

    get required() {
        if (this.readOnly) return false;
        if (this.optional) return false;
        return this._required;
    }

    get showEditSectionButton() {
        return this.readOnly && !this.alwaysReadOnly && this.isAnnualForm;
    }

    get isAnnualForm() {
        return this.businessProcess === "Annual Report";
    }

    get isNBRForm() {
        return this.businessProcess === "New Business";
    }

    get isChangeForm() {
        return this.businessProcess === "Change";
    }

    setComponentProperties() {
        this._readOnly = this.cmpProperties.readOnly || false;
        this.isInternal = this.cmpProperties.isInternal || false;
    }

    @api
    get formData() {
        return this._formData;
    }
    set formData(value) {
        this._formData = value;
        this.processFormData();
    }

    get entityType() {
        return this.formConfig?.entityType || this.formData["Case.breg_Entity_Type__c"] || this.formData["Case.breg_New_Entity_Type__c"];
    }

    get editMode() {
        return !this.readOnly;
    }

    // Has changed checkbox
    get hasChangedCheckboxLabel() {
        return this.componentSettings?.hasChangedCheckboxLabel || `The ${this.title?.toLowerCase()} has changed.`;
    }
    get showHasChangedCheckbox() {
        return "hasChanged" in this.targetFieldsMapping;
    }
    get hasChangedReadOnly() {
        return this.readOnly || this.componentSettings?.hasChangedAlwaysReadOnly;
    }


    get showFields() {
        return !this.showHasChangedCheckbox || (this.showHasChangedCheckbox && this.hasChangedValue)
    }

    // Descriptions
    get description() {
        if (this.readOnly) {
            return this.componentSettings?.descriptionReadOnly ?? this.config?.labelOverrideLong;
        }
        return this.config?.labelOverrideLong;
    }

    get showDescription() {
        return this.description && (this.editMode || this.componentSettings?.descriptionReadOnly || this.componentSettings?.showDescriptionInReadOnlyMode);
    }

    get description2() {
        if (this.readOnly) {
            return this.componentSettings?.description2ReadOnly ?? this.componentSettings?.description2;
        }
        return this.componentSettings?.description2;
    }

    get showDescription2() {
        return this.description2 && (this.editMode || this.componentSettings?.description2ReadOnly || this.componentSettings?.showDescriptionInReadOnlyMode);
    }

    connectedCallback() {
        const { accountId } = getPageParamsFromUrl();
        try {
            if (this.formConfig) {
                this.formConfigId = this.formConfig.id;
                this.prefix = this.formConfig.prefix;
                this.whatIsThisForm = this.formConfig.whatIsThisForm;
                this.suffix = this.formConfig.suffix;
                this.formName = this.formConfig.formName;
                this.formCode = this.formConfig.formCode;
                this.businessProcess = this.formConfig.businessProcess;
                this.businessLocation = this.formConfig.businessLocation;
                this.businessStructure = this.formConfig.businessStructure;
                this.businessProfit = this.formConfig.businessProfit;
                this.registrationType = this.formConfig.registrationType;
                this.corporationType = this.formConfig.corporationType;
                this.cooperativeType = this.formConfig.cooperativeType;
                this.stockType = this.formConfig.stockType;
                this.partnershipType = this.formConfig.partnershipType;
                this.linkedForm = this.formConfig.linkedForm;
            } else {
                console.warn(`** base cmp -> formConfig is not set for component: ${this.config?.name}, order: ${this.config?.order}`);
            }

            this.title =
                !this.labelHidden && this.config?.labelOverride && this.config?.labelOverride === this.labelHiddenValue
                    ? ""
                    : !this.labelHidden
                      ? this.config?.labelOverride || this.defaultTitle
                      : "";

            this.targetFieldsMapping = this.config?.targetFieldsMapping ? JSON.parse(this.config.targetFieldsMapping) : {};
            this.sourceFieldsMapping = this.config?.sourceFieldsMapping ? JSON.parse(this.config.sourceFieldsMapping) : {};
            this.defaultValuesMapping = this.config?.targetDefaultValues ? JSON.parse(this.config.targetDefaultValues) : {};
            this.componentSettings = this.config?.componentSettings ? JSON.parse(this.config.componentSettings) : {};
            this.alwaysReadOnly = this.componentSettings?.alwaysReadOnly ?? false;
            this.onlyAddressEditable = this.componentSettings?.onlyAddressEditable ?? false;
            this.conditionalReadOnly = this.componentSettings?.conditionalReadOnly && accountId != null ? true : false;
            this.alwaysEditMode = this.componentSettings?.alwaysEditMode ?? false;
            this.optional = this.componentSettings?.optional ?? false;
            this.showSection = this.componentSettings?.showSectionByDefault ?? true;

            // console.log("** base cmp -> target fields mapping:", JSON.stringify(this.targetFieldsMapping));
            // console.log("** base cmp -> default fields mapping:", JSON.stringify(this.defaultValuesMapping));
            console.log("*** Component loaded:", this.config.name, this.config.order);
            this.populateDefaultValues();
            this.processFormData();
        } catch (err) {
            console.error("*** base cmp -> load config error:", JSON.stringify(err));
        }
    }

    @api
    async reportValidity() {
        const allValid = [
            ...this.template.querySelectorAll("lightning-input"),
            ...this.template.querySelectorAll("lightning-textarea"),
            ...this.template.querySelectorAll("lightning-radio-group"),
            ...this.template.querySelectorAll("lightning-checkbox-group"),
            ...this.template.querySelectorAll("lightning-combobox"),
            ...this.template.querySelectorAll(".form-cmp")
        ].reduce(async (validSoFar, inputCmp) => {
            await inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
        return allValid;
    }

    @api
    checkValidity() {
        const allValid = [
            ...this.template.querySelectorAll("lightning-input"),
            ...this.template.querySelectorAll("lightning-textarea"),
            ...this.template.querySelectorAll("lightning-radio-group"),
            ...this.template.querySelectorAll("lightning-checkbox-group"),
            ...this.template.querySelectorAll("lightning-combobox"),
            ...this.template.querySelectorAll(".form-cmp")
        ].reduce((validSoFar, inputCmp) => {
            return validSoFar && inputCmp.checkValidity();
        }, true);
        return allValid;
    }

    @api
    setCustomValidity(message) {
        const components = [
            ...this.template.querySelectorAll("lightning-input"),
            ...this.template.querySelectorAll("lightning-textarea"),
            ...this.template.querySelectorAll("lightning-radio-group"),
            ...this.template.querySelectorAll("lightning-combobox"),
            ...this.template.querySelectorAll(".form-cmp")
        ];
        components.forEach((component) => {
            component.setCustomValidity(message);
        });
    }

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();
        const inputTag = event?.target?.tagName?.toLowerCase();
        const inputType = event?.target?.type;
        if ((inputTag === "lightning-input" && inputType !== "checkbox") || inputTag === "lightning-textarea") return;
        const inputName = event.target.dataset.name || event.target.name;

        let value = this.getValueFromEvent(event);
        this[`${inputName}Value`] = value;
        this.resetDependentFieldsValue(inputName);

        if (inputTag === "lightning-checkbox-group") value = value.join(";");
        console.log("** change event:", inputName, value);
        if (this.isNested) {
            this.dispatchCustomEvent("change", { inputName, value });
        } else {
            this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value));
        }
    }

    handleChangeNestedComponent(event) {
        event.preventDefault();
        event.stopPropagation();
        const inputName = event.detail.value.inputName;
        const value = event.detail.value.value;
        this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value));
    }

    handleInputBlur(event) {
        if (this.readOnly && !this.onlyAddressEditable) return;
        try {
            event.preventDefault();
            event.stopPropagation();
            const inputTag = event?.target?.tagName?.toLowerCase();
            if (inputTag !== "lightning-input" && inputTag !== "lightning-textarea") return;
            const inputType = event?.target?.type;
            const inputName = event?.target?.name;
            let value = this.getValueFromEvent(event);
            console.log("** handleBlur:", inputTag, inputName, value, typeof value);

            if (value && typeof value === "string") {
                value = value.toUpperCase();
            }
            if (inputType === "number") {
                value = parseFloat(value);
            }
            this[`${inputName}Value`] = value;
            this.resetDependentFieldsValue(inputName);
            if (this.isNested) {
                this.dispatchCustomEvent("change", { inputName, value });
            } else {
                this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value));
            }
        } catch (error) {
            console.error("** handleInputBlur error:", error);
        }
    }

    getValueFromEvent(event) {
        let value;
        const isBoolean =
            event?.target?.type === "checkbox" ||
            (event?.target?.tagName?.toLowerCase() === "lightning-input" && event?.target?.type === "checkbox") ||
            event?.target?.type === "toggle";

        if (isBoolean) {
            value = event.target.checked;
        } else {
            value = event?.target?.value || event?.detail?.value || null;
        }
        return value;
    }

    getValueByInputName(inputName) {
        const fieldName = this.getFieldName(inputName);
        return this.formData[fieldName];
    }

    resetDependentFieldsValue(inputName) {
        const mapping = this.dependentFieldsMapping[inputName];
        if (!mapping || mapping.length === 0) return;
        let sendingEvent = false;
        console.log("*** resetDependentFieldsValue for:", inputName, mapping);
        const formData = { ...this.formData };

        mapping.forEach((inputNameToRest) => {
            const fieldApiName = this.getFieldName(inputNameToRest);
            if (formData[fieldApiName] != null) {
                sendingEvent = true;
                this[`${inputNameToRest}Value`] = null;
                formData[fieldApiName] = null;
            }
        });

        if (sendingEvent) {
            this.dispatchCustomEvent("formupdate", { formData });
        }
    }

    dispatchCustomEvent(eventName, data) {
        this.dispatchEvent(
            new CustomEvent(eventName, {
                detail: {
                    value: data,
                    customEvent: true
                }
            })
        );
    }

    getValueChangeData(inputName, value) {
        return {
            field: this.getFieldName(inputName),
            value: value
        };
    }

    populateDefaultValues() {
        try {
            if (this.isNested) return;
            if (!this.defaultValuesMapping || Object.keys(this.defaultValuesMapping).length === 0) return;
            // Create a new object with current formData and default values
            const formData = {};
            for (const [key, value] of Object.entries(this.defaultValuesMapping)) {
                formData[key] = value;
            }

            // Update the internal _formData property directly
            // this._formData = updatedFormData;
            // console.log("*** form with defaults:", JSON.stringify(this.formData));

            this.dispatchCustomEvent("formupdate", { formData });
        } catch (error) {
            console.error("*** populateDefaultValues error:", error);
        }
    }

    processFormData(data = this.formData) {
        // console.log('processFormData for component: ', this.config?.name);
        if (!this.targetFieldsMapping || typeof this.targetFieldsMapping !== "object") {
            // console.warn('processFormData: targetFieldsMapping is not a valid object');
            return;
        }

        try {
            for (const [inputName, field] of Object.entries(this.targetFieldsMapping)) {
                if (!field) continue;
                let value = data[field];
                // console.log('inputName:', inputName);
                if (value !== undefined && this[`${inputName}Value`] !== value) {
                    this[`${inputName}Value`] = value;
                }
            }
        } catch (error) {
            console.error("Error in processFormData:", error);
        }
    }

    setCBOptionsFromPicklistValues(data) {
        let options = [];
        const controllingValuesMap = {};
        if (!data) {
            return options;
        }
        try {
            Object.keys(data.controllerValues).forEach((controllerValue) => {
                controllingValuesMap[data.controllerValues[controllerValue]] = controllerValue;
            });

            options = data.values.map((value) => ({
                label: value.label.toUpperCase(),
                value: value.value
            }));
        } catch (e) {
            console.error("*** setCBOptionsFromPicklistValues error", e);
            return options;
        }
        return options;
    }

    getLabelFromOptions(options, value) {
        if (!options || !Array.isArray(options) || value == null) {
            return null;
        }
        const option = options.find((opt) => opt.value === value);
        return option ? option.label : null;
    }

    getFieldName(inputName) {
        return this.targetFieldsMapping ? this.targetFieldsMapping[inputName] : undefined;
    }

    handleFormUpdate(event) {
        this.dispatchCustomEvent("formupdate", event.detail.value);
    }

    handleFileUpload(event) {
        this.dispatchCustomEvent("fileupload", event.detail.value);
    }

    handleFileRemove(event) {
        this.dispatchCustomEvent("fileremove", event.detail.value);
    }

    handleEditSectionClick() {
        const formConfig = this.prepareFormConfigForEditSectionModal();
        this.dispatchEvent(
            new CustomEvent("editsection", {
                detail: {
                    formConfig,
                    title: this.title
                }
            })
        );
    }

    copyAddress(sourceAddressConfig) {
        let targetFieldsMapping = JSON.parse(sourceAddressConfig.targetFieldsMapping);
        const formData = {};
        for (let targetField in targetFieldsMapping) {
            if (!targetFieldsMapping[targetField] || !this.targetFieldsMapping[targetField]) {
                continue;
            }
            let sourceFieldName = targetFieldsMapping[targetField];
            let targetFieldName = this.getFieldName(targetField, this.targetFieldsMapping);
            formData[targetFieldName] = this.formData[sourceFieldName] || "";
        }

        this.dispatchCustomEvent("formupdate", { formData });
        return formData;
    }

    isSameAddress(sourceAddressConfig, targetFormData = this.formData) {
        let targetFieldsMapping = JSON.parse(sourceAddressConfig.targetFieldsMapping);
        let isSame = true;
        // console.log("Starting address comparison...");
        for (let targetField in targetFieldsMapping) {
            if (!targetFieldsMapping[targetField] || !this.targetFieldsMapping[targetField]) {
                isSame = false;
            } else {
                let sourceFieldName = targetFieldsMapping[targetField];
                let targetFieldName = this.getFieldName(targetField, this.targetFieldsMapping);
                // console.log(
                //     "Comparing fields:",
                //     targetFieldName,
                //     "and",
                //     sourceFieldName,
                //     "values:",
                //     targetFormData[targetFieldName],
                //     targetFormData[sourceFieldName]
                // );
                isSame = targetFormData[targetFieldName] === targetFormData[sourceFieldName];
                if (!isSame) {
                    break;
                }
            }
        }
        return isSame;
    }

    prepareFormConfigForEditSectionModal() {
        const formConfig = { ...this.formConfig };
        const config = { ...this.config };
        config.labelOverride = this.labelHiddenValue; // used to hide section title in modal
        formConfig.elements = [config];
        return formConfig;
    }
}