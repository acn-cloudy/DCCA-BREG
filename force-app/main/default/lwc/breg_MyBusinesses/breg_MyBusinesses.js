import { LightningElement, api, track } from 'lwc';
import { Labels } from "./labels";

export default class Breg_MyBusinesses extends LightningElement {
    @api data;
    @track columns;
    // Labels
    labels = Labels;

    connectedCallback() {
        this.setColumns();
    }

    // Set columns for the datatable
    setColumns() {
        this.columns = [
            {
                label: this.labels.NAME,
                type: "button",
                fieldName: "businessName",
                typeAttributes: {
                    label: { fieldName: "businessName" },
                    name: "openDetails",
                    variant: "base"
                },
                initialWidth: 450
            },
            {
                label: this.labels.RECORD_TYPE,
                fieldName: "recordType",
                type: "text"
            },
            {
                label: this.labels.FILE_NUMBER,
                fieldName: "fileNumber",
                type: "text"
            },
            { 
                label: this.labels.STATUS,
                fieldName: "status",
                type: "text"
            }
        ];
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case "openDetails":
                window.location.href = `/search-and-buy?entityId=${row.recordId}`;
                break;
            default:
                console.log("wrong action name");
        }
    }
}