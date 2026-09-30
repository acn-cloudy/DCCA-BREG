import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_OptionalProvisions extends BaseFormComponent {
    defaultTitle = "Optional Provisions";

    get longText() {
        return this.config != null && this.config.labelOverrideLong != null;
    }

    get longText2() {
        return this.config != null && this.config.labelOverrideLong2 != null;
    }
}