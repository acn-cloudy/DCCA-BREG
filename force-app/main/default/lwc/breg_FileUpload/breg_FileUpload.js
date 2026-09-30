import { api } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import FILE_IS_REQUIRED from '@salesforce/label/c.BREG_FileIsRequired';

export default class Breg_FileUpload extends BaseFormComponent {
    defaultTitle = "Upload File";
    maxFileNameLength = 200;

    @api uploadTarget = "generic";
    @api files = [];
    @api hideTitle = false;
    @api descriptionOverride = "";
    @api description2Override = "";

    acceptedFormats = ".pdf,.jpg,.jpeg,.bmp,.tif,.tiff,.gif,.png";
    maxFileSize = 5 * 1024 * 1024; // 3MB in bytes
    uploadedFile;

    fileIcon = "utility:file";
    fileUploaded = false;
    fileName;

    fileErrorMessage = "";

    connectedCallback() {
        super.connectedCallback();
        this.uploadTarget = this.componentSettings?.setFileUploadTarget || this.uploadTarget;

        if (this.componentSettings?.title && !this.isNested) {
            this.title = this.componentSettings?.title;
        }

        const existingFile = this.files.find((file) => this.isMatchingFile(file));
        if (existingFile) {
            this.fileName = existingFile.fileName;
            const fileExtension = "." + existingFile.fileName.split(".").pop().toLowerCase();
            this.fileIcon = fileExtension === ".pdf" ? "doctype:pdf" : "utility:file";
            this.fileUploaded = true;
        }
    }

    async handleFileUpload(event) {
        const files = event.target.files;
        if (files.length > 0) {
            const file = files[0];

            if (file.name.length > this.maxFileNameLength) {
                this.setCustomValidity(`File name exceeds ${this.maxFileNameLength} characters limit`);
                this.resetFileInput();
                return;
            }

            // Validate file size
            if (file.size > this.maxFileSize) {
                // Show error - file too large
                this.setCustomValidity("File size exceeds 5MB limit");
                this.resetFileInput();
                return;
            }

            // Validate file format
            const fileExtension = "." + file.name.split(".").pop().toLowerCase();
            const allowedFormats = this.acceptedFormats.split(",");
            if (!allowedFormats.includes(fileExtension)) {
                // Show error - invalid format
                this.setCustomValidity("Invalid file format. Please use " + this.acceptedFormatsString);
                this.resetFileInput();
                return;
            }

            this.uploadedFile = file;
            this.setCustomValidity("");
            this.fileUploaded = true;
            this.fileName = file.name;
            this.fileIcon = fileExtension === ".pdf" ? "doctype:pdf" : "utility:file";

            try {
                const fileBody = await this.fileToBase64(file);
                // Dispatch change event with file information
                this.dispatchCustomEvent("fileupload", {
                    fileName: file.name,
                    base64Data: this.stripDataUrlPrefix(fileBody),
                    fileType: file.type,
                    id: file.id,
                    uploadTarget: this.uploadTarget,
                    configId: this.config?.id || null
                });
            } catch (error) {
                console.error("Error converting file to base64:", error);
                this.setCustomValidity("Error processing file. Please try again.");
                this.resetFileInput();
            }
        }
    }

    handleRemoveFile() {
        const removedFileId = this.uploadedFile?.id;
        this.uploadedFile = null;
        this.fileUploaded = false;
        this.fileName = null;
        this.fileIcon = "utility:file";
        this.fileErrorMessage = "";
        this.resetFileInput();

        // Dispatch change event indicating file removal
        this.dispatchCustomEvent("fileremove", {
            id: removedFileId,
            uploadTarget: this.uploadTarget,
            configId: this.config?.id || null
        });
    }

    handleDragOver(event) {
        event.preventDefault();
        event.currentTarget.classList.add("slds-has-drag-over");
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.currentTarget.classList.remove("slds-has-drag-over");
    }

    handleDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove("slds-has-drag-over");

        const files = event.dataTransfer.files;
        if (files.length > 0) {
            // Simulate file input change
            const fileInput = this.template.querySelector('input[type="file"]');
            const dataTransfer = new DataTransfer();
            dataTransfer.items.add(files[0]);
            fileInput.files = dataTransfer.files;

            // Trigger file upload handler
            this.handleFileUpload({ target: { files: files } });
        }
    }

    handleChooseFile() {
        const fileInput = this.template.querySelector('input[type="file"]');
        fileInput.click();
    }

    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result);
            reader.onerror = (error) => reject(error);
        });
    }

    stripDataUrlPrefix(dataUrl) {
        const base64Index = dataUrl.indexOf("base64,");
        return base64Index !== -1 ? dataUrl.substring(base64Index + 7) : dataUrl;
    }

    resetFileInput() {
        const fileInput = this.template?.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.value = null;
        }
    }

    isMatchingFile(file) {
        if (file.configId !== this.config?.id) {
            return false;
        }

        if (file.uploadTarget) {
            return file.uploadTarget === this.uploadTarget;
        }

        return true;
    }

    get description() {
        let defaultDescription = !this.isNested ? this.config?.labelOverrideLong : this.descriptionOverride;
        if (this.readOnly) {
            return this.componentSettings?.fileUploadDescriptionReadOnly ?? defaultDescription;
        }
        return defaultDescription;
    }

    get description2() {
        return !this.isNested ? this.config?.labelOverrideLong2 : this.description2Override;
    }

    get acceptedFormatsString() {
        return this.acceptedFormats?.toUpperCase().replace(/,/g, ", ");
    }

    get displayUploadArea() {
        return this.editMode || this.showEditSectionButton;
    }

    get showMainDescription() {
        return this.showDescription || this.componentSettings?.showDescriptionInReadOnly;
    }

    @api
    reportValidity() {
        if (!this.required) {
            this.fileErrorMessage = "";
            return true;
        }

        if (!this.fileUploaded) {
            this.fileErrorMessage = FILE_IS_REQUIRED;
            return false;
        }

        this.fileErrorMessage = "";
        return true;
    }

    @api
    checkValidity() {
        return !this.required || this.fileUploaded;
    }
}