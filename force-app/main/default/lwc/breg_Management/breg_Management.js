import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Management extends BaseFormComponent {
    defaultTitle = "Management type";
    managementTypeValue;
    numberOfInitialMembersValue;

    get readOnlyManagementType() {
        return this.componentSettings?.ReadOnlyManagementType || this.readOnly;
    }

    get readOnlyManagementTypeValue() {
        return this.managementTypeValue ? this.managementTypeValue.toUpperCase() : this.emptyInputString;
    }

    get readOnlyNumberValue() {
        return `${this.config.labelOverride2} ${this.numberOfInitialMembersValue ? this.numberOfInitialMembersValue : "0"}`;
    }

    managementTypeOptions = [
        {
            label: "Manager Managed, and the name(s) and address(es) of the initial manager(s) are listed below",
            value: "Manager Managed"
        },
        {
            label: "Member Managed, and the name(s) and address(es) of the initial member(s) are listed below",
            value: "Member Managed"
        }
    ];

    get showNumberOfInitialMembers() {
        return this.managementTypeValue === "Manager Managed" && this.config.targetFieldsMapping?.includes("numberOfInitialMembers");
    }

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();
        super.handleInputChange(event);
        const inputName = event.target.name;
        const value = this.getValueFromEvent(event);

        this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value === "Manager Managed"));
    }

    processFormData() {
        super.processFormData();
        const managementTypeField = this.targetFieldsMapping?.managementType;

        if (managementTypeField) {
            const managementTypeValue = this.formData[managementTypeField];

            if (managementTypeValue === true) {
                this.managementTypeValue = "Manager Managed";
            } else if (managementTypeValue === false) {
                this.managementTypeValue = "Member Managed";
            }
        }
    }
}