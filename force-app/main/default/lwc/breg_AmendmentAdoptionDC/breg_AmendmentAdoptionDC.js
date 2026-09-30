import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_AmendmentAdoptionDC extends BaseFormComponent {
    defaultTitle = "Amendment Adoption";
    adoptedDateValue;
    amendmentAdoptionTypeValue;
    classSeriesValue;
    totalNumberOfMembershipsValue;
    totalNumberOfVotesValue;
    numberOfVotesForValue;
    numberOfVotesAgainstValue;
    writtenConsentDateValue;

    dependentFieldsMapping = {
        amendmentAdoptionType: ["adoptedDate", "classSeries", "totalNumberOfVotes", "numberOfVotesFor", "numberOfVotesAgainst", "writtenConsentDate"]
    };
    
    get amendmentAdoptionTypeOptions() {
        let options = [{ label: "Adopted at a meeting of shareholders", value: "Meeting" }];

        if (this.formCode) {
            if (this.formCode === "DC-13") {
                options.push({ label: "Adopted by unanimous written consent", value: "Unanimous Written Consent" });
            } else {
                options.push({ label: "By written consent signed by all shareholders", value: "Written Consent" });
            }

            if (this.formCode === "DC-12") {
                options.push({ label: "By the board of directors authorized by the shareholders", value: "Board Directors Vote" });
                options.push({ label: "By the incorporators", value: "Incorporators" });
            }
        }
        return options;
    }

    get readOnlyAmendmentAdoptionTypeValue() {
        return `${this.amendmentAdoptionTypeLabel.toUpperCase()} ${this.getLabelFromOptions(this.amendmentAdoptionTypeOptions, this.amendmentAdoptionTypeValue).toUpperCase()}`;
    }

    get readOnlyAdoptedDateValue() {
        return `${this.labels.BREG_Adopted_Date_Label.toUpperCase()} ${this.adoptedDateValue.replace(/-/g, "/")}`;
    }

    get readOnlyClassSeriesValue() {
        return `${this.labels.BREG_Class_Series.toUpperCase()}:`;
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

    get readOnlyWrittenConsentDateValue() {
        return `${this.labels.BREG_Written_Consent_Date.toUpperCase()}: ${this.writtenConsentDateValue.replace(/-/g, "/")}`;
    }

    get showMeetingFields() {
        return this.amendmentAdoptionTypeValue === "Meeting";
    }

    get showAdoptedDate() {
        return "adoptedDate" in this.targetFieldsMapping;
    }

    get showWrittenConsentDate() {
        return this.amendmentAdoptionTypeValue === "Written Consent";
    }

    get amendmentAdoptionTypeLabel() {
        return this.config?.labelOverride2 || this.config?.labelOverrideLong2 || "Amendment was approved";
    }
    get adoptedDateLabel() {
        return this.componentSettings?.adoptedDateLabel || "Shareholders Meeting Date";
    }
    get numberOfVotesForLabel() {
        return this.componentSettings?.numberOfVotesForLabel || "Number of Votes Cast by Each Class For the Amendment";
    }
    get numberOfVotesAgainstLabel() {
        return this.componentSettings?.numberOfVotesAgainstLabel || `Number of Votes Cast by Each Class Against the Amendment`;
    }
}