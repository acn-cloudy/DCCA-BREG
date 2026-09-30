import { LightningElement, api, track, wire } from 'lwc';
import { focusFirstEle } from "c/mdsUtility";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import fetchINETRequestData from '@salesforce/apex/CATV_DashboardController.fetchINETRequestData';
import fetchQuoteData from '@salesforce/apex/CATV_DashboardController.fetchQuoteData';
import updateRequestStatus from '@salesforce/apex/CATV_DashboardController.updateRequestStatus';
import fetchPurchaseData from '@salesforce/apex/CATV_DashboardController.fetchPurchaseData';
import fetchInvoiceData from '@salesforce/apex/CATV_DashboardController.fetchInvoiceData'; 
import updateInvoice from '@salesforce/apex/CATV_DashboardController.updateInvoice'; 
import uploadFile from '@salesforce/apex/CATV_DashboardController.uploadFile';
import getFileContent from '@salesforce/apex/CATV_DashboardController.getFileContent';
import MDS_Style from '@salesforce/resourceUrl/MDS_Style'; 

export default class Catv_provider_tabs extends LightningElement {
    picture = MDS_Style + '/media/images/no-data-found.svg';
    @api provider;
    @api providerContact;
    @track inetRequestList;
    @track inetRequestProviderList = [];
    @track inetRequestActiveList = [];
    @track inetRequestClosedList = [];
    @track activeCount = 0; 
    @track closedCount = 0; 
    @track inetRequestListBackup = [];
    @track searchValue;
    activeTab;
    requestobjectName = 'INET_Request__c';
    quoteObjectName = 'Quotes__c';
    purchaseOrderObjectName = 'Purchase_Order__c';
    invoiceObjectName = 'Invoice__c';
    quoteRecord = '';
    inetRequestRecordId='';
    createQuoteModal = false;
    viewRequestModal = false;
    viewQuoteModal = false;
    todaysDate;
    showSpinner = false;
    firstLoading = true;
    viewPurchaseOrderModal = false;
    purchaseOrderRecord = '';
    newInvoiceModal = false;
    viewInvoiceModal = false;
    updateProviderContactModal = false;
    updateProgressModal = false;
    workCompletionModal = false;
    showSearchRecords = false;
    invoiceRecords = '';
    showQuoteAcceptedDate = false;
    showWorkCompletedDate = false;
    showProviderContactName = false;
    showUpdateProgressDetails = false;
    @track invoiceColumns = []; 
    @track showMarkAllInvoicePaidButtom = false;
    triggerButton;
    fileData;
    fileUrl;
    @track screenReaderMessage = '';
    @track showMessage = false;

    connectedCallback() {
        // Adding event listener for keydown event
        //this.template.addEventListener('keydown', (event) => this.handleKeydown(event));

        //Todays date logic
        var today = new Date();
        const hawaiiOffset = -10;
        const hawaiiTime = new Date(today.getTime() + (hawaiiOffset * 60 + today.getTimezoneOffset()) * 60000);
        var dd = String(hawaiiTime.getDate()).padStart(2, '0');
        var mm = String(hawaiiTime.getMonth() + 1).padStart(2, '0');
        var yyyy = hawaiiTime.getFullYear();
        this.todaysDate = yyyy + '-' + mm + '-' + dd;

        this.fetchINETRequestdetails();
    }

