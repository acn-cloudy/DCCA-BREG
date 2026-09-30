import { LightningElement, api, track, wire } from 'lwc';
import getPaymentTransactionLineWrappers from '@salesforce/apex/BREGPaymentController.getPaymentTransactionLineWrappers';
import getPaymentSiteBaseUrl from '@salesforce/apex/BREGPaymentController.getPaymentSiteBaseUrl';

export default class Breg_Payment extends LightningElement {
    @api paymentId;
    @track transactionLines = [];
    @track isLoading = true;

    @wire(getPaymentSiteBaseUrl)
    paymentSiteBaseUrl;

    connectedCallback() {
        this.paymentId = this.getParamFromUrl('pid');
        this.loadTransactionLines();
    }

    getParamFromUrl(paramName) {
        const urlParams = new URLSearchParams(window.location.search);
        return urlParams.get(paramName);
    }

    async loadTransactionLines() {
        try {
            if (this.paymentId) {
                this.transactionLines = await getPaymentTransactionLineWrappers({ paymentId: this.paymentId });
                console.log('Transaction lines:', this.transactionLines);
            }
        } catch (error) {
            console.error('Error loading transaction lines:', error);
        } finally {
            this.isLoading = false;
        }
    }

    get paymentUrl() {
        const base = this.paymentSiteBaseUrl?.data;
        if (!base) return null;
        return `${base}/pmtx/pymt__SiteCheckout?pid=${this.paymentId}&mode=bregportal&completed_url=${this.completedUrl}`;
    }

    get completedUrl() {
        return encodeURIComponent(`${window.location.origin}/payment-redirection`);
    }
}