import { LightningElement, api } from "lwc";

export default class Breg_DatatableNameCell extends LightningElement {
    @api label;
    @api recordId;
    @api fileNumber;
    @api sourceObject;

    handleClick() {
        this.dispatchEvent(
            new CustomEvent("namecellopened", {
                composed: true,
                bubbles: true,
                cancelable: true,
                detail: {
                    recordId: this.recordId,
                    fileNumber: this.fileNumber,
                    sourceObject: this.sourceObject
                }
            })
        );
    }
}