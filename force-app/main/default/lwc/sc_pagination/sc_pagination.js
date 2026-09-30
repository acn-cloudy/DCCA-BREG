import { LightningElement, api, track } from 'lwc';

export default class Sc_pagination extends LightningElement {
    @api currentPageNumber;
    @api maxPageNumber;
    @track pageNumber;

    connectedCallback(){
        this.pageNumber = this.currentPageNumber;
    }
    
    firstPage(){
        this.pageNumber = 1;
        this.captureChanges();
    }
    prevPage(){
        this.pageNumber = Math.max(this.pageNumber-1, 1);
        this.captureChanges();
    }
    nextPage(){
        this.pageNumber =  Math.min(this.pageNumber+1, this.maxPageNumber);
        this.captureChanges();
    }
    lastPage(){
        this.pageNumber = this.maxPageNumber;
        this.captureChanges();
    }
    captureChanges() {        
        const eventUpdate = new CustomEvent('updatecurrentpage', {
            detail: {pageNumber: this.pageNumber}
        });
        this.dispatchEvent(eventUpdate);        
    }
}