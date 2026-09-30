import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import USER_NAME from "@salesforce/schema/User.Name";
import checkTicketAccess from "@salesforce/apex/tkt_TicketController.checkTicketAccess";
import createTicket from "@salesforce/apex/tkt_TicketController.createTicket";
import attachFile from "@salesforce/apex/tkt_TicketController.attachFile";

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const MAX_FILES = 5;

export default class TktCreateTicket extends NavigationMixin(LightningElement) {
    @api recordId;

    // Current user info
    currentUserId = USER_ID;
    currentUserName = "";

    // Form fields
    subject = "";
    description = "";
    priority = "Medium";
    category = "";
    impact = "Individual";
    environment = "Production";

    // UI state
    isLoading = true;
    accessDenied = false;
    isSubmitting = false;
    isSubmitted = false;
    errorMessage = "";
    createdTicketId;
    uploadProgress = 0;
    uploadStatus = "";

    // File upload state
    selectedFiles = [];
    fileError = "";

    // Record context
    recordName = "";
    recordType = "";
    recordIcon = "standard:record";
    recordApiName = "";

    priorityOptions = [
        { label: "Low", value: "Low" },
        { label: "Medium", value: "Medium" },
        { label: "High", value: "High" },
        { label: "Critical", value: "Critical" }
    ];

    categoryOptions = [
        { label: "-- Select Category --", value: "" },
        { label: "General Inquiry", value: "General Inquiry" },
        { label: "Technical Issue", value: "Technical Issue" },
        { label: "Access Request", value: "Access Request" },
        { label: "Bug Report", value: "Bug Report" },
        { label: "Feature Request", value: "Feature Request" }
    ];

    impactOptions = [
        { label: "Individual - Affects only me", value: "Individual" },
        { label: "Branch - Affects my branch", value: "Branch" },
        { label: "Division - Affects my division", value: "Division" }
    ];

    environmentOptions = [
        { label: "Production", value: "Production" },
        { label: "Sandbox", value: "Sandbox" },
        { label: "UAT", value: "UAT" },
        { label: "Development", value: "Development" },
        { label: "Not Applicable", value: "Not Applicable" }
    ];

    // Wire to get current user's name
    @wire(getRecord, { recordId: "$currentUserId", fields: [USER_NAME] })
    wiredUser({ error, data }) {
        if (data) {
            this.currentUserName = getFieldValue(data, USER_NAME);
        } else if (error) {
            console.error("Error fetching user:", error);
            this.currentUserName = "Current User";
        }
    }

    @wire(checkTicketAccess)
    wiredAccess({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.accessDenied = !data.hasAccess;
        } else if (error) {
            this.accessDenied = true;
            console.error("Error checking access:", error);
        }
    }

    // Wire to get the context record details (if on a record page)
    @wire(getRecord, { recordId: "$recordId", layoutTypes: ["Compact"] })
    wiredRecord({ error, data }) {
        if (data) {
            const apiName = data.apiName;
            
            // Skip if this is somehow returning User record for the current user
            // (Global Actions sometimes return the current user's ID)
            if (apiName === "User" && data.id === this.currentUserId) {
                this.recordName = "";
                this.recordType = "";
                return;
            }

            const fields = data.fields;
            
            // Get record name based on object type
            if (fields.Name?.value) {
                this.recordName = fields.Name.value;
            } else if (fields.Subject?.value) {
                this.recordName = fields.Subject.value;
            } else if (fields.CaseNumber?.value) {
                this.recordName = fields.CaseNumber.value;
            } else if (fields.Title?.value) {
                this.recordName = fields.Title.value;
            } else {
                // Don't fall back to ID - just leave it empty if no name found
                this.recordName = "";
            }
            
            this.recordApiName = apiName;
            this.recordType = this.getObjectLabel(apiName);
            this.recordIcon = this.getObjectIcon(apiName);
            
            // Pre-populate description with record context if we have a valid record
            if (this.recordName && !this.description) {
                this.description = `Related to ${this.recordType}: ${this.recordName}\n\n`;
            }
        } else if (error) {
            // Don't show error for missing record - just means we're not on a record page
            console.log("No record context available");
        }
    }

    get hasRecordContext() {
        return this.recordId && this.recordName && this.recordApiName !== "User";
    }

    get showForm() {
        return !this.isLoading && !this.accessDenied && !this.isSubmitted;
    }

    get submitButtonLabel() {
        if (this.isSubmitting) {
            return "Submitting...";
        }
        return this.hasFiles ? `Submit Ticket with ${this.fileCount} Screenshot(s)` : "Submit Ticket";
    }

    get hasFiles() {
        return this.selectedFiles.length > 0;
    }

    get fileCount() {
        return this.selectedFiles.length;
    }

    get totalFileSize() {
        const totalBytes = this.selectedFiles.reduce((sum, file) => sum + file.size, 0);
        return this.formatFileSize(totalBytes);
    }

