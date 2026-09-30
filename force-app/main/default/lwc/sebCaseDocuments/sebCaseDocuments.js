import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getCaseContactDocuments from '@salesforce/apex/SEBSearchController.getCaseContactDocuments';

export default class SebCaseDocuments extends NavigationMixin(LightningElement) {
    @api recordId;
    
    _data = [];
    tableColumns = [
        { 
            label:'Document Name', type: 'navigation', wrapText: true, typeAttributes: {
                label: { fieldName: 'Name' },
                recordId: { fieldName: 'Id'},
                pageRef: { fieldName: 'pageRef'}
            }
        },
        {
            label: 'Date',
            type: 'date-local',
            fieldName: 'CreatedDate',
            typeAttributes: {
                month: '2-digit',
                day: '2-digit',
                year: 'numeric',
            },
            cellAttributes: { alignment: 'center' }
        }
    ];

    get data(){
        return this._data;
    } set data(val){
        this._data = val;
    }

    @wire(CurrentPageReference)
    handlePageRef({ state }) {
        if (!state) return;
        this.recordId = state.id || state.recordId || state.c__recordId;
    }

    @wire(getCaseContactDocuments, {caseContactId: '$recordId'})
    getCaseDocuments({data, error}){
        console.log(data);
        console.log(error);
        if(data){
            let _data = [];
            data.forEach(datum => {
                _data.push({...datum, pageRef: {
                    type: 'standard__webPage',
                    attributes: {
                        url: datum.PublicURL__c ? datum.PublicURL__c.replace('Public/Document', 'Public/DownloadPdf') : null
                    }
                }});
            });

            this.data = _data;
        } else {
            console.log('ERROR');
            console.log(error);
        }
    }
}