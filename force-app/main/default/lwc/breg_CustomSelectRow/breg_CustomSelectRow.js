import { LightningElement, api } from "lwc";

export default class Breg_CustomSelectRow extends LightningElement {
    @api disabledItem;
    @api checkedItem;
    @api rowId;
    @api recordId;

    handleCheckBoxSelected(event) {
        const customEvent = new CustomEvent("customselectrowclicked", {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                rowId: this.rowId,
                checked: event.target.checked,
                recordId: this.recordId
            }
        });
        this.dispatchEvent(customEvent);
    }
}