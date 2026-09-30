import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_DateIncorporated extends BaseFormComponent {
    defaultTitle = "Date Incorporated";
    dateIncorporatedValue;
    get readOnlyDateIncorporatedValue() {
        return `${this.dateIncorporatedValue.replace(/-/g, "/")}`;
    }
}