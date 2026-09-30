import BaseFormComponent from "c/breg_BaseFormComponent";
export default class Breg_Dropdown extends BaseFormComponent {
    dropdownValue;
    get options() {
        let options = [];
        let values = this.config.labelOverrideLong.split("\n");
        values.forEach((value) => {
            options.push({ label: value.toUpperCase(), value: value });
        });
        return options;
    }

    get dropdownValueReadOnly() {
        const option = this.options.find((opt) => opt.value === this.dropdownValue);
        return option ? option.label.toUpperCase() : "";
    }
}