import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMyTickets from "@salesforce/apex/tkt_TicketController.getMyTickets";
import getTicketWithComments from "@salesforce/apex/tkt_TicketController.getTicketWithComments";
import addComment from "@salesforce/apex/tkt_TicketController.addComment";
import closeTicket from "@salesforce/apex/tkt_TicketController.closeTicket";

export default class TktMyTickets extends LightningElement {
    @track tickets = [];
    @track selectedTicket = null;
    @track comments = [];
    
    isLoading = true;
    hasError = false;
    errorMessage = "";
    
    newComment = "";
    isAddingComment = false;
    
    // Close ticket state
    showCloseModal = false;
    closeNote = "";
    isClosingTicket = false;

    connectedCallback() {
        this.loadTickets();
    }

    get showList() {
        return !this.selectedTicket;
    }

    get showDetail() {
        return this.selectedTicket !== null;
    }

    get hasTickets() {
        return this.tickets.length > 0;
    }

    get ticketCount() {
        return this.tickets.length;
    }

    get hasComments() {
        return this.comments.length > 0;
    }

    get commentCount() {
        return this.comments.length;
    }

    get addCommentButtonLabel() {
        return this.isAddingComment ? "Posting..." : "Post Comment";
    }

    get isAddCommentDisabled() {
        return this.isAddingComment || !this.newComment || !this.newComment.trim();
    }

    get canCloseTicket() {
        return this.selectedTicket && this.selectedTicket.Status__c !== 'Closed';
    }

    get closeButtonLabel() {
        return this.isClosingTicket ? "Closing..." : "Close Ticket";
    }

    async loadTickets() {
        this.isLoading = true;
        this.hasError = false;
        
        try {
            const result = await getMyTickets();
            this.tickets = result.map(ticket => this.formatTicket(ticket));
        } catch (error) {
            this.hasError = true;
            this.errorMessage = error.body?.message || "Failed to load tickets.";
        } finally {
            this.isLoading = false;
        }
    }

    formatTicket(ticket) {
        return {
            ...ticket,
            formattedDate: this.formatDate(ticket.CreatedDate),
            formattedDueDate: ticket.Due_Date__c ? this.formatDate(ticket.Due_Date__c) : null,
            statusClass: this.getStatusClass(ticket.Status__c),
            priorityClass: this.getPriorityClass(ticket.Priority__c),
            categoryDisplay: ticket.Category__c || "—",
            impactDisplay: ticket.Impact__c || "—",
            environmentDisplay: ticket.Environment__c || "—",
            relatedRecordUrl: ticket.Related_Record_Id__c ? `/${ticket.Related_Record_Id__c}` : null
        };
    }

    formatDate(dateString) {
        if (!dateString) {
            return "";
        }
        const date = new Date(dateString);
        return date.toLocaleDateString("en-US", {
            year: "numeric",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit"
        });
    }

    getStatusClass(status) {
        const classes = {
            "New": "slds-badge_inverse",
            "In Progress": "slds-theme_warning",
            "Pending": "slds-theme_warning",
            "Resolved": "slds-theme_success",
            "Closed": "slds-theme_shade"
        };
        return classes[status] || "";
    }

    getPriorityClass(priority) {
        const classes = {
            "Low": "",
            "Medium": "",
            "High": "slds-theme_warning",
            "Critical": "slds-theme_error"
        };
        return classes[priority] || "";
    }

    async handleTicketClick(event) {
        const ticketId = event.currentTarget.dataset.id;
        this.isLoading = true;
        
        try {
            const result = await getTicketWithComments({ ticketId: ticketId });
            this.selectedTicket = this.formatTicket(result.ticket);
            this.comments = result.comments.map(comment => ({
                ...comment,
                formattedDate: this.formatDate(comment.CreatedDate),
                postedByName: comment.Posted_By__r?.Name || "Unknown"
            }));
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: error.body?.message || "Failed to load ticket details.",
                    variant: "error"
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToList() {
        this.selectedTicket = null;
        this.comments = [];
        this.newComment = "";
    }

    handleCommentChange(event) {
        this.newComment = event.target.value;
    }

    async handleAddComment() {
        if (!this.newComment || !this.newComment.trim()) {
            return;
        }

        this.isAddingComment = true;

        try {
            await addComment({
                ticketId: this.selectedTicket.Id,
                commentBody: this.newComment
            });

            // Refresh comments
            const result = await getTicketWithComments({ ticketId: this.selectedTicket.Id });
            this.comments = result.comments.map(comment => ({
                ...comment,
                formattedDate: this.formatDate(comment.CreatedDate),
                postedByName: comment.Posted_By__r?.Name || "Unknown"
            }));

            this.newComment = "";

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Comment added successfully.",
                    variant: "success"
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: error.body?.message || "Failed to add comment.",
                    variant: "error"
                })
            );
        } finally {
            this.isAddingComment = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent("close"));
    }

    // Close ticket methods
    handleOpenCloseModal() {
        this.showCloseModal = true;
        this.closeNote = "";
    }

    handleCancelClose() {
        this.showCloseModal = false;
        this.closeNote = "";
    }

    handleCloseNoteChange(event) {
        this.closeNote = event.target.value;
    }

    async handleConfirmClose() {
        this.isClosingTicket = true;

        try {
            await closeTicket({
                ticketId: this.selectedTicket.Id,
                closeNote: this.closeNote
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Success",
                    message: "Ticket closed successfully.",
                    variant: "success"
                })
            );

            // Refresh the ticket detail
            const result = await getTicketWithComments({ ticketId: this.selectedTicket.Id });
            this.selectedTicket = this.formatTicket(result.ticket);
            this.comments = result.comments.map(comment => ({
                ...comment,
                formattedDate: this.formatDate(comment.CreatedDate),
                postedByName: comment.Posted_By__r?.Name || "Unknown"
            }));

            this.showCloseModal = false;
            this.closeNote = "";

        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "Error",
                    message: error.body?.message || "Failed to close ticket.",
                    variant: "error"
                })
            );
        } finally {
            this.isClosingTicket = false;
        }
    }
}