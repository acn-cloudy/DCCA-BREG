import { wire } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { CurrentPageReference } from "lightning/navigation";
import { getPageParamsFromUrl, getStateParamsFromUrl } from "c/utils";

export default class Breg_RegistrationType extends BaseFormComponent {
    defaultTitle = "Registration Type";
    registrationTypeValue;
    certificateNumberValue;
    isRenewal = false;
    pageReference;

    dependentFieldsMapping = {
        registrationType: ["certificateNumber"]
    };

    registrationTypeOptions = [
        { label: "NEW", value: "New" },
        { label: "RENEWAL", value: "Renewal" }
    ];

    get showCertificateNumberField() {
        return this.registrationTypeValue === "Renewal";
    }

    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (pageRef) {
            this.pageReference = pageRef;
        }
    }

    connectedCallback() {
        super.connectedCallback();
        const { isRenewal } = getPageParamsFromUrl();
        const internalParams = getStateParamsFromUrl(this.pageReference);
        this.isRenewal = isRenewal === "true" || internalParams.isRenewal === "true";
        if (this.isRenewal) {
            this.alwaysReadOnly = true;
        }
        this.setDefaultValues();
    }

    processFormData() {
        super.processFormData();
        this.setDefaultValues();
    }

    setDefaultValues() {
        const registrationTypeFieldName = this.getFieldName("registrationType");
        if (registrationTypeFieldName && !this.formData[registrationTypeFieldName]) {
            this.registrationTypeValue = this.isRenewal ? "Renewal" : "New";
            this.dispatchCustomEvent("formupdate", this.getValueChangeData("registrationType", this.registrationTypeValue));
        }
    }
}