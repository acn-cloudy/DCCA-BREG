import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import FORM_FACTOR from '@salesforce/client/formFactor';
import searchSEBCaseContacts from '@salesforce/apex/SEBSearchController.searchSEBCaseContacts';
import getContactSEBCases from '@salesforce/apex/SEBSearchController.getContactSEBCases';
import UtililtyIcons from '@salesforce/resourceUrl/UtililtyIcons';

export default class SebSearch extends NavigationMixin(LightningElement) {
    searchKey = '';
    @track contacts = [];
    @track cases = [];

    isLoading = false;
    isSearching = false;
    hasSearched = false;

    pageNumber = 1;
    pageSize = 10;
    totalRecords = 0;

    contactColumns = [
        {
            label: 'Matching entity or individual with Pending or Prior Complaints or Cases (click on the name to view more details)',
            fieldName: 'Name',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'Name' },
                name: 'view_cases',
                variant: 'base'
            }
        }
    ];

    caseColumns = [
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
            fixedWidth: 100,
            typeAttributes: {
                rowActions: this.getRowActions
            }
        }
    ]  

    get showNoResults() {
        return this.hasSearched && !this.isSearching && this.contacts.length === 0;
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    get searchContainerClass() { return 'search-container' + (FORM_FACTOR === 'Small' ? ' search-container-mobile' : ''); }
    
    get isMobileDevice() { return FORM_FACTOR === 'Small'; }
    
    getRowActions(row, doneCallback) {
        const actions = [];
        
        if(row.Public__c){
            actions.push({
                label: 'View Enforcement Action Documents',
                name: 'view'
            });
        } else {
            actions.push({
                label: 'No Document available',
                name: 'no',
                disabled: true
            });
        }

        doneCallback(actions);
    }

    handleSearchTextChange(evt) {
        this.searchKey = evt.detail.value.trim();
        this.hasSearched = false;
        this.dispatchTermUpdate();
    }    
    
    dispatchTermUpdate() {
        this.dispatchEvent(new CustomEvent('termupdate', {
            detail: { term: this.searchKey }
        }));
    }

    handleInputChange(event) {
        this.searchKey = event.target.value;
        this.hasSearched = false;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearch();
        }
    }

    handleSearch() {      
        this.cases = [];

        if (!this.searchKey || this.searchKey.trim().length < 2) {
            this.contacts = [];
            return;
        }

        
        this.pageNumber = 1;  
        this.isSearching = true;
        this.isLoading = true;
        this.loadContacts();
    }

    handleNext() {
        this.pageNumber++;
        this.loadContacts();
    }

    handlePrevious() {
        this.pageNumber--;
        this.loadContacts();
    }

    loadContacts(){
        try{
            searchSEBCaseContacts({ 
                queryTerm: this.searchKey.trim(),
                pageSize: this.pageSize,
                pageNumber: this.pageNumber
            })
                .then(data => {
                    let _contacts = [];
                    if(data?.records){
                        data.records.forEach(element => {
                            _contacts.push(element);
                        });
                    }

                    this.contacts = _contacts;
                    this.totalRecords = data?.totalRecords || 0;
                    this.hasSearched = true;
                });
        } catch (error) {
            console.error(error);
        } finally {
            this.isSearching = false;
            this.isLoading = false;
        }
    }

    handleContactClick(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_cases') {
            getContactSEBCases({ contactId: row.Id })
                .then(data => {
                    let _cases = [];
                    if(data){
                        data.forEach(_case => {
                            _cases.push({
                                Id: _case.Id,
                                Name: _case.Name,
                                Case: _case.SEBCase__r?.SEBCaseNumber__c,
                                ClosedDate: _case.SEBCase__r?.ClosedDateTime__c,
                                Result: _case.CaseResult__c,
                                Public__c: _case.Public__c
                            });
                        });
                    }

                    this.cases = _cases; 
                })
                .catch(error => {
                    console.error(error);
                    this.cases = [];
                });
        }
    }

    handleRowAction(event) {
        const row = event.detail.row;
        const pageReference = {
            type: 'comm__namedPage',
            attributes: {
                name: 'SEB_Case_Documents__c'
            },
            state: {
                recordId: row.Id,
            }
        };

        // Generate the URL and open it in a new tab
        this[NavigationMixin.GenerateUrl](pageReference).then(url => {
            window.open(url, '_blank');
        });
    }
}