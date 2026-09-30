import { LightningElement, api } from 'lwc';

export default class Breg_RadioGroupWithHelp extends LightningElement {

    @api name;
    @api label;
    @api value;
    @api options = [];
    @api variant = "label-stacked";
    @api required = false;
    @api disabled = false;

    get isLabelHidden() {
        return this.variant === "label-hidden";
    }

    get computedOptions() {
        return this.options.map((opt) => {
            return {
                ...opt,
                id: `${this.name}-${opt.value}`,
                checked: this.value === opt.value
            };
        });
    }

    handleChange(event) {
        const value = event.detail?.value ?? event.target.value;

        this.dispatchEvent(
            new CustomEvent("change", {
                bubbles: true,
                composed: true,
                detail: {
                    value: value
                }
            })
        );
    }
}