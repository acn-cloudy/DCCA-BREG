import { LightningElement, api } from 'lwc';

export default class Breg_HelpTextTooltip extends LightningElement {

    @api label;
    @api title;
    @api message;

    isOpen = false;

    get hasTitle() {
        return !!this.title;
    }

    handleMouseEnter() {
        this.isOpen = true;
    }

    handleMouseLeave() {
        this.isOpen = false;
    }

    handleFocusIn() {
        this.isOpen = true;
    }

    handleFocusOut() {
        this.isOpen = false;
    }
}