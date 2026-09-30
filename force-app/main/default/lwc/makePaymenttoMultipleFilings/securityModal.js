import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class SecurityModal extends LightningModal {
    @api content;
    @api label;

    handleOkay() {
        this.close('okay');
    }
}