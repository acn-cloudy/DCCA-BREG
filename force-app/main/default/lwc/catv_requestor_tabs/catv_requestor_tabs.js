/**
 * @description       : 
 * @author            : Gaurav Agarwal
 * @group             : ISCO
 * @last modified on  : 02-06-2026
 * @last modified by  : Marichris Roy
**/
import { LightningElement, track, wire, api} from 'lwc';
import { focusFirstEle } from "c/mdsUtility";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import INET_REQUEST from '@salesforce/schema/INET_Request__c';
import LightningConfirm from 'lightning/confirm';
import fetchINETRequestData from '@salesforce/apex/CATV_DashboardController.fetchINETRequestData';
import fetchQuoteData from '@salesforce/apex/CATV_DashboardController.fetchQuoteData';
import getRejectionReasons from '@salesforce/apex/CATV_DashboardController.getRejectionReasons';
import updateRequestStatus from '@salesforce/apex/CATV_DashboardController.updateRequestStatus';
import updateQuote from '@salesforce/apex/CATV_DashboardController.updateQuote';
import fetchPurchaseData from '@salesforce/apex/CATV_DashboardController.fetchPurchaseData';
import fetchInvoiceData from '@salesforce/apex/CATV_DashboardController.fetchInvoiceData';
import changeOwnerToQueue from '@salesforce/apex/CATV_DashboardController.changeOwnerToQueue';
import getAccounts from '@salesforce/apex/CATV_DashboardController.getAccounts';
import uploadFile from '@salesforce/apex/CATV_DashboardController.uploadFile';
import getFileContent from '@salesforce/apex/CATV_DashboardController.getFileContent';
import MDS_Style from '@salesforce/resourceUrl/MDS_Style'; 
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

export default class Catv_requestor_tabs extends LightningElement {
    picture = MDS_Style + '/media/images/no-data-found.svg';
    @api requestor;
    @api requestorContact;
    @track recordTypeId;
    @track inetRequestList;
    @track inetRequestDraftList = [];
    @track inetRequestSubmittedList = [];
    @track inetRequestAssignedBackList = [];
    @track inetRequestActiveList =[];
    @track inetRequestClosedList= [];
    @track draftCount = 0; 
    @track submittedCount = 0; 
    @track assignedBackCount = 0; 
    @track activeCount = 0; 
    @track closedCount = 0; 
    @track showSpinner = false;
    @track firstLoading = true;
    @track feedbackModal = false;
    @track feedbackText;
    @track documentList = [];
    @track currentTab = 'active';
    @track inetRequestListBackup = [];
    @track searchValue = '';
    requestobjectName = 'INET_Request__c';
    
    // --Quote Properties--
    quoteObjectName = 'Quotes__c';
    quoteRecord = '';
    viewQuoteModal = false;
    showQuoteAcceptedDate = false;
    showAcceptRejectButton = false;
    @track isDenied = false; 
    @track rejectionReason = ''; 
    @track rejectionOptions = []; 

    purchaseOrderObjectName = 'Purchase_Order__c';
    invoiceObjectName = 'Invoice__c';
    inetRequestRecordId = '';
    todaysDate;
    requestStatus = '';
    newRequestModal = false;
    newPurchaseModal = false;
    viewRequestModal = false;
    exitRequestModal = false;
    viewPurchaseOrderModal = false;
    showSaveDraftButton = true;
    viewInvoiceModal = false;
    showSearchRecords = false;
    purchaseOrderRecord = '';
    invoiceRecords = '';
    providerAccount;
    showWorkCompletedDate = false;
    showProviderContactName = false;
    showUpdateProgressDetails = false;
    @track invoiceColumns = [];
    triggerButton;
    fileData;
    fileUrl;
    @track screenReaderMessage = '';
    @track showMessage = false;
    @track providerOptions = [];
    @track providerValue;


