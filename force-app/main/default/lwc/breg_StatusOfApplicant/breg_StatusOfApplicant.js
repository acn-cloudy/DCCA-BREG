import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_StatusOfApplicant extends BaseFormComponent {
    defaultTitle = "Status of Applicant";
    applicantStatusValue;

    applicantStatusOptions = [
        { label: "Sole Proprietor", value: "Sole Proprietor" },
        { label: "Corporation", value: "Corporation" },
        { label: "LLC", value: "LLC" },
        { label: "LLP", value: "LLP" },
        { label: "Unincorporated Association", value: "Unincorporated Association" },
        { label: "Other", value: "Other" }
    ];
}