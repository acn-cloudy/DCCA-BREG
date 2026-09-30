import { LightningElement, api } from 'lwc';
import getPicklist from "@salesforce/apex/FieldUtils.getPicklistValues";
export default class CustomSelectInput extends LightningElement {
    @api label;
    @api value;
    @api options;
    @api required;
    @api fieldName;
    @api objectName;
    @api reportValidity(){
        return this.template.querySelector("lightning-combobox").reportValidity();
    }
    @api checkValidity(){
        return this.template.querySelector("lightning-combobox").checkValidity();

    }
    handleUpdate(event) {
        console.log("event", event);
        const { fieldName } = this;
        let item = {};
        item[fieldName] = event.detail.value;
        const changeDataEvent = new CustomEvent('changedata', {detail: item});
        this.dispatchEvent(changeDataEvent);
    }

    connectedCallback() {
        this.getPicklistOptions();
    }
    async getPicklistOptions() {
        const {fieldName, objectName} = this;
        const options = await getPicklist({fieldName, objectName});
        this.options = JSON.parse(options);
        console.log("options", options);
    }
}