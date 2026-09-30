import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_IsAmended extends BaseFormComponent {
    defaultTitle = 'Is Amended';
    isAmendedCheckboxLabel = 'Is Amended?';
    isAmendedValue;

    get showAmendedSection() {
        this.setDefaultValues();
        return this.cmpProperties?.isAmendedAnnualReport;
    }

    connectedCallback() {
        super.connectedCallback();
        this.setDefaultValues();
    }

    setDefaultValues() {
        const isAmendedFieldName = this.getFieldName('isAmended');

        if (this.isAmendedValue == undefined 
        && isAmendedFieldName
        && this.formData[isAmendedFieldName] == undefined
        && (this.cmpProperties?.isAmendedAnnualReport === true || this.cmpProperties?.isAmendedAnnualReport === 'true')) {
            this.isAmendedValue = true;
            this.dispatchCustomEvent('formupdate', this.getValueChangeData('isAmended', this.isAmendedValue));
        }
    }
}