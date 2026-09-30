import BaseFormComponent from "c/breg_BaseFormComponent";
import BREG_HelpText_ApplicantLocationType_Domestic from "@salesforce/label/c.BREG_HelpText_ApplicantLocationType_Domestic";
import BREG_HelpText_ApplicantLocationType_Foreign from "@salesforce/label/c.BREG_HelpText_ApplicantLocationType_Foreign";


export default class Breg_ApplicantLocationType extends BaseFormComponent {
    applicantLocationTypeValue;

    get applicantLocationTypeOptions() {
        return [
            {
                label: "Person intending to organize or change name of a Domestic business entity",
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
                label: "Person intending to organize or change name of a Foreign business entity",
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

    get applicantLocationTypeLabel() {
        return `Location Type`;
    }

    get applicantLocationTypeValueReadOnly() {
        const option = this.applicantLocationTypeOptions.find(
            (opt) => opt.value === this.applicantLocationTypeValue
        );
        return `<b>${this.applicantLocationTypeLabel}</b>: <br> ${option ? option.label?.toUpperCase() : ""}<br>`;
    }

    handleInputChange(event) {

        const value = event.detail.value;

        const syntheticEvent = {
            target: {
                name: "applicantLocationType",
                value: value,
                dataset: { name: "applicantLocationType" }
            },
            preventDefault(){},
            stopPropagation(){}
        };

        // const name = originalEvent.target.name;
        // const value = originalEvent.target.value;

        // if (name === "applicantLocationType") {
        //     this.applicantLocationTypeValue = value;
        // }

        this.applicantLocationTypeValue = value;

        super.handleInputChange(syntheticEvent);
    }
}