import { LightningElement, api } from 'lwc';

export default class RedirectToRecordButton extends LightningElement {

    @api recordId;
    @api objectApiName;
    @api buttonLabel = 'Open Record';

    handleClick() {

        if (!this.recordId) {
            return;
        }

        const url =
            '/lightning/r/' +
            this.objectApiName +
            '/' +
            this.recordId +
            '/view';

        window.open(url, '_top');
    }
}