import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_FormedOn extends BaseFormComponent {
    inputDateValue;

    get inputDateLabel() {
        return this.config.labelOverrideLong2 || this.config.labelOverride2 || "Date";
    }

    get readOnlyInputDateValue() {
        return this.inputDateLabel === "Date" ? 
            (this.inputDateValue?.replace(/-/g, "/") ?? "") : 
            `${this.inputDateLabel?.toUpperCase() ?? ""} ${this.inputDateValue?.replace(/-/g, "/") ?? ""}`;
    }
}