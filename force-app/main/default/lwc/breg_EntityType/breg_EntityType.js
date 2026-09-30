import { wire, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import ENTITY_TYPE_FIELD from "@salesforce/schema/Case.breg_Entity_Type__c";

const DOMESTIC_LOCATION_VALUE = "Domestic";
const FOREIGN_LOCATION_VALUE = "Foreign";
export default class Breg_EntityType extends BaseFormComponent {
    defaultTitle = "Entity Type";
    entityTypeValue;
    allEntityTypes = [];
    @track entityTypeOptions = [];
    caseRecTypeId;
    locationType;

    get entityTypeLabel() {
        return this.config?.labelOverride2 || "Entity Type";
    }

    get showEntityTypeDescription() {
        return this.entityTypeValue === "Other";
    }

    getAllowedEntityTypes() {
        if (!this.allEntityTypes.length) return;
        let options = [];
        const entityApiNames = this.componentSettings?.entityTypeList?.split(";") || [];
        options = this.allEntityTypes
            .filter((option) => entityApiNames.includes(option.value))
            .map(option => ({ ...option })); // Create a copy of the option to avoid mutating the original allEntityTypes
        if (this.config?.targetFieldsMapping?.includes("entityTypeDescription")) {
            options.push({ label: "OTHER", value: "Other" });
        }
        return [...options];
    }

    get readOnlyEntityType() {
        let label = this.getLabelFromOptions(this.allEntityTypes, this.entityTypeValue);
        if (this.entityTypeDescriptionValue != null) {
            label = this.entityTypeDescriptionValue;
        }
        return this.entityTypeLabel === "Entity Type" ? `${label.toUpperCase()}` : `<b>${this.entityTypeLabel}</b>: <br> ${label.toUpperCase()}`;
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    results({ data }) {
        if (data) {
            // Find BREG Case record type by name since recordTypeInfos is keyed by ID
            const bregCaseRecordType = Object.values(data.recordTypeInfos).find((rt) => rt.name === "BREG Case");
            this.caseRecTypeId = bregCaseRecordType?.recordTypeId || data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: "$caseRecTypeId", fieldApiName: ENTITY_TYPE_FIELD })
    async entityTypeOptionsWired({ data }) {
        this.allEntityTypes = this.setCBOptionsFromPicklistValues(data);
        this.entityTypeOptions = this.getAllowedEntityTypes();
        this.switchEntityTypeLocation();
    }

    connectedCallback() {
        super.connectedCallback();
        this.entityTypeOptions = this.getAllowedEntityTypes();
        this.switchEntityTypeLocation();
        this.setShowSection();
    }

    processFormData() {
        super.processFormData();
        this.switchEntityTypeLocation();
        this.setShowSection();
    }

    setShowSection() {
        const showSectionMemberTypeField = this.componentSettings?.showSectionMemberTypeField;
        const showSectionMemberTypeValue = this.formData[showSectionMemberTypeField];
        if (showSectionMemberTypeField && showSectionMemberTypeValue) {
            if (showSectionMemberTypeValue === "Individual" && this.showSection) {
                this.showSection = false;
                if (this.getValueByInputName("entityType")) {
                    this.entityTypeValue = null;
                    this.dispatchCustomEvent("formupdate", this.getValueChangeData("entityType", null));
                }
            } else if (showSectionMemberTypeValue === "Entity" && !this.showSection) {
                this.showSection = true;
            }
        }
    }

    switchEntityTypeLocation() {
        // Only switch entity types when locationTypeRelatedField setting is configured
        if (!this.componentSettings?.locationTypeRelatedField || !this.allEntityTypes.length) return;

        const locationTypeRelatedField = this.componentSettings.locationTypeRelatedField;
        let locationType = this.formData[locationTypeRelatedField];

        if (!locationType) locationType = DOMESTIC_LOCATION_VALUE; // Default to Domestic to show entity types without 'location' on initial load 
        
        // Skip if location hasn't changed or is invalid
        if (this.locationType === locationType
        || (locationType !== DOMESTIC_LOCATION_VALUE && locationType !== FOREIGN_LOCATION_VALUE)) {
            return;
        }
        
        this.locationType = locationType;
        let options = this.getAllowedEntityTypes();
        const oldOptions = [...this.entityTypeOptions];

        // Filter entity types matching the location type and strip location prefix from labels
        options = options
            .filter(option => {
                return option.label.toUpperCase().includes(locationType.toUpperCase()) || option.value === "Other";              
            })
            .map((option) => {
                option.label = option.label.replace(locationType.toUpperCase(), "").trim();
                return option;
            });
                
        this.entityTypeOptions = [...options];
        
        if (this.entityTypeValue && oldOptions.length) {
            // Preserve selection when switching locations by matching the stripped label
            const oldOptionLabel = oldOptions.find((opt) => opt.value === this.entityTypeValue)?.label;
            const entityTypeValue = this.entityTypeOptions.find((opt) => opt.label === oldOptionLabel)?.value;
            if (entityTypeValue && this.entityTypeValue !== entityTypeValue ) {
                this.entityTypeValue = entityTypeValue;
                this.dispatchCustomEvent("formupdate", this.getValueChangeData("entityType", this.entityTypeValue));
            }
        }
    }
}