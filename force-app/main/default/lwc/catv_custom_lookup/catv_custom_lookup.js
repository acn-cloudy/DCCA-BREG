import { LightningElement, api } from 'lwc';
import fetchRecords from '@salesforce/apex/CATV_CustomLookUpController.fetchRecords';
/** The delay used when debouncing event handlers before invoking Apex. */
const DELAY = 500;
const UP_ARROW_KEY_CODE = 38;
const DOWN_ARROW_KEY_CODE = 40;
const ENTER_KEY_CODE = 13;
const ESCAPE_KEY_CODE = 27;
export default class Catv_custom_lookup extends LightningElement {
    @api helpText = "custom search lookup";
    @api label = "Parent Account";
    @api required;
    @api placeholder;
    @api selectedIconName = "standard:account";
    @api objectLabel = "Account";
    recordsList = [];
    selectedRecordName;
    @api objectApiName = "Account";
    @api fieldApiName = "Name";
    @api otherFieldApiName = "Type";
    @api searchString = "";
    @api selectedRecordId = "";
    @api parentRecordId;
    @api parentFieldApiName;
    @api selectedOrg;
    recordsFoundMsg;

    @api
    removeSelectedAccount() {
        this.selectedRecordId = null;
        this.selectedRecordName = null;
        this.recordsList = [];
    }

    @api handleSearchFocus(){
        setTimeout(() => {
            let searchField = this.template.querySelector('.searchField');
            if (searchField) {
                searchField?.focus();
            }
        }, 500);
    }

    get methodInput() {
        return {
            objectApiName: this.objectApiName,
            fieldApiName: this.fieldApiName,
            otherFieldApiName: this.otherFieldApiName,
            searchString: this.searchString,
            selectedRecordId: this.selectedRecordId,
            parentRecordId: this.parentRecordId,
            parentFieldApiName: this.parentFieldApiName,
            selectedOrg: this.selectedOrg
        };
    }

    get showRecentRecords() {
        if (!this.recordsList) {
            return false;
        }
        return this.recordsList.length > 0;
    }

    //getting the default selected record
    connectedCallback() {
        if (this.selectedRecordId) {
            this.fetchSobjectRecords(true);
        }
    }

    //call the apex method
    fetchSobjectRecords(loadEvent) {
        fetchRecords({
            inputWrapper: this.methodInput
        }).then(result => {
            if (loadEvent && result) {
                this.selectedRecordName = result[0].mainField;
            } else if (result) {
                this.recordsList = JSON.parse(JSON.stringify(result));
                this.announceNumOfRecsFound(this.recordsList);
            } else {
                this.recordsList = [];
            }
        }).catch(error => {
            console.log(error);
        })
    }

    get isValueSelected() {
        return this.selectedRecordId;
    }

    //handler for calling apex when user change the value in lookup
    handleChange(event) {
        this.searchString = event.target.value;
        this.fetchSobjectRecords(false);
    }

    //handler for deselection of the selected item
    handleCommit() {
        this.selectedRecordId = "";
        this.selectedRecordName = "";
        // Creates the event
        const removedEvent = new CustomEvent('valueremoved', {
            detail: this.selectedRecordId
        });
        //dispatching the custom event
        this.dispatchEvent(removedEvent);
    }

    //handler for selection of records from lookup result list
    handleSelect(event) {
        let selectedRecord = {
            mainField: event.currentTarget.dataset.mainfield,
            subField: event.currentTarget.dataset.subfield,
            id: event.currentTarget.dataset.id
        };
        this.selectedRecordId = selectedRecord.id;
        this.selectedRecordName = selectedRecord.mainField;
        this.recordsList = [];

        // Creates the event
        const selectedEvent = new CustomEvent('valueselected', {
            detail: this.selectedRecordId
        });
        //dispatching the custom event
        this.dispatchEvent(selectedEvent);
    }

    announceNumOfRecsFound(recordList) {
        if (!Array.isArray(recordList)) return;
    
        let recordLen = recordList.length;
        this.recordsFoundMsg = recordLen === 1 
            ? `${recordLen} record found.` 
            : `${recordLen} records found.`;
            setTimeout( () => {
                this.template.querySelector('.results-found')?.focus();
            }, 2000 );
            setTimeout( () => {
                this.handleSearchFocus();
            }, 3000 );
    }

    onKeyDown(event) {
        const items = this.template.querySelectorAll('.searchresults div[tabindex="0"]');
        const index = Array.from(items).indexOf(event.target);
    
        switch (event.keyCode) {
            case DOWN_ARROW_KEY_CODE:
                event.preventDefault();
                if (index < items.length - 1) {
                    items[index + 1].focus();
                }
                break;
    
            case UP_ARROW_KEY_CODE:
                event.preventDefault();
                if (index === 0) {
                    const input = this.template.querySelector('.searchField');
                    input?.focus();
                } else if (index > 0) {
                    items[index - 1].focus();
                }
                break;
    
            case ENTER_KEY_CODE:
                this.handleSelect(event);
                break;
    
            case ESCAPE_KEY_CODE:
                this.recordsList = [];
                break;
        }
    }

    handleInputKeydown(event) {
        if (event.key === 'ArrowDown' || event.keyCode === DOWN_ARROW_KEY_CODE) {
            event.preventDefault();
    
            // Focus the first result item
            const firstResult = this.template.querySelector('.searchresults div[tabindex="0"]');
            if (firstResult) {
                firstResult.focus();
            }
        }
    }
    
}