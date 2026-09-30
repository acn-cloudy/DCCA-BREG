import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getPaymentConfirmation from "@salesforce/apex/BREGPaymentController.getPaymentConfirmation";
import downloadDocument from "@salesforce/apex/BREGPaymentController.downloadDocument";
import generatePaymentReceiptPdf from "@salesforce/apex/BREGPaymentController.generatePaymentReceiptPdf";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";
import labels from "./labels";
import { createDownloadLink } from "c/utils";

export default class Breg_PaymentConfirmation extends NavigationMixin(LightningElement) {
    confirmationData = null;
    isLoading = true;
    error = null;
    documentDownloadError = null;
    paymentId = null;
    labels = labels;

    expeditedProcessingDisabled = false;

    connectedCallback() {
        this.loadExpeditedProcessingStatus(); 
        this.loadPaymentConfirmation();
    }

    async loadExpeditedProcessingStatus() {
        try {
            this.expeditedProcessingDisabled = await isExpeditedProcessingDisabled();
        } catch (error) {
            console.error("Error checking expedited processing status:", error);
        }
    }

    loadPaymentConfirmation() {
        try {
            const urlParams = new URLSearchParams(window.location.search);
            this.paymentId = urlParams.get("pid");

            if (!this.paymentId) {
                this.error = labels.BREG_PaymentConfirmation_NoPaymentInfoFound;
                this.isLoading = false;
                return;
            }

            // Call Apex method to get payment confirmation data
            getPaymentConfirmation({ paymentId: this.paymentId })
                .then((result) => {
                    if (result) {
                        this.confirmationData = result;
                    } else {
                        this.error = labels.BREG_PaymentConfirmation_NoPaymentInfoFound;
                    }
                    this.isLoading = false;
                })
                .catch((error) => {
                    console.error("Error getting payment confirmation:", error);
                    this.error = "Error retrieving payment: " + (error.body?.message || error.message);
                    this.isLoading = false;
                });
        } catch (error) {
            console.error("Error in loadPaymentConfirmation:", error);
            this.error = "Error retrieving payment: " + (error.body?.message || error.message);
            this.isLoading = false;
        }
    }

    get isWithdrawalForm() {
        if (!this.confirmationData?.transactionLineWrappers || this.confirmationData.transactionLineWrappers.length === 0) {
            return false;
        }
        const firstLine = this.confirmationData.transactionLineWrappers[0];
        return firstLine?.formCode?.toString().toUpperCase() === "WD";
    }

    get showNotCompletedMessage() {
        return this.confirmationData && !this.confirmationData.isCompleted;
    }

    get isZeroAmountPayment() {
        return this.confirmationData && 
               this.confirmationData.isCompleted && 
               (this.confirmationData.paymentAmount === 0 || this.confirmationData.paymentAmount === null);
    }

    get showZeroAmountConfirmation() {
        return this.isZeroAmountPayment;
    }

    get showPaymentConfirmationInfo() {
        return this.confirmationData && this.confirmationData.isCompleted && !this.isZeroAmountPayment;
    }

    get formTypeName() {
        if (!this.confirmationData?.transactionLineWrappers || this.confirmationData.transactionLineWrappers.length === 0) {
            return "";
        }
        // Get the first transaction line description to extract the form type
        const firstLine = this.confirmationData.transactionLineWrappers[0];
        return firstLine?.formCode + ' ' + firstLine?.formName || "";
    }

    get isResubmission() {
        if (!this.confirmationData?.transactionLineWrappers || this.confirmationData.transactionLineWrappers.length === 0) {
            return false;
        }
        // Get the first transaction line description to extract the form type
        const firstLine = this.confirmationData.transactionLineWrappers[0];
        return firstLine?.formAction?.toString().toLowerCase() === "resubmit";
    }

    get showExpeditedInfo() {
        return !this.isResubmission && !this.expeditedProcessingDisabled;
    }

    get filingActionLabel1() {
        if (this.isResubmission) {
            return "resubmitting";
        }
        return "submitting";
    }

