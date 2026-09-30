import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_LiabilityOfMembers extends BaseFormComponent {
    defaultTitle = "Liability of Members";
    liabilityOfMembersValue;
    liabilityDetailsValue;

    liabilityOptions = [
        {
            label: "Shall not be liable for the debts, obligations, and liabilities of the company.",
            value: "None"
        },
        {
            label: "Shall be liable for all debts, obligations, and liabilities of the company.",
            value: "Full"
        },
        {
            label: "Shall be liable for specific debts, obligations, and liabilities of the company as stated below, and have consented in writing to the adoption of this provision or to be bound by this provision.",
            value: "Partial"
        }
    ];

    get showLiabilityDetailsField() {
        return this.liabilityOfMembersValue === "Partial";
    }

    get liabilityOfMembersValueReadOnly() {
        const option = this.liabilityOptions.find((opt) => opt.value === this.liabilityOfMembersValue);
        return `<b>Liability of Members:</b><br> ${option ? option.label.toUpperCase() : ""}`;
    }

    get liabilityDetailsValueReadOnly() {
        return `<br><b>Liability Details:</b> ${this.liabilityDetailsValue.toUpperCase() ?? ""}`;
    }
}