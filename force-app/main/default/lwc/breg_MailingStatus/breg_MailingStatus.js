import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_MailingStatus extends BaseFormComponent {
    defaultTitle = "Mailing Status";
    mailingStatusValue;
    mailingDateValue;

    get mailingStatusOptions() {
        return [
            { label: "A copy of the Plan of Merger was mailed to all of the shareholders of the subsidiary corporation on:", value: "Mailed" },
            { label: "Mailing requirement was waived.", value: "Waived" }
        ];
    }

    get showMailingDateField() {
        return this.mailingStatusValue === "Mailed";
    }

    get mailingStatusValueReadOnly() {
        const option = this.mailingStatusOptions.find((opt) => opt.value === this.mailingStatusValue);
        return `${this.config.labelOverride2 ? this.config.labelOverride2 + ": " : ""} ${option ? option.label.toUpperCase() : ""}`;
    }

    get mailingDateValueReadOnly() {
        return `<b>${this.mailingDateValue ? this.mailingDateValue.replace(/-/g, "/") : ""}</b>`;
    }
}