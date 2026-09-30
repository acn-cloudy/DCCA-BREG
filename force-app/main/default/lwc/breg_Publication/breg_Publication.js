import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Publication extends BaseFormComponent {
    defaultTitle = "Publication";
    publicationTypeValue;
    publicationDate1Value;
    publicationDate2Value;
    publicationDate3Value;
    publicationDate4Value;

    get publicationTypeOptions() {
        return [
            { label: "Publication was not made.", value: "Not Published" },
            {
                label:
                    this.config?.labelOverrideLong ||
                    "The notice of intent to withdraw from the State of Hawaii was published",
                value: "Published"
            }
        ];
    }

    get showPublishedSection() {
        return this.publicationTypeValue === "Published";
    }

    get publicationTypeValueReadOnly() {
        const option = this.publicationTypeOptions.find((opt) => opt.value === this.publicationTypeValue);
        return `${this.config.labelOverride2 ? this.config.labelOverride2 + ": " : ""} ${option ? option.label.toUpperCase() : ""}`;
    }

    get publicationDate1ValueReadOnly() {
        return `<b>Publication Date 1:</b> <br>${this.publicationDate1Value ? this.publicationDate1Value.replace(/-/g, "/") : ""}`;
    }

    get publicationDate2ValueReadOnly() {
        return `<b>Publication Date 2:</b> <br>${this.publicationDate2Value ? this.publicationDate2Value.replace(/-/g, "/") : ""}`;
    }

    get publicationDate3ValueReadOnly() {
        return `<b>Publication Date 3:</b> <br>${this.publicationDate3Value ? this.publicationDate3Value.replace(/-/g, "/") : ""}`;
    }

    get publicationDate4ValueReadOnly() {
        return `<b>Publication Date 4:</b> <br>${this.publicationDate4Value ? this.publicationDate4Value.replace(/-/g, "/") : ""}`;
    }

    get publicationNameValueReadOnly() {
        return `<br><b>Name of Publication/Newspaper:</b> <br>${this.publicationNameValue ? this.publicationNameValue.toUpperCase() : ""}`;
    }
}