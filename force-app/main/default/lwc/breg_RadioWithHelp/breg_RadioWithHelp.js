import { LightningElement, api } from 'lwc';

export default class Breg_RadioWithHelp extends LightningElement {

    @api name;
    @api required = false;
    @api disabled = false;
    @api checked = false;
    @api option;

    get optionId() {
        return this.option?.id ?? `${this.name}-${this.option?.value}`;
    }

    get action() {
        return this.option?.action;
    }

    get hasAction() {
        return !!this.action;
    }

    get isTooltip() {
        return this.action?.type === 'tooltip';
    }

    get isLink() {
        return this.action?.type === 'link';
    }

    get isModal() {
        return this.action?.type === 'modal';
    }

    handleChange(event) {
        const value = event.target.value;

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                bubbles: true,
                composed: true,
                detail: {
                    value: value
                }
            })
        );
    }
}