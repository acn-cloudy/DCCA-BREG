import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_TNTMSMDescription extends BaseFormComponent {
    defaultTitle = "Trademark Description";

    TNTMSMWithSymbolValue = "Yes";
    TNTMSMDescriptionValue;

    yesNoOptions = [
        { label: "Yes", value: "Yes" },
        { label: "No", value: "No" }
    ];

    get showSymbolUpload() {
        return this.TNTMSMWithSymbolValue === "Yes";
    }

    get TNTMSMDescriptionValueReadOnly() {
        return `${this.config.labelOverride2}: <b>${this.TNTMSMDescriptionValue.toUpperCase()}</b>`;
    }

    get TNTMSMWithSymbolValueReadOnly() {
        return `${this.config.labelOverrideLong} <b>${this.TNTMSMWithSymbolValue.toUpperCase()}</b>`;
    }

    get showSpecimenDescription() {
        return this.componentSettings?.specimenDescription || false;
    }

    // Attachment Descriptions
    get symbolDescription() {
        let desc = this.config?.labelOverrideLong2;
        if (this.componentSettings?.symbolDescriptionReadOnly && this.readOnly) {
            desc = this.componentSettings?.symbolDescriptionReadOnly;
        }
        return desc;
    }
    get symbolDescription2() {
        return this.componentSettings?.symbolDescription2;
    }

    get specimenDescription() {
        let desc = this.componentSettings?.specimenDescription;
        if (this.componentSettings?.specimenDescriptionReadOnly && this.readOnly) {
            desc = this.componentSettings?.specimenDescriptionReadOnly;
        }
        return desc;
    }
    get specimenDescription2() {
        return this.componentSettings?.specimenDescription2;
    }

    handleInputChange(event) {
        super.handleInputChange(event);
        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag === "lightning-input" || inputTag === "lightning-textarea") return;
        const inputName = event.target.name;
        const value = event.target.value;
        if (inputName === "TNTMSMWithSymbol") {
            this.dispatchCustomEvent("change", this.getValueChangeData(inputName, value === "Yes"));
        }
    }

    processFormData() {
        super.processFormData();
        const withSymbolField = this.targetFieldsMapping?.TNTMSMWithSymbol;
        if (withSymbolField) {
            const withSymbolValue = this.formData[withSymbolField];
            if (withSymbolValue === true) {
                this.TNTMSMWithSymbolValue = "Yes";
            } else if (withSymbolValue === false) {
                this.TNTMSMWithSymbolValue = "No";
            }
        }
    }
}