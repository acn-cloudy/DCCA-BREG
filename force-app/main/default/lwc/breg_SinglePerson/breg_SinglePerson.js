import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Member extends BaseFormComponent {
    defaultTitle = "Member Name and Address";

    get showOfficeTitleField() {
        return this.config.targetFieldsMapping?.includes("officeTitle");
    }

    firstNameValue = '';
    lastNameValue = '';
    fullName = '';
    officeTitleValue = '';

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();
        super.handleInputChange(event);
        this.fullName = `${this.firstNameValue} ${this.lastNameValue}`;
        this.dispatchCustomEvent("change", { field: "member", value: this.fullName});
    }
}