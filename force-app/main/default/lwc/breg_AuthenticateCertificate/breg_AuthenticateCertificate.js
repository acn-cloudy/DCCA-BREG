import { LightningElement } from "lwc";
import getCertificate from "@salesforce/apex/BREGSearchAndBuyController.getCertificate";
import downloadDocument from "@salesforce/apex/BREGPaymentController.downloadDocument";
import { createDownloadLink } from "c/utils";
import { Labels } from "./labels";

export default class Breg_AuthenticateCertificate extends LightningElement {
    authCodeOrDocumentId;
    isLoading = false;
    showError = false;
    errorMessage = "";
    showSuccess = false;
    certificate;
    get orderDate() {
        const timestamp = this.certificate?.breg_Published_Timestamp__c;
        if (!timestamp) return '';
        
        const date = new Date(timestamp);
    
        // Convert to Hawaii Timezone
        const hstDate = date.toLocaleDateString('en-US', {
            timeZone: 'Pacific/Honolulu',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    
        return `${this.labels.BREG_Order_date} ${hstDate}`;
    }
    entityName;
    entityId;
    get recordUrl() {
        return `/search-and-buy?entityId=${this.entityId}`;
    }

    // Labels
    labels = Labels;

    // Handle input change
    handleInputChange(event) {
        this.authCodeOrDocumentId = event.target.value;
    }

    // Handle authenticate button click
    async handleAuthenticate() {
        // Validate input
        if (!this.authCodeOrDocumentId || this.authCodeOrDocumentId.trim() === "") {
            this.showErrorSection(this.labels.requiredFieldError);
            return;
        }

        this.clearMessages();

        try {
            this.isLoading = true;
            const certificate = await getCertificate({ authCodeOrDocumentId: this.authCodeOrDocumentId.trim() });
            if (certificate) {
                this.showSuccessSection();
                this.certificate = certificate;
                this.entityName = this.certificate?.breg_Document__r?.breg_Account__r?.Name;
                this.entityId = this.certificate?.breg_Document__r?.breg_Account__c;
            } else {
                this.showErrorSection(this.labels.invalidCodeError);
            }
        } catch (error) {
            console.error("Authentication error:", error);
            this.showErrorSection(this.labels.authenticationError);
        } finally {
            this.isLoading = false;
        }
    }

    // Show error message
    showErrorSection(message) {
        this.errorMessage = message;
        this.showError = true;
        this.showSuccess = false;
    }

    // Show success message
    showSuccessSection() {
        this.showSuccess = true;
        this.showError = false;
    }

    // Clear all messages
    clearMessages() {
        this.showError = false;
        this.showSuccess = false;
        this.errorMessage = "";
    }

    // Handle close error message
    handleCloseError() {
        this.showError = false;
    }

    // Handle close success message
    handleCloseSuccess() {
        this.showSuccess = false;
    }
}