import { LightningElement, api } from 'lwc';
import getLines from "@salesforce/apex/PaymentDisplayController.getTransactionLines";
import getPayLink from "@salesforce/apex/PaymentDisplayController.getPaymentLink";
import getTransactionInProgress from "@salesforce/apex/PaymentDisplayController.transactionAdjustmentInProgress";

export default class PaymentDisplay extends LightningElement {
    isModalOpen = false;
    @api
    valueMap;
    @api
    formData;
    @api
    application;
    items;
    cancel_url;
    finish_url;
    payment_url;
    isPolling;
    loadingText = 'Saving application'
    connectedCallback() {
        const {application} = this;
        const recordId = application.Id;
        if(this.formData) {
            const data = JSON.parse(this.formData);
            this.cancel_url = data.cancel_url;
            this.finish_url = data.finish_url;

        }

        var count = 1;
        this.isPolling = true;
        var polling = setInterval(() => {
            getTransactionInProgress({recordId}).then(res => {
                if(count==10){
                    this.loadingText = 'Getting payment details'
                }
                if(!res || count >=20 ){
                    clearInterval(polling);
                    getLines({recordId}).then(res => {
                        this.items = JSON.parse(res);
                        this.openModal();
                        this.isPolling = false;
                    });
                }
                count++
            });
        }, 1000); 
        
        getPayLink({recordId}).then(res => {
            this.payment_url = res;
        });
    }

    get totalAmount() {
        return this.items ? this.items.reduce((result, item) => {
            result += item.Amount__c ;
            return result;
        }, 0) : 0;
    }

    openModal() {
        this.template.querySelector('c-pvl_popup').openModal();
      }

    closeModal() {
        this.template.querySelector('c-pvl_popup').closeModal();
    }

    cancel() {
        this.closeModal();
    }

    get payURL() {
        return this.payment_url + "&from_checkout=true&finish_url=" + encodeURI(this.finish_url);
    }
}