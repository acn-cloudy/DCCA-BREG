import { LightningElement, api } from 'lwc';

export default class EditPdfButton extends LightningElement {
    @api recordId;

    get editPdfUrl() {
       return `pdfedit://edit?documentId=${this.recordId}`;
    }
}