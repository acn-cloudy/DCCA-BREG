import { LightningElement } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class CallQuickEntry extends LightningElement {
    handleStatusChange(event) {
        const { status } = event.detail;
        
        // Close the modal when flow finishes or encounters an error
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}