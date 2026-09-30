import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_DissolutionReason extends BaseFormComponent {
    dissolutionReasonValue = [];
    otherReasonValue;

    dissolutionReasonOptions = [
        { label: "Mutual Consent", value: "Mutual Consent" },
        { label: "Disagreement Among Partners", value: "Disagreement Among Partners" },
        { label: "Death Of A Partner", value: "Death Of A Partner" },
        { label: "Other", value: "Other" }
    ];

    get showOtherReasonField() {
        return this.dissolutionReasonValue.includes("Other");
    }

    get dissolutionReasonValueReadOnly() {
        if (this.dissolutionReasonValue.length === 0) {
            return "";
        }
        let labels = this.dissolutionReasonOptions.filter((opt) => this.dissolutionReasonValue.includes(opt.value)).map((opt) => opt.label);
        if (this.showOtherReasonField && this.otherReasonValue) {
            labels = labels.map((label) => (label === "Other" ? `Other: ${this.otherReasonValue.toUpperCase()}` : label.toUpperCase()));
        }
        return labels.join(", ");
    }
}