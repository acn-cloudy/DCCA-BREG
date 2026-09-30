import { track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_RadioGroup extends BaseFormComponent {
    radioGroupValue = [];
    multiSelect = false;
    @track radioGroupOptions = [];

    connectedCallback() {
        super.connectedCallback();
        this.initializeOptions();
        this.multiSelect = this.componentSettings?.multiSelect;
    }

    initializeOptions() {
        let options = [];
        try {
            if (!this.config?.labelOverrideLong) console.warn("labelOverrideLong is not defined");
            let jsonString = this.config.labelOverrideLong;
            // Replace HTML entities
            jsonString = jsonString
                .replace(/&quot;/g, '"')
                .replace(/&amp;/g, "&")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/&#39;/g, "'");

            console.log("Parsed JSON string for radio group options:", jsonString);
            const values = JSON.parse(jsonString);
            if (typeof values !== "object" || values === null) console.error("Parsed JSON is not a valid object:", values);

            for (const [value, label] of Object.entries(values)) {
                options.push({ label: label, value: value });
            }
            console.log("Radio group options:", JSON.stringify(options));
        } catch (error) {
            console.error("Error parsing labelOverrideLong JSON:", this.config?.labelOverrideLong, error);
        }
        this.radioGroupOptions = [...options];
    }

    processFormData() {
        super.processFormData();
        if (this.multiSelect && typeof this.radioGroupValue === "string") {
            this.radioGroupValue = this.radioGroupValue.split(";");
        }
    }

    get radioGroupValueReadOnly() {
        let result;
        if (this.multiSelect) {
            const selectedLabels = this.radioGroupOptions.filter((option) => this.radioGroupValue.includes(option.value)).map((option) => option.label);
            result = `${selectedLabels.join(", ")}`;
        } else {
            const option = this.radioGroupOptions.find((opt) => opt.value === this.radioGroupValue);
            result = `${option ? option.label : ""}`;
        }
        return result.toUpperCase();
    }
}