    //This method is used to fetch all the INET Request.
    fetchINETRequestdetails() {
        this.showSpinner = true;
        fetchINETRequestData({
            account: this.provider
        }).then(result => {
            if (result) {
                this.inetRequestList = result;
                this.inetRequestList.forEach(item => {
                    item.viewDetailsButtonAriaLabel = 'View Details Button '+ item.IROC_Id__c;
                    item.viewRequestButtonAriaLabel = 'View Request Button '+ item.IROC_Id__c;
                    item.viewQuoteButtonAriaLabel = 'View Quote Button '+ item.IROC_Id__c;
                    item.updateProviderContactButtonAriaLabel = 'Create Quote Button '+ item.IROC_Id__c;
                    item.createQuotesButtonAriaLabel = 'Create Quote Button '+ item.IROC_Id__c;
                    item.viewPurchaseOrderButtonAriaLabel = 'View Purchase Order Button '+ item.IROC_Id__c;
                    item.workStartedButtonAriaLabel = 'Work Started Button '+ item.IROC_Id__c;
                    item.updateProgressButtonAriaLabel = 'Update Progress Button '+ item.IROC_Id__c;
                    item.workCompletedButtonAriaLabel = 'Work Completed Button '+ item.IROC_Id__c;
                    item.createInvoicesButtonAriaLabel = 'Create Invoice Button '+ item.IROC_Id__c;
                    item.viewInvoicesButtonAriaLabel = 'View Invoice(s) Button '+ item.IROC_Id__c;
                    if (item.Status__c == 'CATV Review' || (item.Status__c == 'Quote') || item.Status__c == 'PO Created' || item.Status__c == 'Work Initiated' || item.Status__c == 'Work Completed' || item.Status__c == 'Invoice Created' || item.Status__c == 'Invoice Paid' || item.Status__c == 'Connected to INET') {
                        item.showViewDetails = true;
                        if (item.Status__c == 'Quote' && (item.Quote_Subtype__c == 'Quote Requested') && item.Provider_Contact_Name__c == null) {
                            item.showUpdateProviderContactButton = true;
                        }
                        if (item.Status__c == 'Quote' && (item.Quote_Subtype__c == 'Quote Requested' || item.Quote_Subtype__c == 'Quote Rejected')) {
                            if(item.Provider_Contact_Name__c == null || item.Provider_Contact_Name__c == undefined){
                                item.disableCreateQuoteButton = true;
                            }
                            item.showCreateQuoteButton = true;
                        }
                        if (item.Status__c == 'PO Created' || (item.Status__c == 'Quote' && (item.Quote_Subtype__c == 'Quote Sent' || item.Quote_Subtype__c == 'Quote Accepted' || item.Quote_Subtype__c == 'Quote Rejected'))) {
                            item.showVieQuoteDetails = true;
                        }
                        if (item.Status__c == 'PO Created') {
                            item.showViePurchaseOrderDetails = true;
                            item.showStartWorkButton = true;
                        } else if (item.Status__c == 'Work Initiated') {
                            item.showVieQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showWorkCompletedButton = true;
                        } else if (item.Status__c == 'Work Completed') {
                            item.showVieQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showSubmitInvoiceButton = true;
                        } else if (item.Status__c == 'Invoice Created') {
                            item.showViewInvoiceDetails = true;
                            item.showViewDetails = false;
                            item.showSubmitInvoiceButton = true;
                        } else if (item.Status__c == 'Invoice Paid') {
                            item.showViewDetails = false;
                            item.showViewInvoiceDetails = true;
                        } else if (item.Status__c == 'Connected to INET') {
                            item.showVieQuoteDetails = true;
                            item.showViePurchaseOrderDetails = true;
                            item.showViewInvoices = true;
                        }
                        this.inetRequestActiveList.push(item);
                        this.inetRequestProviderList.push(item);
                        this.activeCount = this.inetRequestActiveList.length > 0 ? this.inetRequestActiveList.length : 0;
                    }
                    if (item.Status__c == 'Completed') {
                        item.showViewDetails = true;
                        item.showVieQuoteDetails = true;
                        item.showViePurchaseOrderDetails = true;
                        item.showViewInvoices = true;
                        this.inetRequestClosedList.push(item);
                        this.inetRequestProviderList.push(item);
                        this.closedCount = this.inetRequestClosedList.length > 0 ? this.inetRequestClosedList.length : 0;
                    }
                });
                this.inetRequestListBackup = JSON.parse(JSON.stringify(this.inetRequestProviderList));
            }
            this.showSpinner = false;
            this.firstLoading = false;
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
            this.firstLoading = false
        })

    }

