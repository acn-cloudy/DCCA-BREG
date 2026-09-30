import { LightningElement, api } from 'lwc';

export default class Breg_HelpTextPopup extends LightningElement {

    @api label;
    @api title;
    @api message;
    @api nextButtonLabel;
    @api cancelButtonLabel = 'Close';
    @api hideNextButton;
    @api hideTrigger = false;
    @api size = 'medium';

    isOpen = false;
    modalTitle;
    modalContent;

    get showTrigger() {
        return !this.hideTrigger && !!this.label;
    }

    get resolvedTitle() {
        return this.modalTitle ?? this.title;
    }

    get resolvedMessage() {
        return this.modalContent ?? this.message;
    }

    get showNextButton() {
        return this.hideNextButton === false || this.hideNextButton === 'false';
    }

    get normalizedSize() {
        const size = (this.size || 'medium').toLowerCase();
        if (size === 'small' || size === 'large') {
            return size;
        }
        return 'medium';
    }

    get modalContainerClass() {
        return `slds-modal__container help-text-popup__container help-text-popup__container_size-${this.normalizedSize}`;
    }

    handleOpenClick(event) {
        event.preventDefault();
        this.open();
    }

    handleCancel() {
        this.close();
        this.dispatchEvent(new CustomEvent("cancel"));
    }

    handleContinue() {
        this.close();
        this.dispatchEvent(new CustomEvent("continue"));
    }

    @api open(title = this.title, message = this.message) {
        this.modalTitle = title ?? this.title;
        this.modalContent = message ?? this.message;
        this.isOpen = true;
    }

    @api close() {
        this.isOpen = false;
        this.modalTitle = undefined;
        this.modalContent = undefined;
    }
}