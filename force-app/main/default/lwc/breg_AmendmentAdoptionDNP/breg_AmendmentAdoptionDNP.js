import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_AmendmentAdoptionDNP extends BaseFormComponent {
    defaultTitle = "Amendment Adoption";
    adoptedDateValue;
    amendmentAdoptionTypeValue;
    designationValue;
    totalNumberOfMembershipsValue;
    totalNumberOfVotesValue;
    numberOfVotesForValue;
    numberOfVotesAgainstValue;

    dependentFieldsMapping = {
        amendmentAdoptionType: ["designation", "totalNumberOfMemberships", "totalNumberOfVotes", "numberOfVotesFor", "numberOfVotesAgainst"]
    };

    get amendmentAdoptionTypeOptions() {
        let options = [
            { label: "at a meeting of the members", value: "Meeting" },
            { label: "by written consent of the members holding at least eighty percent of the voting power", value: "Written Consent" },
            {
                label: "by a sufficient vote of the board of directors or incorporators because member approval was not required",
                value: "Board Directors Vote"
            }
        ];
        return options;
    }

    get readOnlyAdoptedDateValue() {
        return `${this.labels.BREG_Adopted_Date_Label.toUpperCase()} ${this.adoptedDateValue.replace(/-/g, "/")}`;
    }

    get readOnlyAmendmentAdoptionTypeValue() {
        return `${this.amendmentAdoptionTypeLabel.toUpperCase()} ${this.getLabelFromOptions(this.amendmentAdoptionTypeOptions, this.amendmentAdoptionTypeValue).toUpperCase()}`;
    }

    get readOnlyDesignationValue() {
        return `${this.labels.BREG_Designation_class.toUpperCase()}:`;
    }

    get readOnlyTotalNumberOfMembershipsValue() {
        return `${this.labels.BREG_Total_Number_Outstanding.toUpperCase()}:`;
    }

    get readOnlyTotalNumberOfVotesValue() {
        return `${this.labels.BREG_Total_Number_Entitled.toUpperCase()}:`;
    }

    get readOnlyNumberOfVotesForValue() {
        return `${this.numberOfVotesForLabel.toUpperCase()}:`;
    }

    get readOnlyNumberOfVotesAgainstValue() {
        return `${this.numberOfVotesAgainstLabel.toUpperCase()}:`;
    }

    get showMeetingFields() {
        return this.amendmentAdoptionTypeValue === "Meeting";
    }

    get amendmentAdoptionTypeLabel() {
        return this.config?.labelOverride2 || this.config?.labelOverrideLong2 || "Amendment was approved";
    }
    get adoptedDateLabel() {
        return this.componentSettings?.adoptedDateLabel || "Date Adopted";
    }
    get numberOfVotesForLabel() {
        return this.componentSettings?.numberOfVotesForLabel || "Number of Votes Cast by Each Class For the Amendment";
    }
    get numberOfVotesAgainstLabel() {
        return this.componentSettings?.numberOfVotesAgainstLabel || `Number of Votes Cast by Each Class Against the Amendment`;
    }
}