import { api } from 'lwc';
import StartNewBusinessWizardComponent from 'c/breg_StartNewBusinessWizard';

export default class Breg_TNTMSMPage extends StartNewBusinessWizardComponent {
    searchValue = '';
    searchType = '';
    @api isNotGuest;

    steps = [
        "Initial Information",
        "Search",
        "Form Filling",
        "Form Review",
        "Forms and Fees"
    ];

    businessProcessOptions = [
        { label: 'I would like to register a trade name, trademark, service mark or publicity rights in Hawaii', value: 'Name Registration' },
        { label: 'I would like to renew, file assignment, or file an address change for an already registered trade name or trademark or service mark or publicity rights in Hawaii', value: 'Change' }
    ];

    get continueButtonDisabled() {
        let isDisabled = true;        
        if (this.businessProcessValue === 'Name Registration') {
            if (this.registrationTypeValue) {
                isDisabled = false;
            }
        } else if (this.businessProcessValue === 'Change') {
            isDisabled = false;
        }
        return isDisabled;
    }

    get searchStep() {
        return this.currentStep === "Search";
    }

    get dynamicFormsHeaderTitle() {
        return "Business Filing";
    }

    get showGeneralControlButtons() {
        return this.searchStep || this.formDataStep;
    }



    handleBack() {
        if (this.businessProcessValue === 'Name Registration' && this.currentStep === "Form Filling") {
            this.setStep(-2);
        } else {
            this.setStep(-1);
        }
    }

    handleContinue() {
        if (this.businessProcessValue === 'Name Registration' && this.currentStep === "Initial Information") {
            this.loadFormConfiguration();
            this.setStep(2);
        } else  {
            this.setStep(1);
        }
    }

    handleConfirm() {
        this.setStep(1);
    }

    // Open details
    handleOpenDetails(event) {
        let recordId = event.detail.recordId;
        window.location.href = `/search-and-buy?entityId=${recordId}&activeTab=forms`;
    }

    handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
    }
}