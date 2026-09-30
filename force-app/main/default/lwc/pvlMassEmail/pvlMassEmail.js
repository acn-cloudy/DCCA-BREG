import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import runMassEmail from '@salesforce/apex/PVL_MassEmailController.runMassEmail';
import getEmailTemplates from '@salesforce/apex/PVL_MassEmailController.getEmailTemplates';
import getStatusPicklistValues from '@salesforce/apex/PVL_MassEmailController.getStatusPicklistValues';
import getMolPicklistValues from '@salesforce/apex/PVL_MassEmailController.getMolPicklistValues';
import getPrivilegePicklistValues from '@salesforce/apex/PVL_MassEmailController.getPrivilegePicklistValues';
import getClassificationValues from '@salesforce/apex/PVL_MassEmailController.getClassificationValues';

export default class PvlMassEmail extends LightningElement {
    @api recordId;

    // Form state
    target = 'Licenses';
    contentType = 'Template';
    selectedTemplateId = '';
    subject = '';
    body = '';
    selectedStatuses = [];
    selectedMol = [];
    selectedPrivileges = [];
    selectedClassifications = [];

    // UI state
    emailTemplates = [];
    statusOptions = [];
    molOptions = [];
    privilegeOptions = [];
    classificationOptions = [];
    isSubmitting = false;
    isLoading = true;

    // ── Options ──────────────────────────────────────────────

    get targetOptions() {
        return [
            { label: 'Licenses', value: 'Licenses' },
            { label: 'Applications', value: 'Applications' }
        ];
    }

    get contentTypeOptions() {
        return [
            { label: 'Email Template', value: 'Template' },
            { label: 'Free Text', value: 'FreeText' }
        ];
    }

    get emailTemplateOptions() {
        return this.emailTemplates.map(t => ({
            label: t.name,
            value: t.id
        }));
    }

    // ── Computed ─────────────────────────────────────────────

    get isTemplate() {
        return this.contentType === 'Template';
    }

    get isFreeText() {
        return this.contentType === 'FreeText';
    }

    get isLicenses() {
        return this.target === 'Licenses';
    }

    get isApplications() {
        return this.target === 'Applications';
    }

    get mergeTagHelpText() {
        return 'Supported merge tags: {!Name}, {!LicenseNumber}, {!LicenseType}';
    }

    get classificationLabel() {
        return this.target === 'Applications' ? 'Application Classification' : 'License Classification';
    }

    // ── Wire: load email templates ──────────────────────────

    @wire(getEmailTemplates)
    wiredTemplates({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.emailTemplates = data;
        } else if (error) {
            console.error('Error loading email templates', error);
            this.showToast('Error', 'Failed to load email templates.', 'error');
        }
    }

    // ── Wire: load status picklist values ────────────────────

    @wire(getStatusPicklistValues, { target: '$target' })
    wiredStatuses({ error, data }) {
        if (data) {
            this.statusOptions = data.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } else if (error) {
            console.error('Error loading status values', error);
        }
    }

    // ── Wire: load MOL picklist values ───────────────────────

    @wire(getMolPicklistValues, { target: '$target' })
    wiredMol({ error, data }) {
        if (data) {
            this.molOptions = data.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } else if (error) {
            console.error('Error loading MOL values', error);
        }
    }

    // ── Wire: load Privilege picklist values ──────────────────

    @wire(getPrivilegePicklistValues)
    wiredPrivileges({ error, data }) {
        if (data) {
            this.privilegeOptions = data.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } else if (error) {
            console.error('Error loading privilege values', error);
        }
    }

    // ── Wire: load Classification values ──────────────────────

    @wire(getClassificationValues, { licenseTypeId: '$recordId' })
    wiredClassifications({ error, data }) {
        if (data) {
            this.classificationOptions = data.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } else if (error) {
            console.error('Error loading classification values', error);
        }
    }

    // ── Change handlers ─────────────────────────────────────

    handleTargetChange(event) {
        this.target = event.detail.value;
        // Reset filter selections when target changes (different picklist values)
        this.selectedStatuses = [];
        this.selectedMol = [];
        this.selectedPrivileges = [];
        this.selectedClassifications = [];
    }

    handleContentTypeChange(event) {
        this.contentType = event.detail.value;
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
    }

    handleBodyChange(event) {
        this.body = event.detail.value;
    }

    handleStatusFilterChange(event) {
        this.selectedStatuses = event.detail.value;
    }

    handleMolFilterChange(event) {
        this.selectedMol = event.detail.value;
    }

    handleSpecialPrivilegeFilterChange(event) {
        this.selectedPrivileges = event.detail.value;
    }

    handleClassificationFilterChange(event) {
        this.selectedClassifications = event.detail.value;
    }

    // ── Actions ─────────────────────────────────────────────

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSubmit() {
        if (!this.validate()) {
            return;
        }

        this.isSubmitting = true;

        const statusList = this.selectedStatuses;
        const molList = this.selectedMol;
        const privilegeList = this.selectedPrivileges;
        const classificationList = this.selectedClassifications;

        runMassEmail({
            licenseTypeId: this.recordId,
            target: this.target,
            contentType: this.contentType,
            emailTemplateId: this.isTemplate ? this.selectedTemplateId : null,
            subject: this.isFreeText ? this.subject : null,
            body: this.isFreeText ? this.body : null,
            statusFilter: statusList,
            molFilter: molList,
            specialPrivilegeFilter: privilegeList,
            classificationFilter: classificationList
        })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                const message = error.body ? error.body.message : 'An unexpected error occurred.';
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    // ── Helpers ──────────────────────────────────────────────

    validate() {
        if (this.isTemplate && !this.selectedTemplateId) {
            this.showToast('Validation Error', 'Please select an email template.', 'error');
            return false;
        }
        if (this.isFreeText && !this.subject) {
            this.showToast('Validation Error', 'Please enter an email subject.', 'error');
            return false;
        }
        if (this.isFreeText && !this.body) {
            this.showToast('Validation Error', 'Please enter an email body.', 'error');
            return false;
        }
        return true;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}