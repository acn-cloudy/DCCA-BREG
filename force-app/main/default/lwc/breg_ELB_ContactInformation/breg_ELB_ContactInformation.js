import { LightningElement, api } from "lwc";

export default class Breg_ELB_ContactInformation extends LightningElement {
    @api searchInput; // Public property to receive input from parent
    showConfirmEmailError = false;
    nameOrCompany = "";
    email = "";
    confirmEmail = "";

    connectedCallback() {
        this.nameOrCompany = this.searchInput.nameOrCompany;
        this.email = this.searchInput.email;
        this.confirmEmail = this.searchInput.confirmEmail;
    }
    @api
    validate() {
        const inputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        if (this.email !== this.confirmEmail) {
            isValid = false;
        }
        return isValid;
    }
    handleInput(event) {
        const fieldName = event.target.name;

        if (this.email !== this.confirmEmail) {
            this.showConfirmEmailError = true;
        } else {
            this.showConfirmEmailError = false;
            // Proceed with success logic

            this.dispatchEvent(
                new CustomEvent("stepdata", {
                    detail: {
                        [fieldName]: event.target.value
                    }
                })
            );
        }
    }
}