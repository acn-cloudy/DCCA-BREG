import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createRequest from '@salesforce/apex/CATV_SelfRegistrationController.createContactAndAccountRequest';
import decrypt from '@salesforce/apex/CATV_SelfRegistrationController.decrypt';
export default class Catv_registration_page extends NavigationMixin(LightningElement){
    @track registrationObj = {};
    @track showMessage = false;
    @track successMessage = false;
    @track isValid;
    @track showSpinner = false;
    @track decryptedEmail;
    liveMessage;
    
    

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            let encryptedEmail = currentPageReference.state?.email;
            decrypt({ 
                data : encryptedEmail
            }).then(result => {
                this.decryptedEmail = result;
                this.registrationObj['email'] = result;
        
            }).catch(error => {
                this.showToast("Error", error.body.pageErrors ? error.body.pageErrors[0].message : error.body.message, "error");
            })
        }
    }

    get providerOptions() {
        return [{
                label: 'Provider',
                value: 'Provider'
            },
            {
                label: 'Requestor',
                value: 'Requestor'
            }
        ];
    }

    handleInput(event){
        let name = event.target.name;
        let value = event.target.value;
        this.registrationObj[name] = value;


        if(name == 'phoneNo'){
            this.formatPhone(event.target);
        }else if(name == 'provideOrRequestor'){
            if(this.registrationObj.accountId){
                this.registrationObj.accountId = null;
                this.template.querySelector('c-catv_custom_lookup').removeSelectedAccount();
            }
        }
    }

    handleAccountSelect(event){
        this.registrationObj.accountId = event.detail;
    }

    handleAccountRemove(event){
        this.registrationObj.accountId = null;
    }

    handleRegister(){
        console.log('this.registrationObj'+JSON.stringify(this.registrationObj));
        if(this.validateInputData()){
            this.isValid = true;
            if(!this.registrationObj.accountId){
                this.isValid = false;
                this.showToast('error', 'Error: Please select a valid Organization Name.', 'Error');
                this.template.querySelector("c-catv_custom_lookup").handleSearchFocus();
            }
            if(this.isValid){
                this.showSpinner = true;
                createRequest({ 
                    inputData : JSON.stringify(this.registrationObj)
                }).then(result => {
                    this.showSpinner = false;
                    if (result == 'Successfully Registered' || result == 'Contact exists but no pending Account Access Requests') {
                        this.showMessage = true;
                        //this.successMessage = true;
                        this.liveMessage = '';
                        setTimeout(() => {
                            this.liveMessage = 'Your Registration request has been successfully submitted for CATV review. Please expect a notification email once approved.';
                        },2000);
                        
                    } else if (result == 'Contact and User both exists') {
                        this.template.querySelector('c-catv_custom_toast').showToast('warning', 'Warning: User already exists with the provided email. Kindly login.');                
                    } else if (result == 'Contact exists and Account Access Request pending') {
                        this.template.querySelector('c-catv_custom_toast').showToast('warning', 'Warning: Your Registration request is already under review. Please expect a notification email once approved.');                
                    } else if (result == 'Contact already exits for the selected account') {
                        this.template.querySelector('c-catv_custom_toast').showToast('warning', 'Warning: Contact already exits for the selected account.');                
                    } else if (result == 'Pending Account Access Requests exist') {
                        this.template.querySelector('c-catv_custom_toast').showToast('warning', 'Warning: There is already a pending Registration request with the selected account.');                
                    } 
                }).catch(error => {
                    this.showSpinner = false;
                    this.template.querySelector('c-catv_custom_toast').showToast('error', 'Error: Unexpected error occured, please try after some time.');
                })
            }
        }
    }

    formatPhone(obj) {
        var numbers = obj.value.replace(/\D/g, ""),
            char = {
                0: "(",
                3: ") ",
                6: "-"
            };
        obj.value = "";
        for (var i = 0; i < numbers.length; i++) {
            obj.value += (char[i] || "") + numbers[i];
        }
    }

    validateInputData() {
        var isValidVal = true;
        var inputFields = this.template.querySelectorAll('.reqInpField');
        inputFields.forEach(inputField => {
            if(!inputField.checkValidity()) {
                inputField.reportValidity();
                isValidVal = false;
            }
        });
        var allInput = this.template.querySelector(".slds-has-error");
        if (allInput) {
            allInput.focus();
        }
        return isValidVal;
    }

    handleRefresh(){
        this.navigateToPage('Home');
    }

    navigateToPage(pageName){
        this[NavigationMixin.GenerateUrl]({
            type: "comm__namedPage",
            attributes: {
                name: pageName
            }
        }).then(url => {
            window.open(url, "_self");
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    get selectedOrganization(){
        return this.registrationObj && this.registrationObj.provideOrRequestor && this.registrationObj.provideOrRequestor == 'Provider' 
               ? JSON.stringify(['Provider']) 
               : JSON.stringify(['City', 'County', 'State', 'University']);
    }

    get showAccountOptions(){
        return this.registrationObj && this.registrationObj.provideOrRequestor;
    }
}