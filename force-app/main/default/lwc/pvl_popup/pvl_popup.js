import { LightningElement, api } from 'lwc';

export default class Pvl_popup extends LightningElement {
    @api defaultOpen;
    @api modalTitle;
    showModal;
    get modalHeadingId() {
        return `modal-heading-${this.uniqueId}`;
    }

    get uniqueId() {
        return Date.now();
    }
    @api
    openModal() {
        this.showModal = true;
    }
    @api
    closeModal() {
        this.showModal = false;
        this.dispatchEvent(new CustomEvent('close'));
    }
}