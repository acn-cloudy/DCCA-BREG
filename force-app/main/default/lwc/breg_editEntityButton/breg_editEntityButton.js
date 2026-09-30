import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import findEditableFields from '@salesforce/apex/BREGEditEntityButtonController.findEditableFields';
import validateBeforeSave from '@salesforce/apex/BREGEditEntityButtonController.validateBeforeSave';

export default class Breg_editEntityButton extends LightningElement {
    _recordId;
    isLoading = true;
    isSaving = false;
    isAllowed = false;
    errorMessage;

    step = 1;
    editableFields = [];
    selectedFieldNames = [];

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.initialize();
        }
    }

    async initialize() {
        this.isLoading = true;
        this.errorMessage = null;
        this.step = 1;
        this.selectedFieldNames = [];

        try {
            const result = await findEditableFields({ accountId: this.recordId });
            this.isAllowed = result.allowed;
            this.errorMessage = result.message;
            this.editableFields = result.editableFields || [];
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleCheckboxChange(event) {
        const fieldName = event.target.dataset.fieldName;
        const checked = event.target.checked;

        if (checked) {
            if (!this.selectedFieldNames.includes(fieldName)) {
                this.selectedFieldNames = [...this.selectedFieldNames, fieldName];
            }
        } else {
            this.selectedFieldNames = this.selectedFieldNames.filter(name => name !== fieldName);
        }
    }

    handleNext() {
        this.errorMessage = null;

        if (!this.selectedFieldNames.length) {
            this.errorMessage = 'Please select at least one field to edit.';
            return;
        }

        this.step = 2;
    }

    handleBack() {
        this.errorMessage = null;
        this.step = 1;
    }

    async handleSubmit(event) {
        event.preventDefault();
        this.errorMessage = null;
        this.isSaving = true;

        try {
            await validateBeforeSave({ accountId: this.recordId });

            const fields = event.detail.fields;
            const form = this.template.querySelector('lightning-record-edit-form');

            if (!form) {
                throw new Error('Record edit form was not found.');
            }

            form.submit(fields);
        } catch (e) {
            this.isSaving = false;
            this.errorMessage = this.normalizeError(e);
        }
    }

    handleSuccess() {
        this.isSaving = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Account was updated successfully.',
                variant: 'success'
            })
        );

        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleError(event) {
        this.isSaving = false;
        this.errorMessage = this.normalizeError(event.detail);
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    get disableButtons() {
        return this.isLoading || this.isSaving;
    }

    get hasEditableFields() {
        return this.editableFields.length > 0;
    }

    get isStep1() {
        return this.step === 1;
    }

    get isStep2() {
        return this.step === 2;
    }

    get fieldOptions() {
        return this.editableFields.map(field => ({
            label: field.label,
            value: field.fieldName,
            checked: this.selectedFieldNames.includes(field.fieldName)
        }));
    }

    get fieldOptionsLeft() {
        const options = this.fieldOptions;
        const middle = Math.ceil(options.length / 2);
        return options.slice(0, middle);
    }

    get fieldOptionsRight() {
        const options = this.fieldOptions;
        const middle = Math.ceil(options.length / 2);
        return options.slice(middle);
    }

    get selectedSectionsForForm() {
        return this.editableFields
            .filter(field => this.selectedFieldNames.includes(field.fieldName))
            .map((field, index) => {
                const isAddressGroup = field.isAddressGroup === true;
                const renderAsCompound = field.renderAsCompound === true;

                if (isAddressGroup && renderAsCompound) {
                    return {
                        key: `section-${field.fieldName}-${index}`,
                        label: field.label,
                        fieldName: field.fieldName,
                        isCompoundAddress: true,
                        isCustomAddressGroup: false,
                        isRegularSection: false,
                        fields: []
                    };
                }

                if (isAddressGroup) {
                    const children = [...(field.childFields || [])];

                    const getOrder = (fieldName) => {
                        const lower = (fieldName || '').toLowerCase();

                        if (lower.includes('country')) {
                            return 1;
                        }
                        if (lower.includes('street')) {
                            return 2;
                        }
                        if (lower.includes('city')) {
                            return 3;
                        }
                        if (lower.includes('state') || lower.includes('province') || lower.includes('statecode')) {
                            return 4;
                        }
                        if (lower.includes('postal') || lower.includes('zip')) {
                            return 5;
                        }

                        return 99;
                    };

                    const getClassName = (fieldName) => {
                        const lower = (fieldName || '').toLowerCase();

                        if (lower.includes('country')) {
                            return 'slds-col slds-size_1-of-1 slds-p-horizontal_x-small slds-m-bottom_small';
                        }
                        if (lower.includes('street')) {
                            return 'slds-col slds-size_1-of-1 slds-p-horizontal_x-small slds-m-bottom_small';
                        }
                        if (
                            lower.includes('city') ||
                            lower.includes('state') ||
                            lower.includes('province') ||
                            lower.includes('statecode')
                        ) {
                            return 'slds-col slds-size_1-of-2 slds-p-horizontal_x-small slds-m-bottom_small';
                        }
                        if (lower.includes('postal') || lower.includes('zip')) {
                            return 'slds-col slds-size_1-of-1 slds-p-horizontal_x-small slds-m-bottom_small';
                        }

                        return 'slds-col slds-size_1-of-1 slds-p-horizontal_x-small slds-m-bottom_small';
                    };

                    const childFields = children
                        .sort((a, b) => getOrder(a.fieldName) - getOrder(b.fieldName))
                        .map((child, childIndex) => ({
                            key: `${field.fieldName}-${child.fieldName}-${childIndex}`,
                            fieldName: child.fieldName,
                            label: child.label,
                            className: getClassName(child.fieldName)
                        }));

                    return {
                        key: `section-${field.fieldName}-${index}`,
                        label: field.label,
                        fieldName: field.fieldName,
                        isCompoundAddress: false,
                        isCustomAddressGroup: true,
                        isRegularSection: false,
                        fields: childFields
                    };
                }

                return {
                    key: `section-${field.fieldName}-${index}`,
                    label: field.label,
                    fieldName: field.fieldName,
                    isCompoundAddress: false,
                    isCustomAddressGroup: false,
                    isRegularSection: true,
                    fields: [{
                        key: `${field.fieldName}-${index}`,
                        fieldName: field.fieldName,
                        label: field.label
                    }]
                };
            });
    }

    normalizeError(error) {
        if (!error) {
            return 'Unknown error';
        }

        if (Array.isArray(error.body)) {
            return error.body.map(item => item.message).join(', ');
        }

        if (error.body?.message) {
            return error.body.message;
        }

        if (error.detail?.message) {
            return error.detail.message;
        }

        if (error.message) {
            return error.message;
        }

        if (error.output?.errors?.length) {
            return error.output.errors.map(item => item.message).join(', ');
        }

        return 'Unknown error';
    }
}