import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateDescription from"@salesforce/apex/SpringCMConnector.updateDescription";


export default class ClmFiles extends LightningElement {
    @api label;
    @api des;
    @api recordId;
    @api value;
    @api uploadUrl;
    @track files;
    selectedFile;

    @api getVal() {
        const { value } = this;
        try {
            this.files = JSON.parse(value);    
            return value;
        } catch(ex ) {
            if(this.files && this.files.length) {
                return JSON.stringify(this.files);
            } else {
                return null;
            }
            
        } 
    }

    connectedCallback() {
        const { value } = this;
        if(value) {
            try {
                this.files = JSON.parse(value);    
            } catch(ex ) {
                this.files = [];
                this.value = null;
            }
        } else {
            this.files = [];
        }
    }

    handleUploadFinished(event) {
        const newFiles = event.detail.files;
        const { files } = this;
        if(files ) {
            this.files = [...files, ...newFiles];
        } else {
            this.files = [...newFiles];
        }
        this.saveDescription(newFiles);
    }
    openCommentBox(event) {
        const fileURL = event.currentTarget.accessKey;
        const selectedFiles = this.files.filter((file) => file.fileUrl === fileURL);
        if(selectedFiles && selectedFiles.length) {
            this.selectedFile = selectedFiles[0];
        }
    }

    closeComment() {
        this.selectedFile = null;
    }
    async saveDescription(newFiles) {
        const fileURL = newFiles[0].fileUrl; 
        const { des } = this;
        const result = await updateDescription({fileURL, des});
        if(result) {
            const { files } = this;
            this.files = files.reduce((result, file) => {
                if(file.fileUrl === fileURL) {
                    file.comment = des;
                }
                return [...result, file];
            }, []);
            const value = JSON.stringify(this.files);
            this.dispatchEvent(new CustomEvent("capturechange", {detail: {value}}));
        }
    }
    async saveComment() {
        const fileURL = this.selectedFile.fileUrl; 
        const des = this.template.querySelector("lightning-textarea").value;
        const result = await updateDescription({fileURL, des});
        if(result) {
            const { files } = this;
            this.files = files.reduce((result, file) => {
                if(file.fileUrl === fileURL) {
                    file.comment = des;
                }
                return [...result, file];
            }, []);

            this.closeComment();
            this.dispatchEvent(new ShowToastEvent({
                title: "Success",
                variant: "success",
                message: "Comments have been saved successfully!"
              }));
              const value = JSON.stringify(this.files);
              this.dispatchEvent(new CustomEvent("capturechange", {detail: {value}}));
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: "Error",
                variant: "error",
                message: "There is an error saving comments"
              }));
        }
    }
    deleteDoc(event) {
        const url = event.currentTarget.accessKey;
        // try not to delete file as there may be syncing issues. 
        // await deleteFile({url});
        const { files } = this;
        this.files = files.reduce((result, file) => {
            if(file.fileUrl !== url) {
                return [...result, file];
            } else {
                return [...result];
            }
            
        }, []);
        this.dispatchEvent(new ShowToastEvent({
            title: "Success",
            variant: "success",
            message: "File has been deleted successfully!"
            }));
        const value = JSON.stringify(this.files);
        this.dispatchEvent(new CustomEvent("capturechange", {detail: {value}}));
        
    }
}