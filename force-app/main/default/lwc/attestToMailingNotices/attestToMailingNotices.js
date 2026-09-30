import {LightningElement, track} from 'lwc';
import getNotifications from '@salesforce/apex/AttestToMailingNoticesController.getNotifications';
import executeBatch from '@salesforce/apex/AttestToMailingNoticesController.executeBatch';

export default class AttestToMailingNotices extends LightningElement {
    @track notifications;
    @track isLoading = false;
    @track columns;
    @track submittedTableColumns;
    @track selectedRows;
    @track isSubmitted = false;
    @track showSpinner = false;

    get isSubmitDisabled() {
        return !this.selectedRows || this.selectedRows.length <= 0;
    }

    connectedCallback() {
        this.columns = [
            {
                label: 'Date Sent to Printer',
                type: 'date-local',
                fieldName: 'timeDelivered',
                hideDefaultActions: true,
                typeAttributes: {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit'
                },
                cellAttributes: {alignment: 'left'}
            },
            {
                label: 'Number of Notices Sent',
                type: 'number',
                fieldName: 'count',
                hideDefaultActions: true,
                cellAttributes: {alignment: 'left'}
            }
        ];

        this.submittedTableColumns = [];
        this.submittedTableColumns.push(...this.columns);
        this.submittedTableColumns.push(
            {
                label: 'Mailed Date / Time',
                type: 'date',
                fieldName: 'mailedDateTime',
                editable: true,
                hideDefaultActions: true,
                cellAttributes: {alignment: 'left'},
                typeAttributes: {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit',
                    hour: '2-digit',
                    minute: '2-digit'
                }
            }
        );

        this.submittedTableColumns.push(
            {
                label: 'Mailed By',
                type: 'text',
                fieldName: 'mailedBy',
                hideDefaultActions: true,
                cellAttributes: {alignment: 'left'}
            }
        );

        this.isLoading = true;
        getNotifications().then(result => {
            this.notifications = result;
        }).catch(error => {

        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleCancelClicked() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleSubmit() {
        this.isSubmitted = true;
    }

    handleRowSelect(event) {
        this.selectedRows = [];
        this.selectedRows = event.detail.selectedRows;
    }

    handleConfirm(event) {
        this.showSpinner = true;
        setTimeout(() => {
            const dt = this.template.querySelector('[data-id="forConfirmation"]');
            const drafts = dt.draftValues || [];
            const selectedRows = this.selectedRows
            executeBatch({selectedRows, drafts});

            this.dispatchEvent(new CustomEvent('confirm'));
            this.showSpinner = false;
        }, 1000);
    }
}