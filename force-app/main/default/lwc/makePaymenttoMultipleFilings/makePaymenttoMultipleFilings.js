import { LightningElement, api, track } from 'lwc';
import Id from '@salesforce/user/Id';
import getUserTransactions from '@salesforce/apex/SecurityPortalTransactionsHelper.getUserTransactions';
import getUserAccountId from '@salesforce/apex/SecurityPortalTransactionsHelper.getUserAccountId';
import groupTransactions from '@salesforce/apex/SecurityPortalTransactionsHelper.groupTransactions';
import SecurityModal from './securityModal';

const columns = [
    { 
        label: 'Filing', 
        fieldName: 'Filing',
        sortable: true,
    },
    { 
        label: 'Type', 
        fieldName: 'ApplicationType__c', 
        sortable: true,
        cellAttributes: { 
            alignment: 'center' 
        } 
    },
    { 
        label: 'Filing Account', 
        fieldName: 'FilingAccount__c', 
        sortable: true,
    },
    { 
        label: 'Filed By', 
        fieldName: 'FiledBy__c', 
        sortable: true,
    },
    { 
        label: 'Created On', 
        fieldName: 'CreatedDate', 
        type: 'date', 
        sortable: true,
        typeAttributes:{
            day:'numeric',
            month:'numeric',
            year:'numeric',
            hour:'2-digit',
            minute:'2-digit',
            second:'2-digit',
            hour12:true
        }, 
        cellAttributes: { 
            alignment: 'center' 
        } 
    },
    { 
        label: 'Age', 
        fieldName: 'AgeDaysFormula__c', 
        type: 'integer', 
        sortable: true,
        cellAttributes: { 
            alignment: 'center' 
        } 
    },
    { 
        label: 'Transaction', 
        fieldName: 'Name', 
        sortable: true,
        cellAttributes: { 
            alignment: 'center' 
        } 
    },
    { 
        label: 'Amount Outstanding', 
        fieldName: 'AmountOutstanding__c', 
        type: 'currency',        
        sortable: true,
    },
    { 
        label: 'Transaction Total Amount', 
        fieldName: 'TotalAmount__c', 
        type: 'currency',
        sortable: true,
    },
];

export default class MakePaymenttoMultipleFilings extends LightningElement {
    // Component Properties
    @api paymentPageURL;

    // Local Variables
    columns = columns;
    showLoader = true;
    accId = null;

    @track data = [];
    @track sortedDirection  = 'asc';
    @track sortedBy = 'Filing';


    // Get data from Salesforce on Page Load
    connectedCallback(){
        // this.loadData();
        if(this.accId == null){
            getUserAccountId({userId: Id})
            .then(result => {     
                console.log("USER DATA LOADED");
                console.log(result);

                if(result){
                    this.accId = result;
                    this.loadData();
                } else {
                    this.showAlert("Error", "Failed to load Accout Details. \n\n If issue persists, contact your Administrator.");
                }
            })
            .catch(error => {
                console.log("ERROR");
                console.log(error);
                this.showAlert("Error", "Failed to load Accout Details. \n\n If issue persists, contact your Administrator.");
            })
            .finally(() => {
                this.showLoader = false;
            });
        } else {
            this.loadData();
        }
    }

    renderedCallback(){
        console.log(document.getElementsByClassName('slds-scrollable_y'));
    }
  
    showAlert(header = "", content){
        SecurityModal.open({
            size: 'small',
            label: header,
            description: 'Accessible description of modal\'s purpose',
            content: content,
        });
    }

