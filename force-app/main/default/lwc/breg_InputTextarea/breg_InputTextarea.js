import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_InputTextarea extends BaseFormComponent {
    inputTextareaValue;

    get readOnlyTextAreaValue() {
        if (this.config?.labelOverride2.includes("Nature of") || this.config?.labelOverride.includes("Nature of")) {

            const isNatureOfActivities =
                this.config?.labelOverride2?.toLowerCase().includes("nature of activities") ||
                this.config?.labelOverride?.toLowerCase().includes("nature of activities");

            const emptyNatureString = isNatureOfActivities
                ? this.natureOfActivitiesEmptyString
                : this.natureOfBusinessEmptyString;

            return this.inputTextareaValue
                ? this.inputTextareaValue.toUpperCase()
                : emptyNatureString.toUpperCase();

        } else {
            return this.inputTextareaValue ? this.inputTextareaValue.toUpperCase() : this.emptyInputString;
        }
    }

    // get variant() {
    //     return this.config.labelOverride2 ? "" : "label-hidden";
    // }
}