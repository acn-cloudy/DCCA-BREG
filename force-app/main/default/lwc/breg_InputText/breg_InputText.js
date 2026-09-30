import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_InputText extends BaseFormComponent {
    inputTextValue;
    get readOnlyTextValue() {
        return this.inputTextValue ? this.inputTextValue.toUpperCase() : this.emptyInputString;
    }
}