    loadData(){
        this.showLoader = true;
        this.data = [];

        let sortBy = '';
        switch(this.sortedBy){
            case 'Filing':
                sortBy = 'Filing__r.Name';
                break;
            case 'ApplicationType__c':
                sortBy = 'Filing__r.ApplicationType__c';
                break;                
            case 'FilingAccount__c':
                sortBy = 'Filing__r.Account__r.Name';
                break;              
            case 'FiledBy__c':
                sortBy = 'Filing__r.CreatedBy.Name';
                break;
            case 'CreatedDate':
                sortBy = 'Filing__r.CreatedDate';
                break;
            case 'AgeDaysFormula__c':
                sortBy = 'Filing__r.AgeDaysFormula__c';
                break;
            default:
                sortBy = this.sortedBy
        }

        getUserTransactions({userId: Id, accId: this.accId, sortBy: sortBy, sortDir: this.sortedDirection })
        .then(result => {            
            var _data = [];

            console.log("DATA LOADED");
            console.log(result);

            // Format returned data for datatable
            if(result && result.length){
                result.forEach(function(item, index){
                    var _item = {
                        Id: item.Id,
                        Filing: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('Name') ? item.Filing__r.Name : null,
                        ApplicationType__c: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('ApplicationType__c') ? item.Filing__r.ApplicationType__c : null,
                        FilingAccount__c: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('Account__r') && item.Filing__r.Account__r.hasOwnProperty('Name') ? item.Filing__r.Account__r.Name : null,
                        FiledBy__c: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('CreatedBy') && item.Filing__r.CreatedBy.hasOwnProperty('Name') ? item.Filing__r.CreatedBy.Name : null,
                        CreatedDate: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('CreatedDate') ? item.Filing__r.CreatedDate : null,
                        AgeDaysFormula__c: item.hasOwnProperty('Filing__r') && item.Filing__r.hasOwnProperty('AgeDaysFormula__c') ? item.Filing__r.AgeDaysFormula__c : null,
                        Name: item.hasOwnProperty('Name') ? item.Name : null,
                        AmountOutstanding__c: item.hasOwnProperty('AmountOutstanding__c') ? item.AmountOutstanding__c : null,
                        TotalAmount__c: item.hasOwnProperty('TotalAmount__c') ? item.TotalAmount__c : null,
                    };
                    _data.push(_item);
                });
            }

            // Sort Data; for some reasons, SOQL doesn't sort correctly
            this.data = this.sortData(_data, this.sortedBy, this.sortedDirection);
        })
        .catch(error => {
            console.log("ERROR");
            console.log(error);
        })
        .finally(() => {
            this.showLoader = false;
        });
    }

    sortColumns(event){
        let field = event.detail.fieldName;
        let dir  = event.detail.sortDirection;
        this.sortedBy = field;
        this.sortedDirection = dir;
        this.loadData();
    }

    sortData(_data, fieldname, direction) {
        let parseData = _data;
        // Return the value stored in the field
        let keyValue = (a) => {
            return a[fieldname];
        };
        // cheking reverse direction
        let isReverse = direction === 'asc' ? 1: -1;
        // sorting data
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';
            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });
        
        return parseData;
    }    

    // Make Payment for Selected Transactions button click handler
    paySelectedTransactions(event){
        let selectedRecords =  this.template.querySelector("lightning-datatable").getSelectedRows();
        if(selectedRecords.length > 1) {
            console.log('selectedRecords are ', selectedRecords);

            let ids = [];
            let total = 0;
            selectedRecords.forEach(currentItem => {
                ids.push(currentItem.Id);
                total += parseFloat(currentItem.TotalAmount__c);
            });
            
            return this.createGroupTransactions(ids, total);
        } else {
            this.showAlert("Error", "You must select more than one Transaction to complete a Group Transaction.");
        }  
    }

    // Submit Selected Transactions to API for Group Transactions creation
    createGroupTransactions(ids, total){
        this.showLoader = true;
        groupTransactions({transactionIDs: ids, accId: this.accId, totalAmount: total})
        .then(result => {        
            console.log(result);    
            console.log("SAVED");

            this.showLoader = false;
            if(result && result.hasOwnProperty('Id')){
                let paymentURL = this.paymentPageURL + '?pid=' + result.Id;
                let newWin = window.open(paymentURL, '_blank');

                // If popup window is blocked
                if(!newWin || newWin.closed || typeof newWin.closed=='undefined') 
                { 
                    window.location.href = paymentURL;
                }
            } else {
                this.showAlert("Error", "An error was encountered while processing Group Payment. \n\n Contact your Administrator if issue persists.");
            }
        })
        .catch(error => {
            console.log("ERROR");
            console.log(error);            
            this.showLoader = false;
            this.showAlert("Error", "An error was encountered while processing Group Payment. \n\n Contact your Administrator if issue persists.");
        });
    }
}