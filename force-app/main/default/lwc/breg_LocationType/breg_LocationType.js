import BaseFormComponent from "c/breg_BaseFormComponent";
import BREG_HelpText_ApplicantLocationType_Domestic from "@salesforce/label/c.BREG_HelpText_ApplicantLocationType_Domestic";
import BREG_HelpText_ApplicantLocationType_Foreign from "@salesforce/label/c.BREG_HelpText_ApplicantLocationType_Foreign";

export default class Breg_LocationType extends BaseFormComponent {
    locationTypeValue;
    formationStateValue;
    filingDateValue;

    get locationTypeOptions() {
        return [
            {
                label: "Domestic",
                value: "Domestic",
                action: {
                    type: "tooltip",
                    prefix: "[",
                    label: "More info",
                    suffix: "]",
                    header: "Domestic",
                    body: BREG_HelpText_ApplicantLocationType_Domestic
                }
            },
            {
                label: "Foreign",
                value: "Foreign",
                action: {
                    type: "tooltip",
                    prefix: "[",
                    label: "More info",
                    suffix: "]",
                    header: "Foreign",
                    body: BREG_HelpText_ApplicantLocationType_Foreign
                }
            }
        ];
    }

    get selectedLocationTypeOption() {
        return this.locationTypeOptions.find((opt) => opt.value === this.locationTypeValue);
    }

    get helpTextTitleReadOnly() {
        return this.selectedLocationTypeOption?.action?.header ?? "";
    }

    get helpTextMessageReadOnly() {
        return this.selectedLocationTypeOption?.action?.body ?? "";
    }

    get showLocationTypeHelpTextReadOnly() {
        return !!this.helpTextMessageReadOnly;
    }

    get showFormationStateField() {
        return this.locationTypeValue === "Foreign" && this.config.targetFieldsMapping?.includes("formationState");
    }

    get showFilingDateField() {
        return this.locationTypeValue && this.config.targetFieldsMapping?.includes("filingDate");
    }

    get filingDateLabel() {
        return (
            "The Statement of " +
            (this.locationTypeValue === "Domestic" ? "" : "Foreign") +
            " Qualification was filed with the Department of Commerce and Consumer Affairs on"
        );
    }

    get locationTypeValueReadOnly() {
        const option = this.locationTypeOptions.find((opt) => opt.value === this.locationTypeValue);
        return `${this.config.labelOverride2 ? this.config.labelOverride2 + ": " : ""} <b>${option ? option.label.toUpperCase() : ""}</b>`;
    }

    handleInputChange(event) {
        const inputName = event?.target?.dataset?.name || event?.target?.name;

        if (inputName === "locationType" && event?.detail?.value !== undefined) {
            const value = event.detail.value;

            const syntheticEvent = {
                target: {
                    name: "locationType",
                    value: value,
                    dataset: { name: "locationType" }
                },
                detail: { value: value },
                preventDefault() {},
                stopPropagation() {}
            };

            this.locationTypeValue = value;
            super.handleInputChange(syntheticEvent);
            return;
        }

        super.handleInputChange(event);
    }

    get formationStateValueReadOnly() {
        return `The State, Province, or Country of Formation is: ${this.formationStateValue.toUpperCase()}`;
    }

    get filingDateValueReadOnly() {
        return `${this.filingDateLabel}: <br><b>${this.filingDateValue.replace(/-/g, "/")}</b>`;
    }
}