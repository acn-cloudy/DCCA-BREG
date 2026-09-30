import { LightningElement, api } from "lwc";
import { Labels } from "./labels";

export default class Breg_MyCommunication extends LightningElement {
    labels = Labels;
    @api chosenCommunication;
    csvFormat = /^[a-zA-Z0-9]{15} - [A-Z][a-z]{2} \d{1,2}, \d{4}$/;

    get attachmentsExists() {
        return this.chosenCommunication.attachments.length > 0;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent("close"));
    }

    downloadAttach(event) {
        this.dispatchEvent(
            new CustomEvent("download", {
                detail: {
                    docusignDocumentId: event.target.dataset.id,
                    description: event.target.dataset.name,
                    fileType: this.csvFormat.test(event.target.dataset.name) ? "csv" : "pdf"
                }
            })
        );
    }
}