    get filingActionLabel2() {
        if (this.isResubmission) {
            return "resubmitted";
        }
        return "submitted";
    }

    get formattedTransactionDate() {
        if (!this.confirmationData?.transactionDate) {
            return "";
        }

        const locale = 'en-US';
        const d = this.confirmationData.transactionDate;
        const [year, month, day] = d.split("-");
        const date = new Date(Date.UTC(year, month - 1, day));

        return new Intl.DateTimeFormat(locale.replace("_", "-"), {
            year: "numeric",
            month: "long",
            day: "numeric",
            timeZone: "UTC"
        }).format(date);
    }

    get formattedAmount() {
        if (this.confirmationData?.paymentAmount) {
            return "$" + this.confirmationData.paymentAmount.toFixed(2);
        }
        return "";
    }

    get referenceId() {
        return this.confirmationData?.referenceId;
    }

    get transactionId() {
        return this.confirmationData?.transactionId;
    }

    get authorizationCode() {
        return this.confirmationData?.authorizationId;
    }

    get contactName() {
        return this.confirmationData?.contactName;
    }

    get contactPhone() {
        return this.confirmationData?.contactPhone;
    }

    get billingAddress() {
        if (!this.confirmationData) return "";

        const addressParts = [];
        if (this.confirmationData.billingStreet) addressParts.push(this.confirmationData.billingStreet);
        if (this.confirmationData.billingCity) addressParts.push(this.confirmationData.billingCity);
        if (this.confirmationData.billingState) addressParts.push(this.confirmationData.billingState);
        if (this.confirmationData.billingPostalCode) addressParts.push(this.confirmationData.billingPostalCode);
        if (this.confirmationData.billingCountry) addressParts.push(this.confirmationData.billingCountry);

        return addressParts.join(", ");
    }

    get totalAmount() {
        if (this.confirmationData?.transactionLines) {
            return this.confirmationData.transactionLines.reduce((total, line) => total + line.amount, 0);
        }
        return this.confirmationData?.paymentAmount || 0;
    }

    async printReceipt() {
        try {
            // Show loading spinner
            this.isLoading = true;

            // Generate the payment receipt PDF
            const pdfBase64 = await generatePaymentReceiptPdf({ paymentId: this.paymentId });

            if (pdfBase64) {
                const filename = `BREG_Payment_Receipt`;
                // Use the utility function to download the PDF
                createDownloadLink(pdfBase64, filename, "pdf");

                console.log("Payment receipt PDF download initiated");
            } else {
                console.error("No PDF content received");
                this.error = "Error generating payment receipt PDF";
            }
        } catch (error) {
            console.error("Error generating payment receipt PDF:", error);
            this.error = "Error generating payment receipt: " + (error.body?.message || error.message);
        } finally {
            // Hide loading spinner
            this.isLoading = false;
        }
    }

    handleContinue() {
        window.top.location.href = "/";
    }

    handleGoToDashboard() {
        window.top.location.href = "/my-dashboard";
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async handleDownloadDocument(event) {
        const documents = event.detail.documents;

        if (!documents || documents.length === 0) {
            this.documentDownloadError = "No documents provided for download";
            return;
        }

        this.isLoading = true;
        try {
            const results = await Promise.all(
                documents.map((doc) => downloadDocument({ docusignDocumentId: doc.docusignDocumentId }))
            );

            // Process sequentially with an awaitable delay
            for (let i = 0; i < results.length; i++) {
                if (results[i]) {
                    createDownloadLink(results[i], documents[i].description, documents[i].fileType);
                    
                    // Wait 1 second before triggering the next one
                    // This gives the browser time to process the first and prompt the user for permission
                    if (i < results.length - 1) {
                        await this.delay(1000); 
                    }
                } else {
                    console.error(`No content received for ${documents[i].description}`);
                }
            }
        } catch (error) {
            console.error("Error downloading document:", error);
            console.error(error.body?.message || error.message);
            this.documentDownloadError = "Error downloading document";
        } finally {
            this.isLoading = false;
        }
    }
}