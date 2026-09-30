import { LightningElement, wire } from "lwc";
import getMyCommunications from "@salesforce/apex/BREGMyDashboardController.getMyCommunications";
import BREG_Empty_Communications from "@salesforce/label/c.BREG_Empty_Communications";
export default class Breg_MyCommunications extends LightningElement {
    emptyCommunicationsLabel = BREG_Empty_Communications;
    communications = [];
    showCommunicationCard = false;
    chosenCommunication;
    get isCommunicationsExists() {
        return this.communications.length > 0;
    }

    get columns() {
        if (this.isCommunicationsExists) {
            return [
                { label: "Subject", fieldName: "subject", initialWidth: 650 },
                { label: "Sent date", fieldName: "createdDate" },
                { label: "Related Entity", fieldName: "associatedEntity" },
                {
                    type: "action",
                    typeAttributes: {
                        rowActions: [{ label: "View", name: "view" }]
                    }
                }
            ];
        }
    }

    handleAction(event) {
        const { action, row } = event.detail;
        if (action.name === "view") {
            this.chosenCommunication = row;
            this.showCommunicationCard = true;
        }
    }

    handleDownload(event) {
        this.dispatchEvent(
            new CustomEvent("downloaddocument", {
                detail: {
                    documents: [
                        {
                        docusignDocumentId: event.detail.docusignDocumentId,
                        description: event.detail.description,
                        fileType: event.detail.fileType
                        }
                    ]
                }
            })
        );
    }

    @wire(getMyCommunications)
    wiredCommunicationsWrappers({ error, data }) {
        if (data) {
            this.communications = data;
        } else if (error) {
            console.error("Error retrieving communications wrappers: ", error);
        }
    }

    handleCardClose() {
        this.showCommunicationCard = false;
    }
}