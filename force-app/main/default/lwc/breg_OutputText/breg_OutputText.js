import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_OutputText extends BaseFormComponent {
    connectedCallback() {
        super.connectedCallback();
        if (this.config?.labelOverrideLong) {
            this.title = this.config?.labelOverrideLong;
        }
        this.setShowSection();
    }

    setComponentProperties() {
        super.setComponentProperties();
        this.setShowSection();
    }

    setShowSection() {
        if (this.componentSettings?.showSectionByDefault === undefined) return;

        // Display text next to Signature component for GP-1 form when LLP and GP are registered together
        if (this.cmpProperties?.needToFillLLPForm !== undefined) {
            this.showSection = this.cmpProperties.needToFillLLPForm;
        }
    }
}