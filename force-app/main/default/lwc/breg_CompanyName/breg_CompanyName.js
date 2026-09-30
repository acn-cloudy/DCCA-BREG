import BaseFormComponent from "c/breg_BaseFormComponent";
import validateName from "@salesforce/apex/BREGStartNewBusinessUtils.validateName";
import BREG_Fictitious_Name_Error from "@salesforce/label/c.BREG_Fictitious_Name_Error";
import { Labels } from "./labels";

export default class Breg_CompanyName extends BaseFormComponent {
    defaultTitle = "Company Name";
    companyNameValue;
    fictitiousNameValue;
    showModal = false;
    labels = Labels;

    nameRulesText = "";

    connectedCallback() {
        super.connectedCallback();
        this.loadNameRules();
    }

    loadNameRules() {
        validateName({ entityName: this.companyNameValue ?? "-INVALID-", formCode: this.formCode,  entityType: this.entityForValidation})
            .then((result) => {
                this.nameRulesText = result || "";
            })
            .catch((error) => {
                this.nameRulesText = "";
                console.error("*** nameRules load error:", JSON.stringify(error));
            });
    }

    get entityForValidation() {
        if (this.componentSettings?.validateByNewEntityType) {
            return this.formData["Case.breg_New_Entity_Type__c"];
        }

        return this.entityType;
    }

    get businessProcessNameReservation() {
        return this.businessProcess === "Name Reservation";
    }

    get includesFictitious() {
        return this.fictitiousNameValue !== null && this.fictitiousNameValue !== undefined;
    }

    get modalText() {
        return this.config.labelOverrideLong2;
    }

    get showPendingDocText() {
        return this.isNBRForm && this.readOnly;
    }

    get showNameRulesText(){
        return !!this.nameRulesText;
    }

    get showFictitiousName() {
        return this.targetFieldsMapping && "fictitiousName" in this.targetFieldsMapping;
    }

    processFormData() {
        super.processFormData();

        if (this.componentSettings?.validateByNewEntityType) {
            this.loadNameRules();
        }
    }

    handleModalContinue() {
        this.showModal = false;
    }

    handleModalCancel() {
        this.showModal = false;
    }

    handleLearnMoreClick(event) {
        event.preventDefault();
        this.showModal = true;
    }

    get showFileNumber() {
        return "fileNumber" in this.targetFieldsMapping;
    }

    handleInputBlur(event) {
        super.handleInputBlur(event);
        this.reportValidity();
    }

    processFormData() {
        super.processFormData();
        if (this.showFictitiousName && this.fictitiousNameValue) {
            this.reportValidity();
        }
    }

    reportValidity() {
        const companyNameInput = this.template.querySelector(".companyName");
        const fictitiousNameInput = this.template.querySelector(".fictitiousName");
        companyNameInput?.setCustomValidity("");
        fictitiousNameInput?.setCustomValidity("");

        const isDomestic = this.formData["Case.breg_Applicant_Location_Type__c"] === "Domestic";

        if (this.showFictitiousName && this.fictitiousNameValue && isDomestic) {
            fictitiousNameInput?.setCustomValidity(BREG_Fictitious_Name_Error);
        }

        const allValid = [...this.template.querySelectorAll("lightning-input")].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (this.companyNameValue) {
            validateName({ entityName: this.companyNameValue, formCode: this.formCode,  entityType: this.entityForValidation})
                .then((result) => {
                    if (result?.length) {
                        companyNameInput?.setCustomValidity(result);
                        companyNameInput.reportValidity();
                    }
                })
                .catch((error) => {
                    console.error("*** name validation error:", JSON.stringify(error));
                });
        }

        this.showErrorSpacer = !allValid;

        return allValid;
    }
}