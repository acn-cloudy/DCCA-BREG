import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_WrittenApprovalType extends BaseFormComponent {
    defaultTitle = "Written Approval";
    writtenApprovalTypeValue;
    get readOnlyWrittenApprovalTypeValue() {
        return this.getWrittenApprovalLabelByValue(this.writtenApprovalTypeValue).toUpperCase();
    }

    get writtenApprovalTypeLabel() {
        return this.componentSettings?.writtenApprovalTypeLabel || "Select one of the following statements, as applicable.";
    }

    get writtenApprovalTypeOptions() {
        return [
            {
                label: "The written approval of a specified person or persons named in the articles of incorporation was obtained.",
                value: "Written Approval Obtained"
            },
            { label: "The written approval of a specified person or persons is not required.", value: "Written Approval Not Required" }
        ];
    }

    getWrittenApprovalLabelByValue(value) {
        if (!value) return null;
        const opt = this.writtenApprovalTypeOptions.find((o) => o.value === value);
        return opt ? opt.label : null;
    }
}