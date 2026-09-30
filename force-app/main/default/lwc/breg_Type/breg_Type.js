import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Type extends BaseFormComponent {
    defaultTitle = "Type";

    typeOptions = [
        { label: "Domestic", value: "Domestic" },
        { label: "Foreign", value: "Foreign" }
    ];

    typeValue;

    connectedCallback() {
        super.connectedCallback();
        this.typeValue = this.businessLocation;
        console.log("** typeValue", this.typeValue);
    }
}