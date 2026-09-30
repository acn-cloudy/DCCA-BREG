import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getContactSEBCases from '@salesforce/apex/SEBSearchController.getContactSEBCases';


export default class SebSearchResult extends NavigationMixin(LightningElement) {
    @api recordId;

    _data = [];
    tableColumns = [
        { label: 'Name', fieldName: 'Name'},
        { label: 'Case #', fieldName: 'Case', cellAttributes: { alignment: 'center' }},
        { label: 'Result', fieldName: 'Result', cellAttributes: { alignment: 'center' }},
        { 
            label: 'Closed Date', 
            fieldName: 'ClosedDate',
            type: 'date-local',
            typeAttributes: {
                month: '2-digit',
                day: '2-digit',
                year: 'numeric',
            },
            cellAttributes: { alignment: 'center' }
        },
        {
            type: 'action',
            label: 'Actions',
            typeAttributes: {
                rowActions: this.getRowActions
            }
        }
    ]

    @track isLoading = false;

    get data(){
        return this._data;
    } set data(val){
        this._data = val;
    }

    getRowActions(row, doneCallback) {
        const actions = [
            {
                label: 'View',
                name: 'view',
                disabled: !row.PublicURL__c
            }
        ];

        doneCallback(actions);
    }
    
    
    @wire(CurrentPageReference)
    handlePageRef({ state }) {
        if (!state) return;
        this.recordId = state.id || state.c__recordId;
    }

    connectedCallback(){
        this.doQuery();
    }

    async doQuery(){
        if(!this.recordId) return;
        this.data = [];
        this.isLoading = true;

        try{

            const _data = await getContactSEBCases({
                contactId: this.recordId
            });

            if(_data.length){
                let records = [];
                _data.forEach(datum => {
                    records.push({
                        Id: datum.Id,
                        Name: datum.Name,
                        Case: datum.SEBCase__r?.Name,                    
                        ClosedDate: datum.SEBCase__r?.ClosedDateTime__c,
                        Result: '',
                        PublicURL__c: datum.PublicURL__c
                    });
                });

                this.data = records;
            }
        } catch (e){
            console.log('ERROR FETCHING RECORDS');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'view':
                this.handleView(row);
                break;
            default:
        }
    }

    handleView(row) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: row.PublicURL__c
            }
        });
    }
}