import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_QualificationAmendment extends BaseFormComponent {
    qualificationAmendmentValue;
    newEntityNameValue;
    otherAmendmentDetailsValue;

    qualificationAmendmentOptions = [
        { label: "The name of the limited liability partnership is changed to", value: "Name Change" },
        { label: "The limited liability partnership voluntarily cancels its limited liability status.", value: "Voluntary Cancel" },
        { label: "Other (State/attach the amendment for the Statement of Qualification or Statement of Foreign Qualification.)", value: "Other" }
    ];

    qualificationAmendmentLabel = {
        "Name Change": "The general partnership is required to file the Partnership Change of Name Statement (FORM GP-2).",
        "Voluntary Cancel":
            "The general partnership is required to file the General Partnership Dissolution Statement (FORM GP-4) or file the Partnership Change of Name Statement (FORM GP-2) if it will remain registered as a general partnership pursuant to Part I. of Chapter 425, Hawaii Revised Statutes.",
        Other: "The general partnership is required to file the Statement of Change (FORM GP-3)."
    };

    get showNewEntityNameField() {
        return this.qualificationAmendmentValue === "Name Change";
    }

    get showOtherAmendmentDetailsField() {
        return this.qualificationAmendmentValue === "Other";
    }

    get showQualificationAmendmentLabel() {
        return this.qualificationAmendmentValue;
    }

    get getQualificationAmendmentLabel() {
        return this.qualificationAmendmentLabel[this.qualificationAmendmentValue] ?? "";
    }

    get qualificationAmendmentValueReadOnly() {
        const option = this.qualificationAmendmentOptions.find((opt) => opt.value === this.qualificationAmendmentValue);
        return `${this.config.labelOverride2 ? this.config.labelOverride2 + ": " : ""} ${option ? option.label.toUpperCase() : ""}`;
    }

    get newEntityNameValueReadOnly() {
        return `<b>${this.newEntityNameValue.toUpperCase()}</b><br>`;
    }

    get otherAmendmentDetailsValueReadOnly() {
        return `<b>Details:</b> <br>${this.otherAmendmentDetailsValue.toUpperCase()}<br>`;
    }
}