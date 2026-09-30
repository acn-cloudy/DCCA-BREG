import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_CertificateOfGoodStanding extends BaseFormComponent {
    defaultTitle = "Certificate of Good Standing";

    get longText() {
        return this.config != null && this.config.labelOverrideLong != null;
    }
}