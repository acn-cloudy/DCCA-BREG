import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_InputNumber extends BaseFormComponent {
    inputNumberValue;

    get readOnlyInputNumberValue() {
        return this.inputNumberValue ? this.inputNumberValue : 0;
    }

    get formatter() {
        return this.componentSettings?.formatter || "";
    }
    get step() {
        return this.componentSettings?.step || "1";
    }
}