    @wire(getObjectInfo, { objectApiName: INET_REQUEST })
    handleObjectInfo({ error, data }) {
        if (data) {
            const rtis = data.recordTypeInfos;
            this.recordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'INET Request');
        }
    }

    connectedCallback() {
        // Adding event listener for keydown event
        //this.template.addEventListener('keydown', (event) => this.handleKeydown(event));
        this.showSpinner = true;

        //Todays date logic
        var today = new Date();
        const hawaiiOffset = -10;
        const hawaiiTime = new Date(today.getTime() + (hawaiiOffset * 60 + today.getTimezoneOffset()) * 60000);
        var dd = String(hawaiiTime.getDate()).padStart(2, '0');
        var mm = String(hawaiiTime.getMonth() + 1).padStart(2, '0');
        var yyyy = hawaiiTime.getFullYear();
        this.todaysDate = yyyy + '-' + mm + '-' + dd;

        getAccounts()
            .then(result => {
                this.providerOptions = result.map(acc => ({
                    label: acc.Name,
                    value: acc.Id
                }));
            })
            .catch(error => {
                console.error('Error loading accounts', error);
            });

        this.fetchINETRequestdetails();
        
    }


    handleProviderChange(event) {
        this.providerValue = event.detail.value;
    }
   
    //This method is used to fetch the INET Request.
    fetchINETRequestdetails(){
        fetchINETRequestData({
            account: this.requestor
        }).then(result => {
            if (result) {
                this.inetRequestList = result;
                this.inetRequestList.forEach(item => {
                    item.viewDetailsButtonAriaLabel = 'View Details Button '+ item.IROC_Id__c;
                    item.viewRequestButtonAriaLabel = 'View Request Button '+ item.IROC_Id__c;
                    item.resumeButtonAriaLabel = 'Resume Button '+ item.IROC_Id__c;
                    item.viewFeedbackButtonAriaLabel = 'View Feedback Button '+ item.IROC_Id__c;
                    item.submitUpdatesButtonAriaLabel = 'Submit Updates Button '+ item.IROC_Id__c;
                    item.viewQuoteButtonAriaLabel = 'View Quote Button '+ item.IROC_Id__c;
                    item.createPurchaseOrderButtonAriaLabel = 'Create Purchase Order Button '+ item.IROC_Id__c;
                    item.viewPurchaseOrderButtonAriaLabel = 'View Purchase Order Button '+ item.IROC_Id__c;
                    item.viewInvoicesButtonAriaLabel = 'View Invoice(s) Button '+ item.IROC_Id__c;
                    item.connectedToINETButtonAriaLabel = 'Connected to INET Button '+ item.IROC_Id__c;
                    if (item.Status__c == 'Draft') {
                        item.showResumeButton = true;
                        this.inetRequestDraftList.push(item);
                        this.draftCount = this.inetRequestDraftList.length > 0 ? this.inetRequestDraftList.length : 0;
                    }
                    if (item.Status__c == 'Submitted' || item.Status__c == 'Resubmitted') {
                        item.showViewDetails = true;
                        this.inetRequestSubmittedList.push(item);
                        this.submittedCount = this.inetRequestSubmittedList.length > 0 ? this.inetRequestSubmittedList.length : 0;
                    }
                    if (item.Status__c == 'Assigned Back') {
                        item.showAssignBackButton = true;
                        this.inetRequestAssignedBackList.push(item);
                        this.assignedBackCount = this.inetRequestAssignedBackList.length > 0 ? this.inetRequestAssignedBackList.length : 0;
                    }
                    if (item.Status__c == 'CATV Review' || item.Status__c == 'Quote' || item.Status__c == 'PO Created' || item.Status__c == 'Work Initiated' || item.Status__c == 'Work Completed' || item.Status__c == 'Invoice Created' || item.Status__c == 'Invoice Paid' || item.Status__c == 'Connected to INET') {
                        item.showViewDetails = true;
                        if (item.Status__c == 'PO Created' || (item.Status__c == 'Quote' && (item.Quote_Subtype__c == 'Quote Sent' || item.Quote_Subtype__c == 'Quote Accepted' || item.Quote_Subtype__c == 'Quote Rejected'))) {
                            item.showViewQuoteDetails = true;
                        }
                        if (item.Status__c == 'Quote' && (item.Quote_Subtype__c == 'Quote Accepted')) {
                            item.showCreatePurchaseOrderButton = true;
                        } else if (item.Status__c == 'PO Created') {
                            item.showViePurchaseOrderDetails = true;
                        } else if (item.Status__c == 'Work Initiated') {
                            item.showViewQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                        } else if (item.Status__c == 'Work Completed') {
                            item.showViewQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                        } else if (item.Status__c == 'Invoice Created') {
                            item.showViewQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showViewInvoiceDetails = true;
                        } else if (item.Status__c == 'Invoice Paid') {
                            item.showViewQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showViewInvoiceDetails = true;
                            item.showConnectedToINETButton = true;
                        } else if (item.Status__c == 'Connected to INET') {
                            item.showViewQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showViewInvoiceDetails = true;
                        }
                        this.inetRequestActiveList.push(item);
                        this.activeCount = this.inetRequestActiveList.length > 0 ? this.inetRequestActiveList.length : 0;
                    }
                    if (item.Status__c == 'Completed') {
                        item.showViewDetails = true;
                        this.inetRequestClosedList.push(item);
                        item.showViePurchaseOrderDetails = true;
                        item.showViewQuoteDetails = true;
                        item.showViewInvoiceDetails = true;
                        this.closedCount = this.inetRequestClosedList.length > 0 ? this.inetRequestClosedList.length : 0;
                    }
                });

                this.inetRequestListBackup = JSON.parse(JSON.stringify(this.inetRequestList));
            }
            this.showSpinner = false;
            this.firstLoading = false;
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
            this.firstLoading = false;
        })
    }

    //It handles the New Request button Which open the modal to create new inet request.
    handleNewRequest() {
        this.showSpinner = true;
        this.showSaveDraftButton = true;
        this.inetRequestRecordId = '';
        this.newRequestModal = true;
        this.providerAccount = '';
        setTimeout(() => {
            this.showSpinner = false;
        }, 2500);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }
    
    //handle Resume the inet Request form 
    handleResumeRequest(event){
        this.feedbackModal = false;
        this.inetRequestRecordId = event.target.dataset.id;
        let selectedRecord = this.inetRequestAssignedBackList.find(data => data.Id === this.inetRequestRecordId);
        this.providerValue = selectedRecord.Provider__c;
        this.triggerButton = event.currentTarget;
        if(event.target.dataset.flowtype == 'feedback'){
            this.requestStatus = 'Resubmitted';
            this.showSaveDraftButton = false;
        }else{
            this.requestStatus = 'Submitted';
        }
        this.showSpinner = true;
        this.newRequestModal = true;
        setTimeout(() => {
            this.showSpinner = false;
        }, 2000);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    //It handles the Create Purchase Order Which open the modal to create new purchase order.
    handlePurchaseOrder(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.newPurchaseModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    //Exit the new request which open the confirmation modal.
    async handleRequestExit() {
        const result = await LightningConfirm.open({
            label: 'Are you sure?',
            message: 'Are you sure you want to exit this form? Your progress will not be saved.',
            theme: 'warning'
        });
        // Confirm modal has been closed, user clicked either 'OK' or 'Cancel'.If user clicked 'Cancel' promise returns false
        if (result) {
            this.newRequestModal = false;
        }
    }

    //handle View Feedback of inet Request
    handleViewFeedback(event){
        this.feedbackText = event.target.dataset.message;
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.feedbackModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    //handle View Request button functionality
    handleViewRequest(event){
        this.showSpinner = true;
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        let selectedRecord;
        if(this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId)){
            selectedRecord = this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId);
        }else{
            selectedRecord = this.inetRequestClosedList.find(data => data.Id === this.inetRequestRecordId);
        }
        if(selectedRecord?.Permit_Status__c != null || selectedRecord?.Projected_Deployment_Date__c != null || 
            selectedRecord?.Scheduled_Deployment_Date__c != null || selectedRecord?.Deployment_Start_Date__c != null){
            this.showUpdateProgressDetails = true;
        }
        if(selectedRecord?.Status__c == 'Work Completed' || selectedRecord?.Status__c == 'Invoice Created' || selectedRecord?.Status__c == 'Invoice Paid' || selectedRecord?.Status__c == 'Connected to INET' ||  selectedRecord?.Status__c == 'Completed'){
            this.showWorkCompletedDate = true;
        }
        if(selectedRecord?.Provider_Contact_Name__c != null && selectedRecord?.Provider_Contact_Name__c != undefined){
            this.showProviderContactName = true;
        }
        this.viewRequestModal = true;
        setTimeout(() => {
            this.showSpinner = false;
        }, 2000);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async handleViewPurchaseOrder(event){
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        let purchasedata  = await this.fetchPurchaseOrderDetails(this.inetRequestRecordId);
        this.purchaseOrderRecord = purchasedata[0];
        this.viewPurchaseOrderModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async handleViewInvoice(event){
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        let selectedRecord = this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId);
         if(selectedRecord?.Status__c == 'Invoice Created'){
            this.invoiceColumns = [
                { label: 'Invoice Number', fieldName: 'Name', sortable: true },
                { label: 'Invoice Date', fieldName: 'Invoice_Date__c', sortable: true },
                { label: 'Invoice Amount', fieldName: 'Invoice_Amount__c', type: 'currency', sortable: true },
                { label: 'Status', fieldName: 'Status__c', sortable: true },
                {
                    type: "button", label: 'Invoice', typeAttributes: {
                        label: 'Preview',
                        name: 'Preview',
                        title: 'Preview',
                        disabled: false,
                        value: 'Preview',
                        variant:'Brand'
                    }
                }
            ]; 
        }else{
            this.invoiceColumns = [
                { label: 'Invoice Number', fieldName: 'Name', sortable: true },
                { label: 'Invoice Date', fieldName: 'Invoice_Date__c', sortable: true },
                { label: 'Invoice Amount', fieldName: 'Invoice_Amount__c', type: 'currency', sortable: true },
                { label: 'Status', fieldName: 'Status__c', sortable: true },
                { label: 'Invoice Paid Date', fieldName: 'Invoice_Paid_Date__c', sortable: true },
                {
                    type: "button", label: 'Invoice', typeAttributes: {
                        label: 'Preview',
                        name: 'Preview',
                        title: 'Preview',
                        disabled: false,
                        value: 'Preview',
                        variant:'Brand'
                    }
                }
            ]; 
        }
        let invoicedata  = await this.fetchInvoiceDetails(this.inetRequestRecordId);
        this.invoiceRecords = invoicedata;
        this.viewInvoiceModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async callRowAction(event) {
        const name = event.detail.row.Name;
        const recordId = event.detail.row.Id;
        const actionName = event.detail.action.name;
        this.screenReaderMessage = 'Preview invoice ' + name;
        this.showMessage = true;
        if (actionName === 'Preview') {
            await getFileContent({recordId: recordId, objectName: this.invoiceObjectName}).then(result => {
                if(result){
                    const base64Content = result.base64Content;
                    const contentType = 'application/pdf';

                    this.filePreview(base64Content, contentType);
                    setTimeout(() => {
                        this.showMessage = false;
                        this.screenReaderMessage = '';
                    }, 2000);
                }
            }).catch((err) => {
                this.showToast("Info", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "info");
            })
        } 
    }

    async fetchInvoiceDetails(requestId){
        this.showSpinner = true; 
        let invoiceData;
        await fetchInvoiceData({
            requestId : requestId
        }).then(result =>{
            if(result){
                invoiceData = result;
            }
            this.showSpinner = false; 
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false; 
        })
        return invoiceData;
    }

    // --- QUOTE LOGIC BLOCK ---
    @wire(getRejectionReasons)
    wiredRejectionReasons({ error, data }) {
        if (data) {
            this.rejectionOptions = data;
        } else if (error) {
            console.error('Error fetching rejection reasons:', error);
        }
    }
    
    get providerName() {
        return this.quoteRecord?.Provider__r?.Name || '';
    }

    get requestorName() {
        return this.quoteRecord?.Requestor__r?.Name || '';
    }

    get inetRequestNumber() {
        return this.quoteRecord?.INET_Request__r?.INET_Request_Number__c || '';
    }

    get selectedRejectionReason() {
        return this.quoteRecord?.Rejection_Reason__c || '';
    }

    get isAlreadyDenied() {
        return this.quoteRecord?.Status__c === 'Denied';
    }

    async fetchQuoteDetails(requestId) {
        let quotedata = null; 
        try {
            const result = await fetchQuoteData({ requestId: requestId });
            if (result && result.length > 0) {
                quotedata = result[0]; 
            }
        } catch (err) {
            this.showToast("Error", err.body?.message || err.message, "error");
        }
        return quotedata; 
    }

    //handle View Quote button functionality
    async handleViewQuote(event) {
        this.quoteRecord = null; 
        this.isDenied = false;
        this.rejectionReason = '';
        this.showAcceptRejectButton = false;
        this.showQuoteAcceptedDate = false;
        this.showSpinner = true;

        this.inetRequestRecordId = event.target.dataset.id;
    
        try {
            const result = await this.fetchQuoteDetails(this.inetRequestRecordId);

        
            if (result) {
                this.quoteRecord = result;

                if (this.quoteRecord.Status__c === 'Sent') {
                    this.showAcceptRejectButton = true;
                }

                if (this.quoteRecord.Status__c !== 'Denied' && this.quoteRecord.Status__c !== 'Sent') {
                    this.showQuoteAcceptedDate = true;
                }

                this.viewQuoteModal = true;
                setTimeout(() => { focusFirstEle(this); }, 500);
            } else {
            this.showToast("Info", "No quote found for this request.", "info");
            }
        } catch (error) {
            console.error('Error in handleViewQuote:', error);
        } finally {
            this.showSpinner = false;
        }
    }

    handleRejectionReasonChange(event) {
        this.rejectionReason = event.detail.value;
    }
    
    validateSalesforceId(id) {
        const sfIdPattern = /^[a-zA-Z0-9]{15,18}$/;
        if (!id || !sfIdPattern.test(id)) {
            throw new Error("Invalid Salesforce record ID: " + id);
        }
        return true;
    }

    async updateQuoteUI(targetId, toastMessage) {
        try {
            this.validateSalesforceId(targetId);

            await notifyRecordUpdateAvailable([
                { recordId: this.quoteRecord.Id },
                { recordId: targetId }
            ]);

            const freshData = await this.fetchQuoteDetails(targetId);
            if (freshData) {
                this.quoteRecord = freshData;
                this.showAcceptRejectButton = false;
            
                if (this.quoteRecord.Status__c !== 'Denied' && this.quoteRecord.Status__c !== 'Sent') {
                    this.showQuoteAcceptedDate = true;
                } else {
                    this.showQuoteAcceptedDate = false;
                }
            }

            this.showToast('Success', toastMessage, 'success');
        
            if (this.wiredData) await refreshApex(this.wiredData);
        } catch (error) {
            const errorMsg = error.body?.message || error.message || 'Unknown Error';
            this.showToast('Error', errorMsg, 'error');
        }
    }

    //This method accept the quote request
    async handleAcceptQuote() {
        this.showSpinner = true;
        try {
            await this.updateINETRequestStatus(this.inetRequestRecordId, 'Quote Accepted', 'Quote');
            await this.updateQuoteDetails(this.quoteRecord.Id, 'Accepted');

            const targetId = this.inetRequestRecordId || this.quoteRecord?.INET_Request__c;
            await this.updateQuoteUI(targetId, 'Quote has been accepted');
        } catch (error) {
            const errorMsg = error.body?.message || error.message || 'Unknown Error';
            this.showToast('Error', errorMsg, 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    //This method reject the quote request
    handleRejectQuote() {
        this.isDenied = true;
    }

    cancelRejection() {
        this.isDenied = false;
        this.rejectionReason = '';
    }

    async confirmRejection() {
        if (!this.rejectionReason) {
            this.showToast('Error', 'Please select a rejection reason', 'error');
            return;
        }
        
        this.isDenied = false;
        this.showSpinner = true;
        
        try {
            await this.updateINETRequestStatus(this.inetRequestRecordId, 'Quote Rejected', 'Quote');
            await this.updateQuoteDetails(this.quoteRecord.Id, 'Denied', this.rejectionReason);

            const targetId = this.inetRequestRecordId || this.quoteRecord?.INET_Request__c;
            await this.updateQuoteUI(targetId, 'Quote has been rejected');
        } catch (error) {
            const errorMsg = error.body?.message || error.message || 'Unknown Error';
            this.showToast('Error', errorMsg, 'error');
        } finally {
            this.showSpinner = false;
            this.rejectionReason = ''; 
        }
    }

    async updateQuoteDetails(quoteId, status, rejectionReason) {
        try {
            await updateQuote({ 
                quoteId: quoteId, 
                status: status, 
                rejectionReason: rejectionReason 
            });

        } catch (err) {
            this.showToast("Error", err.body?.message || err.message, "error");
            throw err;
        }
    }

    async fetchPurchaseOrderDetails(requestId) {
        this.showSpinner = true;
        let purchaseData;
        await fetchPurchaseData({
            requestId: requestId
        }).then(result => {
            if (result) {
                purchaseData = result;
            }
            this.showSpinner = false;
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
        })
        return purchaseData;
    }

    //It Close the Modal popup on click of close
    closeModal() {
        this.newPurchaseModal = false;
        this.viewRequestModal = false;
        this.newRequestModal = false;
        this.viewQuoteModal = false;
        this.viewPurchaseOrderModal = false;
        this.feedbackModal = false;
        this.feedbackText = '';
        this.viewInvoiceModal = false;
        this.showUpdateProgressDetails = false;
        this.showQuoteAcceptedDate = false;
        this.showWorkCompletedDate = false;
        this.showProviderContactName = false;
        setTimeout(() => {
            if (this.triggerButton) {
                this.triggerButton.focus();
            }
        }, 0);
    }
    
    //It Close the Modal popup on click of esc
    closeModalOnEsc(event) {
        if(event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    get acceptedFormats() {
        return ['.pdf'];
    }

    onfileUpload(event) { 
        const file = event.target.files[0]; 
        var reader = new FileReader();
        const objName = event.target.dataset.objectname;
        const MAX_FILE_SIZE_MB = 25;
        const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;
        if (file.type !== 'application/pdf' || file.size > MAX_FILE_SIZE_BYTES) {
            this.showToast("Error","Please upload only PDF file with a maximum size of 25 MB","error");
            return;
        }
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];
            
            this.fileData = {
                'fileName': file.name,
                'fileContent': base64,
                'recordId': null,
                'objectName': objName
            }
            this.documentList.push(this.fileData);
        }
        reader.readAsDataURL(file)
    }

    clearFile() {
        this.fileData = null;
    }

    handleEnterKey(event){
        if(event.code == 'Enter' || event.code == 'Space') {
            this.clearFile();
        }
    }

    //This method is use to Save the INET Request with draft status
    handleDraftInetRequest(event){
        this.requestStatus = 'Draft';
    }
    
    //This method is use to Submit the INET Request 
    handleSubmit(event) {
        const zipCode = parseInt(event.detail.fields.Zip_Code__c, 10);
        if (event.detail.fields.Target_Date__c <= this.todaysDate) {
            event.preventDefault();
            this.showToast("Error", "Target Date should be in future date", "Error");
        }else if (zipCode <= 0 || isNaN(zipCode)) {
            event.preventDefault();
            this.showToast("Error", "Please enter the 5 digit zip code and it must be greater than zero.", "Error");
        }else if (!this.providerValue){
            const combo = this.template.querySelector('[data-id="provider-combobox"]');
            combo.setCustomValidity('Provider is required');
            combo.reportValidity();
            return;
        }else {
            event.preventDefault();
            this.showSpinner = true;
            const fields = event.detail.fields;

            if (fields.Sow_Needed__c == true && this.fileData == null) {
                event.preventDefault();
                this.showToast("Warning", "Please Upload the SOW before submitting the request", "Warning");
                this.showSpinner = false;
            } else {
                //Map remainig fields to values here 
                fields.Requestor__c = this.requestor;
                fields.Requestor_Contact_Name__c = this.requestorContact;
                fields.Provider__c = this.providerValue;
                fields.Quote_Subtype__c = '';
                if (this.requestStatus == 'Draft') {
                    fields.Status__c = 'Draft';
                } else if (this.requestStatus == 'Resubmitted') {
                    fields.Status__c = 'Resubmitted';
                    fields.Approval_status__c = '';
                    fields.Approval_Comments__c = '';
                    fields.Rejection_Comments__c = '';
                } else {
                    fields.Request_Date__c = this.todaysDate;
                    fields.Status__c = 'Submitted';
                }
                this.template.querySelector('lightning-record-edit-form').submit(fields);
            }
        }
    }

    async handleFileUpload(){
        const {fileName, fileContent, recordId, objectName} = this.fileData;
        const result =  await uploadFile({recordId: recordId, fileName: fileName, fileContent: fileContent, recObjectName: objectName});
        this.clearFile();
    }

    //After submit the sucess called which return the record Id 
    handleSuccess(event) {
        let requestId = event.detail.id;
        if (requestId) {
            if (this.requestStatus == 'Draft') {
                this.clearFile();
                this.showToast("Success", "New Request has been added in the Draft", "success");
            } else if (this.requestStatus == 'Resubmitted') {
                if(this.fileData){
                    this.fileData.recordId = requestId;
                    this.handleFileUpload();
                }
                this.showToast("Success", "New Request has been Resubmitted successfully.", "success");
            } else {
                if(this.fileData){
                    this.fileData.recordId = requestId;
                    this.handleFileUpload();
                }
                this.showToast("Success", "New Request has been successfully submitted.", "success");
                changeOwnerToQueue({ recordId: requestId })
                .then(() => {
                    // handle success (e.g., show toast)
                })
                .catch(error => {
                    this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
                });
            }
            this.resetINETData();
            this.fetchINETRequestdetails();
        }
        this.newRequestModal = false;
        this.showSpinner = false;
    }

    handleError(event) {
        this.showToast("Error", event.detail.detail , "error");
        this.showSpinner = false;
    }

    async handleConnectedToINET(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        const result = await LightningConfirm.open({
            label: 'Are you sure?',
            message: 'Are you sure that you are Connected to INET?',
            theme: 'warning'
        });
        if (result) {
            await this.updateINETRequestStatus(this.inetRequestRecordId, '', 'Connected to INET')
        }
    }

    //This method update the inet request data
    async updateINETRequestStatus(requestId, subtype, status) {
        this.showSpinner = true;
        await updateRequestStatus({ requestId: requestId, subtype: subtype, status: status }).then((res) => {
            this.resetINETData();
            this.fetchINETRequestdetails();
            this.showSpinner = false;
            return "success";
        }).catch((err) => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
        })
    }

    async handlePreview(event){
        const objectName = event.target.dataset.objectname;
        const recordId = event.target.dataset.recordid;
        await getFileContent({recordId: recordId, objectName: objectName}).then(result => {
            if(result){
                const base64Content = result.base64Content;
                const contentType = 'application/pdf';

                this.filePreview(base64Content, contentType);
            }
        }).catch((err) => {
            this.showToast("Info", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "info");
        })
        
    }

    filePreview(base64Content, contentType){
        if (base64Content && contentType) {
            const byteCharacters = atob(base64Content);
            const byteNumbers = new Array(byteCharacters.length);
            for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
            }
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: contentType });

            this._currentObjectUrl = URL.createObjectURL(blob);
            this.fileUrl = this._currentObjectUrl;

            const link = document.createElement('a');
            link.href = this.fileUrl;
            link.target = '_blank'; 
            link.rel = 'noopener noreferrer'; 
            //link.download = 'Test3';
            link.click();
            link.remove();

        }
    }
    
    async handlePurchaseOrderSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        let purchaseOrderList = await this.fetchPurchaseOrderDetails(null);
        //const poNumber = parseInt(event.detail.fields.Name, 10);
        const poAmount = parseInt(event.detail.fields.PO_Amount__c, 10);
        if (event.detail.fields.PO_Date__c < this.todaysDate) {
            this.showToast("Error", "PO Date should be in future date", "Error");
        } /*else if (purchaseOrderList.find(data => data.Name === fields.Name)) {
            this.showToast("Error", "A Purchase Order with the same number already exists", "Error");
        } else if (poNumber <= 0 || isNaN(poNumber)) {
            this.showToast("Error", "PO Number must be a number greater than zero.", "Error");
        } */else if (poAmount <= 0 || isNaN(poAmount)) {
            this.showToast("Error", "PO Amount must be greater than zero.", "Error");
        }else {
            this.showSpinner = true;
            let selectedRecord = this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId);
            fields.Provider__c = selectedRecord.Provider__c;
            fields.Actual_PO_Amount__c = fields.PO_Amount__c;
            fields.INET_Request__c = this.inetRequestRecordId;
            this.quoteRecord = await this.fetchQuoteDetails(this.inetRequestRecordId);
            if (this.quoteRecord && this.quoteRecord.Status__c == 'Accepted') {
                fields.Quote__c = this.quoteRecord.Id;
            }
            fields.Requestor__c = this.requestor;
            this.template.querySelector('lightning-record-edit-form').submit(fields);
        }
    }

    handlePurchaseOrderSuccess(event){
        let purchaseOrderId = event.detail.id;
        this.showSpinner = false;
        if(purchaseOrderId){
            if(this.fileData){
                this.fileData.recordId = purchaseOrderId;
                this.handleFileUpload();
            }
            this.showToast("Success", "Purchase Order has been created successfully.", "success");
            let res =  this.updateINETRequestStatus(this.inetRequestRecordId, null, 'PO Created');
        }
        this.newPurchaseModal = false;
        
    }

    handlePurchaseOrderError(event){
        this.showToast("Error", event.detail.detail, "error");
        this.showSpinner = false;
    }

    handleSearch(event) {
        this.searchValue = event.target.value.toLowerCase();
        if(this.searchValue){
            this.showSearchRecords = true;
            this.inetRequestList = this.inetRequestListBackup.filter(element => {
                return (
                    element.INET_Request_Number__c?.toLowerCase().includes(this.searchValue) || 
                    element.Site_Name__c?.toLowerCase().includes(this.searchValue) || 
                    element.Address__c?.toLowerCase().includes(this.searchValue) || 
                    element.Island__c?.toLowerCase().includes(this.searchValue) || 
                    element.City__c?.toLowerCase().includes(this.searchValue)
                );
            });
        } else {
            this.handleClearSearch();
        }
    }

    handleClearSearch(event) {
        if (!event.target.value.length) {
            this.showSearchRecords = false;
            this.inetRequestList = JSON.parse(JSON.stringify(this.inetRequestListBackup));
        }
    }

    //This method is used to reset all the field after submitting the new request to refresh the screen date
    resetINETData(){
        this.inetRequestRecordId = '';
        this.requestStatus = '';
        this.inetRequestList = [];
        this.invoiceColumns = [];
        this.inetRequestDraftList = [];
        this.inetRequestSubmittedList = [];
        this.inetRequestAssignedBackList = [];
        this.inetRequestActiveList =[];
        this.inetRequestClosedList= [];
        this.draftCount = 0; 
        this.submittedCount = 0; 
        this.assignedBackCount = 0; 
        this.activeCount = 0; 
        this.closedCount = 0; 
        this.showSaveDraftButton = true;
        this.showAcceptRejectButton = false;
        this.searchValue = '';
        this.showSearchRecords = false;
        this.firstLoading = true;
    }
    
    //Methods which handles the UI Part 
    handleResponsiveTabItems(event) {
        // Function for handling click events for "Custom Tabset (Responsive)"
        const clickedTabId = event.currentTarget.id; // Get the ID of the clicked tab
        const clickedTab = event.currentTarget; // Reference to the clicked tab element
        const tabContainer = clickedTab.closest('.mds-tabs_responsive'); // Get the parent responsive tab container
        const navElement = clickedTab.closest('.mds-tabs_default__nav');
        const isActive = clickedTab.getAttribute('aria-selected') === 'true';
        this.updateTabState(clickedTabId, tabContainer); // Update the tab state for the specific container

        this.currentTab = event.currentTarget.dataset.type;

        if (tabContainer) {
            // Only apply the class if it is in a responsive context
            if (isActive) {
                // Add 'mds-tabs-mobile__expand' class if the active tab is clicked
                navElement.classList.add('mds-tabs-mobile__expand');
            } else {
                // Remove 'mds-tabs-mobile__expand' class if another tab is selected
                navElement.classList.remove('mds-tabs-mobile__expand');
            }
        }
        //this.fetchINETRequestdetails();
        this.updateTabState(clickedTabId, tabContainer); // Update the tab state for the specific container
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    handleKeydown(event) {
        // Determine which container is currently focused
        const focusedTab = this.template.querySelector('.mds-tabs_default__item a:focus');
        const tabContainer = focusedTab.closest('.mds-tabs_default, .mds-tabs_responsive'); // Get the parent container
        const tabs = Array.from(tabContainer.querySelectorAll('.mds-tabs_default__item a'));
        const focusedIndex = tabs.indexOf(focusedTab);
        
        let newIndex;
        if (event.key === 'ArrowRight') {
            // Move to the next tab
            newIndex = (focusedIndex + 1) % tabs.length;
        } else if (event.key === 'ArrowLeft') {
            // Move to the previous tab
            newIndex = (focusedIndex - 1 + tabs.length) % tabs.length;
        } else {
            return; // Exit if the key is not an arrow key
        }

        // Set focus to the new tab
        tabs[newIndex].focus();
        this.updateTabState(tabs[newIndex].id, tabContainer); // Update the state for the specific container
        event.preventDefault(); // Prevent default browser behavior
    }

    updateTabState(activeTabId, container) {
        // Select all tab items and content areas within the specified container
        const tabs = container.querySelectorAll('.mds-tabs_default__item a');
        const contents = container.querySelectorAll('.mds-tabs_default__content');
        // Update the state of the tabs (active/inactive)
        tabs.forEach((tab) => {
            const isActive = tab.id === activeTabId;

            // Update tab's parent element (li) and attributes
            tab.parentElement.classList.toggle('mds-is-active', isActive);
            tab.setAttribute('aria-selected', isActive);
            tab.setAttribute('tabindex', isActive ? '0' : '-1');
        });

        // Update the state of the content areas (show/hide)
        contents.forEach((content) => {
            // Check if the content is associated with the active tab
            const isVisible = content.getAttribute('aria-labelledby') === activeTabId;

            // Show or hide content based on whether it's linked to the active tab
            content.classList.toggle('mds-show', isVisible);
            content.classList.toggle('mds-hide', !isVisible);
        });
    }

    get showDraftData(){
        return this.inetRequestDraftList.length > 0;
    }

    get showSubmittedData(){
        return this.inetRequestSubmittedList.length > 0;
    }

    get showAssignBackData(){
        return this.inetRequestAssignedBackList.length > 0;
    }

    get showActiveData(){
        return this.inetRequestActiveList.length > 0;
    }

    get showClosedData(){
        return this.inetRequestClosedList.length > 0;
    }

    get showAllData(){
        return this.inetRequestList.length > 0;
    }

    get getSearchAriaLabel() {
        if(this.searchValue){
            let result = this.inetRequestList ? String(this.inetRequestList.length) : '0';
            return (result + ' records found');
        }else{
            return 'Search Requests';
        }
    }
}