    getObjectLabel(apiName) {
        const labels = {
            Account: "Account",
            Contact: "Contact",
            Opportunity: "Opportunity",
            Lead: "Lead",
            Case: "Case",
            Order: "Order",
            Contract: "Contract",
            Campaign: "Campaign",
            Product2: "Product",
            Asset: "Asset",
            User: "User",
            Task: "Task",
            Event: "Event"
        };
        // Handle custom objects by removing __c and replacing underscores
        if (!labels[apiName] && apiName) {
            return apiName.replace("__c", "").replace(/_/g, " ");
        }
        return labels[apiName] || "Record";
    }

    getObjectIcon(apiName) {
        const icons = {
            Account: "standard:account",
            Contact: "standard:contact",
            Opportunity: "standard:opportunity",
            Lead: "standard:lead",
            Case: "standard:case",
            Order: "standard:order",
            Contract: "standard:contract",
            Campaign: "standard:campaign",
            Product2: "standard:product",
            Asset: "standard:asset",
            User: "standard:user",
            Task: "standard:task",
            Event: "standard:event"
        };
        return icons[apiName] || "standard:record";
    }

    formatFileSize(bytes) {
        if (bytes === 0) {
            return "0 Bytes";
        }
        const k = 1024;
        const sizes = ["Bytes", "KB", "MB", "GB"];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
        this.errorMessage = "";
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
    }

    handleCategoryChange(event) {
        this.category = event.detail.value;
    }

    handleImpactChange(event) {
        this.impact = event.detail.value;
    }

    handleEnvironmentChange(event) {
        this.environment = event.detail.value;
    }

    handleFileChange(event) {
        this.fileError = "";
        const files = Array.from(event.target.files);
        
        if (files.length + this.selectedFiles.length > MAX_FILES) {
            this.fileError = `Maximum ${MAX_FILES} files allowed.`;
            return;
        }

        for (const file of files) {
            if (file.size > MAX_FILE_SIZE) {
                this.fileError = `File "${file.name}" exceeds 5MB limit.`;
                return;
            }

            if (!file.type.startsWith("image/")) {
                this.fileError = `File "${file.name}" is not an image.`;
                return;
            }

            if (this.selectedFiles.some(f => f.name === file.name)) {
                this.fileError = `File "${file.name}" is already selected.`;
                return;
            }
        }

        const newFiles = files.map(file => ({
            name: file.name,
            size: file.size,
            sizeLabel: this.formatFileSize(file.size),
            type: file.type,
            file: file
        }));

        this.selectedFiles = [...this.selectedFiles, ...newFiles];
    }

    handleRemoveFile(event) {
        const fileName = event.currentTarget.dataset.filename;
        this.selectedFiles = this.selectedFiles.filter(f => f.name !== fileName);
        this.fileError = "";
    }

    async readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(",")[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    async handleSubmit() {
        if (!this.subject || !this.subject.trim()) {
            this.errorMessage = "Please enter a subject.";
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = "";
        this.uploadProgress = 0;

        try {
            let fullDescription = this.description || "";
            if (this.hasRecordContext) {
                fullDescription += `\n\n---\nContext: ${this.recordType} - ${this.recordName} (${this.recordId})`;
            }

            this.uploadStatus = "Creating ticket...";
            this.uploadProgress = 10;

            this.createdTicketId = await createTicket({
                subject: this.subject,
                description: fullDescription,
                priority: this.priority,
                category: this.category || null,
                impact: this.impact,
                environment: this.environment,
                relatedRecordId: this.hasRecordContext ? this.recordId : null
            });

            this.uploadProgress = 30;

            if (this.hasFiles) {
                const progressPerFile = 60 / this.selectedFiles.length;
                
                for (let i = 0; i < this.selectedFiles.length; i++) {
                    const fileInfo = this.selectedFiles[i];
                    this.uploadStatus = `Uploading screenshot ${i + 1} of ${this.selectedFiles.length}...`;
                    
                    const base64Data = await this.readFileAsBase64(fileInfo.file);
                    
                    await attachFile({
                        ticketId: this.createdTicketId,
                        fileName: fileInfo.name,
                        base64Data: base64Data,
                        contentType: fileInfo.type
                    });
                    
                    this.uploadProgress = 30 + (progressPerFile * (i + 1));
                }
            }

            this.uploadProgress = 100;
            this.uploadStatus = "Complete!";
            this.isSubmitted = true;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Ticket created successfully" + (this.hasFiles ? ` with ${this.fileCount} screenshot(s)` : ""),
                    variant: "success"
                })
            );
        } catch (error) {
            this.errorMessage = error.body?.message || "An error occurred while creating the ticket.";
        } finally {
            this.isSubmitting = false;
        }
    }

    handleViewTicket() {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.createdTicketId,
                objectApiName: "tkt_Ticket__c",
                actionName: "view"
            }
        });
        this.handleClose();
    }

    handleCancel() {
        this.handleClose();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent("close"));
    }
}