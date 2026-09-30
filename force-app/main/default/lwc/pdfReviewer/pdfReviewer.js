import { LightningElement, api } from 'lwc';

export default class PdfReviewer extends LightningElement {
    @api displayUrl;
    openModal() {
        this.template.querySelector('c-pvl_popup').openModal();
      }
    
}