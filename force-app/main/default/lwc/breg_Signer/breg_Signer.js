import { api } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Signer extends BaseFormComponent {
    @api member;
    @api titleOptions;
    signerSignedByFirstNameValue;
    signerSignedByLastNameValue;
    signerSignedByTitleSelectorValue;
    signerSignedByTitleTextValue;
    signerSignatureValue;

    get label() {
        return this.member?.memberName;
    }

    get showSignerSignedByTitleSelector() {
        return (
            "signerSignedByTitleSelector" in this.targetFieldsMapping &&
            this.member?.memberType === "Entity" &&
            this.member["breg_Account_Affiliation__c.breg_Officer_Director_Titles_Formula__c"]
        );
    }

    get showSignerSignedByTitleText() {
        return "signerSignedByTitleText" in this.targetFieldsMapping && this.member?.memberType === "Entity" && !this.showSignerSignedByTitleSelector;
    }

    get showSignerSignedByName() {
        return "signerSignedByFirstName" in this.targetFieldsMapping && this.member?.memberType === "Entity";
    }

    connectedCallback() {
        super.connectedCallback();
        this.processFormData();
    }

    handleInputChange(event) {
        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag === "lightning-input" || inputTag === "lightning-textarea") return;

        const inputName = event.target.dataset.name || event.target.name;
        const value = this.getValueFromEvent(event);
        const field = this.getFieldName(inputName);
        let member = { ...this.member };
        member[field] = value;
        member[inputName] = value;
        this[`${inputName}Value`] = value;
        this.resetDependentFieldsValue(inputName, member);
        this.dispatchCustomEvent("change", { member });
    }

    handleInputBlur(event) {
        if (this.readOnly) return;
        try {
            const inputTag = event?.target?.tagName?.toLowerCase();
            const inputName = event?.target?.name;
            const field = this.getFieldName(inputName);
            let value = this.getValueFromEvent(event);
            console.log("** handleBlur Signer cmp:", inputTag, inputName, value, typeof value);
            if (value && typeof value === "string") {
                value = value.toUpperCase();
                let member = { ...this.member };
                member[field] = value;
                member[inputName] = value;
                this[`${inputName}Value`] = value;
                this.resetDependentFieldsValue(inputName, member);
                this.dispatchCustomEvent("change", { member });
            }
        } catch (error) {
            console.error("** Member handleInputBlur error:", error);
        }
    }

    processFormData() {
        super.processFormData(this.member);
    }
}