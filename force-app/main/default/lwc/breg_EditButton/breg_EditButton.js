import { LightningElement, api } from 'lwc';

export default class Breg_EditButton extends LightningElement {
    @api label = 'Edit';
    @api variant = 'brand';

    handleClick(event) {
        this.dispatchEvent(new CustomEvent('click', {
            detail: event,
            bubbles: true,
            composed: true
        }));
    }
}