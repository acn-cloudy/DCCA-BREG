import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import MDS_Style from '@salesforce/resourceUrl/MDS_Style'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Catv_error_handling_cmp extends NavigationMixin(LightningElement){
    backgroundImg = MDS_Style + '/media/images/catv-background.svg';

    @track showMessage;
    errorDescription;
    decryptedEmail;

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const rawErrorDesc = urlParams.get('ErrorDescription'); // No%20User%20Found
        this.errorDescription = decodeURIComponent(rawErrorDesc); // "No User Found"
        const encyptedEmail = this.errorDescription.split('@')[1];
        if (this.errorDescription.includes('No User Found')) {
            this[NavigationMixin.GenerateUrl]({
                type: "comm__namedPage",
                attributes: {
                    name: "Registration__c"
                },
                state: {
                    email: encyptedEmail
                }
            }).then(url => {
                window.open(url, "_self");
            });

        }else if(this.errorDescription.includes('Access Request Pending')){
            this.showMessage = true;
        }
    }

    handleRefresh(){
        this.navigateToPage('Home');
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
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
}