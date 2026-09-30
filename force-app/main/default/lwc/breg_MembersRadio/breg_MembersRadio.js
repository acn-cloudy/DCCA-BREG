import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_MembersRadio extends BaseFormComponent {
    defaultTitle = "Members";
    hasMembersValue;

    hasMembersOptions = [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" }
    ];

    handleInputChange(event) {
        super.handleInputChange(event);
        const inputName = event?.target?.name;
        const value = this.getValueFromEvent(event);
        if (inputName === "hasMembers") {
            this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value === "Yes"));
        }
    }

    processFormData() {
        super.processFormData();
        const hasMembersField = this.targetFieldsMapping?.hasMembers;
        if (hasMembersField) {
            const hasMembersValue = this.formData[hasMembersField];
            if (hasMembersValue === true) {
                this.hasMembersValue = "Yes";
            } else if (hasMembersValue === false) {
                this.hasMembersValue = "No";
            }
        }
    }

    get hasMembersValueReadOnly() {
        const option = this.hasMembersOptions.find((opt) => opt.value === this.hasMembersValue);
        return `Does the corporation have members?: <b>${option ? option.label.toUpperCase() : ""}</b>`;
    }
}