    //It Close the Modal popup on click of close
    closeModal() {
        this.createQuoteModal = false;
        this.viewRequestModal = false;
        this.viewQuoteModal = false;
        this.viewPurchaseOrderModal = false;
        this.newInvoiceModal = false;
        this.viewInvoiceModal = false;
        this.workCompletionModal = false;
        this.updateProgressModal = false;
        this.updateProviderContactModal = false;
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
        if (event.code == 'Escape') {
            this.closeModal();
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    handleUpdateProviderContact(event){
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.updateProviderContactModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    handleUpdateContactSubmit(event){
        const fields = event.detail.fields;
        event.preventDefault();
        this.showSpinner = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleUpdateContactSuccess(event){
        this.updateProviderContactModal = false;
        this.showToast("Success", "Provider Contact has been updated successfully.", "success");
        this.resetINETData();
        this.fetchINETRequestdetails();
        this.showSpinner = false;
    }

    handleUpdateContactError(event){
        this.showToast("Error", event.detail.detail, "error");
        this.showSpinner = false;
    }

    //This method is use to open the create quote modal.
    handleCreateQuote(event) {
        this.triggerButton = event.currentTarget;
        this.inetRequestRecordId = event.target.dataset.id;
        this.createQuoteModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    //This method update the inet request status. 
    async handleWorkStarted(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        const result = await LightningConfirm.open({
            label: 'Are you sure?',
            message: 'Are you sure you want to update to Work Initiated?',
            theme: 'warning'
        });
        if (result) {
            await this.updateRequestDetails(this.inetRequestRecordId, 'Work Initiated')
        }

    }
    
    //This method update the inet request progress. 
    async handleUpdateProgress(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.showSpinner = true;
        this.updateProgressModal = true;
        setTimeout(() => {
            this.showSpinner = false;
        }, 2000);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    handleUpdateProgressSubmit(event) {
        const fields = event.detail.fields;
        event.preventDefault();
        this.showSpinner = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
        /*if (event.detail.fields.Projected_Deployment_Date__c < this.todaysDate) {
            event.preventDefault();
            this.showToast("Error", "Projected Deployment Date should be in future date", "Error");
            setTimeout(() => {
                let projectedDeploymentDate = this.template.querySelector('.projectedDeploymentDate');
                if (projectedDeploymentDate) {
                    projectedDeploymentDate?.focus();
                }
            }, 500); 
            
        }else if (event.detail.fields.Scheduled_Deployment_Date__c < this.todaysDate) {
            event.preventDefault();
            this.showToast("Error", "Scheduled Deployment Date should be in future date", "Error");
            setTimeout(() => {
                let scheduledDeploymentDate = this.template.querySelector('.scheduledDeploymentDate');
                if (scheduledDeploymentDate) {
                    scheduledDeploymentDate?.focus();
                }
            }, 500);
        }else if (event.detail.fields.Deployment_Start_Date__c < this.todaysDate) {
            event.preventDefault();
            this.showToast("Error", "Deployment Start Date should be in future date", "Error");
            setTimeout(() => {
                let deploymentStartDate = this.template.querySelector('.deploymentStartDate');
                if (deploymentStartDate) {
                    deploymentStartDate?.focus();
                }
            }, 500); 
        }else{*/
           
        //}
    }

    handleUpdateProgressSuccess(event) {
        this.updateProgressModal = false;
        this.showToast("Success", "INET Request Progress has been Updated successfully.", "success");
        this.resetINETData();
        this.fetchINETRequestdetails();
        this.showSpinner = false;
      
    }

    handleUpdateprogressError(event) {
        this.showToast("Error", event.detail.detail, "error");
        this.showSpinner = false;
    }

    //This method update the inet request status. 
    async handleWorkCompleted(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.showSpinner = true;
        this.workCompletionModal = true;
        setTimeout(() => {
            this.showSpinner = false;
        }, 2000);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
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

    handleSubmit(event) {
        const fields = event.detail.fields;
        if(fields.Mileage__c <= 0 ){
            event.preventDefault();
            this.showToast("Error", "Please enter positive value lesser than or equal to 25.", "Error");
        } else if (fields.Mileage__c > 25 ) {
            event.preventDefault();
            this.showToast("Error", "Mileage cannot exceed 25 miles.", "Error");
        } else {
            event.preventDefault();
            this.showSpinner = true;
            fields.Status__c = 'Work Completed';
            fields.Work_Completed_Date__c =  this.todaysDate;
            this.template.querySelector('lightning-record-edit-form').submit(fields);
        }
    }

    handleWorkCompletedError(event) {
        this.showToast("Error", event.detail.detail, "error");
        this.showSpinner = false;
    }

    async handleFileUpload(){
        const {fileName, fileContent, recordId, objectName} = this.fileData;
        const result =  await uploadFile({recordId: recordId, fileName: fileName, fileContent: fileContent, recObjectName: objectName});
        this.clearFile();
    }

    handleSuccess(event) {
            this.workCompletionModal = false;
            this.showToast("Success", "Work has been Completed successfully.", "success");
            this.resetINETData();
            this.fetchINETRequestdetails();
            this.showSpinner = false;
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

    async updateRequestDetails(requestId, status) {
        this.showSpinner = true;
        await updateRequestStatus({ requestId: requestId, subtype: '', status: status }).then((res) => {
            this.resetINETData();
            this.fetchINETRequestdetails();
            this.showSpinner = false;
        }).catch((err) => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
        })
    }

    //This method is use to create the quote on submission.
    async handleQuoteSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        this.showSpinner = true;
        let selectedRecord = this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId);
        fields.Provider__c = this.provider;
        fields.INET_Request__c = this.inetRequestRecordId
        fields.Requestor__c = selectedRecord.Requestor__c;
        fields.Status__c = 'Sent';
        fields.Submitted_Date__c = this.todaysDate;
        this.template.querySelector('lightning-record-edit-form').submit(fields);

    }

    //After submit the sucess called which return the record Id 
    handleQuoteSuccess(event) {
        let newquoteId = event.detail.id;
        if (newquoteId) { 
            if(this.fileData){
                this.fileData.recordId = newquoteId;
                this.handleFileUpload();
            }
            this.showToast("Success", "Quote has been created successfully.", "success");
            updateRequestStatus({ requestId: this.inetRequestRecordId, subtype: 'Quote Sent', status: 'Quote' }).then((res) => {
                this.resetINETData();
                this.fetchINETRequestdetails();
                this.showSpinner = false;
            }).catch((err) => {
                this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
                this.showSpinner = false;
            })
        }
        this.createQuoteModal = false;
    }

    handleQuoteError(event) {
        this.showToast("Error", event.detail.detail, "error");
        this.showSpinner = false;
    }

    //This method is used to reset all the field after submitting the new request to refresh the screen date
    resetINETData() {
        this.inetRequestRecordId = '';
        this.inetRequestList = [];
        this.invoiceColumns = [];
        this.inetRequestProviderList = [];
        this.inetRequestActiveList = [];
        this.inetRequestClosedList = [];
        this.activeCount = 0;
        this.closedCount = 0;
        this.showMarkAllInvoicePaidButtom = false;
        this.showSearchRecords = false;
        this.searchValue = '';
        this.firstLoading = true;
    }

    //This method View Request button functionality
    handleViewRequest(event) {
        this.showSpinner = true;
        this.inetRequestRecordId = event.target.dataset.id;
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
        }, 2500);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    //This method View Quote button functionality
    async handleViewQuote(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        let quotedata = await this.fetchQuoteDetails(this.inetRequestRecordId);
        this.quoteRecord = quotedata[0];
        if(this.quoteRecord.Status__c == 'Accepted'){
            this.showQuoteAcceptedDate = true;
        }
        this.viewQuoteModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async fetchQuoteDetails(requestId) {
        this.showSpinner = true;
        let quotedata;
        await fetchQuoteData({
            requestId: requestId
        }).then(result => {
            if (result) {
                quotedata = result;
            }
            this.showSpinner = false;
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
        })
        return quotedata;
    }

    async handleViewPurchaseOrder(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        this.purchaseOrderRecord = await this.fetchPurchaseOrderDetails(this.inetRequestRecordId);
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async fetchPurchaseOrderDetails(requestId) {
        this.showSpinner = true;
        let purchaseData;
        await fetchPurchaseData({
            requestId: requestId
        }).then(result => {
            if (result) {
                this.viewPurchaseOrderModal = true;
                purchaseData = result[0];
            }
            this.showSpinner = false;
        }).catch(err => {
            this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
            this.showSpinner = false;
        })
        return purchaseData;
    }

    //It handles the Create Purchase Order Which open the modal to create new purchase order.
    handleSubmitInvoice(event) {
        this.inetRequestRecordId = event.target.dataset.id;
        this.newInvoiceModal = true;
        setTimeout(() => {
            focusFirstEle(this);
        }, 500);
    }

    async handleInvoiceSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        let invoiceList = await this.fetchInvoiceDetails(null);
        //const invoiceNumber = parseInt(event.detail.fields.Name, 10);
        const invoiceAmount = parseInt(event.detail.fields.Invoice_Amount__c, 10);
        if (event.detail.fields.Invoice_Date__c < this.todaysDate) {
            this.showToast("Error", "Invoice Date should be in future date", "Error");
        }/*else if (invoiceList.find(data => data.Name === fields.Name)) {
            this.showToast("Error", "An Invoice with the same number already exists", "Error");
        }else if (invoiceNumber <= 0 || isNaN(invoiceNumber)) {
            this.showToast("Error", "Invoice Number must be a number greater than zero.", "Error");
        }*/else if (invoiceAmount <= 0 || isNaN(invoiceAmount)) {
            this.showToast("Error", "Invoice Amount must be greater than zero.", "Error");
        } else {
            this.showSpinner = true;
            fields.INET_Request__c = this.inetRequestRecordId;
            fields.Status__c = 'Unpaid';
            this.template.querySelector('lightning-record-edit-form').submit(fields);
        }
    }

    handleInvoiceSuccess(event){
        let invoiceId = event.detail.id;
        this.showSpinner = false;
        if(invoiceId){
            if(this.fileData){
                this.fileData.recordId = invoiceId;
                this.handleFileUpload();
            }
            this.showToast("Success", "Invoice has been created successfully.", "success");
            let selectedRecord = this.inetRequestActiveList.find(data => data.Id === this.inetRequestRecordId);
            if(selectedRecord?.Status__c != 'Invoice Created'){
                this.updateRequestDetails(this.inetRequestRecordId, 'Invoice Created');
            }
        }
        this.newInvoiceModal = false;
    }

    handleInvoiceError(event){
        this.showToast("Error", event.detail.detail , "error");
        this.showSpinner = false;
    }

    async handleViewInvoice(event){
        this.inetRequestRecordId = event.target.dataset.id;
        this.triggerButton = event.currentTarget;
        let invoicedata  = await this.fetchInvoiceDetails(this.inetRequestRecordId);
        this.invoiceRecords = invoicedata;
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
            this.showMarkAllInvoicePaidButtom = true;
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
            this.showMarkAllInvoicePaidButtom = false;
        }
        let selectedRecordClosedList = this.inetRequestClosedList.find(data => data.Id === this.inetRequestRecordId);
        if(selectedRecordClosedList?.Status__c == 'Completed'){
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
            this.showMarkAllInvoicePaidButtom = false;
        }
        this.viewInvoiceModal = true;
       
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

    async handleUpdateInvoice(event){
        this.showSpinner = true;
        updateInvoice({ requestId: this.inetRequestRecordId}).then((res) => {
            if(res){
                this.showToast("Success", "Invoice has been Updated successfully.", "success");
                this.fetchInvoiceDetails(this.inetRequestRecordId);
            }
       }).catch((err) => {
        this.showToast("Error", err.body.pageErrors ? err.body.pageErrors[0].message : err.body.message, "error");
       })
       await this.updateRequestDetails(this.inetRequestRecordId, 'Invoice Paid');
       this.viewInvoiceModal = false;
       this.showSpinner = false;
       
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

    handleSearch(event) {
        this.searchValue = event.target.value.toLowerCase();
        if (this.searchValue) {
            this.showSearchRecords = true;
        // Search across the full provider list backup
            this.inetRequestProviderList = this.inetRequestListBackup.filter(element => {
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
            this.inetRequestProviderList = JSON.parse(JSON.stringify(this.inetRequestListBackup));
        }
    }

    //Methods which handles the UI Part 
    handleResponsiveTabItems(event) {
        // Function for handling click events for "Custom Tabset (Responsive)"
        const clickedTabId = event.currentTarget.id; // Get the ID of the clicked tab
        const clickedTab = event.currentTarget; // Reference to the clicked tab element
        this.activeTab = clickedTabId;
        const tabContainer = clickedTab.closest('.mds-tabs_responsive'); // Get the parent responsive tab container
        const navElement = clickedTab.closest('.mds-tabs_default__nav');
        const isActive = clickedTab.getAttribute('aria-selected') === 'true';
        this.updateTabState(clickedTabId, tabContainer); // Update the tab state for the specific container

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

    get showActiveData(){
        return this.inetRequestActiveList.length > 0;
    }

    get showClosedData(){
        return this.inetRequestClosedList.length > 0;
    }

    get showAllData(){
        return this.inetRequestProviderList.length > 0;
    }

    get getSearchAriaLabel() {
        if(this.searchValue){
            let result = this.inetRequestProviderList ? String(this.inetRequestProviderList.length) : '0';
            return (result + ' records found');
        }else{
            return 'Search Requests';
        }
    }
}