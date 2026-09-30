import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_ApplicantType extends BaseFormComponent {
    defaultTitle = "Applicant Type";
    applicantTypeValue;

    get readOnlyApplicantTypeValue() {
        return this.applicantTypeValue.toUpperCase();
    }
    get originatorName() {
        return this.formCode === "T-1" ? "The originator of the trade name" : "Originator of name";
    }
    get assigneeName() {
        return this.formCode === "T-1" ? "An Assignee (Name was assigned to applicant)" : "Assignee (one to whom name was assigned to by another)";
    }

    applicantTypeOptions = [
        { label: this.originatorName, value: "Originator" },
        { label: this.assigneeName, value: "Assignee" }
    ];
}